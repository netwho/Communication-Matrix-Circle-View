--[[
Communication Matrix Report (Vertical circles + Top Conversations)
Menu: Tools -> Communication Matrix Report

Features:
- MAC circle (top) + IP circle (bottom) arranged vertically
- Right side: Table showing top conversations by packet count
- Table includes: Source, Destination, Packets, Bytes, Ports, Protocol
- Automatic PNG conversion before opening in viewer
- PDF export to HOME directory

Tested with Wireshark 4.x
--]]

if not gui_enabled() then return end

------------------------------------------------------------
-- Plugin Information
------------------------------------------------------------
set_plugin_info({
  version = "0.1.2",
  description = "Communication Matrix Report - Circular visualization with conversation table",
  author = "Communication Matrix Project",
  repository = "https://github.com/netwho/Communication-Matrix-Circle-View"
})

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

-- L4 Ports
local f_tcp_srcport = F("tcp.srcport")
local f_tcp_dstport = F("tcp.dstport")
local f_udp_srcport = F("udp.srcport")
local f_udp_dstport = F("udp.dstport")

-- Frame info
local f_frame_len = F("frame.len")
local f_frame_protocols = F("frame.protocols")

------------------------------------------------------------
-- Utils
------------------------------------------------------------
local function f2s(field)
  if not field then return nil end
  local ok, v = pcall(function() return tostring(field()) end)
  if ok and v and v ~= "" then return v end
  return nil
end

local function f2n(field)
  if not field then return nil end
  local ok, v = pcall(function() return tonumber(tostring(field())) end)
  if ok and v then return v end
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

local function tmp_png()
  return os.tmpname() .. ".png"
end

local function get_home_dir()
  local home = os.getenv("HOME") or os.getenv("USERPROFILE")
  if home and home ~= "" then return home end
  local tmp = os.tmpname()
  return tmp:match("^(.*)[/\\]") or "."
end

local function run_sh(cmd)
  local rc = os.execute(cmd)
  return rc == true or rc == 0
end

local function find_cmd(candidates)
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
    "magick", "convert",
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

local function format_bytes(bytes)
  if bytes < 1024 then return string.format("%d B", bytes)
  elseif bytes < 1024*1024 then return string.format("%.1f KB", bytes/1024)
  elseif bytes < 1024*1024*1024 then return string.format("%.1f MB", bytes/(1024*1024))
  else return string.format("%.1f GB", bytes/(1024*1024*1024)) end
end

------------------------------------------------------------
-- Collect matrix (MAC or IP) with conversation details
------------------------------------------------------------
local function collect_matrix_with_details(mode) -- "MAC" | "IP"
  local nodes_idx, nodes, counts = {}, {}, {}
  local conversations = {}  -- detailed conversation tracking
  
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
    
    local frame_len = f2n(f_frame_len) or 0
    local src_port = f2n(f_tcp_srcport) or f2n(f_udp_srcport)
    local dst_port = f2n(f_tcp_dstport) or f2n(f_udp_dstport)
    local protocols = f2s(f_frame_protocols) or ""
    
    -- Check if IP layer is present
    local has_ip = f2s(f_ip_src) or f2s(f_ip6_src) or f2s(f_ip_dst) or f2s(f_ip6_dst)

    if mode == "MAC" then
      local src = f2s(f_eth_src) or f2s(f_wlan_sa)
      local dst = f2s(f_eth_dst) or f2s(f_wlan_da)

      if src or dst then dbg_mode_matched = dbg_mode_matched + 1 end
      if not (src and dst) then return end

      dbg_extracted = dbg_extracted + 1
      local si, di = idx_for(src), idx_for(dst)
      counts[si] = counts[si] or {}
      counts[si][di] = (counts[si][di] or 0) + 1
      
      -- Track conversation details
      local conv_key = src .. " -> " .. dst
      if not conversations[conv_key] then
        conversations[conv_key] = {
          src = src,
          dst = dst,
          packets = 0,
          bytes = 0,
          ports = {},
          protocols = {}
        }
      end
      conversations[conv_key].packets = conversations[conv_key].packets + 1
      conversations[conv_key].bytes = conversations[conv_key].bytes + frame_len
      if src_port and dst_port then
        local port_pair = src_port .. ":" .. dst_port
        conversations[conv_key].ports[port_pair] = true
      end
      -- Extract top-level protocol
      local proto = protocols:match("([^:]+)$") or ""
      if proto ~= "" then conversations[conv_key].protocols[proto] = true end

    else -- "IP"
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
      
      -- Track conversation details
      local conv_key = src .. " -> " .. dst
      if not conversations[conv_key] then
        conversations[conv_key] = {
          src = src,
          dst = dst,
          packets = 0,
          bytes = 0,
          ports = {},
          protocols = {}
        }
      end
      conversations[conv_key].packets = conversations[conv_key].packets + 1
      conversations[conv_key].bytes = conversations[conv_key].bytes + frame_len
      if src_port and dst_port then
        local port_pair = src_port .. ":" .. dst_port
        conversations[conv_key].ports[port_pair] = true
      end
      -- Extract top-level protocol
      local proto = protocols:match("([^:]+)$") or ""
      if proto ~= "" then conversations[conv_key].protocols[proto] = true end
    end
  end

  retap_packets()
  tap:remove()

  -- Count conversations
  local conv_count = 0
  for _ in pairs(conversations) do conv_count = conv_count + 1 end

  return nodes, counts, conversations, {
    total = dbg_total,
    matched = dbg_mode_matched,
    extracted = dbg_extracted,
    conversations = conv_count
  }
