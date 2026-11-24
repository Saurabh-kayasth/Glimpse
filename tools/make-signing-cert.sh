#!/bin/zsh
# Makes the "Glimpse Local" code-signing certificate once (P3.2, docs/rollout/P3.2-stable-signing.md).
# A self-signed certificate in your login keychain, valid 10 years, usable only by /usr/bin/codesign without asking.
# It's only for signing your own builds on this Mac: other Macs don't trust it, and it can't notarize.
# Remove it any time: Keychain Access → login → My Certificates → "Glimpse Local" → Delete.
set -euo pipefail

NAME="Glimpse Local"
if security find-identity -p codesigning 2>/dev/null | grep -q "\"$NAME\""; then
  echo "\"$NAME\" already exists:"; security find-identity -p codesigning | grep "\"$NAME\""; exit 0
fi

DIR="$(mktemp -d)"; chmod 700 "$DIR"
trap 'rm -rf "$DIR"' EXIT
cat > "$DIR/cert.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Glimpse Local
O = Glimpse (local build)
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$DIR/key.pem" -out "$DIR/cert.pem" -days 3650 -config "$DIR/cert.cnf" 2>/dev/null
PW="$(openssl rand -hex 16)"   # only protects the temporary .p12 file, which is deleted below
LEGACY=(); openssl version | grep -q "^OpenSSL 3" && LEGACY=(-legacy)   # macOS's keychain reads only the older .p12 format
openssl pkcs12 -export "${LEGACY[@]}" -inkey "$DIR/key.pem" -in "$DIR/cert.pem" -name "$NAME" -out "$DIR/cert.p12" -passout "pass:$PW"
security import "$DIR/cert.p12" -k ~/Library/Keychains/login.keychain-db -P "$PW" -T /usr/bin/codesign
echo "made \"$NAME\":"; security find-identity -p codesigning | grep "\"$NAME\""
echo "(\"CSSMERR_TP_NOT_TRUSTED\" is expected for a self-signed certificate; codesign still uses it.)"
