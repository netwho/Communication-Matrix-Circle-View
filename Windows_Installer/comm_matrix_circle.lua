--[[
Comm Matrix Circle View (strict SVG 1.1, flattened, PDF export to HOME, MAC/IP selector)
Menu: Tools -> Comm Matrix (Circle View)

What's inside
- Selector window: "MAC View" + "IP View" and Help with PDF export prerequisites
- Result window: "Open SVG" + "Export PDF"
- Robust field extraction:
    * MAC mode: Ethernet (eth.src/dst) + Wi-Fi (wlan.sa/da)
    * IP mode : IPv4 (ip.src/dst) + IPv6 (ipv6.src/dst)
- Output: strict SVG 1.1 (ASCII-only), flattened (no defs/groups/filters/markers)
- Smaller circle; labels closer; black node dots
- 5 traffic bins (color + width) with legend:
    1-10, 11-100, 101-500, 501-1000, 1001+

PDF export
- Saves to the user's HOME directory as CommMatrix-YYYYMMDD-HHMMSS.pdf
- Uses first available tool: rsvg-convert | inkscape | ImageMagick (magick/convert)

Tested with Wireshark 4.x
--]]

if not gui_enabled() then return end

------------------------------------------------------------
-- Fields
------------------------------------------------------------
local F = Field.new

-- L2 (Ethernet)
local f_eth_src = F("eth.src")
local f_eth_dst = F("eth.dst")

-- L2 (Wi-Fi / 802.11)
local f_wlan_sa  = F("wlan.sa")
local f_wlan_da  = F("wlan.da")

-- L3 IPv4
local f_ip_src  = F("ip.src")
local f_ip_dst  = F("ip.dst")
-- L3 IPv6
local f_ip6_src = F("ipv6.src")
local f_ip6_dst = F("ipv6.dst")

------------------------------------------------------------
-- Utils
------------------------------------------------------------
local function f2s(field)
  if not field then return nil end
  local ok, v = pcall(function() return tostring(field()) end)
  if ok and v and v ~= "" then return v end
  return nil
end

local function xml_escape(s)
  if not s then return "" end
  s = tostring(s)
  s = s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
       :gsub("\"","&quot;"):gsub("'","&apos;")
  return s
end

local function ascii_only(s)
  return (s:gsub("[^\x20-\x7E]", "?"))
end

local function try_open_in_browser(path)
  if type(browser_open_url) == "function" then
    local ok = pcall(function() browser_open_url("file://"..path) end)
    if ok then return true end
  end
  return false
end

local function tmp_svg()
  return os.tmpname() .. ".svg"
end

-- Home directory helper (macOS/Linux, Windows fallback)
local function get_home_dir()
  local home = os.getenv("HOME") or os.getenv("USERPROFILE")
  if home and home ~= "" then return home end
  -- last resort: temp dir prefix
  local tmp = os.tmpname()
  return tmp:match("^(.*)[/\\]") or "."
end

-- Enhanced command finder: searches PATH and common install dirs
local function run_sh(cmd)
  local rc = os.execute(cmd)
  return rc == true or rc == 0
end

local function find_cmd(candidates)
  -- returns first existing candidate path (string) or nil
  local function in_path(name)
    return run_sh("sh -c 'command -v "..name.." >/dev/null 2>&1'")
  end
  local function is_exec(path)
    return run_sh("sh -c '[ -x "..path.." ]'")
  end
  for _,c in ipairs(candidates) do
    if c:find("/") then
      if is_exec(c) then return c end
    else
      if in_path(c) then return c end
    end
  end
  return nil
end

-- Detect converters (attempt on demand so PATH changes are respected)
local function detect_converters()
  local rsvg_candidates = {
    "rsvg-convert",
    "/opt/homebrew/bin/rsvg-convert", "/usr/local/bin/rsvg-convert", "/usr/bin/rsvg-convert"
  }
  local inkscape_candidates = {
    "inkscape",
    "/Applications/Inkscape.app/Contents/MacOS/inkscape",
    "/opt/homebrew/bin/inkscape", "/usr/local/bin/inkscape", "/usr/bin/inkscape"
  }
  local magick_candidates = {
    "magick", "convert",   -- prefer modern magick, fallback to legacy convert
    "/opt/homebrew/bin/magick", "/usr/local/bin/magick", "/usr/bin/magick",
    "/opt/homebrew/bin/convert", "/usr/local/bin/convert", "/usr/bin/convert"
  }

  local rsvg   = find_cmd(rsvg_candidates)
  local inks   = find_cmd(inkscape_candidates)
  local magick = find_cmd(magick_candidates)

  return {
    rsvg = rsvg,
    inkscape = inks,
    magick = magick,
    tried = {
      rsvg = rsvg_candidates,
      inkscape = inkscape_candidates,
      magick = magick_candidates
    }
  }
