# Communication Matrix Report Plugin Installer for Windows
# Author: Walter Hofstetter (walter.hofstetter@netwho.com)
# Version: 2.0

# Requires PowerShell 5.0 or later
#Requires -Version 5.0

# Configuration
$PLUGIN_NAME = "comm_matrix_reporter.lua"
$WIRESHARK_PLUGINS_DIR = Join-Path $env:APPDATA "Wireshark\plugins"
$INSTALL_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Color functions
function Write-Header {
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "    Communication Matrix Report Plugin Installer (Windows)" -ForegroundColor Blue
    Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Blue
}

function Write-Step {
    param([string]$Message)
    Write-Host "➤ $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

# Check if running as administrator
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check prerequisites
function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    $missing_deps = @()
    
    # Check if Wireshark is installed
    $wireshark_paths = @(
        "C:\Program Files\Wireshark\Wireshark.exe",
        "C:\Program Files (x86)\Wireshark\Wireshark.exe"
    )
    
    $wireshark_found = $false
    foreach ($path in $wireshark_paths) {
        if (Test-Path $path) {
            Write-Success "Wireshark found at: $path"
            $wireshark_found = $true
            break
        }
    }
    
    if (-not $wireshark_found) {
        $wireshark_cmd = Get-Command wireshark.exe -ErrorAction SilentlyContinue
        if ($wireshark_cmd) {
            Write-Success "Wireshark command found in PATH"
            $wireshark_found = $true
        }
    }
    
    if (-not $wireshark_found) {
        $missing_deps += "Wireshark"
    }
    
    # Check for PNG/PDF export tools
    $pdf_tools = @()
    
    if (Get-Command rsvg-convert -ErrorAction SilentlyContinue) {
        $pdf_tools += "rsvg-convert"
    }
    if (Get-Command inkscape -ErrorAction SilentlyContinue) {
        $pdf_tools += "inkscape"
    }
    if (Get-Command magick -ErrorAction SilentlyContinue) {
        $pdf_tools += "ImageMagick"
    }
    elseif (Get-Command convert -ErrorAction SilentlyContinue) {
        $pdf_tools += "ImageMagick (legacy)"
    }
    
    if ($pdf_tools.Count -eq 0) {
        Write-Info "No PNG/PDF export tools found (required for PNG export)"
        Write-Info "Install rsvg-convert from: https://github.com/miyako/console-rsvg-convert"
        Write-Info "(Optional: Inkscape from https://inkscape.org/)"
    }
    else {
        Write-Success "PNG/PDF export tools found: $($pdf_tools -join ', ')"
    }
    
    if ($missing_deps.Count -gt 0) {
        Write-Error "Missing prerequisites: $($missing_deps -join ', ')"
        Write-Host ""
        Write-Info "Please install the missing components:"
        foreach ($dep in $missing_deps) {
            switch ($dep) {
                "Wireshark" {
                    Write-Host "  • Download Wireshark from: https://www.wireshark.org/download.html"
                }
                default {
                    Write-Host "  • Install $dep"
                }
            }
        }
        exit 1
    }
    
    Write-Success "All prerequisites satisfied"
}

# Create directories
function New-Directories {
    Write-Step "Creating necessary directories..."
    
    if (-not (Test-Path $WIRESHARK_PLUGINS_DIR)) {
        New-Item -ItemType Directory -Path $WIRESHARK_PLUGINS_DIR -Force | Out-Null
        Write-Success "Created plugins directory: $WIRESHARK_PLUGINS_DIR"
    }
    else {
        Write-Success "Plugins directory exists: $WIRESHARK_PLUGINS_DIR"
    }
}

# Install plugin
function Install-Plugin {
    Write-Step "Installing Communication Matrix Report plugin..."
    
    $source_plugin = Join-Path $INSTALL_DIR $PLUGIN_NAME
    $target_plugin = Join-Path $WIRESHARK_PLUGINS_DIR $PLUGIN_NAME
    
    if (-not (Test-Path $source_plugin)) {
        Write-Error "Plugin file not found: $source_plugin"
        Write-Info "Make sure $PLUGIN_NAME is in the same directory as this installer"
        exit 1
    }
    
    # Backup existing plugin if it exists
    if (Test-Path $target_plugin) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backup_file = "$target_plugin.backup.$timestamp"
        Copy-Item $target_plugin $backup_file
        Write-Info "Backed up existing plugin to: $backup_file"
    }
    
    # Copy plugin
    Copy-Item $source_plugin $target_plugin -Force
    Write-Success "Plugin installed: $target_plugin"
}

# Verify installation
function Test-Installation {
    Write-Step "Verifying installation..."
    
    $target_plugin = Join-Path $WIRESHARK_PLUGINS_DIR $PLUGIN_NAME
    
    if (Test-Path $target_plugin) {
        Write-Success "Plugin file verified: $target_plugin"
    }
    else {
        Write-Error "Plugin file missing!"
        return $false
    }
    
    return $true
}

