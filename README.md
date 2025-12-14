# Ollama Raspberry Pi One-Go Setup (LAN-Only + Auto Warmup)

This project provides a one-go setup script to install and configure Ollama on a Raspberry Pi (recommended: Pi 4, 8GB, 64-bit OS) to run an Edge LLM locally, expose the API only to devices on the same LAN, and warm up a selected model on boot so the first request is fast.

This enables a local-first, privacy-preserving, secure edge AI setup with zero cloud dependency.

## What this script does

- Installs required dependencies (curl, ufw)
- Installs Ollama (if not already installed)
- Enables Ollama to start automatically on boot
- Binds the Ollama API to the LAN interface (0.0.0.0:11434)
- Applies stable runtime settings optimized for Raspberry Pi
- Pulls a user-selected model (default: phi3:mini)
- Preloads (warms up) the model during system startup
- Locks down API access using UFW (LAN subnet only)

## Requirements

- Raspberry Pi OS 64-bit
- Raspberry Pi connected to your Wi-Fi / LAN
- SSH access (optional but recommended)
- Knowledge of your LAN subnet

Common subnet examples:
- 192.168.1.0/24
- 192.168.0.0/24
- 10.0.0.0/24

## Files created / modified

- Ollama systemd override: /etc/systemd/system/ollama.service.d/override.conf
- Warm-up script: /usr/local/bin/ollama-warmup.sh
- Warm-up systemd service: /etc/systemd/system/ollama-warmup.service
- Firewall rules (UFW)
  - Allows: 22/tcp (SSH), 11434/tcp only from your LAN subnet
  - Denies: 11434/tcp from all other sources

## Install & Run

1. Create or download the script

   Save the setup script as:

   setup-ollama-rpi.sh

2. Make the script executable

   chmod +x setup-ollama-rpi.sh

3. Run the script

   ./setup-ollama-rpi.sh

The script will prompt you for:
- LAN subnet (example: 192.168.1.0/24)
- Ollama model name (default: phi3:mini)

## Verify setup

Check Ollama service:

systemctl status ollama --no-pager

Check warm-up service:

systemctl status ollama-warmup --no-pager

Confirm Ollama is listening on LAN:

ss -lntp | grep 11434

Expected output:

0.0.0.0:11434

### Test from another machine on the same LAN

Replace <PI_IP> with your Raspberry Pi IP (get it using `hostname -I` on the Pi)

List available models:

curl http://<PI_IP>:11434/api/tags

Generate text (proper curl):

curl -X POST http://<PI_IP>:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3:mini",
    "prompt": "Hello",
    "stream": false
  }'

### Reboot test (startup + warm-up)

Reboot the Raspberry Pi:

sudo reboot

After reboot, verify warm-up executed successfully:

systemctl status ollama-warmup --no-pager

## Performance tuning (Raspberry Pi 4 – 8GB)

The script applies safe defaults for stability:

OLLAMA_NUM_PARALLEL=1
Prevents CPU overload

OLLAMA_MAX_LOADED_MODELS=1
Avoids memory spikes

OLLAMA_KEEP_ALIVE=5m
Keeps the model hot between requests

You can adjust these settings here:

sudo nano /etc/systemd/system/ollama.service.d/override.conf

Apply changes:

sudo systemctl daemon-reload
sudo systemctl restart ollama

## Troubleshooting

Curl works on Pi but not from laptop

- Verify Pi IP: `hostname -I`
- Ensure both devices are on the same subnet
- Disable AP Isolation / Client Isolation in your router Wi-Fi settings

Port not reachable

- Check firewall rules:
  sudo ufw status
- Ensure your subnet is allowed:
  sudo ufw allow from <YOUR_SUBNET> to any port 11434 proto tcp
  sudo ufw reload

Ollama only listens on localhost

If you see:

127.0.0.1:11434

The systemd override was not applied correctly.

Fix:

sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo nano /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama

Bruno / Postman fails but curl works

This is usually due to client-side firewall, VPN, or app sandboxing.

- Allow the client app in macOS firewall / security tools
- Disable VPN temporarily and test

Start with:

GET http://<PI_IP>:11434/api/tags

## Security note

This setup is LAN-only by design:

- No public internet exposure
- No cloud dependency
- Firewall blocks all non-LAN access to Ollama

⚠️ Ensure your router does not port-forward port 11434.

## Why this matters

This setup enables:

- Local-first AI
- Privacy-by-design inference
- Edge LLMs for IoT, internal tools, healthcare, factories
- Reliable AI even without internet

Edge AI isn’t a demo anymore — this is production-grade.

## License

Free to use and modify. Attribution appreciated.