end

------------------------------------------------------------
-- Collect matrix (MAC or IP) with robustness + debug
------------------------------------------------------------
local function collect_matrix(mode) -- "MAC" | "IP"
  local nodes_idx, nodes, counts = {}, {}, {}

  local dbg_total = 0
  local dbg_mode_matched = 0
  local dbg_extracted = 0

  local function idx_for(key)
    local i = nodes_idx[key]
    if not i then
      i = #nodes + 1
      nodes_idx[key] = i
      nodes[i] = key
    end
    return i
  end

  local tap = Listener.new("frame", nil)

  function tap.packet(pinfo, tvb)
    dbg_total = dbg_total + 1

    if mode == "MAC" then
      -- Try Ethernet first, then Wi-Fi
      local src = f2s(f_eth_src) or f2s(f_wlan_sa)
      local dst = f2s(f_eth_dst) or f2s(f_wlan_da)

      if src or dst then dbg_mode_matched = dbg_mode_matched + 1 end
      if not (src and dst) then return end

      dbg_extracted = dbg_extracted + 1
      local si, di = idx_for(src), idx_for(dst)
      counts[si] = counts[si] or {}
      counts[si][di] = (counts[si][di] or 0) + 1

    else -- "IP"
      -- Support IPv4 OR IPv6
      local src = f2s(f_ip_src) or f2s(f_ip6_src)
      local dst = f2s(f_ip_dst) or f2s(f_ip6_dst)

      if (f2s(f_ip_src) or f2s(f_ip_dst) or f2s(f_ip6_src) or f2s(f_ip6_dst)) then
        dbg_mode_matched = dbg_mode_matched + 1
      end

      if not (src and dst) then return end

      dbg_extracted = dbg_extracted + 1
      local si, di = idx_for(src), idx_for(dst)
      counts[si] = counts[si] or {}
      counts[si][di] = (counts[si][di] or 0) + 1
    end
  end

  retap_packets()
  tap:remove() -- clean up

  return nodes, counts, {
    total = dbg_total,
    matched = dbg_mode_matched,
    extracted = dbg_extracted
  }
end

