#!/bin/sh
set -eu
umask 077
out=${1:?fixture directory required}
mkdir -p "$out"
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout "$out/ca.key" -out "$out/ca.pem" -days 2 -subj /CN=pi-tv-test-ca -addext basicConstraints=critical,CA:TRUE -addext keyUsage=critical,keyCertSign,cRLSign >/dev/null 2>&1
for role in server client; do
  openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout "$out/$role.key" -out "$out/$role.csr" -subj "/CN=pi-tv-$role" >/dev/null 2>&1
  if [ "$role" = server ]; then usage=serverAuth; san='subjectAltName=DNS:pi-tv.test'; else usage=clientAuth; san='subjectAltName=DNS:pi-tv-client.test'; fi
  printf 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=%s\n%s\n' "$usage" "$san" > "$out/$role.ext"
  openssl x509 -req -in "$out/$role.csr" -CA "$out/ca.pem" -CAkey "$out/ca.key" -CAcreateserial -out "$out/$role.pem" -days 1 -extfile "$out/$role.ext" >/dev/null 2>&1
  openssl x509 -in "$out/$role.pem" -outform DER -out "$out/$role.der"
  openssl pkcs8 -topk8 -nocrypt -in "$out/$role.key" -outform DER -out "$out/$role.key.der"
done
openssl x509 -in "$out/ca.pem" -outform DER -out "$out/ca.der"
touch "$out/index.txt"
printf '01\n' > "$out/serial"
cat > "$out/ca.cnf" <<CONFIG
[ ca ]
default_ca = local
[ local ]
database = $out/index.txt
serial = $out/serial
new_certs_dir = $out
certificate = $out/ca.pem
private_key = $out/ca.key
default_md = sha256
policy = policy
[ policy ]
commonName = supplied
[ server_ext ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = DNS:pi-tv.test
CONFIG
openssl ca -batch -config "$out/ca.cnf" -in "$out/server.csr" -out "$out/expired.pem" -startdate 20200101000000Z -enddate 20200102000000Z -extensions server_ext -notext >/dev/null 2>&1
openssl x509 -in "$out/expired.pem" -outform DER -out "$out/expired.der"
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout "$out/alternate.key" -out "$out/alternate.csr" -subj /CN=pi-tv-alternate >/dev/null 2>&1
openssl x509 -req -in "$out/alternate.csr" -CA "$out/ca.pem" -CAkey "$out/ca.key" -CAcreateserial -out "$out/alternate.pem" -days 1 -extfile "$out/client.ext" >/dev/null 2>&1
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout "$out/alternate-server.key" -out "$out/alternate-server.csr" -subj /CN=pi-tv-alternate-server >/dev/null 2>&1
openssl x509 -req -in "$out/alternate-server.csr" -CA "$out/ca.pem" -CAkey "$out/ca.key" -CAcreateserial -out "$out/alternate-server.pem" -days 1 -extfile "$out/server.ext" >/dev/null 2>&1
