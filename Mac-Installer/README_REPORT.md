# Communication Matrix Report - macOS Installation

Quick installation guide for macOS users.

## Prerequisites

- macOS 10.13 (High Sierra) or later
- Wireshark 4.0 or later
- Homebrew (recommended for PNG/PDF export tools)

## Quick Install

```bash
# Navigate to the Mac-Installer directory
cd Mac-Installer

# Run the installer
./install_comm_matrix_report.sh
```

## What Gets Installed

- Plugin file: `~/.local/lib/wireshark/plugins/comm_matrix_table_view.lua`
- Creates backup of existing plugin if present
- Sets correct file permissions (644)

## PNG/PDF Export Requirements

For PNG export functionality (recommended), install rsvg-convert:

```bash
brew install librsvg
```

Optional additional tools:
```bash
brew install inkscape imagemagick
```

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
- Install librsvg: `brew install librsvg`
- Restart Wireshark
- Check detection in plugin window

### Permission Issues
- Run installer as regular user (not sudo)
- Check file permissions: `chmod 644 ~/.local/lib/wireshark/plugins/comm_matrix_table_view.lua`

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
