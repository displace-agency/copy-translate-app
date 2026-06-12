#!/usr/bin/env bash
# One-time: create a stable self-signed code-signing identity so the app's
# signature (and therefore its macOS Accessibility/TCC grant) stays constant
# across rebuilds. Idempotent — safe to run repeatedly.
set -euo pipefail

IDENTITY="CopyTranslate Self-Signed"
KEYCHAIN="login.keychain"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "✓ Signing identity '$IDENTITY' already exists — nothing to do."
    exit 0
fi

echo "→ Generating self-signed code-signing certificate '$IDENTITY'…"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cfg.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = CopyTranslate Self-Signed
[v3]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -config "$TMP/cfg.cnf" >/dev/null 2>&1

# Apple's `security import` can't verify OpenSSL 3's default PKCS12 MAC, so emit
# a legacy-compatible bundle (SHA1 MAC + 3DES).
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" -passout pass:ct -name "$IDENTITY" \
    -macalg sha1 -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES >/dev/null 2>&1 || \
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" -passout pass:ct -name "$IDENTITY" >/dev/null 2>&1

# Import key + cert; grant codesign permission to use the key without UI prompts.
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P ct \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null

# Trust the cert for code signing (best-effort; the TCC requirement matches on
# the leaf-cert hash, which doesn't require a trusted chain — so this is a nicety
# for `codesign --verify`, not load-bearing). May ask for your login password.
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" >/dev/null 2>&1 || \
    echo "  (note: cert not added to trust roots — fine, signing still works)"

echo ""
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "✓ Created code-signing identity: $IDENTITY"
    echo "  Future 'bash scripts/build-app.sh' runs sign with it automatically."
    echo "  On the first build, if macOS asks whether codesign may use the key,"
    echo "  click 'Always Allow'."
else
    echo "✗ Identity not found after import." >&2
    echo "  GUI fallback: Keychain Access → Certificate Assistant → Create a Certificate" >&2
    echo "  → Name 'CopyTranslate Self-Signed', Identity Type 'Self Signed Root'," >&2
    echo "  → Certificate Type 'Code Signing'. Then re-run build-app.sh." >&2
    exit 1
fi