------------------------------------------------------------
-- SVG builder (strict, flattened)
------------------------------------------------------------
local function build_svg(nodes, counts)
  local N = #nodes
  local W,H  = 1500, 1100
  local CX,CY = W/2, H/2 + 14
  local R     = math.min(W,H) * 0.28
  local label_r = R + 36

  -- positions
  local pos = {}
  for i=1,N do
    local ang = (2*math.pi)*(i-1)/math.max(N,1) - math.pi/2
    pos[i] = { x = CX + R*math.cos(ang), y = CY + R*math.sin(ang), a = ang }
  end

  -- 5 link bins (color + width)
  local bins = {
    {min=1,    max=10,    width=2.0,  color="#2C7BB6", label="1-10"},
    {min=11,   max=100,   width=4.0,  color="#00A6CA", label="11-100"},
    {min=101,  max=500,   width=6.5,  color="#00CCBC", label="101-500"},
    {min=501,  max=1000,  width=9.0,  color="#90EB9D", label="501-1000"},
    {min=1001, max=nil,   width=12.0, color="#F9D057", label="1001+"},
  }
  local function classify(c)
    for _,b in ipairs(bins) do
      if c >= b.min and (not b.max or c <= b.max) then return b end
    end
    return bins[1]
  end

  -- stats
  local links, maxc = 0, 0
  for si,row in pairs(counts) do
    for di,c in pairs(row) do
      if si ~= di and c > 0 then
        links = links + 1
        if c > maxc then maxc = c end
      end
    end
  end
  if maxc == 0 then maxc = 1 end

  local out = {}
  local function add(s) table.insert(out, s) end

  -- header
  add('<?xml version="1.0" encoding="UTF-8"?>\n')
  add('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n')
  add('<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="'..W..'" height="'..H..'" viewBox="0 0 '..W..' '..H..'">\n')
  add('<rect x="0" y="0" width="100%" height="100%" fill="white"/>\n')

  local title = "Communication Matrix - Circle View"
  add('<text x="'..(W/2)..'" y="44" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="24" font-weight="700" fill="#111">'..ascii_only(title)..'</text>\n')
  local subtitle = "Nodes: "..N.." | Links: "..links.." | Max packets on a link: "..maxc
  add('<text x="'..(W/2)..'" y="64" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#444">'..ascii_only(subtitle)..'</text>\n')

  -- links (curved chords)
  for si,row in pairs(counts) do
    local p1 = pos[si]
    if p1 then
      for di,c in pairs(row) do
        if si ~= di and c > 0 then
          local p2 = pos[di]
          local b  = classify(c)
          local d = string.format('M %.2f %.2f Q %.2f %.2f %.2f %.2f', p1.x, p1.y, CX, CY, p2.x, p2.y)
          add('<path d="'..d..'" fill="none" stroke="'..b.color..'" stroke-opacity="0.60" stroke-width="'..string.format('%.2f', b.width)..'"/>\n')
        end
      end
    end
  end

  -- node dots (black)
  for i=1,N do
    local p = pos[i]
    add('<circle cx="'..string.format('%.2f',p.x)..'" cy="'..string.format('%.2f',p.y)..'" r="6.5" fill="#000000"/>\n')
  end

  -- labels (black with white outline)
  for i=1,N do
    local p = pos[i]
    local raw = nodes[i] or ""
    local label = ascii_only(xml_escape(raw))
    local ang_deg = p.a * 180 / math.pi
    local flip = (ang_deg > 90 or ang_deg < -90)
    local rot = ang_deg + (flip and 180 or 0)
    local lx = CX + label_r * math.cos(p.a)
    local ly = CY + label_r * math.sin(p.a)
    local anchor = flip and "end" or "start"
    local dx = flip and -8 or 8
    -- outline
    add('<text x="'..string.format('%.2f',lx)..'" y="'..string.format('%.2f',ly)..'" transform="rotate('..string.format('%.1f',rot)..' '..string.format('%.2f',lx)..' '..string.format('%.2f',ly)..')" ')
    add('text-anchor="'..anchor..'" font-family="Arial, Helvetica, sans-serif" font-size="13" stroke="white" stroke-width="3" stroke-linejoin="round" fill="none">')
    add('<tspan dx="'..dx..'">'..label..'</tspan></text>\n')
    -- fill
    add('<text x="'..string.format('%.2f',lx)..'" y="'..string.format('%.2f',ly)..'" transform="rotate('..string.format('%.1f',rot)..' '..string.format('%.2f',lx)..' '..string.format('%.2f',ly)..')" ')
    add('text-anchor="'..anchor..'" font-family="Arial, Helvetica, sans-serif" font-size="13" fill="#000000">')
    add('<tspan dx="'..dx..'">'..label..'</tspan></text>\n')
  end

  -- legend (bins)
  local Lx, Ly = 30, H - 150
  add('<text x="'..Lx..'" y="'..(Ly-14)..'" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#444">Traffic bins (color and width):</text>\n')
  for i,b in ipairs(bins) do
    local y = Ly + (i-1)*26
    add('<line x1="'..Lx..'" y1="'..y..'" x2="'..(Lx+100)..'" y2="'..y..'" stroke="'..b.color..'" stroke-opacity="0.95" stroke-width="'..string.format('%.2f',b.width)..'"/>\n')
    add('<text x="'..(Lx+112)..'" y="'..(y+4)..'" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#333">'..b.label..' packets</text>\n')
  end

  add('</svg>\n')
  return table.concat(out)
end

------------------------------------------------------------
-- PDF export (using detected converters) to HOME
------------------------------------------------------------
local function export_pdf(svg_path, tw, tools)
  local home = get_home_dir()
  local stamp = os.date("%Y%m%d-%H%M%S")
  local pdf_path = home .. "/CommMatrix-" .. stamp .. ".pdf"

  -- Prefer rsvg-convert
  if tools.rsvg then
    local cmd = "sh -c '\""..tools.rsvg.."\" -f pdf -o \""..pdf_path.."\" \""..svg_path.."\"'"
    if run_sh(cmd) then
      tw:append("Exported PDF via: "..tools.rsvg.." -> "..pdf_path.."\n"); return
    end
  end

  -- Try inkscape
  if tools.inkscape then
    local cmd = "sh -c '\""..tools.inkscape.."\" \""..svg_path.."\" --export-type=pdf --export-filename=\""..pdf_path.."\"'"
    if run_sh(cmd) then
      tw:append("Exported PDF via: "..tools.inkscape.." -> "..pdf_path.."\n"); return
    end
  end

  -- Try ImageMagick (magick OR convert)
  if tools.magick then
    local cmd = tools.magick:match("magick$") and (tools.magick.." convert") or tools.magick
    local full = "sh -c '"..cmd.." \""..svg_path.."\" \""..pdf_path.."\"'"
    if run_sh(full) then
      tw:append("Exported PDF via: "..tools.magick.." -> "..pdf_path.."\n"); return
    end
  end

  tw:append("PDF export not available (no converter succeeded).\n")
  tw:append("Tried:\n  rsvg: "..table.concat(tools.tried.rsvg, ", ").."\n  inkscape: "..table.concat(tools.tried.inkscape, ", ").."\n  imagemagick: "..table.concat(tools.tried.magick, ", ").."\n")