# Check for recommended tools
function Test-RecommendedTools {
    Write-Step "Checking tools for PNG/PDF export..."
    
    $tools_info = @()
    
    # Check for rsvg-convert (preferred)
    $rsvg = Get-Command rsvg-convert -ErrorAction SilentlyContinue
    if ($rsvg) {
        $tools_info += "✓ rsvg-convert: $($rsvg.Source)"
    }
    else {
        $tools_info += "✗ rsvg-convert: not found"
    }
    
    # Check for inkscape
    $inkscape = Get-Command inkscape -ErrorAction SilentlyContinue
    if ($inkscape) {
        $tools_info += "✓ inkscape: $($inkscape.Source)"
    }
    else {
        $tools_info += "✗ inkscape: not found"
    }
    
    # Check for ImageMagick
    $magick = Get-Command magick -ErrorAction SilentlyContinue
    if ($magick) {
        $tools_info += "✓ ImageMagick: $($magick.Source)"
    }
    else {
        $convert = Get-Command convert -ErrorAction SilentlyContinue
        if ($convert) {
            $tools_info += "✓ ImageMagick: $($convert.Source) (legacy)"
        }
        else {
            $tools_info += "✗ ImageMagick: not found"
        }
    }
    
    Write-Info "PNG/PDF export tools status:"
    foreach ($info in $tools_info) {
        Write-Host "    $info"
    }
    
    # Installation recommendations
    $missing_count = ($tools_info | Select-String "✗").Count
    if ($missing_count -gt 0) {
        Write-Host ""
        Write-Info "To install missing PNG/PDF export tools:"
        Write-Host "  • rsvg-convert: https://github.com/miyako/console-rsvg-convert"
        Write-Host "  • Inkscape: https://inkscape.org/release/"
        Write-Host "  • ImageMagick: https://imagemagick.org/script/download.php#windows"
        Write-Info "Note: Restart Wireshark after installing tools for them to be detected."
    }
}

# Print usage instructions
function Write-Usage {
    Write-Step "Installation completed successfully!"
    Write-Host ""
    Write-Info "How to use the Communication Matrix Report plugin:"
    Write-Host "  1. Launch Wireshark"
    Write-Host "  2. Load a packet capture file or start a live capture"
    Write-Host "  3. Apply display filters to focus on specific traffic (optional but recommended)"
    Write-Host "  4. Go to: Tools → Communication Matrix Report (or PacketReporter → 4. Communication Matrix Report if PacketReporter is installed)"
    Write-Host "  5. Wait for processing to complete"
    Write-Host "  6. Click 'Open PNG' to view the visualization"
    Write-Host ""
    Write-Info "What this plugin does:"
    Write-Host "  • Creates a comprehensive network communication report with:"
    Write-Host "    - IP circle (top) showing Layer 3 communications"
    Write-Host "    - MAC circle (bottom) showing Layer 2 communications"
    Write-Host "    - Top 50 conversations table with packets, bytes, ports, and protocols"
    Write-Host "  • Smart node placement: busy pairs positioned opposite each other"
    Write-Host "  • Color-coded traffic: blue (low) to red (high)"
    Write-Host "  • Automatic PNG conversion for easy viewing"
    Write-Host ""
    Write-Info "Export options:"
    Write-Host "  • Open PNG: Converts SVG to PNG and opens in default viewer (requires rsvg-convert)"
    Write-Host "  • Open SVG: Opens SVG file directly in browser"
    Write-Host "  • Export PDF: Saves report to ~/Documents/PacketReporter Reports/comm_matrix_report-YYYYMMDD-HHMMSS.pdf and opens automatically"
    Write-Host ""
    Write-Info "Troubleshooting:"
    Write-Host "  • If no conversations appear: check your display filter"
    Write-Host "  • For large captures: apply a more restrictive display filter first"
    Write-Host "  • PNG export requires rsvg-convert or Inkscape"
    Write-Host "  • Table shows IP addresses for IP traffic, MAC only for ARP/LLDP/STP/CDP"
    Write-Host ""
    Write-Info "Plugin location: $WIRESHARK_PLUGINS_DIR\$PLUGIN_NAME"
    Write-Host ""
    Write-Success "Happy network visualization! 🔍"
}

# Main installation process
function Main {
    Write-Header
    
    if (Test-Administrator) {
        Write-Info "Running as Administrator (not required, but OK)"
    }
    
    Test-Prerequisites
    New-Directories
    Install-Plugin
    
    if (Test-Installation) {
        Test-RecommendedTools
        Write-Usage
    }
    else {
        Write-Error "Installation verification failed!"
        exit 1
    }
}

# Run main function
Main
