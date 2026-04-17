# DevBox

**A phone that runs Claude Code. Nothing else.**

Take a refurbished phone. Flash it with stock Android, root it with Magisk (where the bootloader allows), strip the bloat. Boot into a full Claude Code terminal. Sign in once. Start building.

No personal data on the device. No apps you don't need. No risk to your main machine. Just an AI coding agent in your pocket — isolated, portable, and always ready.

---

## Why

You want to run Claude Code with full permissions. You don't want to give it the keys to your laptop.

DevBox solves this by putting the agent on its own device — a physical sandbox. The agent gets unlimited access to its own filesystem, its own terminal, its own git. It can't see your browser history, your SSH keys, your company Slack. If it does something weird, you factory reset and start over. Total isolation. Zero risk.

And because it's a phone, you take it everywhere. Code from the couch. Debug on the train. Pair a Bluetooth keyboard at a coffee shop. Or control it remotely from your PC over WiFi — full two-way SSH, no cable needed.

## What it actually is

- A **Pixel 8** (or Galaxy S20/S21/S22/S23, or any Android 12+ phone) running **stock Android** — with **Magisk root** on devices with unlockable bootloaders (Pixels, unlocked Samsungs), or stock-with-bloatware-stripped on carrier-locked devices. Real Android, real Play Store, no clutter.
- **Termux** providing a full Linux terminal with Node, Python, git, and SSH. Root-aware where available.
- **Claude Code CLI** installed and ready to go at first boot.
- **MCP servers** preloaded (filesystem, GitHub).
- **State sync** so you can start a project on the phone and pick it up on your PC — via GitHub (bidirectional) or Google Drive (backup).
- **SSH server** so you can connect to the device wirelessly from any machine on your network.

## The 30-second demo

```
# From your PC, over WiFi, no USB:
$ ssh -p 8022 devbox@192.168.1.36

DevBox ready. Type: claude

$ claude

╭──────────────────────────────────────╮
│ Claude Code                          │
│                                      │
│ Pixel 8 · Android 16 · Termux (root) │
│ Your pocket AI sandbox               │
╰──────────────────────────────────────╯

> Build me a REST API for managing tasks.

  I'll create that for you...
```

You're SSH'd into a phone in your pocket, talking to Claude Code, building software. From your couch. Or your office. Or the other side of the house.

## Build your own (15–30 minutes)

Everything you need is in this repo. No special equipment — just a USB cable and a laptop.

### What you need

- Any Android 12+ phone (tested: Pixel 8, Galaxy S20 FE, Galaxy S23 Ultra)
- A USB-C cable (USB 3+ preferred for faster flashing)
- A PC with ADB installed ([download](https://developer.android.com/tools/releases/platform-tools))
- A WiFi network
- An Anthropic account ([sign up](https://claude.ai))
- Chrome/Edge (for `flash.android.com` — Pixel path only)

### Steps

1. **Flash the phone** ([full guide](FLASH.md)) — choose the path for your device:
   - **Pixel (unlockable bootloader, recommended):** use [flash.android.com](https://flash.android.com) to flash stock Android, then patch `init_boot.img` with Magisk for full root. ~15 min.
   - **Carrier-locked Samsung (e.g. Verizon S20 FE):** skip flashing. Just factory-reset and strip bloatware via `adb shell pm uninstall --user 0 ...`. No root. ~10 min.

2. **Install Termux + push DevBox scripts** (both paths)
   ```bash
   bash flash-device.sh
   ```

3. **Open Termux on the phone**, run:
   ```
   bash ~/storage/downloads/devbox/provision.sh
   ```
   Installs Node, Python, Claude Code, MCP servers. ~5 minutes.

4. **Run the wizard**
   ```
   devbox wizard
   ```
   Signs you into Anthropic, sets up sync, wires MCP servers. ~2 minutes.

5. **Done.** Type `claude` and go.

### Optional: SSH from your PC (wireless control)

```bash
# On the phone (in Termux):
sshd

# On your PC:
ssh -p 8022 <phone-ip>
```

Now you can type prompts, read output, and control the agent from your laptop — while the phone sits in your pocket.

## What's inside

| File | What it does |
| --- | --- |
| [`FLASH.md`](FLASH.md) | Full step-by-step for both device paths |
| [`flash-device.sh`](flash-device.sh) | PC-side script: installs Termux + pushes files via ADB |
| [`provision.sh`](provision.sh) | Phone-side: installs Node, Claude Code, MCP servers |
| [`wizard.sh`](wizard.sh) | First-boot setup: Anthropic login, sync, keyboard mode |
| [`sync-github.sh`](sync-github.sh) | Bidirectional project sync to a private GitHub repo |
| [`sync-drive.sh`](sync-drive.sh) | Backup sync to Google Drive via rclone |
| [`kiosk-setup.md`](kiosk-setup.md) | Lock the phone to Termux only (optional) |
| [`reflash-to-stock.md`](reflash-to-stock.md) | Restore the phone to factory Android |

## FAQ

**Will this brick my phone?**
No. On Pixels, the bootloader stays unlocked and the A/B slot system gives us a bailout lane — if Magisk bootloops us, `fastboot set_active <other-slot>` drops us back to clean stock in 3 seconds. On Samsung Verizon, we never touch the bootloader at all. Worst case on any device: re-run `flash.android.com` (Pixel) or factory reset via Recovery (Samsung) — back to stock in 10 minutes.

**Why stock Android instead of LineageOS?**
We tried LineageOS first. It's a worse UX for this product: no Play Store (breaks Whisper Input voice keyboards that buyers expect), no Google services, and more moving parts. The isolation argument doesn't hold — Termux already sandboxes Claude Code regardless of the underlying OS. Stock + Magisk gives us full root where we can have it, plus the app compatibility Play Store provides.

**Does it need a SIM card?**
No. WiFi only. Add a SIM if you want cellular data, but it's not required.

**Can I use it as a regular phone too?**
Yes — it's full Android, you can install any APK. But the point is that you *don't*. The isolation is the feature.

**What about battery life?**
Claude Code sessions are network calls, not local compute. Battery impact is similar to browsing the web. A full charge lasts a workday of moderate use.

**How do I update Claude Code?**
```
devbox update
```

**Can I control it from my PC?**
Yes. Over USB (`adb`) or wirelessly over SSH. Full two-way — you can type prompts and read responses from your laptop while the phone is across the room.

**What stops someone from just installing Claude Code on any phone?**
Nothing. But DevBox is pre-configured, pre-flashed, and ready to go in 30 seconds out of the box. That's the product. This repo is the recipe.

## Status

**v0.2 — Pixel 8 rooted on stock, S20 FE shipping unrooted.**
- **Pixel 8:** stock Android 16 (BP4A.251205.006), Magisk v30.7 root confirmed, Claude Code provisioning in progress.
- **Galaxy S20 FE (Verizon):** stock Samsung One UI, 195+ bloatware packages nuked, Claude Code running, SSH live.
- **Galaxy S23 Ultra:** not started.

Next: finish Pixel 8 provisioning, document the two-path FLASH.md, then a small production run.

## License

MIT

---

*Built with [Claude Code](https://claude.ai/claude-code).*
