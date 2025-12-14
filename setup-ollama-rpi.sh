#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo " Ollama Raspberry Pi One-Go Setup"
echo "======================================"
echo

# -----------------------------
# User Inputs
# -----------------------------

read -rp "Enter LAN subnet (example: 192.168.1.0/24): " LAN_SUBNET
LAN_SUBNET=${LAN_SUBNET:-192.168.1.0/24}

read -rp "Enter Ollama model name [default: phi3:mini]: " MODEL
MODEL=${MODEL:-phi3:mini}

PORT="11434"

echo
echo "Configuration:"
echo "  LAN Subnet : ${LAN_SUBNET}"
echo "  Model      : ${MODEL}"
echo "  Port       : ${PORT}"
echo

read -rp "Proceed with setup? (y/n): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

echo
echo "==> Starting setup..."
echo

# -----------------------------
# System Update
# -----------------------------
sudo apt update -y
sudo apt upgrade -y

# -----------------------------
# Dependencies
# -----------------------------
sudo apt install -y curl ufw

# -----------------------------
# Install Ollama
# -----------------------------
if ! command -v ollama >/dev/null 2>&1; then
  echo "==> Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
else
  echo "==> Ollama already installed."
fi

# -----------------------------
# Enable Ollama
# -----------------------------
sudo systemctl enable ollama
sudo systemctl start ollama

# -----------------------------
# Ollama systemd override
# -----------------------------
sudo mkdir -p /etc/systemd/system/ollama.service.d

sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null <<EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0:${PORT}"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=5m"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

# -----------------------------
# Wait for API
# -----------------------------
echo "==> Waiting for Ollama API..."
until curl -s "http://127.0.0.1:${PORT}/api/tags" >/dev/null; do
  sleep 2
done

# -----------------------------
# Pull model
# -----------------------------
echo "==> Pulling model: ${MODEL}"
ollama pull "${MODEL}"

# -----------------------------
# Warm-up script
# -----------------------------
sudo tee /usr/local/bin/ollama-warmup.sh >/dev/null <<EOF
#!/usr/bin/env bash
set -e

PORT="${PORT}"
MODEL="${MODEL}"

until curl -s "http://127.0.0.1:\${PORT}/api/tags" >/dev/null; do
  sleep 2
done

curl -s "http://127.0.0.1:\${PORT}/api/generate" \
  -H "Content-Type: application/json" \
  -d '{
    "model":"'"${MODEL}"'",
    "prompt":"ping",
    "stream":false,
    "options":{"num_predict":8}
  }' >/dev/null
EOF

sudo chmod +x /usr/local/bin/ollama-warmup.sh

# -----------------------------
# Warm-up service
# -----------------------------
sudo tee /etc/systemd/system/ollama-warmup.service >/dev/null <<EOF
[Unit]
Description=Warm up Ollama model ${MODEL}
After=ollama.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ollama-warmup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ollama-warmup

# -----------------------------
# Firewall (LAN only)
# -----------------------------
sudo ufw allow 22/tcp >/dev/null || true
sudo ufw allow from "${LAN_SUBNET}" to any port "${PORT}" proto tcp >/dev/null || true
sudo ufw deny "${PORT}/tcp" >/dev/null || true

if ! sudo ufw status | grep -q "Status: active"; then
  echo "y" | sudo ufw enable >/dev/null
fi

# -----------------------------
# Final checks
# -----------------------------
PI_IP=$(hostname -I | awk '{print $1}')

echo
echo "======================================"
echo " ✅ Setup Complete!"
echo "======================================"
echo " Pi IP      : ${PI_IP}"
echo " Model      : ${MODEL}"
echo " LAN Access : ${LAN_SUBNET}"
echo
echo " Test from another machine:"
echo " curl http://${PI_IP}:${PORT}/api/tags"
echo
echo " Generate:"
echo " curl -X POST http://${PI_IP}:${PORT}/api/generate \\"
echo "   -H 'Content-Type: application/json' \\"
echo "   -d '{\"model\":\"${MODEL}\",\"prompt\":\"Hello\",\"stream\":false}'"
echo
echo " Reboot recommended:"
echo " sudo reboot"
