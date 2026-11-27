use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    http::{HeaderMap, StatusCode},
    response::{Html, IntoResponse},
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::os::unix::process::CommandExt;
use std::{
    net::SocketAddr,
    process::{Child, Command, Stdio},
    sync::{Arc, Mutex},
};
use tokio::net::TcpListener;
use tracing::{info, warn};

#[derive(Clone, Serialize, Deserialize)]
struct App {
    id: String,
    name: String,
    url: String,
    #[serde(default)]
    description: String,
}
#[derive(Deserialize)]
struct Manifest {
    version: u8,
    apps: Vec<App>,
}

fn validate_manifest(manifest: &Manifest) -> Result<(), &'static str> {
    let mut ids = std::collections::HashSet::new();
    if manifest.version != 1 {
        return Err("unsupported manifest version");
    }
    if manifest.apps.iter().any(|a| {
        a.id.is_empty()
            || !ids.insert(&a.id)
            || !(a.url.starts_with("http://")
                || a.url.starts_with("https://")
                || (a.url.starts_with('/') && !a.url.starts_with("//")))
    }) {
        return Err("invalid application manifest");
    }
    Ok(())
}

#[derive(Clone, Serialize)]
struct Capabilities {
    runtime: &'static str,
    browser: bool,
    fullscreen: bool,
    remote_debugging: bool,
}

#[derive(Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum CommandRequest {
    Launch { app_id: String },
    Home,
    Stop,
}

#[derive(Serialize)]
struct ApiError {
    error: &'static str,
    detail: String,
}

trait RuntimeAdapter: Send + Sync {
    fn launch(&self, url: &str) -> Result<(), String>;
    fn stop(&self) -> Result<(), String>;
    fn capabilities(&self) -> Capabilities;
}

struct MacChrome {
    child: Mutex<Option<Child>>,
    binary: String,
    profile: String,
}

impl RuntimeAdapter for MacChrome {
    fn launch(&self, url: &str) -> Result<(), String> {
        self.stop()?;
        let child = Command::new(&self.binary)
            .args([
                format!("--user-data-dir={}", self.profile),
                "--no-first-run".into(),
                "--no-default-browser-check".into(),
                "--kiosk".into(),
                url.into(),
            ])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .process_group(0)
            .spawn()
            .map_err(|e| format!("browser start failed: {e}"))?;
        *self
            .child
            .lock()
            .map_err(|_| "runtime lock poisoned".to_string())? = Some(child);
        Ok(())
    }
    fn stop(&self) -> Result<(), String> {
        if let Some(mut child) = self
            .child
            .lock()
            .map_err(|_| "runtime lock poisoned".to_string())?
            .take()
        {
            if child.try_wait().map_err(|e| e.to_string())?.is_none() {
                let group = -(child.id() as i32);
                unsafe {
                    libc::kill(group, libc::SIGTERM);
                }
                for _ in 0..40 {
                    if child.try_wait().map_err(|e| e.to_string())?.is_some() {
                        return Ok(());
                    }
                    std::thread::sleep(std::time::Duration::from_millis(50));
                }
                unsafe {
                    libc::kill(group, libc::SIGKILL);
                }
                let _ = child.wait();
            }
        }
        Ok(())
    }
    fn capabilities(&self) -> Capabilities {
        Capabilities {
            runtime: "macos-chrome",
            browser: true,
            fullscreen: true,
            remote_debugging: false,
        }
    }
}

#[derive(Clone)]
struct AppState {
    apps: Arc<Vec<App>>,
    runtime: Arc<dyn RuntimeAdapter>,
}

fn local_request(headers: &HeaderMap) -> bool {
    headers
        .get("host")
        .and_then(|v| v.to_str().ok())
        .is_some_and(|v| v.starts_with("127.0.0.1:") || v.starts_with("localhost:"))
}

fn same_local_origin(headers: &HeaderMap) -> bool {
    let host = headers.get("host").and_then(|v| v.to_str().ok());
    let origin = headers.get("origin").and_then(|v| v.to_str().ok());
    matches!((host, origin), (Some(host), Some(origin)) if origin.strip_prefix("http://") == Some(host) || origin.strip_prefix("https://") == Some(host))
}

