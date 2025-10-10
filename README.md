# Communication Matrix Circle View

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue)]()
[![Wireshark](https://img.shields.io/badge/wireshark-4.0%2B-green)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()
[![Language](https://img.shields.io/badge/language-Lua-purple)]()

A sophisticated Wireshark plugin that creates beautiful **circular network communication diagrams** from packet capture data. Visualize MAC addresses, IP addresses, and traffic patterns in an intuitive circular layout with automatic PDF export capabilities.

![Network Visualization](https://img.shields.io/badge/Network-Visualization-orange?style=for-the-badge)

## 🎯 **What It Does**

Transform your network analysis with stunning circular communication diagrams:

- 🔄 **Circular Network Diagrams**: Visual representation of communication patterns
- 📊 **MAC Address Analysis**: Ethernet and Wi-Fi communication visualization  
- 🌐 **IP Address Analysis**: IPv4 and IPv6 traffic flow diagrams
- 🎨 **Traffic Volume Coding**: 5-level color and thickness coding (1-10 to 1000+ packets)
- 📁 **SVG Export**: Clean, scalable vector graphics
- 📄 **PDF Export**: Automatic PDF generation with timestamp
- 🎛️ **Filter Integration**: Works with Wireshark display filters

## 🚀 **Key Features**

### **Dual Analysis Modes**
- **MAC View**: Shows Ethernet (`eth.src/dst`) and Wi-Fi (`wlan.sa/da`) communication patterns
- **IP View**: Displays IPv4 (`ip.src/dst`) and IPv6 (`ipv6.src/dst`) traffic flows

### **Traffic Volume Visualization**
- **5 Traffic Bins** with distinct colors and line widths:
  - 🔵 **1-10 packets**: Thin blue lines
  - 🔵 **11-100 packets**: Medium cyan lines
  - 🟢 **101-500 packets**: Thick green lines  
  - 🟡 **501-1000 packets**: Very thick yellow lines
  - 🟡 **1000+ packets**: Thickest golden lines

### **Professional Export Options**
- **SVG Format**: Strict SVG 1.1 compatibility, ASCII-only, flattened structure
- **PDF Export**: Automatic export to HOME directory with timestamp
- **Multiple Converters**: rsvg-convert, Inkscape, or ImageMagick support
- **Browser Integration**: SVG files open automatically in your default browser

## 📋 **Quick Start**

### Prerequisites
- **Wireshark** (version 4.0+) - [Download here](https://www.wireshark.org/download.html)
- **PDF Export Tools** (optional but recommended):
  - **rsvg-convert** (preferred)
  - **Inkscape**  
  - **ImageMagick**

## 🖥️ **Installation**

We provide **automated installers for all major platforms**:

### **🍎 macOS (Automated)**
```bash
# 1. Download/clone this repository
git clone https://github.com/yourusername/comm-matrix-circle-view.git

# 2. Navigate to the Mac installer
cd comm-matrix-circle-view/Mac-Installer/

# 3. Run the automated installer
./install_comm_matrix_plugin.sh
```

**macOS PDF Tools Installation:**
```bash
brew install librsvg inkscape imagemagick
```

### **🐧 Linux (Automated)**
```bash
# 1. Download/clone this repository
git clone https://github.com/yourusername/comm-matrix-circle-view.git

# 2. Navigate to the Linux installer
cd comm-matrix-circle-view/Linux-Installer/

# 3. Make installer executable and run
chmod +x install_comm_matrix_plugin_linux.sh
./install_comm_matrix_plugin_linux.sh
```

**Linux PDF Tools Installation:**
```bash
# Ubuntu/Debian
sudo apt install librsvg2-bin inkscape imagemagick

# Fedora
sudo dnf install librsvg2-tools inkscape ImageMagick

# Arch Linux
sudo pacman -S librsvg inkscape imagemagick
```

### **🪟 Windows (Automated)**
```powershell
# 1. Download/clone this repository
git clone https://github.com/yourusername/comm-matrix-circle-view.git
cd comm-matrix-circle-view\Windows-Installer\

# 2. Run the PowerShell installer
.\install_comm_matrix_plugin_windows.ps1

# Or right-click the .ps1 file and select "Run with PowerShell"
```

**Windows PDF Tools Installation:**
```powershell
# Using Chocolatey
choco install rsvg-convert inkscape imagemagick

# Using Scoop  
scoop install librsvg inkscape imagemagick

# Using Winget
winget install Inkscape.Inkscape ImageMagick.ImageMagick
```

## ✨ **What All Installers Do**

All our automated installers provide comprehensive setup:

- ✅ **Prerequisites Check**: Verify Wireshark and detect PDF export tools
- ✅ **Smart Installation**: Copy plugin to correct directory with proper permissions
- ✅ **Tool Detection**: Identify available PDF converters (rsvg-convert, Inkscape, ImageMagick)
- ✅ **Verification**: Confirm installation and check Lua syntax
- ✅ **Safety**: Backup existing plugins with timestamps
- ✅ **Usage Guidance**: Complete instructions for using the plugin

## 📚 **Platform-Specific Guides**

For detailed platform-specific instructions, troubleshooting, and advanced options:

- **📖 macOS**: [Mac-Installer/README.md](./Mac-Installer/README.md)
- **📖 Linux**: [Linux-Installer/README.md](./Linux-Installer/README.md)  
- **📖 Windows**: [Windows-Installer/README.md](./Windows-Installer/README.md)

## ⚙️ **Manual Installation (All Platforms)**

If you prefer manual installation:

### **1. Install Plugin File**
```bash
# macOS/Linux
mkdir -p ~/.local/lib/wireshark/plugins
cp comm_matrix_circle.lua ~/.local/lib/wireshark/plugins/
chmod 644 ~/.local/lib/wireshark/plugins/comm_matrix_circle.lua
```

```powershell
# Windows (PowerShell)
New-Item -Path "$env:APPDATA\Wireshark\plugins" -ItemType Directory -Force
Copy-Item "comm_matrix_circle.lua" "$env:APPDATA\Wireshark\plugins\"
```

### **2. Install PDF Export Tools (Optional)**
Choose one or more:
- **rsvg-convert**: Best performance and compatibility
- **Inkscape**: Feature-rich vector graphics suite
- **ImageMagick**: Versatile image manipulation toolkit

## 📡 **Usage Workflow**

### 1. **Start Wireshark**
- Launch Wireshark
- Load a packet capture file or start live capture
- Apply display filters to focus on specific traffic (optional)

### 2. **Generate Communication Diagram**
- Go to **Tools → Comm Matrix (Circle View)**
- Choose your analysis mode:
  - **MAC View**: For Layer 2 analysis (Ethernet/Wi-Fi)
  - **IP View**: For Layer 3 analysis (IPv4/IPv6)

### 3. **View Results**
- Plugin generates an SVG file automatically
- Click **"Open SVG"** to view in your browser
- Click **"Export PDF"** to save timestamped PDF to your HOME directory

### 4. **Analyze the Diagram**
- **Node Dots**: Black circles represent endpoints
- **Curved Lines**: Communication paths between endpoints
- **Line Colors & Thickness**: Traffic volume indicators
- **Labels**: Endpoint identifiers positioned around the circle

## 🎨 **Visual Elements**

### **Traffic Volume Legend**
| Range | Color | Width | Description |
|-------|-------|-------|-------------|
| 1-10 | 🔵 Blue | Thin | Light communication |
| 11-100 | 🔵 Cyan | Medium | Moderate traffic |
| 101-500 | 🟢 Green | Thick | Heavy traffic |
| 501-1000 | 🟡 Light Yellow | Very Thick | Very heavy traffic |
| 1000+ | 🟡 Golden | Thickest | Extremely heavy traffic |

### **Diagram Layout**
- **Circle Arrangement**: Endpoints arranged in a perfect circle
- **Curved Connections**: Bezier curves connecting communicating endpoints
- **Smart Labeling**: Labels positioned outside the circle with white outlines for readability
- **Clean Design**: Black dots, black text, white background for professional appearance

## 📊 **Example Use Cases**

### **Network Security Analysis**
- **Lateral Movement Detection**: Identify unexpected communication patterns
- **Traffic Baseline**: Establish normal communication patterns
- **Anomaly Detection**: Spot unusual endpoints or traffic volumes

### **Network Troubleshooting**
- **Broadcast Analysis**: Identify chatty devices
- **Communication Flows**: Visualize client-server relationships
- **Load Distribution**: See traffic concentration points

### **Network Documentation**
- **Topology Mapping**: Document actual communication patterns
- **Capacity Planning**: Identify high-traffic links
- **Compliance Reporting**: Visual evidence of network segmentation

## 📁 **File Output**

### **SVG Files**
- **Location**: Temporary directory (auto-generated path)
- **Format**: Strict SVG 1.1, ASCII-only, flattened structure
- **Compatibility**: Opens in all modern browsers and vector graphics applications

### **PDF Files**
- **Location**: User's HOME directory
- **Filename**: `CommMatrix-YYYYMMDD-HHMMSS.pdf`
- **Quality**: High-resolution vector graphics suitable for reports
- **Tools**: Generated using first available: rsvg-convert → Inkscape → ImageMagick

## 🛠️ **Technical Details**

### **Supported Traffic Types**
- **Ethernet**: `eth.src` and `eth.dst` fields
- **Wi-Fi**: `wlan.sa` and `wlan.da` fields  
- **IPv4**: `ip.src` and `ip.dst` fields
- **IPv6**: `ipv6.src` and `ipv6.dst` fields

### **Plugin Architecture**
- **Language**: Lua (Wireshark native)
- **Field Extraction**: Robust multi-protocol field detection
- **SVG Generation**: Custom SVG builder with strict 1.1 compliance
- **Memory Efficient**: Optimized for large capture files
- **Cross-Platform**: Identical functionality on all supported platforms

### **Performance Characteristics**
- **Processing**: Real-time analysis during packet retap
- **Memory Usage**: Efficient node indexing and traffic counting
- **Scalability**: Handles hundreds of endpoints effectively
- **Filter Support**: Full integration with Wireshark display filters

## 📁 **File Locations Reference**

### **macOS**
- Plugin: `~/.local/lib/wireshark/plugins/comm_matrix_circle.lua`
- PDF Output: `~/CommMatrix-YYYYMMDD-HHMMSS.pdf`

### **Linux**  
- Plugin: `~/.local/lib/wireshark/plugins/comm_matrix_circle.lua`
- PDF Output: `~/CommMatrix-YYYYMMDD-HHMMSS.pdf`

### **Windows**
- Plugin: `%APPDATA%\Wireshark\plugins\comm_matrix_circle.lua`
- PDF Output: `%USERPROFILE%\CommMatrix-YYYYMMDD-HHMMSS.pdf`

## 🚨 **Troubleshooting**

### **No Endpoints Appear**
- Check if your capture contains the expected traffic type
- MAC View requires Ethernet (`eth.*`) or Wi-Fi (`wlan.*`) fields
- IP View requires IPv4 (`ip.*`) or IPv6 (`ipv6.*`) fields
- Apply a more specific display filter to focus on relevant traffic

### **Plugin Not Loading**
- Verify plugin file location and permissions
- Check **Help → About → Plugins** in Wireshark
- Ensure file is named exactly: `comm_matrix_circle.lua`
- Restart Wireshark completely

### **PDF Export Not Working**
- Install PDF conversion tools (see installation guides above)
- Restart Wireshark after installing new tools
- Check that tools are in your system PATH
- The plugin will show detected converters in the output window

### **SVG Not Opening**
- SVG files should open in your default browser automatically
- Manually navigate to the temp file location if auto-open fails
- Try opening with: Chrome, Firefox, Safari, or Inkscape

### **Performance Issues**
- Apply display filters before generating diagrams
- Large capture files may take time to process
- Consider filtering to specific time ranges or protocols

## 🤝 **Contributing**

We welcome contributions! Areas for enhancement:
- Additional protocol support
- Enhanced visual styling options
- Performance optimizations for very large datasets
- Interactive SVG features

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 **Author**

**Walter Hofstetter**  
📧 walter.hofstetter@netwho.com

## ⭐ **Support This Project**

If you find this plugin useful for your network analysis work:
- ⭐ Star this repository
- 🐛 Report bugs and suggest features via Issues
- 📖 Improve documentation
- 🔄 Share with the network analysis community

---

## 🎯 **Real-World Applications**

- **Network Forensics**: Visualize communication patterns in incident investigations
- **Traffic Analysis**: Understand network behavior and identify bottlenecks  
- **Security Assessment**: Map actual communication flows vs. intended architecture
- **Documentation**: Create professional network diagrams for reports and presentations
- **Training**: Teach network concepts with visual communication examples

**Transform complex network data into beautiful, insightful visualizations!** 🎨🔍

---

*Perfect for network engineers, security analysts, and anyone who needs to understand network communication patterns at a glance.*