# Communication Matrix Report - Windows Installation

Quick installation guide for Windows users.

## Prerequisites

- Windows 10 or later
- Wireshark 4.0 or later
- PowerShell 5.0 or later (included in Windows 10+)

## Quick Install

1. Open PowerShell (no admin rights needed)
2. Navigate to the Windows_Installer directory:
   ```powershell
   cd Windows_Installer
   ```
3. Run the installer:
   ```powershell
   .\install_comm_matrix_report.ps1
   ```

**Note:** If you get an execution policy error, run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## What Gets Installed

- Plugin file: `%APPDATA%\Wireshark\plugins\comm_matrix_table_view.lua`
- Creates backup of existing plugin if present
- Typical path: `C:\Users\<YourUsername>\AppData\Roaming\Wireshark\plugins\`

## PNG/PDF Export Requirements

For PNG export functionality (recommended), install rsvg-convert:

**Download rsvg-convert:**
- https://github.com/miyako/console-rsvg-convert/releases
- Extract and add to PATH

**Optional additional tools:**
- **Inkscape**: https://inkscape.org/release/
- **ImageMagick**: https://imagemagick.org/script/download.php#windows

### Adding to PATH (Windows)

1. Extract rsvg-convert.exe to a folder (e.g., `C:\Tools\rsvg\`)
2. Open System Properties → Environment Variables
3. Edit "Path" variable
4. Add the folder path
5. Restart Wireshark

## After Installation

1. **Restart Wireshark** (if already running)
2. Find the plugin under: **Tools → Communication Matrix Report**
3. Load a capture file or start live capture
4. Apply display filters (optional but recommended)
5. Run the plugin and click "Open PNG"

## Troubleshooting

### Plugin Not Appearing
- Check if Wireshark is version 4.0+
- Verify file location in PowerShell:
  ```powershell
  Get-Item "$env:APPDATA\Wireshark\plugins\comm_matrix_table_view.lua"
  ```
- Restart Wireshark

### PNG Export Not Working
- Install rsvg-convert (see above)
- Add to PATH
- Restart Wireshark
- Check detection in plugin window

### PowerShell Execution Policy Error
Run as regular user (not admin):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### WinPcap/Npcap Issues
- Ensure Npcap is installed (comes with Wireshark)
- Reinstall Wireshark if packet capture doesn't work

## Features

- **Dual Circle View**: IP (top) and MAC (bottom) circles
- **Conversation Table**: Top 50 conversations with packets, bytes, ports, protocols
- **Smart Layout**: Busy pairs positioned opposite each other
- **Heat Map Colors**: Blue (low) to red (high) traffic
- **Export Options**: PNG, SVG, and PDF

## Uninstall

In PowerShell:
```powershell
Remove-Item "$env:APPDATA\Wireshark\plugins\comm_matrix_table_view.lua"
```

## Support

For issues or questions, please visit the project repository.
