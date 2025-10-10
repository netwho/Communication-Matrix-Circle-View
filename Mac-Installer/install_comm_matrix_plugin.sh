#!/bin/bash

# Communication Matrix Circle View Plugin Installer for macOS
# Author: Walter Hofstetter (walter.hofstetter@netwho.com)
# Version: 1.0

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLUGIN_NAME="comm_matrix_circle.lua"
WIRESHARK_PLUGINS_DIR="$HOME/.local/lib/wireshark/plugins"
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"

# Print functions
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}    Communication Matrix Circle View Plugin Installer (macOS)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${YELLOW}➤ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This installer should NOT be run as root/sudo"
        print_info "Run as your regular user: ./install_comm_matrix_plugin.sh"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check if Wireshark is installed
    if ! command -v wireshark >/dev/null 2>&1; then
        if [[ ! -d "/Applications/Wireshark.app" ]]; then
            missing_deps+=("Wireshark")
        else
            print_success "Wireshark.app found in /Applications"
        fi
    else
        print_success "Wireshark command found in PATH"
    fi
    
    # Check for recommended PDF export tools
    local pdf_tools=()
    if command -v rsvg-convert >/dev/null 2>&1; then
        pdf_tools+=("rsvg-convert")
    fi
    if command -v inkscape >/dev/null 2>&1; then
        pdf_tools+=("inkscape")
    fi
    if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
        pdf_tools+=("ImageMagick")
    fi
    
    if [[ ${#pdf_tools[@]} -eq 0 ]]; then
        print_info "No PDF export tools found (optional for SVG viewing)"
        print_info "Install with: brew install librsvg inkscape imagemagick"
    else
        print_success "PDF export tools found: ${pdf_tools[*]}"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing prerequisites: ${missing_deps[*]}"
        echo
        print_info "Please install the missing components:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "Wireshark")
                    echo "  • Download Wireshark from: https://www.wireshark.org/download.html"
                    ;;
                *)
                    echo "  • Install $dep (usually available via Homebrew: brew install $dep)"
                    ;;
            esac
        done
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

# Create directories
create_directories() {
    print_step "Creating necessary directories..."
    
    # Create plugin directory
    if [[ ! -d "$WIRESHARK_PLUGINS_DIR" ]]; then
        mkdir -p "$WIRESHARK_PLUGINS_DIR"
        print_success "Created plugins directory: $WIRESHARK_PLUGINS_DIR"
    else
        print_success "Plugins directory exists: $WIRESHARK_PLUGINS_DIR"
    fi
}

# Install plugin
install_plugin() {
    print_step "Installing Communication Matrix Circle View plugin..."
    
    local source_plugin="$INSTALL_DIR/$PLUGIN_NAME"
    local target_plugin="$WIRESHARK_PLUGINS_DIR/$PLUGIN_NAME"
    
    if [[ ! -f "$source_plugin" ]]; then
        print_error "Plugin file not found: $source_plugin"
        print_info "Make sure $PLUGIN_NAME is in the same directory as this installer"
        exit 1
    fi
    
    # Backup existing plugin if it exists
    if [[ -f "$target_plugin" ]]; then
        local backup_file="${target_plugin}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$target_plugin" "$backup_file"
        print_info "Backed up existing plugin to: $backup_file"
    fi
    
    # Copy plugin
    cp "$source_plugin" "$target_plugin"
    chmod 644 "$target_plugin"
    print_success "Plugin installed: $target_plugin"
}

# Verify installation
verify_installation() {
    print_step "Verifying installation..."
    
    # Check plugin file
    if [[ -f "$WIRESHARK_PLUGINS_DIR/$PLUGIN_NAME" ]]; then
        print_success "Plugin file verified: $WIRESHARK_PLUGINS_DIR/$PLUGIN_NAME"
    else
        print_error "Plugin file missing!"
        return 1
    fi
    
    # Check Lua syntax (basic check)
    if command -v lua >/dev/null 2>&1; then
        if lua -c "$WIRESHARK_PLUGINS_DIR/$PLUGIN_NAME" 2>/dev/null; then
            print_success "Plugin Lua syntax verified"
        else
            print_error "Plugin has Lua syntax errors!"
            return 1
        fi
    else
        print_info "Lua not available for syntax checking (optional)"
    fi
}

# Check for recommended tools
check_recommended_tools() {
    print_step "Checking recommended tools for PDF export..."
    
    local tools_info=()
    
    # Check for rsvg-convert (preferred)
    if command -v rsvg-convert >/dev/null 2>&1; then
        tools_info+=("✓ rsvg-convert: $(which rsvg-convert)")
    else
        tools_info+=("✗ rsvg-convert: not found")
    fi
    
    # Check for inkscape
    if command -v inkscape >/dev/null 2>&1; then
        tools_info+=("✓ inkscape: $(which inkscape)")
    elif [[ -x "/Applications/Inkscape.app/Contents/MacOS/inkscape" ]]; then
        tools_info+=("✓ inkscape: /Applications/Inkscape.app/Contents/MacOS/inkscape")
    else
        tools_info+=("✗ inkscape: not found")
    fi
    
    # Check for ImageMagick
    if command -v magick >/dev/null 2>&1; then
        tools_info+=("✓ ImageMagick: $(which magick)")
    elif command -v convert >/dev/null 2>&1; then
        tools_info+=("✓ ImageMagick: $(which convert) (legacy)")
    else
        tools_info+=("✗ ImageMagick: not found")
    fi
    
    print_info "PDF export tools status:"
    for info in "${tools_info[@]}"; do
        echo "    $info"
    done
    
    # Installation recommendations
    local missing_count=$(echo "${tools_info[*]}" | grep -o "✗" | wc -l)
    if [[ $missing_count -gt 0 ]]; then
        print_info "To install missing PDF export tools:"
        echo "    brew install librsvg inkscape imagemagick"
        print_info "Note: Restart Wireshark after installing tools for them to be detected."
    fi
}

# Print usage instructions
print_usage() {
    print_step "Installation completed successfully!"
    echo
    print_info "How to use the Communication Matrix Circle View plugin:"
    echo "  1. Launch Wireshark"
    echo "  2. Load a packet capture file or start a live capture"
    echo "  3. Apply display filters to focus on specific traffic (optional)"
    echo "  4. Go to: Tools → Comm Matrix (Circle View)"
    echo "  5. Choose 'MAC View' or 'IP View'"
    echo "  6. View the generated SVG or export to PDF"
    echo
    print_info "What this plugin does:"
    echo "  • Creates circular network communication diagrams"
    echo "  • MAC View: Shows Ethernet and Wi-Fi communication patterns"  
    echo "  • IP View: Shows IPv4 and IPv6 communication patterns"
    echo "  • Color-coded traffic volume (5 levels from 1-10 to 1000+ packets)"
    echo "  • Exports SVG files and can create PDF exports"
    echo
    print_info "PDF Export Features:"
    echo "  • Automatically saves to your HOME directory"
    echo "  • Filename: CommMatrix-YYYYMMDD-HHMMSS.pdf"
    echo "  • Uses first available: rsvg-convert, inkscape, or ImageMagick"
    echo
    print_info "Troubleshooting:"
    echo "  • If no endpoints appear: check your display filter"
    echo "  • MAC View needs Ethernet (eth.*) or Wi-Fi (wlan.*) traffic"
    echo "  • IP View needs IPv4 (ip.*) or IPv6 (ipv6.*) traffic"
    echo "  • SVG opens in your default browser"
    echo
    print_info "Plugin location: $WIRESHARK_PLUGINS_DIR/$PLUGIN_NAME"
    echo
    print_success "Happy network visualization! 🔍"
}

# Main installation process
main() {
    print_header
    
    check_not_root
    check_prerequisites
    create_directories
    install_plugin
    verify_installation
    check_recommended_tools
    print_usage
}

# Run main function
main "$@"