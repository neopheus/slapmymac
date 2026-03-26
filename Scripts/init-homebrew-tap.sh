#!/bin/bash
set -euo pipefail

# Initialize the Homebrew tap repository (neopheus/homebrew-slapmymac)
# Run this once after creating the repo on GitHub

TAP_DIR="/tmp/homebrew-slapmymac"

echo "=== Initializing Homebrew Tap ==="

# Clone or create
if gh repo view neopheus/homebrew-slapmymac &>/dev/null; then
    echo "Repo exists, cloning..."
    rm -rf "$TAP_DIR"
    gh repo clone neopheus/homebrew-slapmymac "$TAP_DIR"
else
    echo "Creating repo neopheus/homebrew-slapmymac..."
    gh repo create neopheus/homebrew-slapmymac --public --description "Homebrew tap for SlapMyMac" --clone "$TAP_DIR" 2>/dev/null || {
        gh repo create neopheus/homebrew-slapmymac --public --description "Homebrew tap for SlapMyMac"
        gh repo clone neopheus/homebrew-slapmymac "$TAP_DIR"
    }
fi

cd "$TAP_DIR"

mkdir -p Casks

# Create README
cat > README.md << 'EOF'
# Homebrew Tap for SlapMyMac

Detects physical slaps on Apple Silicon MacBooks and plays sound effects.

## Install

```bash
brew install neopheus/slapmymac/slapmymac
```

## Requirements

- macOS 14+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
EOF

# Create placeholder Cask (will be updated by CI on first release)
cat > Casks/slapmymac.rb << 'EOF'
cask "slapmymac" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/neopheus/slapmymac/releases/download/v#{version}/SlapMyMac.dmg"
  name "SlapMyMac"
  desc "Detects physical slaps on Apple Silicon MacBooks and plays sound effects"
  homepage "https://github.com/neopheus/slapmymac"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "SlapMyMac.app"

  zap trash: [
    "~/Library/Preferences/com.slapmymac.app.plist",
  ]
end
EOF

git add -A
git commit -m "Initial Homebrew tap for SlapMyMac"
git push

echo ""
echo "=== Homebrew tap ready! ==="
echo "Users can install with: brew install neopheus/slapmymac/slapmymac"
echo ""
echo "The Cask will auto-update on each GitHub release."
