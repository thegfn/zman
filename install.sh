#!/bin/bash
set -euo pipefail

# CONFIG
SRC_DIR="$(pwd)"
INSTALL_DIR="/opt/zman"
WRAPPER="/usr/local/bin/zman"

# Ensure the source directory exists
if [[ ! -d "$SRC_DIR" || ! -f "$SRC_DIR/zman.sh" ]]; then
  echo "[ERROR] ZMAN source directory or zman.sh not found at $SRC_DIR"
  exit 1
fi

# Step 1: Move to /opt
echo "[INFO] Installing ZMAN to $INSTALL_DIR..."
sudo rm -rf "$INSTALL_DIR"
sudo cp -r "$SRC_DIR" "$INSTALL_DIR"
sudo chmod -R 755 "$INSTALL_DIR"

# Step 2: Create wrapper
echo "[INFO] Creating wrapper at $WRAPPER..."
sudo tee "$WRAPPER" >/dev/null <<EOF
#!/bin/bash
exec $INSTALL_DIR/zman.sh "\$@"
EOF

sudo chmod +x "$WRAPPER"

# Step 3: Logfile setup
sudo mkdir -p /var/log
sudo touch /var/log/zman.log
sudo chmod 644 /var/log/zman.log

# Step 4: Verify
echo "[INFO] Verifying installation..."
if command -v zman >/dev/null; then
  echo "[SUCCESS] ZMAN is installed and available as 'zman'"
  echo
  zman --help
else
  echo "[ERROR] Wrapper not available in PATH"
  exit 1
fi