async fn home(headers: HeaderMap) -> impl IntoResponse {
    if !local_request(&headers) {
        return (StatusCode::FORBIDDEN, "loopback only").into_response();
    }
    Html(include_str!("../../web/index.html")).into_response()
}
async fn health(headers: HeaderMap) -> impl IntoResponse {
    if !local_request(&headers) {
        return (StatusCode::FORBIDDEN, "loopback only").into_response();
    }
    Json(serde_json::json!({"status": "ok", "protocol": 1})).into_response()
}
async fn apps_route(State(state): State<AppState>, headers: HeaderMap) -> impl IntoResponse {
    if !local_request(&headers) {
        return (StatusCode::FORBIDDEN, "loopback only").into_response();
    }
    Json(state.apps.as_ref()).into_response()
}
async fn capabilities(State(state): State<AppState>, headers: HeaderMap) -> impl IntoResponse {
    if !local_request(&headers) {
        return (StatusCode::FORBIDDEN, "loopback only").into_response();
    }
    Json(state.runtime.capabilities()).into_response()
}
async fn command(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(cmd): Json<CommandRequest>,
) -> impl IntoResponse {
    if !local_request(&headers) || !same_local_origin(&headers) {
        return (StatusCode::FORBIDDEN, "loopback only").into_response();
    }
    let result = match cmd {
        CommandRequest::Launch { app_id } => state
            .apps
            .iter()
            .find(|a| a.id == app_id)
            .ok_or_else(|| "unknown application".to_string())
            .and_then(|app| state.runtime.launch(&app.url)),
        CommandRequest::Home => state
            .apps
            .iter()
            .find(|a| a.id == "home")
            .ok_or_else(|| "home application missing".to_string())
            .and_then(|app| state.runtime.launch(&app.url)),
        CommandRequest::Stop => state.runtime.stop(),
    };
    match result {
        Ok(()) => (
            StatusCode::OK,
            Json(serde_json::json!({"status":"accepted"})),
        )
            .into_response(),
        Err(detail) => {
            warn!(error = %detail, "command rejected");
            (
                StatusCode::BAD_REQUEST,
                Json(ApiError {
                    error: "command_failed",
                    detail,
                }),
            )
                .into_response()
        }
    }
}
async fn websocket(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
    headers: HeaderMap,
) -> impl IntoResponse {
    if !local_request(&headers) || !same_local_origin(&headers) {
        return (StatusCode::FORBIDDEN, "loopback only").into_response();
    }
    ws.on_upgrade(move |socket| ws_session(socket, state))
        .into_response()
}
async fn ws_session(mut socket: WebSocket, state: AppState) {
    while let Some(Ok(Message::Text(text))) = socket.recv().await {
        let result = serde_json::from_str::<CommandRequest>(&text)
            .map_err(|_| "invalid command JSON".to_string())
            .and_then(|cmd| match cmd {
                CommandRequest::Launch { app_id } => state
                    .apps
                    .iter()
                    .find(|a| a.id == app_id)
                    .ok_or_else(|| "unknown application".to_string())
                    .and_then(|a| state.runtime.launch(&a.url)),
                CommandRequest::Home => state
                    .apps
                    .iter()
                    .find(|a| a.id == "home")
                    .ok_or_else(|| "home application missing".to_string())
                    .and_then(|a| state.runtime.launch(&a.url)),
                CommandRequest::Stop => state.runtime.stop(),
            });
        let reply = match result {
            Ok(()) => serde_json::json!({"status":"accepted"}),
            Err(e) => serde_json::json!({"status":"error","error":"command_failed","detail":e}),
        };
        if socket
            .send(Message::Text(reply.to_string().into()))
            .await
            .is_err()
        {
            break;
        }
    }
}

