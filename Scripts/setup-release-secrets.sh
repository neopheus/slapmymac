#!/bin/bash
set -euo pipefail

# Setup GitHub repository secrets for automated releases
# Requires: gh CLI authenticated
#
# This script helps you configure the 5 secrets needed for
# automated signing, notarization, and Homebrew tap updates.

REPO="neopheus/slapmymac"

echo "=== SlapMyMac Release Secrets Setup ==="
echo ""
echo "This will configure GitHub secrets for: $REPO"
echo "You need:"
echo "  1. A 'Developer ID Application' certificate (.p12)"
echo "  2. Your Apple ID email"
echo "  3. Your Team ID (from developer.apple.com)"
echo "  4. An app-specific password (appleid.apple.com → Security → App-Specific Passwords)"
echo "  5. A GitHub PAT with repo scope (for Homebrew tap updates)"
echo ""

# 1. Developer ID Certificate
echo "--- Step 1: Developer ID Certificate ---"
echo "Export your 'Developer ID Application' certificate from Keychain Access as .p12"
read -rp "Path to .p12 file: " P12_PATH
read -rsp "Certificate password: " CERT_PASSWORD
echo ""

P12_BASE64=$(base64 < "$P12_PATH")
echo "$P12_BASE64" | gh secret set DEVELOPER_ID_CERTIFICATE_P12 --repo "$REPO"
echo "$CERT_PASSWORD" | gh secret set DEVELOPER_ID_CERTIFICATE_PASSWORD --repo "$REPO"
echo "✓ Certificate uploaded"

# 2. Developer ID Name
echo ""
echo "--- Step 2: Signing Identity ---"
echo "Find it with: security find-identity -v -p codesigning"
read -rp "Developer ID name (e.g. 'Developer ID Application: Your Name (TEAMID)'): " DEV_ID
echo "$DEV_ID" | gh secret set DEVELOPER_ID_NAME --repo "$REPO"
echo "✓ Signing identity set"

# 3. Apple ID for notarization
echo ""
echo "--- Step 3: Notarization Credentials ---"
read -rp "Apple ID email: " APPLE_ID
read -rp "Team ID (10-char alphanumeric): " TEAM_ID
read -rsp "App-specific password: " APP_PASSWORD
echo ""

echo "$APPLE_ID" | gh secret set APPLE_ID --repo "$REPO"
echo "$TEAM_ID" | gh secret set TEAM_ID --repo "$REPO"
echo "$APP_PASSWORD" | gh secret set APP_SPECIFIC_PASSWORD --repo "$REPO"
echo "✓ Notarization credentials set"

# 4. Homebrew tap token
echo ""
echo "--- Step 4: Homebrew Tap Token ---"
echo "Create a GitHub PAT at: https://github.com/settings/tokens/new"
echo "Scope: 'repo' (to push to neopheus/homebrew-slapmymac)"
read -rsp "GitHub PAT: " TAP_TOKEN
echo ""

echo "$TAP_TOKEN" | gh secret set HOMEBREW_TAP_TOKEN --repo "$REPO"
echo "✓ Homebrew tap token set"

echo ""
echo "=== All secrets configured! ==="
echo ""
echo "Next steps:"
echo "  1. Create the Homebrew tap repo: gh repo create neopheus/homebrew-slapmymac --public"
echo "  2. Push the initial Cask: see Scripts/init-homebrew-tap.sh"
echo "  3. Tag a release: git tag v1.0.0 && git push --tags"
