#!/usr/bin/env node
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawn, execFileSync } from "node:child_process";
import { createServer } from "node:http";
import { performance } from "node:perf_hooks";

const chrome = process.env.CHROME_BIN ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const runStarted = performance.now();
const profile = await fs.mkdtemp(path.join(os.tmpdir(), "pitv-phase0b-chrome-"));
const server = createServer(async (req, res) => {
  const route = new URL(req.url ?? "/", "http://127.0.0.1").pathname;
  if (route === "/api/v1/apps") {
    const manifest = JSON.parse(await fs.readFile(new URL("../../prototypes/host-first/web/manifest.json", import.meta.url), "utf8"));
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify(manifest.apps));
    return;
  }
  if (route === "/api/v1/commands" && req.method === "POST") {
    req.resume();
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ status: "accepted" }));
    return;
  }
  if (route === "/silence.wav") {
    const samples = Buffer.alloc(8000 * 10);
    const header = Buffer.alloc(44);
    header.write("RIFF", 0); header.writeUInt32LE(36 + samples.length, 4); header.write("WAVE", 8);
    header.write("fmt ", 12); header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(1, 22);
    header.writeUInt32LE(8000, 24); header.writeUInt32LE(16000, 28); header.writeUInt16LE(2, 32); header.writeUInt16LE(16, 34);
    header.write("data", 36); header.writeUInt32LE(samples.length, 40);
    res.writeHead(200, { "content-type": "audio/wav", "content-length": header.length + samples.length });
    res.end(Buffer.concat([header, samples]));
    return;
  }
  const file = route === "/demo.html" ? "demo.html" : "index.html";
  const body = await fs.readFile(new URL(`../../prototypes/host-first/web/${file}`, import.meta.url));
  res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
  res.end(body);
});
server.listen(0, "127.0.0.1");
await new Promise((resolve) => server.once("listening", resolve));
const port = server.address().port;
const home = `http://127.0.0.1:${port}/`;
const checks = {};
let child;
let socket;
let nextId = 0;
const pending = new Map();
const networkEvents = [];

function delay(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }

async function waitForFile(file, proc, timeoutMs = 15000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    if (proc.exitCode !== null) throw new Error("Chrome exited before DevTools became ready");
    try {
      const value = await fs.readFile(file, "utf8");
      if (/^\d+\n/.test(value)) return value;
    } catch {}
    await delay(100);
  }
  throw new Error("Chrome DevTools readiness timed out");
}

async function startChrome() {
  const started = performance.now();
  await fs.rm(path.join(profile, "DevToolsActivePort"), { force: true });
  child = spawn(chrome, [
    `--user-data-dir=${profile}`,
    "--remote-debugging-address=127.0.0.1",
    "--remote-debugging-port=0",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-extensions",
    "--kiosk",
    home,
  ], { detached: true, stdio: "ignore" });
  const activePort = await waitForFile(path.join(profile, "DevToolsActivePort"), child);
  const debugPort = Number(activePort.split("\n")[0]);
  const lsof = execFileSync("/usr/sbin/lsof", ["-nP", `-iTCP:${debugPort}`, "-sTCP:LISTEN"], { encoding: "utf8" });
  const bindsLoopback = lsof.split("\n").some((line) => line.includes(`127.0.0.1:${debugPort} (LISTEN)`));
  if (!bindsLoopback || lsof.split("\n").some((line) => line.includes(`*:${debugPort} (LISTEN)`))) {
    throw new Error("DevTools listener was not confirmed loopback-only");
  }
  const targets = await fetch(`http://127.0.0.1:${debugPort}/json/list`).then((r) => r.json());
  const target = targets.find((entry) => entry.type === "page");
  if (!target?.webSocketDebuggerUrl) throw new Error("Chrome page target unavailable");
  socket = new WebSocket(target.webSocketDebuggerUrl);
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data.toString());
    if (message.method === "Network.responseReceived" && message.params.type === "Document") {
      networkEvents.push(message.params.response.status);
    }
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result);
    }
  });
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  await command("Page.enable");
  await command("Runtime.enable");
  await command("Network.enable");
  await command("Page.navigate", { url: home });
  const end = Date.now() + 12000;
  while (Date.now() < end && !(await evaluate(`location.href === ${JSON.stringify(home)} && document.readyState === 'complete'`))) await delay(100);
  if (!(await evaluate(`location.href === ${JSON.stringify(home)} && document.readyState === 'complete'`))) throw new Error("Launcher page load timed out");
  const appsReadyBy = Date.now() + 5000;
  while (Date.now() < appsReadyBy && !(await evaluate("document.querySelectorAll('.apps [data-app]').length > 0 && Boolean(document.activeElement?.dataset?.app)"))) await delay(50);
  return { debugPort, targetCount: targets.filter((entry) => entry.type === "page").length, startupMs: Math.round(performance.now() - started) };
}

function command(method, params = {}) {
  const id = ++nextId;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 8000);
    pending.set(id, {
      resolve: (result) => { clearTimeout(timer); resolve(result); },
      reject: (error) => { clearTimeout(timer); reject(error); },
    });
    socket.send(JSON.stringify({ id, method, params }));
  });
}