end

------------------------------------------------------------
-- UI flow (selector + result window with export)
------------------------------------------------------------
local function build_and_show(mode)
  local tw = TextWindow.new("Comm Matrix (Circle View)")
  tw:clear()
  tw:append(("Building matrix (mode: %s)...\n"):format(mode))

  local nodes, counts, dbg = collect_matrix(mode)
  if #nodes == 0 then
    tw:append("No endpoints for the chosen mode.\n")
    tw:append(("Debug: total=%d, mode_matched=%d, extracted=%d\n"):format(dbg.total, dbg.matched, dbg.extracted))
    tw:append("Tip: For MAC, ensure frames have eth.* or wlan.* fields. For IP, ensure IPv4 or IPv6 is present.\n")
    return
  end

  local any = false
  for _,row in pairs(counts) do
    for _,c in pairs(row) do if c>0 then any=true break end end
    if any then break end
  end
  if not any then
    tw:append("Found endpoints but no communications.\n")
    tw:append(("Debug: total=%d, mode_matched=%d, extracted=%d\n"):format(dbg.total, dbg.matched, dbg.extracted))
    return
  end

  local svg = build_svg(nodes, counts)
  local out = tmp_svg()
  local fh, err = io.open(out, "wb")
  if not fh then tw:append("Write failed: "..tostring(err).."\n"); return end
  fh:write(svg); fh:close()

  tw:append("Wrote SVG to: "..out.."\n")
  tw:append(("Debug: total=%d, mode_matched=%d, extracted=%d\n"):format(dbg.total, dbg.matched, dbg.extracted))

  local tools = detect_converters()
  tw:append("\nConverters detected:\n")
  tw:append("  rsvg-convert: "..(tools.rsvg or "not found").."\n")
  tw:append("  inkscape    : "..(tools.inkscape or "not found").."\n")
  tw:append("  imagemagick : "..(tools.magick or "not found").."\n\n")

  tw:add_button("Open SVG", function()
    if not try_open_in_browser(out) then
      tw:append("Could not auto-open; open the file manually.\n")
    end
  end)
  tw:add_button("Export PDF", function() export_pdf(out, tw, tools) end)

  tw:append("Tip: apply a display filter first to reduce clutter.\n")
end

local function show_selector()
  local tw = TextWindow.new("Comm Matrix - Select View")
  tw:append("Choose address mode:\n")
  tw:add_button("MAC View", function() build_and_show("MAC") end)
  tw:add_button("IP View", function() build_and_show("IP") end)

  -- Show help + detected tools
  local tools = detect_converters()
  tw:append("\nHelp:\n")
  tw:append("- This tool scans the current display filter, then renders a circle view to an SVG file.\n")
  tw:append("- Line color and thickness reflect packet count in 5 bins: 1-10, 11-100, 101-500, 501-1000, 1001+.\n")
  tw:append("- Node dots are black; labels are drawn close to the ring with a white outline for readability.\n")
  tw:append("\nSVG viewing prerequisites:\n")
  tw:append("  * macOS: Safari (preferred) or Chrome/Firefox/Visual Studio Code\n")
  tw:append("  * Windows: Chrome/Firefox/Edge or Inkscape\n")
  tw:append("  * Linux: Chrome/Firefox/Chromium or Inkscape\n")
  tw:append("\nPDF export prerequisites (any one of these in PATH works):\n")
  tw:append("  * rsvg-convert (librsvg)\n")
  tw:append("  * inkscape\n")
  tw:append("  * magick or convert (ImageMagick)\n")
  tw:append("\nDetected now:\n")
  tw:append("  rsvg-convert: "..(tools.rsvg or "not found").."\n")
  tw:append("  inkscape    : "..(tools.inkscape or "not found").."\n")
  tw:append("  imagemagick : "..(tools.magick or "not found").."\n")
  tw:append("\nInstall hints:\n")
  tw:append("- macOS (Homebrew): brew install librsvg inkscape imagemagick\n")
  tw:append("- Debian/Ubuntu/Kali: sudo apt-get install librsvg2-bin inkscape imagemagick\n")
  tw:append("\nAfter installing, reopen Wireshark so the environment PATH is picked up.\n")
end

register_menu("Comm Matrix (Circle View)", show_selector, MENU_TOOLS_UNSORTED)