end

------------------------------------------------------------
-- SVG builder (vertical circles + conversation table)
------------------------------------------------------------
local function build_vertical_svg_with_table(nodes_mac, counts_mac, convs_mac, nodes_ip, counts_ip, convs_ip)
  local N_mac = #nodes_mac
  local N_ip = #nodes_ip
  
  local circle_width = 1100
  local table_width = 900
  local W = circle_width + table_width + 60  -- Total width with padding
  local H = 2300  -- Increased height for better spacing
  
  local CX = circle_width / 2 + 30           -- Circle X center
  local R = 340  -- Circle radius
  local label_r = R + 40  -- More space for labels
  
  -- Align top of first circle with table title area
  local CY1 = 180 + R + 80  -- Top circle (IP): table_y_start + radius + margin
  local CY2 = CY1 + 1050     -- Bottom circle (MAC): 1050px spacing between centers to avoid label collision

  -- 5 link bins (color + width)
  local bins = {
    {min=1,    max=10,    width=2.0,  color="#2C7BB6", label="1-10"},
    {min=11,   max=100,   width=4.0,  color="#00A6CA", label="11-100"},
    {min=101,  max=500,   width=6.5,  color="#00CCBC", label="101-500"},
    {min=501,  max=1000,  width=9.0,  color="#FF8C42", label="501-1000"},  -- Orange for high traffic
    {min=1001, max=nil,   width=12.0, color="#FF6B6B", label="1001+"},      -- Light red for very high traffic
  }
  
  local function classify(c)
    for _,b in ipairs(bins) do
      if c >= b.min and (not b.max or c <= b.max) then return b end
    end
    return bins[1]
  end

  -- Optimize node placement to put communicating pairs opposite each other
  -- and space out high-traffic nodes to avoid line congestion
  local function optimize_positions(N, counts)
    if N == 0 then return {} end
    
    local order = {}  -- New ordering of node indices
    local placed = {}  -- Track which nodes have been placed
    
    -- Calculate total traffic per node (outgoing + incoming)
    local node_traffic = {}
    for i = 1, N do
      node_traffic[i] = 0
      if counts[i] then
        for j, c in pairs(counts[i]) do
          node_traffic[i] = node_traffic[i] + c
        end
      end
      for j = 1, N do
        if counts[j] and counts[j][i] then
          node_traffic[i] = node_traffic[i] + counts[j][i]
        end
      end
    end
    
    -- Find all communication pairs and sort by traffic
    local pairs = {}
    for si = 1, N do
      for di = 1, N do
        if si < di and counts[si] and counts[si][di] and counts[si][di] > 0 then
          local total = counts[si][di]
          if counts[di] and counts[di][si] then
            total = total + counts[di][si]
          end
          table.insert(pairs, {src = si, dst = di, count = total})
        end
      end
    end
    table.sort(pairs, function(a, b) return a.count > b.count end)
    
    -- Place pairs with smart spacing:
    -- - Partners are opposite (180° apart)
    -- - High-traffic nodes are evenly distributed around the circle
    local placement_positions = {}
    local num_pairs_to_place = math.min(#pairs, math.floor(N / 2))
    
    for i = 1, num_pairs_to_place do
      local pair = pairs[i]
      if not placed[pair.src] and not placed[pair.dst] then
        -- Calculate evenly-spaced position for this pair
        -- Distribute pairs evenly: positions 0, 2, 4, 6, ... (with gaps)
        local base_pos = (i - 1) * 2 + 1
        local opposite_pos = base_pos + math.floor(N / 2)
        
        if base_pos <= N and opposite_pos <= N then
          order[base_pos] = pair.src
          order[opposite_pos] = pair.dst
          placed[pair.src] = true
          placed[pair.dst] = true
        end
      end
    end
    
    -- Fill in remaining nodes in empty positions
    local fill_pos = 1
    for i = 1, N do
      if not placed[i] then
        -- Find next empty position
        while order[fill_pos] do
          fill_pos = fill_pos + 1
          if fill_pos > N then break end
        end
        if fill_pos <= N then
          order[fill_pos] = i
          placed[i] = true
        end
      end
    end
    
    -- Create positions using optimized order
    local positions = {}
    for pos = 1, N do
      local node_idx = order[pos] or pos
      local ang = (2*math.pi)*(pos-1)/math.max(N,1) - math.pi/2
      positions[node_idx] = { x = 0, y = 0, a = ang, pos = pos }
    end
    
    return positions
  end
  
  -- IP positions (top circle) with optimization
  local pos_ip = optimize_positions(N_ip, counts_ip)
  for idx, p in pairs(pos_ip) do
    p.x = CX + R*math.cos(p.a)
    p.y = CY1 + R*math.sin(p.a)
  end

  -- MAC positions (bottom circle) with optimization
  local pos_mac = optimize_positions(N_mac, counts_mac)
  for idx, p in pairs(pos_mac) do
    p.x = CX + R*math.cos(p.a)
    p.y = CY2 + R*math.sin(p.a)
  end

  -- Prepare top conversations list
  -- Strategy: Use IP conversations when available, only use MAC for non-IP protocols (ARP, etc.)
  local all_convs = {}
  local ip_pairs = {}  -- Track IP conversation pairs to avoid duplicates
  
  -- First, add all IP conversations
  for _, conv in pairs(convs_ip) do
    table.insert(all_convs, conv)
    -- Mark this pair as having IP data
    ip_pairs[conv.src .. ":" .. conv.dst] = true
  end
  
  -- Then add MAC conversations only for non-IP protocols (like ARP)
  for _, conv in pairs(convs_mac) do
    -- Check if protocols include non-IP protocols (ARP, etc.)
    local has_non_ip = false
    for proto, _ in pairs(conv.protocols) do
      local proto_lower = proto:lower()
      if proto_lower == "arp" or proto_lower == "lldp" or proto_lower == "stp" or proto_lower == "cdp" then
        has_non_ip = true
        break
      end
    end
    -- Only include MAC conversations for non-IP protocols
    if has_non_ip then
      table.insert(all_convs, conv)
    end
  end
  
  -- Sort by packet count
  table.sort(all_convs, function(a, b) return a.packets > b.packets end)
  
  -- Take top 50 conversations (fits in vertical space)
  local top_convs = {}
  for i = 1, math.min(50, #all_convs) do
    top_convs[i] = all_convs[i]
  end

  local out = {}
  local function add(s) table.insert(out, s) end

  -- Header
  add('<?xml version="1.0" encoding="UTF-8"?>\n')
  add('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n')
  add('<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="'..W..'" height="'..H..'" viewBox="0 0 '..W..' '..H..'">\n')
  add('<rect x="0" y="0" width="100%" height="100%" fill="white"/>\n')

  -- Main title
  local title = "Communication Matrix Report"
  add('<text x="'..(W/2)..'" y="44" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="24" font-weight="700" fill="#111">'..ascii_only(title)..'</text>\n')

  -- Labels will be drawn later in the center of circles, on top of links

  -- IP links (curved chords) - top circle
  for si,row in pairs(counts_ip) do
    local p1 = pos_ip[si]
    if p1 then
      for di,c in pairs(row) do
        if si ~= di and c > 0 then
          local p2 = pos_ip[di]
          local b  = classify(c)
          local d = string.format('M %.2f %.2f Q %.2f %.2f %.2f %.2f', p1.x, p1.y, CX, CY1, p2.x, p2.y)
          add('<path d="'..d..'" fill="none" stroke="'..b.color..'" stroke-opacity="0.60" stroke-width="'..string.format('%.2f', b.width)..'"/>\n')
        end
      end
    end
  end

  -- MAC links (curved chords) - bottom circle
  for si,row in pairs(counts_mac) do
    local p1 = pos_mac[si]
    if p1 then
      for di,c in pairs(row) do
        if si ~= di and c > 0 then
          local p2 = pos_mac[di]
          local b  = classify(c)
          local d = string.format('M %.2f %.2f Q %.2f %.2f %.2f %.2f', p1.x, p1.y, CX, CY2, p2.x, p2.y)
          add('<path d="'..d..'" fill="none" stroke="'..b.color..'" stroke-opacity="0.60" stroke-width="'..string.format('%.2f', b.width)..'"/>\n')
        end
      end
    end
  end

  -- IP node dots (black) - top circle
  for i=1,N_ip do
    local p = pos_ip[i]
    add('<circle cx="'..string.format('%.2f',p.x)..'" cy="'..string.format('%.2f',p.y)..'" r="6.5" fill="#000000"/>\n')
  end

  -- MAC node dots (black) - bottom circle
  for i=1,N_mac do
    local p = pos_mac[i]
add('<circle cx="'..string.format('%.2f',p.x)..'" cy="'..string.format('%.2f',p.y)..'" r="6.5" fill="#000000"/>\n')
  end

  -- IP labels (black with white outline) - top circle
  for i=1,N_ip do
    local p = pos_ip[i]
    local raw = nodes_ip[i] or ""
    local label = ascii_only(xml_escape(raw))
    local ang_deg = p.a * 180 / math.pi
    local flip = (ang_deg > 90 or ang_deg < -90)
    local rot = ang_deg + (flip and 180 or 0)
    local lx = CX + label_r * math.cos(p.a)
    local ly = CY1 + label_r * math.sin(p.a)
    local anchor = flip and "end" or "start"
    local dx = flip and -8 or 8
    -- outline
    add('<text x="'..string.format('%.2f',lx)..'" y="'..string.format('%.2f',ly)..'" transform="rotate('..string.format('%.1f',rot)..' '..string.format('%.2f',lx)..' '..string.format('%.2f',ly)..')" text-anchor="'..anchor..'" font-family="Arial, Helvetica, sans-serif" font-size="13" stroke="white" stroke-width="3" stroke-linejoin="round" fill="none"><tspan dx="'..dx..'">'..label..'</tspan></text>\n')
    -- fill
    add('<text x="'..string.format('%.2f',lx)..'" y="'..string.format('%.2f',ly)..'" transform="rotate('..string.format('%.1f',rot)..' '..string.format('%.2f',lx)..' '..string.format('%.2f',ly)..')" text-anchor="'..anchor..'" font-family="Arial, Helvetica, sans-serif" font-size="13" fill="#000000"><tspan dx="'..dx..'">'..label..'</tspan></text>\n')
  end

  -- MAC labels (black with white outline) - bottom circle
  for i=1,N_mac do
    local p = pos_mac[i]
    local raw = nodes_mac[i] or ""
    local label = ascii_only(xml_escape(raw))
    local ang_deg = p.a * 180 / math.pi
    local flip = (ang_deg > 90 or ang_deg < -90)
    local rot = ang_deg + (flip and 180 or 0)
    local lx = CX + label_r * math.cos(p.a)
    local ly = CY2 + label_r * math.sin(p.a)
    local anchor = flip and "end" or "start"
    local dx = flip and -8 or 8
    -- outline
    add('<text x="'..string.format('%.2f',lx)..'" y="'..string.format('%.2f',ly)..'" transform="rotate('..string.format('%.1f',rot)..' '..string.format('%.2f',lx)..' '..string.format('%.2f',ly)..')" text-anchor="'..anchor..'" font-family="Arial, Helvetica, sans-serif" font-size="13" stroke="white" stroke-width="3" stroke-linejoin="round" fill="none"><tspan dx="'..dx..'">'..label..'</tspan></text>\n')
    -- fill
    add('<text x="'..string.format('%.2f',lx)..'" y="'..string.format('%.2f',ly)..'" transform="rotate('..string.format('%.1f',rot)..' '..string.format('%.2f',lx)..' '..string.format('%.2f',ly)..')" text-anchor="'..anchor..'" font-family="Arial, Helvetica, sans-serif" font-size="13" fill="#000000"><tspan dx="'..dx..'">'..label..'</tspan></text>\n')
  end

  -- Center labels for circles (drawn on top, bold, with white background)
  -- IP circle center label (top)
  add('<rect x="'..(CX - 80)..'" y="'..(CY1 - 18)..'" width="160" height="36" fill="white" fill-opacity="0.9"/>\n')
  add('<text x="'..CX..'" y="'..(CY1 + 6)..'" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="18" font-weight="700" fill="#111">IP Addresses</text>\n')
  
  -- MAC circle center label (bottom)
  add('<rect x="'..(CX - 80)..'" y="'..(CY2 - 18)..'" width="160" height="36" fill="white" fill-opacity="0.9"/>\n')
  add('<text x="'..CX..'" y="'..(CY2 + 6)..'" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="18" font-weight="700" fill="#111">MAC Addresses</text>\n')

  -- Conversation table on right side
  local table_x = circle_width + 50
  local table_y_start = 180
  
  -- Table title
  add('<text x="'..table_x..'" y="'..table_y_start..'" font-family="Arial, Helvetica, sans-serif" font-size="18" font-weight="700" fill="#111">Top Conversations</text>\n')
  add('<line x1="'..table_x..'" y1="'..(table_y_start + 5)..'" x2="'..(table_x + 850)..'" y2="'..(table_y_start + 5)..'" stroke="#999" stroke-width="2"/>\n')
  
  -- Table headers (no background frame, just bold text with divider)
  local header_y = table_y_start + 35
  add('<text x="'..(table_x + 5)..'" y="'..header_y..'" font-family="Arial, Helvetica, sans-serif" font-size="13" font-weight="700" fill="#333">Source</text>\n')
  add('<text x="'..(table_x + 220)..'" y="'..header_y..'" font-family="Arial, Helvetica, sans-serif" font-size="13" font-weight="700" fill="#333">Destination</text>\n')
  add('<text x="'..(table_x + 440)..'" y="'..header_y..'" font-family="Arial, Helvetica, sans-serif" font-size="13" font-weight="700" fill="#333">Packets</text>\n')
  add('<text x="'..(table_x + 530)..'" y="'..header_y..'" font-family="Arial, Helvetica, sans-serif" font-size="13" font-weight="700" fill="#333">Bytes</text>\n')
  add('<text x="'..(table_x + 630)..'" y="'..header_y..'" font-family="Arial, Helvetica, sans-serif" font-size="13" font-weight="700" fill="#333">Ports</text>\n')
  add('<text x="'..(table_x + 730)..'" y="'..header_y..'" font-family="Arial, Helvetica, sans-serif" font-size="13" font-weight="700" fill="#333">Protocol</text>\n')
  add('<line x1="'..table_x..'" y1="'..(header_y + 5)..'" x2="'..(table_x + 850)..'" y2="'..(header_y + 5)..'" stroke="#ccc" stroke-width="1"/>\n')
  
  -- Table rows
  local row_height = 28  -- More compact spacing
  for i, conv in ipairs(top_convs) do
    local row_y = header_y + 18 + (i * row_height)
    
    -- Alternating row background
    if i % 2 == 0 then
      add('<rect x="'..table_x..'" y="'..(row_y - 12)..'" width="850" height="'..row_height..'" fill="#fafafa"/>\n')
    end
    
    -- Truncate long addresses
    local src_display = conv.src
    if #src_display > 22 then src_display = src_display:sub(1, 20) .. ".." end
    local dst_display = conv.dst
    if #dst_display > 22 then dst_display = dst_display:sub(1, 20) .. ".." end
    
    -- Collect ports (show first 2)
    local port_list = {}
    for port, _ in pairs(conv.ports) do
      table.insert(port_list, port)
      if #port_list >= 2 then break end
    end
    local ports_str = table.concat(port_list, ",")
    if #ports_str > 12 then ports_str = ports_str:sub(1, 10) .. ".." end
    
    -- Collect protocols (show first 2)
    local proto_list = {}
    for proto, _ in pairs(conv.protocols) do
      table.insert(proto_list, proto)
      if #proto_list >= 2 then break end
    end
    local proto_str = table.concat(proto_list, ",")
    if #proto_str > 12 then proto_str = proto_str:sub(1, 10) .. ".." end
    
    add('<text x="'..(table_x + 5)..'" y="'..row_y..'" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#222">'..ascii_only(xml_escape(src_display))..'</text>\n')
    add('<text x="'..(table_x + 220)..'" y="'..row_y..'" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#222">'..ascii_only(xml_escape(dst_display))..'</text>\n')
    add('<text x="'..(table_x + 440)..'" y="'..row_y..'" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#222">'..conv.packets..'</text>\n')
    add('<text x="'..(table_x + 530)..'" y="'..row_y..'" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#222">'..format_bytes(conv.bytes)..'</text>\n')
    add('<text x="'..(table_x + 630)..'" y="'..row_y..'" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#444">'..ascii_only(xml_escape(ports_str))..'</text>\n')
    add('<text x="'..(table_x + 730)..'" y="'..row_y..'" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#444">'..ascii_only(xml_escape(proto_str))..'</text>\n')
  end

  -- Legend (bottom left)
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
-- PNG conversion (SVG -> PNG)
------------------------------------------------------------
local function convert_to_png(svg_path, tw, tools)
  local png_path = tmp_png()

  if tools.rsvg then
    local cmd = "sh -c '\""..tools.rsvg.."\" -f png -o \""..png_path.."\" \""..svg_path.."\"'"
    if run_sh(cmd) then
      tw:append("Converted to PNG via: "..tools.rsvg.."\n")
      return png_path
    end
  end

  if tools.inkscape then
    local cmd = "sh -c '\""..tools.inkscape.."\" \""..svg_path.."\" --export-type=png --export-filename=\""..png_path.."\"'"
    if run_sh(cmd) then
      tw:append("Converted to PNG via: "..tools.inkscape.."\n")
      return png_path
    end
  end

  if tools.magick then
    local cmd = tools.magick:match("magick$") and (tools.magick.." convert") or tools.magick
    local full = "sh -c '"..cmd.." \""..svg_path.."\" \""..png_path.."\"'"
    if run_sh(full) then
      tw:append("Converted to PNG via: "..tools.magick.."\n")
      return png_path
    end
  end

  tw:append("PNG conversion not available (no converter succeeded). Opening SVG instead.\n")
  return svg_path
end

------------------------------------------------------------
-- PDF export
------------------------------------------------------------
local function export_pdf(svg_path, tw, tools)
  local home = get_home_dir()
  local stamp = os.date("%Y%m%d-%H%M%S")
  local output_dir = home .. "/Documents/PacketReporter Reports"
  -- Ensure output directory exists
  run_sh("mkdir -p '" .. output_dir .. "'")
  local pdf_path = output_dir .. "/comm_matrix_report-" .. stamp .. ".pdf"

  if tools.rsvg then
    local cmd = "sh -c '\""..tools.rsvg.."\" -f pdf -o \""..pdf_path.."\" \""..svg_path.."\"'"
    if run_sh(cmd) then
      tw:append("Exported PDF via: "..tools.rsvg.." -> "..pdf_path.."\n")
      -- Auto-open the PDF with default app
      run_sh("open '" .. pdf_path .. "'")
      return
    end
  end

  if tools.inkscape then
    local cmd = "sh -c '\""..tools.inkscape.."\" \""..svg_path.."\" --export-type=pdf --export-filename=\""..pdf_path.."\"'"
    if run_sh(cmd) then
      tw:append("Exported PDF via: "..tools.inkscape.." -> "..pdf_path.."\n")
      -- Auto-open the PDF with default app
      run_sh("open '" .. pdf_path .. "'")
      return
    end
  end

  if tools.magick then
    local cmd = tools.magick:match("magick$") and (tools.magick.." convert") or tools.magick
    local full = "sh -c '"..cmd.." \""..svg_path.."\" \""..pdf_path.."\"'"
    if run_sh(full) then
      tw:append("Exported PDF via: "..tools.magick.." -> "..pdf_path.."\n"); return
    end
  end

  tw:append("PDF export not available (no converter succeeded).\n")
end

------------------------------------------------------------
-- Main UI flow
------------------------------------------------------------
local function build_and_show()
  local tw = TextWindow.new("Communication Matrix Report")
  tw:clear()
  tw:append("Building Communication Matrix Report...\n")

  -- Collect MAC data with conversation details
  local nodes_mac, counts_mac, convs_mac, dbg_mac = collect_matrix_with_details("MAC")
  tw:append(string.format("MAC: %d nodes, %d conversations\n", #nodes_mac, dbg_mac.conversations))

  -- Collect IP data with conversation details
  local nodes_ip, counts_ip, convs_ip, dbg_ip = collect_matrix_with_details("IP")
  tw:append(string.format("IP: %d nodes, %d conversations\n", #nodes_ip, dbg_ip.conversations))

  if #nodes_mac == 0 and #nodes_ip == 0 then
    tw:append("No endpoints found for either MAC or IP.\n")
    tw:append("Tip: Apply a display filter first to capture relevant traffic.\n")
    return
  end

  local svg = build_vertical_svg_with_table(nodes_mac, counts_mac, convs_mac, nodes_ip, counts_ip, convs_ip)
  local svg_path = tmp_svg()
  local fh, err = io.open(svg_path, "wb")
  if not fh then tw:append("Write failed: "..tostring(err).."\n"); return end
  fh:write(svg); fh:close()

  tw:append("Wrote SVG to: "..svg_path.."\n")

  local tools = detect_converters()
  tw:append("\nConverters detected:\n")
  tw:append("  rsvg-convert: "..(tools.rsvg or "not found").."\n")
  tw:append("  inkscape    : "..(tools.inkscape or "not found").."\n")
  tw:append("  imagemagick : "..(tools.magick or "not found").."\n\n")

  tw:add_button("Open PNG", function()
    local png_path = convert_to_png(svg_path, tw, tools)
    if not try_open_in_browser(png_path) then
      tw:append("Could not auto-open; open the file manually: "..png_path.."\n")
    end
  end)
  
  tw:add_button("Open SVG", function()
    if not try_open_in_browser(svg_path) then
      tw:append("Could not auto-open; open the file manually.\n")
    end
  end)
  
  tw:add_button("Export PDF", function() export_pdf(svg_path, tw, tools) end)

  tw:append("Tip: Apply a display filter before opening this tool to reduce clutter.\n")
end

------------------------------------------------------------
-- Smart Menu Registration
------------------------------------------------------------
-- Check if PacketReporter plugin is installed by looking for its menu entry
local function check_packet_reporter_installed()
  local home = get_home_dir()
  local check_paths = {
    home .. "/.local/lib/wireshark/plugins/packet_reporter.lua",
    home .. "/.wireshark/plugins/packet_reporter.lua",
  }
  -- Note: This plugin file is now named comm_matrix_reporter.lua
  
  for _, path in ipairs(check_paths) do
    local f = io.open(path, "r")
    if f then
      f:close()
      return true
    end
  end
  return false
end

-- Register menu in appropriate location
if check_packet_reporter_installed() then
  -- If PacketReporter is installed, add as 4th menu item
  register_menu("PacketReporter/4. Communication Matrix Report", build_and_show, MENU_TOOLS_UNSORTED)
else
  -- Otherwise, add to root Tools menu
  register_menu("Communication Matrix Report", build_and_show, MENU_TOOLS_UNSORTED)
end