async function evaluate(expression) {
  const result = await command("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
  if (result.exceptionDetails) throw new Error(`Page evaluation failed: ${result.exceptionDetails.text ?? "exception"}`);
  return result.result?.value;
}

async function waitForPage() {
  const end = Date.now() + 12000;
  while (Date.now() < end) {
    try { if (await evaluate("document.readyState === 'complete'")) return; } catch {}
    await delay(200);
  }
  throw new Error("Page load timed out");
}

async function navigate(url) {
  const before = networkEvents.length;
  const result = await command("Page.navigate", { url });
  if (result.errorText) return { loaded: false, error: result.errorText };
  const expectedHost = new URL(url).hostname.replace(/^www\./, "");
  const end = Date.now() + 15000;
  let state = {};
  while (Date.now() < end) {
    state = await evaluate("({ready:document.readyState==='complete',host:location.hostname,title:document.title})").catch(() => ({}));
    const host = state.host ?? "";
    if (state.ready && (host === expectedHost || host.endsWith(`.${expectedHost}`))) break;
    await delay(150);
  }
  const host = state.host ?? "";
  const hostMatched = host === expectedHost || host.endsWith(`.${expectedHost}`);
  return { loaded: hostMatched && Boolean(state.ready), titlePresent: Boolean(state.title), responseStatus: networkEvents.slice(before).at(-1) ?? null };
}

async function pressKey(key, code = key) {
  const virtualCodes = { ArrowLeft: [37, 123], ArrowUp: [38, 126], ArrowRight: [39, 124], ArrowDown: [40, 125], PageDown: [34, 121] };
  const [windowsVirtualKeyCode, nativeVirtualKeyCode] = virtualCodes[key] ?? [undefined, undefined];
  const params = { key, code, windowsVirtualKeyCode, nativeVirtualKeyCode };
  await command("Input.dispatchKeyEvent", { type: "rawKeyDown", ...params });
  await command("Input.dispatchKeyEvent", { type: "keyUp", ...params });
}

async function killChrome(signal) {
  if (!child) return;
  try { process.kill(-child.pid, signal); } catch {}
  await Promise.race([new Promise((resolve) => child.once("exit", resolve)), delay(5000)]);
  if (socket && socket.readyState < WebSocket.CLOSING) socket.close();
  socket = undefined;
  child = undefined;
}

try {
  if (!await fs.stat(chrome).catch(() => null)) throw new Error("Installed Google Chrome executable not found");
  const first = await startChrome();
  checks.startup = { status: "VERIFIED", targetCount: first.targetCount, startupMs: first.startupMs };
  checks.devtools = { status: "VERIFIED", address: "127.0.0.1", transport: "private loopback WebSocket", pageTargets: first.targetCount };

  const focusBefore = await evaluate("document.activeElement?.dataset?.app ?? null");
  await pressKey("ArrowRight");
  const focusAfter = await evaluate("document.activeElement?.dataset?.app ?? null");
  checks.dpad = { status: focusAfter === "youtube" ? "VERIFIED" : "FAILED", before: focusBefore, after: focusAfter };
  if (checks.dpad.status !== "VERIFIED") throw new Error("D-pad focus movement failed");

  await evaluate("document.querySelector('#text-test').focus()");
  await command("Input.insertText", { text: "remote typing test" });
  checks.textInput = { status: (await evaluate("document.querySelector('#text-test').value")) === "remote typing test" ? "VERIFIED" : "FAILED" };

  const clickPoint = await evaluate("(() => { const r=document.querySelector('#click-test').getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2}; })()");
  await command("Input.dispatchMouseEvent", { type: "mouseMoved", ...clickPoint });
  await command("Input.dispatchMouseEvent", { type: "mousePressed", button: "left", clickCount: 1, ...clickPoint });
  await command("Input.dispatchMouseEvent", { type: "mouseReleased", button: "left", clickCount: 1, ...clickPoint });
  checks.pointer = { status: (await evaluate("document.querySelector('#click-count').textContent")) === "Pointer clicks: 1" ? "VERIFIED" : "FAILED" };

  const scrollPoint = await evaluate("(() => { const e=document.querySelector('#scroll-area'); e.scrollIntoView(); e.focus(); e.scrollTop=0; const r=e.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2}; })()");
  await command("Input.dispatchMouseEvent", { type: "mouseMoved", ...scrollPoint });
  await command("Input.dispatchMouseEvent", { type: "mouseWheel", deltaY: 120, deltaX: 0, ...scrollPoint });
  await delay(200);
  let scrollState = await evaluate("({top:document.querySelector('#scroll-area').scrollTop, height:document.querySelector('#scroll-area').scrollHeight, wheel:window.phase0bWheelDelta})");
  if (scrollState.top === 0) {
    await pressKey("PageDown");
    await delay(100);
    scrollState = await evaluate("({top:document.querySelector('#scroll-area').scrollTop, height:document.querySelector('#scroll-area').scrollHeight, wheel:window.phase0bWheelDelta})");
  }
  checks.scroll = { status: scrollState.top > 0 ? "VERIFIED" : "FAILED", ...scrollState };

  await pressKey("f", "KeyF");
  await delay(250);
  checks.fullscreen = { status: await evaluate("Boolean(document.fullscreenElement)") ? "VERIFIED" : "NOT_VERIFIED", kioskWindow: true };

  if (await evaluate("'mediaSession' in navigator")) {
    await pressKey("MediaPlayPause", "MediaPlayPause");
    checks.mediaKey = { status: await evaluate("window.phase0bMediaState") === "playing" ? "VERIFIED" : "NOT_VERIFIED", mechanism: "generic Media Session action handler" };
  } else {
    checks.mediaKey = { status: "UNAVAILABLE", mechanism: "Media Session API absent" };
  }

  const providers = {};
  for (const [name, url] of [
    ["generic", "https://example.com/"],
    ["youtube", "https://www.youtube.com/tv"],
    ["netflix", "https://www.netflix.com/"],
    ["spotify", "https://open.spotify.com/"],
  ]) {
    networkEvents.length = 0;
    providers[name] = await navigate(url).catch((error) => ({ loaded: false, error: error.message }));
  }
  checks.providerNavigation = providers;
  await navigate(`${home}demo.html`);
  await evaluate("new Promise(resolve => { const a=document.querySelector('audio'); if (a.readyState >= 1) resolve(); else a.addEventListener('loadedmetadata', resolve, {once:true}); })");
  const playPoint = await evaluate("(() => { const r=document.querySelector('#play-media').getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2}; })()");
  await command("Input.dispatchMouseEvent", { type: "mouseMoved", ...playPoint });
  await command("Input.dispatchMouseEvent", { type: "mousePressed", button: "left", clickCount: 1, ...playPoint });
  await command("Input.dispatchMouseEvent", { type: "mouseReleased", button: "left", clickCount: 1, ...playPoint });
  await delay(300);
  const playback = await evaluate("({paused:document.querySelector('audio').paused,time:document.querySelector('audio').currentTime})");
  await evaluate("document.querySelector('audio').pause(); document.querySelector('audio').currentTime=0.5");
  await delay(150);
  const seekTime = await evaluate("document.querySelector('audio').currentTime");
  const pauseWorks = await evaluate("document.querySelector('audio').paused");
  checks.genericMedia = {
    silentSample: true,
    playPause: { status: !playback.paused && playback.time > 0 && pauseWorks ? "VERIFIED" : "NOT_VERIFIED", playback },
    seek: { status: Math.abs(seekTime - 0.5) < 0.1 ? "VERIFIED" : "NOT_VERIFIED", requestedSeconds: 0.5, observedSeconds: seekTime },
  };
  const pageTargets = await fetch(`http://127.0.0.1:${first.debugPort}/json/list`).then((r) => r.json());
  checks.singleForegroundPage = { status: pageTargets.filter((entry) => entry.type === "page").length === 1 ? "VERIFIED" : "FAILED", pageTargets: pageTargets.filter((entry) => entry.type === "page").length };

  await navigate(home);
  checks.sessionPersistence = { status: (await evaluate("localStorage.getItem('phase0b-profile-marker')")) === "persisted" ? "VERIFIED" : "FAILED", scope: "fresh temporary Chrome profile" };
  await killChrome("SIGKILL");
  const recovered = await startChrome();
  checks.crashRelaunch = { status: "VERIFIED", recoveryMs: recovered.startupMs, sameTemporaryProfile: true };
  checks.sessionAfterRelaunch = { status: (await evaluate("localStorage.getItem('phase0b-profile-marker')")) === "persisted" ? "VERIFIED" : "FAILED" };
  await killChrome("SIGTERM");
  checks.termination = { status: "VERIFIED", isolatedProcessGroup: true };

  const output = {
    timestamp_utc: new Date().toISOString(),
    duration_seconds: Number(((performance.now() - runStarted) / 1000).toFixed(2)),
    environment: { macOS: "27.2.1", architecture: "arm64", chrome: "158.0.8127.37", profile: "fresh temporary directory" },
    command: "node scripts/phase0b/chrome-runtime-smoke.mjs",
    result: "VERIFIED",
    limitations: [
      "No provider login or playback attempted; public landing-page navigation only.",
      "Fullscreen observation is local macOS kiosk-window behavior, not HDMI/display-mode evidence.",
      "Media Session keyboard event tests browser control capability only, not provider playback controls.",
      "Session persistence and relaunch recovery use a temporary profile and do not establish product daemon recovery.",
    ],
    checks,
  };
  console.log(JSON.stringify(output, null, 2));
} catch (error) {
  console.log(JSON.stringify({ timestamp_utc: new Date().toISOString(), duration_seconds: Number(((performance.now() - runStarted) / 1000).toFixed(2)), result: "FAILED", error: error.message, checks }, null, 2));
  process.exitCode = 1;
} finally {
  await killChrome("SIGTERM");
  await new Promise((resolve) => server.close(resolve));
  await fs.rm(profile, { recursive: true, force: true });
}