fn routes(state: AppState) -> Router {
    Router::new()
        .route("/", get(home))
        .route("/api/v1/health", get(health))
        .route("/api/v1/apps", get(apps_route))
        .route("/api/v1/capabilities", get(capabilities))
        .route("/api/v1/commands", post(command))
        .route("/api/v1/events", get(websocket))
        .with_state(state)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt().json().with_target(false).init();
    let port: u16 = std::env::var("PITV_PORT")
        .unwrap_or_else(|_| "8765".into())
        .parse()?;
    let manifest: Manifest = serde_json::from_str(include_str!("../../web/manifest.json"))?;
    validate_manifest(&manifest)?;
    let home_url = format!("http://127.0.0.1:{port}/");
    let mut apps = manifest.apps;
    for app in &mut apps {
        if app.url.starts_with('/') {
            app.url = format!("http://127.0.0.1:{port}{}", app.url);
        }
    }
    apps.push(App {
        id: "home".into(),
        name: "Home".into(),
        url: home_url,
        description: "Return to launcher".into(),
    });
    let runtime: Arc<dyn RuntimeAdapter> = Arc::new(MacChrome {
        child: Mutex::new(None),
        binary: std::env::var("CHROME_BIN").unwrap_or_else(|_| {
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome".into()
        }),
        profile: std::env::var("PITV_PROFILE_DIR").unwrap_or_else(|_| {
            format!(
                "{}/.pitv-host-first-profile",
                std::env::var("TMPDIR").unwrap_or_else(|_| "/tmp".into())
            )
        }),
    });
    let state = AppState {
        apps: Arc::new(apps),
        runtime,
    };
    let home_url = state
        .apps
        .iter()
        .find(|a| a.id == "home")
        .expect("home manifest entry")
        .url
        .clone();
    let startup_runtime = state.runtime.clone();
    let app = routes(state);
    let listener = TcpListener::bind(SocketAddr::from(([127, 0, 0, 1], port))).await?;
    info!(address = %listener.local_addr()?, "host-first daemon listening");
    let server = tokio::spawn(async move {
        axum::serve(listener, app)
            .with_graceful_shutdown(async {
                let _ = tokio::signal::ctrl_c().await;
            })
            .await
    });
    startup_runtime.launch(&home_url)?;
    server.await??;
    startup_runtime.stop()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures_util::{SinkExt, StreamExt};
    use tokio_tungstenite::tungstenite::client::IntoClientRequest;

    struct MockRuntime(Mutex<Vec<String>>);
    impl RuntimeAdapter for MockRuntime {
        fn launch(&self, url: &str) -> Result<(), String> {
            self.0.lock().unwrap().push(url.into());
            Ok(())
        }
        fn stop(&self) -> Result<(), String> {
            Ok(())
        }
        fn capabilities(&self) -> Capabilities {
            Capabilities {
                runtime: "mock",
                browser: false,
                fullscreen: false,
                remote_debugging: false,
            }
        }
    }

    #[test]
    fn manifest_rejects_non_web_and_duplicate_entries() {
        let parse = |url: &str| Manifest {
            version: 1,
            apps: vec![App {
                id: "x".into(),
                name: "X".into(),
                url: url.into(),
                description: String::new(),
            }],
        };
        assert!(validate_manifest(&parse("javascript:alert(1)")).is_err());
        let duplicate = Manifest {
            version: 1,
            apps: vec![
                App {
                    id: "x".into(),
                    name: "X".into(),
                    url: "https://example.com".into(),
                    description: String::new()
                };
                2
            ],
        };
        assert!(validate_manifest(&duplicate).is_err());
        assert!(validate_manifest(&parse("https://example.com")).is_ok());
    }

    #[tokio::test]
    async fn websocket_dispatches_manifest_app_command() {
        let runtime = Arc::new(MockRuntime(Mutex::new(Vec::new())));
        let state = AppState {
            apps: Arc::new(vec![App {
                id: "demo".into(),
                name: "Demo".into(),
                url: "https://example.com".into(),
                description: String::new(),
            }]),
            runtime: runtime.clone(),
        };
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap();
        let server =
            tokio::spawn(async move { axum::serve(listener, routes(state)).await.unwrap() });
        let mut request = format!("ws://{address}/api/v1/events")
            .into_client_request()
            .unwrap();
        request
            .headers_mut()
            .insert("origin", format!("http://{address}").parse().unwrap());
        let (mut socket, _) = tokio_tungstenite::connect_async(request).await.unwrap();
        socket
            .send(tokio_tungstenite::tungstenite::Message::Text(
                r#"{"type":"launch","app_id":"demo"}"#.into(),
            ))
            .await
            .unwrap();
        let reply = socket.next().await.unwrap().unwrap().into_text().unwrap();
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(&reply).unwrap()["status"],
            "accepted"
        );
        assert_eq!(*runtime.0.lock().unwrap(), ["https://example.com"]);
        server.abort();
    }
}
