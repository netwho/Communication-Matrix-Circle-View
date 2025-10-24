# Communication Matrix Report - Linux Installation

Quick installation guide for Linux users.

## Prerequisites

- Linux (Ubuntu, Debian, Fedora, CentOS, Arch, openSUSE, or similar)
- Wireshark 4.0 or later
- Package manager access for PNG/PDF export tools

## Quick Install

```bash
# Navigate to the Linux_Installer directory
cd Linux_Installer

# Make installer executable (if needed)
chmod +x install_comm_matrix_report.sh

# Run the installer
./install_comm_matrix_report.sh
```

## What Gets Installed

- Plugin file: `~/.local/lib/wireshark/plugins/comm_matrix_table_view.lua`
- Creates backup of existing plugin if present
- Sets correct file permissions (644)

## PNG/PDF Export Requirements

For PNG export functionality (recommended), install rsvg-convert:

**Ubuntu/Debian:**
```bash
sudo apt install librsvg2-bin
```

**Fedora:**
```bash
sudo dnf install librsvg2-tools
```

**Arch:**
```bash
sudo pacman -S librsvg
```

**openSUSE:**
```bash
sudo zypper install librsvg-tools
```

Optional additional tools:
```bash
# Ubuntu/Debian
sudo apt install inkscape imagemagick

# Fedora
sudo dnf install inkscape ImageMagick

# Arch
sudo pacman -S inkscape imagemagick
```

## Wireshark Permissions

To capture packets without root, add your user to the wireshark group:

```bash
sudo usermod -a -G wireshark $USER
```

Then log out and back in for changes to take effect.

## After Installation

1. **Restart Wireshark** (if already running)
2. Find the plugin under: **Tools → Communication Matrix Report**
3. Load a capture file or start live capture
4. Apply display filters (optional but recommended)
5. Run the plugin and click "Open PNG"

## Troubleshooting

### Plugin Not Appearing
- Check if Wireshark is version 4.0+
- Verify file location: `ls -la ~/.local/lib/wireshark/plugins/comm_matrix_table_view.lua`
- Restart Wireshark

### PNG Export Not Working
- Install librsvg2-bin or librsvg2-tools (see above)
- Restart Wireshark
- Check detection in plugin window

### Permission Issues for Packet Capture
- Add user to wireshark group (see above)
- Log out and back in
- Verify: `groups | grep wireshark`

## Features

- **Dual Circle View**: IP (top) and MAC (bottom) circles
- **Conversation Table**: Top 50 conversations with packets, bytes, ports, protocols
- **Smart Layout**: Busy pairs positioned opposite each other
- **Heat Map Colors**: Blue (low) to red (high) traffic
- **Export Options**: PNG, SVG, and PDF

## Uninstall

```bash
rm ~/.local/lib/wireshark/plugins/comm_matrix_table_view.lua
```

## Support

For issues or questions, please visit the project repository.
