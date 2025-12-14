# Ollama Raspberry Pi One-Go Setup (LAN-Only + Auto Warmup)

This project provides a one-go setup script to install and configure Ollama on a Raspberry Pi (recommended: **Pi 4, 8GB, 64-bit OS**) to run an Edge LLM locally, expose the API only to devices on the same LAN, and automatically warm up the model on system startup.

This enables a **local-first, privacy-preserving, secure edge AI setup** with zero cloud dependency.

## What this script does

- Installs required dependencies (`curl`, `ufw`)
- Installs Ollama (if not already installed)
- Enables Ollama to start automatically on boot
- Binds the Ollama API to the LAN interface (`0.0.0.0:11434`)
- Applies stable runtime settings optimized for Raspberry Pi
- Pulls a user-selected model (default: `phi3:mini`)
- Preloads (warms up) the model during system startup
- Locks down API access using UFW (LAN subnet only)

## Requirements

- **Raspberry Pi OS 64-bit**
- Raspberry Pi connected to your Wi-Fi / LAN
- SSH access (optional but recommended)
- Knowledge of your LAN subnet

**Common subnet examples:**

- `192.168.1.0/24`
- `192.168.0.0/24`
- `10.0.0.0/24`

## Files created / modified

- **Ollama systemd override:** `/etc/systemd/system/ollama.service.d/override.conf`
- **Warm-up script:** `/usr/local/bin/ollama-warmup.sh`
- **Warm-up systemd service:** `/etc/systemd/system/ollama-warmup.service`
- **Firewall rules (UFW)**
  - Allows: `22/tcp` (SSH), `11434/tcp` only from your LAN subnet
  - Denies: `11434/tcp` from all other sources

## Install & Run

### 1. Create or download the script

Save the setup script as:

```bash
setup-ollama-rpi.sh
```

> **Note:** If you have a raw URL, you can use `curl` or `wget` to download. Otherwise, create the file and paste the script.

### 2. Make the script executable

```bash
chmod +x setup-ollama-rpi.sh
```

### 3. Run the script

```bash
./setup-ollama-rpi.sh
```

The script will prompt you for:

- **LAN subnet** (example: `192.168.1.0/24`)
- **Ollama model name** (default: `phi3:mini`)

## Verify setup

### Check Ollama service

```bash
systemctl status ollama --no-pager
```

### Check warm-up service

```bash
systemctl status ollama-warmup --no-pager
```

### Confirm Ollama is listening on LAN

```bash
ss -lntp | grep 11434
```

**Expected output:**

```text
0.0.0.0:11434
```

### Test from another machine on the same LAN

Replace `<PI_IP>` with your Raspberry Pi IP (get it using `hostname -I` on the Pi).

#### Get the Pi IP

```bash
hostname -I
```

#### List available models

```bash
curl http://<PI_IP>:11434/api/tags
```

#### Generate text

```bash
curl -X POST http://<PI_IP>:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3:mini",
    "prompt": "Hello",
    "stream": false
  }'
```

> **Tip:** Alternatively, use a simple GET request to list tags:
>
> ```bash
> curl http://<PI_IP>:11434/api/tags
> ```

### Reboot test (startup + warm-up)

#### Reboot the Raspberry Pi

```bash
sudo reboot
```

#### Verify warm-up executed successfully

After reboot, check the warm-up service:

```bash
systemctl status ollama-warmup --no-pager
```

## Performance tuning (Raspberry Pi 4 – 8GB)

The script applies safe defaults for stability:

| Setting                    | Value | Purpose                              |
| -------------------------- | ----- | ------------------------------------ |
| `OLLAMA_NUM_PARALLEL`      | `1`   | Prevents CPU overload                |
| `OLLAMA_MAX_LOADED_MODELS` | `1`   | Avoids memory spikes                 |
| `OLLAMA_KEEP_ALIVE`        | `5m`  | Keeps the model hot between requests |

### Adjust settings

You can modify these settings by editing the override configuration:

```bash
sudo nano /etc/systemd/system/ollama.service.d/override.conf
```

After making changes, apply them:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## Troubleshooting

### Curl works on Pi but not from laptop

**Solution:**

1. Verify Pi IP:

   ```bash
   hostname -I
   ```

2. Ensure both devices are on the same subnet
3. Disable **AP Isolation** / **Client Isolation** in your router Wi-Fi settings

### Port not reachable

**Solution:**

1. Check firewall rules:

   ```bash
   sudo ufw status
   ```

2. Ensure your subnet is allowed:
   ```bash
   sudo ufw allow from <YOUR_SUBNET> to any port 11434 proto tcp
   sudo ufw reload
   ```

### Ollama only listens on localhost

If you see:

```text
127.0.0.1:11434
```

The systemd override was not applied correctly.

**Fix:**

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo nano /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Bruno / Postman fails but curl works

This is usually due to client-side firewall, VPN, or app sandboxing.

**Solution:**

- Allow the client app in macOS firewall / security tools
- Disable VPN temporarily and test

**Start with:**

```bash
curl http://<PI_IP>:11434/api/tags
```

## Security note

This setup is **LAN-only by design:**

- ✅ No public internet exposure
- ✅ No cloud dependency
- ✅ Firewall blocks all non-LAN access to Ollama

> ⚠️ **Warning:** Ensure your router does not port-forward port `11434`.

## Why this matters

This setup enables:

- 🏠 **Local-first AI** — Your data never leaves your network
- 🔒 **Privacy-by-design inference** — Complete data sovereignty
- 🏭 **Edge LLMs for IoT, internal tools, healthcare, factories** — Deploy anywhere
- 🌐 **Reliable AI even without internet** — Works offline

> **Edge AI isn't a demo anymore — this is production-grade.**

## License

Free to use and modify. Attribution appreciated.

---

**Made with ❤️ for the edge AI community**
