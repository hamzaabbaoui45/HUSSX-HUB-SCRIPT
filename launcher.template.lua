--!nocheck
--[[
================================================================================
  PAYED SCRIPTS HUB  ·  all-in-one launcher
  educational use only
================================================================================

  WHAT THIS IS
  Every hub from the folder is embedded in this single file, deflate-compressed
  and base64-encoded (~1.2 MB of source stored in ~300 KB). Pick one from the
  list, it is unpacked, compiled with loadstring() and runs exactly like it
  would if you had pasted that file straight into your executor.

  EXECUTOR NOTES
  Written to survive locked-down executors: no service is touched without a
  pcall, CoreGui is optional (PlayerGui is preferred), loadstring() is looked up
  through several fallbacks, and any startup failure draws an error panel with
  the actual message instead of dying silently in the console.

  WHY YOU CAN'T RUN THEM ALL AT ONCE
  8 duel hubs that were never designed to coexist. They all:
    * write Humanoid.WalkSpeed / AssemblyLinearVelocity every Heartbeat
    * bind the same keys (X, Z, C, E, F, Q, T, L, R, G, M, V, ...)
    * spawn their own ScreenGui, mobile panel and intro
  Merge them literally and the loops fight each other: your speed snaps
  between values, one key triggers three toggles, and the frame rate dies.
  So this launcher runs ONE at a time and cleans the previous one up first.

  CONTROLS
    RightShift .......... show / hide      (click the key chip to rebind)
    search box .......... filter by name or feature
    LOAD ................ start that hub (stops the running one first)
    STOP ................ remove the running hub's GUIs + its _G flags
    — ................... collapse to a small floating button
    × ................... hide completely (RightShift brings it back)

  NOTE: a pure Luau script cannot disconnect connections it did not create,
  so a hub's Heartbeat loops survive a STOP. They idle harmlessly once the
  GUIs are gone and their toggles are off. For a 100% clean slate, rejoin.
================================================================================
]]

-- running this file twice tears the old instance down first, so keybinds and
-- connections never stack up
if type(_G.__PSH_CLEANUP) == "function" then
    pcall(_G.__PSH_CLEANUP)
elseif _G.__PSH_GUI then
    pcall(function() _G.__PSH_GUI:Destroy() end)
end
_G.__PSH_CLEANUP = nil
_G.__PSH_GUI = nil

local CONFIG_FILE = "PayedScriptsHub.json"

-- ============================================================================
--  executor-safe startup
--  everything here has to work even on a locked-down executor, otherwise the
--  user just sees "nothing happened" with no clue why.
-- ============================================================================
local function safeService(name)
    local ok, service = pcall(function() return game:GetService(name) end)
    if ok then return service end
    return nil
end

local Players = safeService("Players")
local UIS     = safeService("UserInputService")
local TS      = safeService("TweenService")
local HttpS   = safeService("HttpService")
local LP      = Players and Players.LocalPlayer

-- CoreGui is identity-gated on some executors, so it is never touched until
-- it is actually needed, and always inside pcall
local function guiCandidates()
    local list = {}
    if LP then
        local ok, pg = pcall(function() return LP:FindFirstChildOfClass("PlayerGui") end)
        if ok and pg then list[#list + 1] = pg end
    end
    local okc, cg = pcall(function() return game:GetService("CoreGui") end)
    if okc and cg then list[#list + 1] = cg end
    local okh, hui = pcall(function()
        if gethui then return gethui() end
        return nil
    end)
    if okh and hui then list[#list + 1] = hui end
    return list
end

local function guiRoots()
    local list, seen = {}, {}
    for _, parent in ipairs(guiCandidates()) do
        if not seen[parent] then
            seen[parent] = true
            list[#list + 1] = parent
        end
    end
    return list
end

local function feedGui(gui)
    for _, parent in ipairs(guiCandidates()) do
        local ok = pcall(function() gui.Parent = parent end)
        if ok and gui.Parent == parent then return parent end
    end
    return nil
end

-- last resort: put the actual error on screen instead of dying silently
local function showFatal(message)
    local text = tostring(message)
    if #text > 1500 then text = string.sub(text, 1, 1500) .. "…" end
    warn("[PayedScriptsHub] " .. text)

    local ok, gui = pcall(function()
        local parent = guiCandidates()[1]
        if not parent then error("no gui parent") end

        local g = Instance.new("ScreenGui")
        g.Name = "PayedScriptsHubError"
        g.ResetOnSpawn = false
        g.DisplayOrder = 2147483000
        g.Parent = parent

        local frame = Instance.new("Frame")
        frame.Size = UDim2.fromOffset(440, 230)
        frame.Position = UDim2.new(0.5, -220, 0.5, -115)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        frame.BorderSizePixel = 0
        frame.Parent = g

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 12)
        c.Parent = frame

        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(110, 45, 45)
        s.Parent = frame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -32, 0, 24)
        title.Position = UDim2.fromOffset(16, 14)
        title.BackgroundTransparency = 1
        title.Text = "PAYED SCRIPTS — could not start"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextColor3 = Color3.fromRGB(255, 120, 120)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = frame

        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -32, 1, -96)
        body.Position = UDim2.fromOffset(16, 42)
        body.BackgroundTransparency = 1
        body.Text = text
        body.Font = Enum.Font.Code
        body.TextSize = 12
        body.TextColor3 = Color3.fromRGB(215, 215, 228)
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextWrapped = true
        body.Parent = frame

        local close = Instance.new("TextButton")
        close.Size = UDim2.fromOffset(90, 26)
        close.Position = UDim2.new(1, -106, 1, -40)
        close.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
        close.Text = "dismiss"
        close.Font = Enum.Font.GothamMedium
        close.TextSize = 11
        close.TextColor3 = Color3.fromRGB(200, 200, 215)
        close.AutoButtonColor = false
        close.Parent = frame
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 7)
        cc.Parent = close
        close.MouseButton1Click:Connect(function() g:Destroy() end)

        return g
    end)

    if not ok then
        warn("[PayedScriptsHub] could not draw the error panel either")
    end
end

-- palette ---------------------------------------------------------------------
local C = {
    bg      = Color3.fromRGB(13, 13, 17),
    panel   = Color3.fromRGB(21, 21, 27),
    row     = Color3.fromRGB(27, 27, 34),
    rowHi   = Color3.fromRGB(35, 35, 44),
    stroke  = Color3.fromRGB(48, 48, 61),
    text    = Color3.fromRGB(238, 238, 246),
    dim     = Color3.fromRGB(133, 133, 155),
    faint   = Color3.fromRGB(96, 96, 115),
    ok      = Color3.fromRGB(110, 220, 150),
    bad     = Color3.fromRGB(255, 112, 112),
}

local FONT       = Enum.Font.Gotham
local FONT_B     = Enum.Font.GothamBold
local FONT_M     = Enum.Font.GothamMedium

-- settings --------------------------------------------------------------------
local Settings = {
    toggleKey = "RightShift",
    autoHide  = true,
}

do
    pcall(function()
        if not (isfile and readfile and isfile(CONFIG_FILE)) then return end
        local data = HttpS:JSONDecode(readfile(CONFIG_FILE))
        if type(data) ~= "table" then return end
        if type(data.toggleKey) == "string" and Enum.KeyCode[data.toggleKey] then
            Settings.toggleKey = data.toggleKey
        end
        if type(data.autoHide) == "boolean" then Settings.autoHide = data.autoHide end
    end)
end

local function saveSettings()
    pcall(function()
        if not (writefile and HttpS) then return end
        writefile(CONFIG_FILE, HttpS:JSONEncode({
            toggleKey = Settings.toggleKey,
            autoHide  = Settings.autoHide,
        }))
    end)
end

-- hub table, filled in by the build script ------------------------------------
local HUBS = {}
--@@HUBS@@

-- helpers ---------------------------------------------------------------------
local CONNS = {}
local function track(conn)
    CONNS[#CONNS + 1] = conn
    return conn
end

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = o
    return c
end

local function stroke(o, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or C.stroke
    s.Thickness = th or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = o
    return s
end

local function label(parent, text, size, pos, font, colour, align)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = size
    l.Position = pos
    l.Text = text
    l.Font = font or FONT
    l.TextSize = 11
    l.TextColor3 = colour or C.text
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Parent = parent
    return l
end

-- what a hub owns, so STOP never nukes the game's own UI
local function snapshot()
    local guis, keys = {}, {}
    for _, root in ipairs(guiRoots()) do
        for _, c in ipairs(root:GetChildren()) do
            if c:IsA("ScreenGui") then guis[c] = true end
        end
    end
    for k in pairs(_G) do keys[k] = true end
    return guis, keys
end

-- how many windows the launched hub has put on screen so far
local function newGuiCount(preGuis, mine)
    local n = 0
    for _, root in ipairs(guiRoots()) do
        for _, c in ipairs(root:GetChildren()) do
            if c:IsA("ScreenGui") and c ~= mine and not preGuis[c] then
                n = n + 1
            end
        end
    end
    return n
end

local function cleanHub(hub, preGuis, preKeys, keep)
    local wanted = hub.guiSet
    for _, root in ipairs(guiRoots()) do
        for _, c in ipairs(root:GetChildren()) do
            if c:IsA("ScreenGui") and c ~= keep and not preGuis[c] then
                if not wanted or wanted[c.Name] then
                    pcall(function() c:Destroy() end)
                end
            end
        end
    end
    local dead = {}
    for k in pairs(_G) do
        if not preKeys[k] then dead[#dead + 1] = k end
    end
    for _, k in ipairs(dead) do
        pcall(function() _G[k] = nil end)
    end
end

-- ============================================================================
--  payload decompression (raw DEFLATE + base64, RFC 1951)
--  the hubs are stored compressed: 1.2 MB of source becomes ~300 KB, which
--  keeps the script under the size limits some executors impose on the
--  script box. decompression only runs for the hub you actually launch.
-- ============================================================================
local decompress = (function()
    local b32 = rawget(_G, "bit32")
    local band, bor, shl, shr
    if b32 then
        band, bor, shl, shr = b32.band, b32.bor, b32.lshift, b32.rshift
    else
        band = function(a, b) return a & b end
        bor  = function(a, b) return a | b end
        shl  = function(a, n) return a << n end
        shr  = function(a, n) return a >> n end
    end

    local LEN_BASE   = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
    local LEN_EXTRA  = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
    local DIST_BASE  = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
    local DIST_EXTRA = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
    local CL_ORDER   = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}

    local B64_CHARS  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local B64_LOOKUP = {}
    for i = 1, 64 do B64_LOOKUP[string.sub(B64_CHARS, i, i)] = i - 1 end

    local function base64(s)
        -- the payload is wrapped across lines for readability; drop everything
        -- that is not part of the alphabet
        s = string.gsub(s, "[^%w%+/=]", "")
        local parts = {}
        local i, n = 1, #s
        while i <= n do
            local c1 = B64_LOOKUP[string.sub(s, i, i)] or 0
            local c2 = B64_LOOKUP[string.sub(s, i + 1, i + 1)] or 0
            local ch3 = string.sub(s, i + 2, i + 2)
            local ch4 = string.sub(s, i + 3, i + 3)
            local c3 = (ch3 ~= "" and ch3 ~= "=") and B64_LOOKUP[ch3] or nil
            local c4 = (ch4 ~= "" and ch4 ~= "=") and B64_LOOKUP[ch4] or nil

            parts[#parts + 1] = string.char(band(bor(shl(c1, 2), shr(c2, 4)), 255))
            if c3 then
                parts[#parts + 1] = string.char(band(bor(shl(band(c2, 15), 4), shr(c3, 2)), 255))
                if c4 then
                    parts[#parts + 1] = string.char(band(bor(shl(band(c3, 3), 6), c4), 255))
                end
            end
            i = i + 4
        end
        return table.concat(parts)
    end

    local function inflate(src)
        local pos, bitbuf, bitcnt = 1, 0, 0

        local function bits(n)
            while bitcnt < n do
                local byte = string.byte(src, pos)
                if not byte then error("inflate: truncated stream") end
                bitbuf = bor(bitbuf, shl(byte, bitcnt))
                pos = pos + 1
                bitcnt = bitcnt + 8
            end
            local value = band(bitbuf, shl(1, n) - 1)
            bitbuf = shr(bitbuf, n)
            bitcnt = bitcnt - n
            return value
        end

        local function build(lengths, n)
            local count = {}
            for i = 1, 16 do count[i] = 0 end
            for i = 1, n do
                local l = lengths[i]
                if l and l > 0 then count[l] = count[l] + 1 end
            end
            local offs = { 0 }
            for l = 1, 15 do offs[l + 1] = offs[l] + count[l] end
            local symbol = {}
            for i = 1, n do
                local l = lengths[i]
                if l and l > 0 then
                    symbol[offs[l] + 1] = i - 1
                    offs[l] = offs[l] + 1
                end
            end
            return { count = count, symbol = symbol }
        end

        local function decode(h)
            local code, first, index = 0, 0, 0
            for len = 1, 15 do
                code = bor(code, bits(1))
                local c = h.count[len]
                if code - c < first then
                    return h.symbol[index + (code - first) + 1]
                end
                index = index + c
                first = shl(first + c, 1)
                code = shl(code, 1)
            end
            error("inflate: bad huffman code")
        end

        local out, recent, recentLen = {}, {}, 0

        local function push(chunk)
            if chunk == "" then return end
            out[#out + 1] = chunk
            recent[#recent + 1] = chunk
            recentLen = recentLen + #chunk
            if recentLen > 131072 then
                local joined = table.concat(recent)
                joined = string.sub(joined, -32768)
                recent = { joined }
                recentLen = #joined
            end
        end

        -- last `d` bytes of output, for a back-reference
        local function tail(d)
            local parts, need = {}, d
            for i = #recent, 1, -1 do
                local c = recent[i]
                local len = #c
                if len >= need then
                    parts[#parts + 1] = string.sub(c, len - need + 1)
                    need = 0
                    break
                end
                parts[#parts + 1] = c
                need = need - len
            end
            if need > 0 then error("inflate: distance beyond output") end
            local buf = {}
            for i = #parts, 1, -1 do buf[#buf + 1] = parts[i] end
            return table.concat(buf)
        end

        repeat
            local final = bits(1)
            local btype = bits(2)

            if btype == 0 then
                bitbuf, bitcnt = 0, 0
                local len = (string.byte(src, pos) or 0) + (string.byte(src, pos + 1) or 0) * 256
                pos = pos + 4
                push(string.sub(src, pos, pos + len - 1))
                pos = pos + len
            elseif btype == 1 or btype == 2 then
                local litTree, distTree

                if btype == 1 then
                    local lengths = {}
                    for i = 1, 144 do lengths[i] = 8 end
                    for i = 145, 256 do lengths[i] = 9 end
                    for i = 257, 280 do lengths[i] = 7 end
                    for i = 281, 288 do lengths[i] = 8 end
                    litTree = build(lengths, 288)
                    local dl = {}
                    for i = 1, 30 do dl[i] = 5 end
                    distTree = build(dl, 30)
                else
                    local hlit = bits(5) + 257
                    local hdist = bits(5) + 1
                    local hclen = bits(4) + 4

                    local cl = {}
                    for i = 1, 19 do cl[i] = 0 end
                    for i = 1, hclen do cl[CL_ORDER[i] + 1] = bits(3) end
                    local clTree = build(cl, 19)

                    local lengths, idx = {}, 1
                    while idx <= hlit + hdist do
                        local sym = decode(clTree)
                        if sym < 16 then
                            lengths[idx] = sym
                            idx = idx + 1
                        elseif sym == 16 then
                            local prev = lengths[idx - 1]
                            if prev == nil then error("inflate: repeat with no base") end
                            for _ = 1, 3 + bits(2) do lengths[idx] = prev; idx = idx + 1 end
                        elseif sym == 17 then
                            for _ = 1, 3 + bits(3) do lengths[idx] = 0; idx = idx + 1 end
                        else
                            for _ = 1, 11 + bits(7) do lengths[idx] = 0; idx = idx + 1 end
                        end
                    end

                    litTree = build(lengths, hlit)
                    local dl = {}
                    for i = 1, hdist do dl[i] = lengths[hlit + i] end
                    distTree = build(dl, hdist)
                end

                local literal = {}
                local function flush()
                    if #literal > 0 then
                        push(table.concat(literal))
                        literal = {}
                    end
                end

                while true do
                    local sym = decode(litTree)
                    if sym < 256 then
                        literal[#literal + 1] = string.char(sym)
                    elseif sym == 256 then
                        flush()
                        break
                    else
                        flush()
                        local li = sym - 256
                        if li < 1 or li > 29 then error("inflate: bad length symbol") end
                        local len = LEN_BASE[li]
                        local le = LEN_EXTRA[li]
                        if le > 0 then len = len + bits(le) end

                        local ds = decode(distTree) + 1
                        if ds < 1 or ds > 30 then error("inflate: bad distance symbol") end
                        local dist = DIST_BASE[ds]
                        local de = DIST_EXTRA[ds]
                        if de > 0 then dist = dist + bits(de) end
                        if dist > recentLen then error("inflate: distance beyond output") end

                        local piece = tail(dist)
                        local copied
                        if len <= dist then
                            copied = string.sub(piece, 1, len)
                        else
                            copied = string.sub(string.rep(piece, math.ceil(len / dist)), 1, len)
                        end
                        push(copied)
                    end
                end
            else
                error("inflate: bad block type")
            end
        until final == 1

        return table.concat(out)
    end

    return function(payload)
        return inflate(base64(payload))
    end
end)()

-- ============================================================================
--  UI
-- ============================================================================
local function main()
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "PayedScriptsHub"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 2147483000
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Enabled = true
feedGui(Gui)
_G.__PSH_GUI = Gui

local ROW_H    = 38
local ROW_GAP  = 5
local W        = 322
local PAD      = 12
local HEAD_H   = 58
local SEARCH_Y = 66
local SEARCH_H = 30
local LIST_Y   = 104
local LIST_H   = (#HUBS * ROW_H) + ((#HUBS - 1) * ROW_GAP)
local FOOT_H   = 56
local H        = LIST_Y + LIST_H + 10 + FOOT_H

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(W, H)
root.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
root.BackgroundColor3 = C.bg
root.BorderSizePixel = 0
root.Active = true
root.ClipsDescendants = true
root.Parent = Gui
corner(root, 14)
stroke(root, C.stroke, 1)

local scale = Instance.new("UIScale")
scale.Parent = root

-- header ----------------------------------------------------------------------
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, HEAD_H)
header.BackgroundColor3 = C.panel
header.BorderSizePixel = 0
header.Parent = root
corner(header, 14)

local headerFill = Instance.new("Frame")
headerFill.Size = UDim2.new(1, 0, 0, 14)
headerFill.Position = UDim2.new(0, 0, 1, -14)
headerFill.BackgroundColor3 = C.panel
headerFill.BorderSizePixel = 0
headerFill.Parent = header

local hGrad = Instance.new("UIGradient")
hGrad.Rotation = 90
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(21, 21, 27)),
})
hGrad.Parent = header

local titleLbl = label(header, "PAYED SCRIPTS", UDim2.new(1, -110, 0, 20),
    UDim2.fromOffset(16, 10), FONT_B, C.text)
titleLbl.TextSize = 15

local tGrad = Instance.new("UIGradient")
tGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(150, 210, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 150, 255)),
})
tGrad.Parent = titleLbl

local subLbl = label(header, #HUBS .. " hubs  ·  one at a time", UDim2.new(1, -110, 0, 14),
    UDim2.fromOffset(16, 30), FONT, C.faint)
subLbl.TextSize = 9

-- icons are drawn from frames, not font glyphs: a lot of the nicer unicode
-- symbols (magnifier, keyboard) are missing from Gotham and render as tofu
local function makeBar(w, h, colour, rot)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = UDim2.fromOffset(w, h)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.Rotation = rot or 0
    f.BackgroundColor3 = colour
    f.BorderSizePixel = 0
    f.Parent = nil
    corner(f, math.max(1, h / 2))
    return f
end

local function iconBtn(xOffset, parts)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(26, 26)
    b.Position = UDim2.new(1, xOffset, 0, 15)
    b.BackgroundColor3 = Color3.fromRGB(33, 33, 42)
    b.Text = ""
    b.AutoButtonColor = false
    b.Parent = header
    corner(b, 8)
    local s = stroke(b, C.stroke, 1)
    for _, p in ipairs(parts) do p.Parent = b end
    local base = parts[1].BackgroundColor3
    track(b.MouseEnter:Connect(function()
        TS:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(48, 48, 62) }):Play()
        TS:Create(s, TweenInfo.new(0.12), { Color = Color3.fromRGB(84, 84, 106) }):Play()
        for _, p in ipairs(parts) do
            TS:Create(p, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(235, 235, 245) }):Play()
        end
    end))
    track(b.MouseLeave:Connect(function()
        TS:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(33, 33, 42) }):Play()
        TS:Create(s, TweenInfo.new(0.15), { Color = C.stroke }):Play()
        for _, p in ipairs(parts) do
            TS:Create(p, TweenInfo.new(0.15), { BackgroundColor3 = base }):Play()
        end
    end))
    return b
end

local minBtn = iconBtn(-72, { makeBar(11, 2, C.dim) })
local closeBtn = iconBtn(-40, {
    makeBar(11, 2, Color3.fromRGB(196, 132, 132), 45),
    makeBar(11, 2, Color3.fromRGB(196, 132, 132), -45),
})

-- search ----------------------------------------------------------------------
local searchBox = Instance.new("Frame")
searchBox.Size = UDim2.new(1, -PAD * 2, 0, SEARCH_H)
searchBox.Position = UDim2.fromOffset(PAD, SEARCH_Y)
searchBox.BackgroundColor3 = C.panel
searchBox.BorderSizePixel = 0
searchBox.Parent = root
corner(searchBox, 9)
local searchStroke = stroke(searchBox, C.stroke, 1)

local searchRing = Instance.new("Frame")
searchRing.Size = UDim2.fromOffset(9, 9)
searchRing.Position = UDim2.fromOffset(11, 10)
searchRing.BackgroundTransparency = 1
searchRing.BorderSizePixel = 0
searchRing.Parent = searchBox
corner(searchRing, 5)
local ringStroke = stroke(searchRing, C.faint, 1.3)
ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local searchHandle = Instance.new("Frame")
searchHandle.AnchorPoint = Vector2.new(0.5, 0.5)
searchHandle.Size = UDim2.fromOffset(2, 5)
searchHandle.Position = UDim2.fromOffset(19, 19)
searchHandle.Rotation = 45
searchHandle.BackgroundColor3 = C.faint
searchHandle.BorderSizePixel = 0
searchHandle.Parent = searchBox
corner(searchHandle, 1)

local search = Instance.new("TextBox")
search.Size = UDim2.new(1, -46, 1, 0)
search.Position = UDim2.fromOffset(28, 0)
search.BackgroundTransparency = 1
search.PlaceholderText = "search hubs or features…"
search.PlaceholderColor3 = C.faint
search.Text = ""
search.Font = FONT
search.TextSize = 11
search.TextColor3 = C.text
search.TextXAlignment = Enum.TextXAlignment.Left
search.ClearTextOnFocus = false
search.Parent = searchBox

track(search.Focused:Connect(function()
    TS:Create(searchStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(90, 120, 170) }):Play()
end))
track(search.FocusLost:Connect(function()
    TS:Create(searchStroke, TweenInfo.new(0.15), { Color = C.stroke }):Play()
end))

-- list ------------------------------------------------------------------------
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -PAD * 2, 0, LIST_H)
list.Position = UDim2.fromOffset(PAD, LIST_Y)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 78)
list.ScrollBarImageTransparency = 0.3
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.Parent = root

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, ROW_GAP)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

-- footer ----------------------------------------------------------------------
local footerY = LIST_Y + LIST_H + 10

local keyChip = Instance.new("TextButton")
keyChip.Size = UDim2.fromOffset(112, 24)
keyChip.Position = UDim2.fromOffset(PAD, footerY)
keyChip.BackgroundColor3 = C.row
keyChip.Text = "KEY  " .. Settings.toggleKey
keyChip.Font = FONT_M
keyChip.TextSize = 10
keyChip.TextColor3 = C.dim
keyChip.AutoButtonColor = false
keyChip.Parent = root
corner(keyChip, 7)
local chipStroke = stroke(keyChip, C.stroke, 1)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.fromOffset(86, 24)
stopBtn.Position = UDim2.new(1, -PAD - 86, 0, footerY)
stopBtn.BackgroundColor3 = C.row
stopBtn.Text = "STOP"
stopBtn.Font = FONT_B
stopBtn.TextSize = 10
stopBtn.TextColor3 = C.bad
stopBtn.AutoButtonColor = false
stopBtn.Enabled = false
stopBtn.Parent = root
corner(stopBtn, 7)
local stopStroke = stroke(stopBtn, C.stroke, 1)

local statusLbl = label(root, "idle", UDim2.new(1, -PAD * 2, 0, 12),
    UDim2.fromOffset(PAD, footerY + 30), FONT, C.faint)
statusLbl.TextSize = 9

-- floating pill (minimised state) ---------------------------------------------
local pill = Instance.new("TextButton")
pill.Size = UDim2.fromOffset(46, 36)
pill.Position = UDim2.new(0.5, -23, 0, 12)
pill.BackgroundColor3 = C.panel
pill.Text = "PS"
pill.Font = FONT_B
pill.TextSize = 13
pill.TextColor3 = Color3.fromRGB(150, 210, 255)
pill.AutoButtonColor = false
pill.Visible = false
pill.Parent = Gui
corner(pill, 10)
local pillStroke = stroke(pill, C.stroke, 1)
track(pill.MouseEnter:Connect(function()
    TS:Create(pill, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(33, 33, 43) }):Play()
    TS:Create(pillStroke, TweenInfo.new(0.12), { Color = Color3.fromRGB(78, 78, 100) }):Play()
end))
track(pill.MouseLeave:Connect(function()
    TS:Create(pill, TweenInfo.new(0.15), { BackgroundColor3 = C.panel }):Play()
    TS:Create(pillStroke, TweenInfo.new(0.15), { Color = C.stroke }):Play()
end))

-- ============================================================================
--  behaviour
-- ============================================================================
local Active = nil
local rows = {}
local listening = false
local baseScale = 1
local launchSeq = 0

local function setStatus(msg, colour)
    statusLbl.Text = msg
    statusLbl.TextColor3 = colour or C.faint
end

local function refreshRows()
    for _, r in ipairs(rows) do
        local on = Active ~= nil and Active.id == r.hub.id
        if on then
            r.btn.Text = "RUNNING"
            r.btn.TextColor3 = C.bg
            r.btn.BackgroundColor3 = r.hub.accent
            r.btn.BackgroundTransparency = 0
            r.btn.Size = UDim2.fromOffset(68, 22)
            r.btn.Position = UDim2.new(1, -78, 0.5, -11)
            r.strip.BackgroundTransparency = 0
            r.name.TextColor3 = C.text
        else
            r.btn.Text = "LOAD"
            r.btn.TextColor3 = r.hub.accent
            r.btn.BackgroundColor3 = r.hub.accent
            r.btn.BackgroundTransparency = 0.86
            r.btn.Size = UDim2.fromOffset(56, 22)
            r.btn.Position = UDim2.new(1, -66, 0.5, -11)
            r.strip.BackgroundTransparency = 0.35
            r.name.TextColor3 = Color3.fromRGB(214, 214, 228)
        end
    end
    stopBtn.Enabled = Active ~= nil
    stopBtn.TextColor3 = Active and C.bad or C.faint
end

local function stopHub(silent)
    if not Active then
        if not silent then setStatus("nothing is running", C.faint) end
        return
    end
    local was = Active.title
    cleanHub(Active.hub, Active.preGuis, Active.preKeys, Gui)
    Active = nil
    refreshRows()
    if not silent then
        setStatus("stopped " .. was .. " · rejoin for a clean slate", C.dim)
    end
end

local function hidePanel()
    pill.Visible = true
    task.spawn(function()
        TS:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Scale = baseScale * 0.9,
        }):Play()
        task.wait(0.14)
        root.Visible = false
        scale.Scale = baseScale
    end)
end

local function showPanel()
    Gui.Enabled = true
    root.Visible = true
    pill.Visible = false
    scale.Scale = baseScale * 0.9
    TS:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = baseScale,
    }):Play()
end

local function findCompiler()
    local candidates = {
        loadstring,
        rawget(_G, "loadstring"),
        (getgenv and getgenv() and getgenv().loadstring) or nil,
        load,
        rawget(_G, "load"),
        (getgenv and getgenv() and getgenv().load) or nil,
    }
    for _, fn in ipairs(candidates) do
        if type(fn) == "function" then return fn end
    end
    return nil
end

local function launch(hub)
    if Active then stopHub(true) end

    local compile = findCompiler()
    if type(compile) ~= "function" then
        setStatus("no loadstring() in this executor · cannot run hubs", C.bad)
        warn("[PayedScriptsHub] loadstring is unavailable, hubs cannot be executed")
        return
    end

    local preGuis, preKeys = snapshot()
    launchSeq = launchSeq + 1
    local token = launchSeq

    Active = { id = hub.id, title = hub.title, hub = hub, token = token,
               preGuis = preGuis, preKeys = preKeys }
    refreshRows()
    setStatus("unpacking " .. hub.title .. " …", C.dim)

    -- decompression is pure Lua and blocks the frame, so let the status paint
    -- first and run it in its own thread
    task.spawn(function()
        task.wait()

        if not (Active and Active.token == token) then return end

        local okUnpack, src = pcall(decompress, hub.src)
        if not okUnpack then
            if Active and Active.token == token then
                Active = nil
                refreshRows()
            end
            setStatus("unpack failed · check console", C.bad)
            warn("[PayedScriptsHub] unpack: " .. tostring(src))
            return
        end

        if not (Active and Active.token == token) then return end

        local fn, err = compile(src, "=" .. hub.id)
        if not fn then
            Active = nil
            refreshRows()
            setStatus("compile error · check console", C.bad)
            warn("[PayedScriptsHub] " .. tostring(err))
            return
        end

        setStatus("starting " .. hub.title .. " …", C.dim)

        if Settings.autoHide then
            -- only step out of the way once the hub actually shows something,
            -- otherwise the user would be staring at an empty screen
            task.delay(1.25, function()
                if not (Active and Active.token == token) then return end
                if newGuiCount(preGuis, Gui) > 0 then
                    hidePanel()
                else
                    setStatus(hub.title .. " is running · no window detected", C.dim)
                end
            end)
        end

        local ok, runErr = pcall(fn)
        if not ok then
            setStatus(hub.title .. " error · check console", C.bad)
            warn("[PayedScriptsHub] " .. tostring(runErr))
        elseif Active and Active.token == token then
            setStatus(hub.title .. " is live", C.ok)
        end
    end)
end

local function applyFilter()
    local q = search.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    for _, r in ipairs(rows) do
        local hit = q == ""
            or r.hub.title:lower():find(q, 1, true) ~= nil
            or (r.hub.tags or ""):lower():find(q, 1, true) ~= nil
        r.row.Visible = hit
    end
end

-- rows ------------------------------------------------------------------------
for i, hub in ipairs(HUBS) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, ROW_H)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.LayoutOrder = i
    row.Parent = list
    corner(row, 9)
    local rowStroke = stroke(row, C.stroke, 1)

    local strip = Instance.new("Frame")
    strip.Size = UDim2.new(0, 3, 0.55, 0)
    strip.Position = UDim2.new(0, 0, 0.225, 0)
    strip.BackgroundColor3 = hub.accent
    strip.BackgroundTransparency = 0.35
    strip.BorderSizePixel = 0
    strip.Parent = row
    corner(strip, 3)

    local name = label(row, hub.title, UDim2.new(1, -96, 0, 14),
        UDim2.fromOffset(14, 5), FONT_M, Color3.fromRGB(214, 214, 228))
    name.TextSize = 11

    local tags = label(row, hub.tags or "", UDim2.new(1, -96, 0, 11),
        UDim2.fromOffset(14, 20), FONT, C.faint)
    tags.TextSize = 8

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(56, 22)
    btn.Position = UDim2.new(1, -66, 0.5, -11)
    btn.BackgroundColor3 = hub.accent
    btn.BackgroundTransparency = 0.86
    btn.Text = "LOAD"
    btn.Font = FONT_B
    btn.TextSize = 9
    btn.TextColor3 = hub.accent
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)

    track(row.MouseEnter:Connect(function()
        TS:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = C.rowHi }):Play()
        TS:Create(rowStroke, TweenInfo.new(0.12), { Color = Color3.fromRGB(70, 70, 88) }):Play()
    end))
    track(row.MouseLeave:Connect(function()
        TS:Create(row, TweenInfo.new(0.16), { BackgroundColor3 = C.row }):Play()
        TS:Create(rowStroke, TweenInfo.new(0.16), { Color = C.stroke }):Play()
    end))
    track(btn.MouseEnter:Connect(function()
        if Active and Active.id == hub.id then return end
        TS:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.7 }):Play()
    end))
    track(btn.MouseLeave:Connect(function()
        if Active and Active.id == hub.id then return end
        TS:Create(btn, TweenInfo.new(0.16), { BackgroundTransparency = 0.86 }):Play()
    end))
    track(btn.MouseButton1Click:Connect(function() launch(hub) end))

    rows[#rows + 1] = { hub = hub, row = row, btn = btn, name = name, strip = strip }
end

track(search:GetPropertyChangedSignal("Text"):Connect(applyFilter))

-- drag ------------------------------------------------------------------------
do
    local dragging, dragStart, startPos = false, nil, nil
    track(header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, root.Position
        end
    end))
    track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            local x = startPos.X.Offset + d.X
            local y = startPos.Y.Offset + d.Y

            -- keep at least a strip of the panel on screen so it can't be lost
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize
            if vp then
                local w, h = W * scale.Scale, H * scale.Scale
                local sx, sy = startPos.X.Scale, startPos.Y.Scale
                x = math.clamp(x, 90 - w - sx * vp.X, vp.X - 90 - sx * vp.X)
                y = math.clamp(y, 34 - sy * vp.Y, vp.Y - 44 - sy * vp.Y)
            end

            root.Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y)
        end
    end))
    track(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

-- buttons ---------------------------------------------------------------------
track(minBtn.MouseButton1Click:Connect(hidePanel))
track(pill.MouseButton1Click:Connect(showPanel))
track(closeBtn.MouseButton1Click:Connect(function() Gui.Enabled = false end))
track(stopBtn.MouseButton1Click:Connect(function() stopHub(false) end))

-- keybind chip ----------------------------------------------------------------
track(keyChip.MouseButton1Click:Connect(function()
    listening = true
    keyChip.Text = "press a key"
    keyChip.TextColor3 = Color3.fromRGB(150, 210, 255)
    TS:Create(chipStroke, TweenInfo.new(0.12), { Color = Color3.fromRGB(90, 120, 170) }):Play()
end))

-- global keys -----------------------------------------------------------------
track(UIS.InputBegan:Connect(function(input, processed)
    if listening then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            listening = false
            Settings.toggleKey = input.KeyCode.Name
            keyChip.Text = "KEY  " .. Settings.toggleKey
            keyChip.TextColor3 = C.dim
            TS:Create(chipStroke, TweenInfo.new(0.2), { Color = C.stroke }):Play()
            saveSettings()
        end
        return
    end
    if processed then return end
    if Enum.KeyCode[Settings.toggleKey] and input.KeyCode == Enum.KeyCode[Settings.toggleKey] then
        if Gui.Enabled then
            Gui.Enabled = false
        else
            Gui.Enabled = true
            showPanel()
        end
    end
end))

-- responsive ------------------------------------------------------------------
local function fit()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize
    if not vp then return end
    local s = 1
    if vp.Y < H + 40 then s = math.clamp((vp.Y - 40) / H, 0.7, 1) end
    if vp.X < W + 40 then s = math.min(s, math.clamp((vp.X - 40) / W, 0.7, 1)) end
    baseScale = s
    scale.Scale = s
end
fit()
local cam0 = workspace.CurrentCamera
if cam0 then
    track(cam0:GetPropertyChangedSignal("ViewportSize"):Connect(fit))
end

-- ============================================================================
--  startup
-- ============================================================================
refreshRows()

if findCompiler() then
    setStatus("ready · pick a hub", C.faint)
else
    setStatus("no loadstring() · hubs cannot run here", C.bad)
    warn("[PayedScriptsHub] loadstring is unavailable, hubs cannot be executed")
end

scale.Scale = baseScale * 0.92
TS:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Scale = baseScale,
}):Play()

_G.__PSH_CLEANUP = function()
    for _, c in ipairs(CONNS) do
        pcall(function() c:Disconnect() end)
    end
    CONNS = {}
    pcall(function() Gui:Destroy() end)
    _G.__PSH_GUI = nil
end
end

-- everything is wrapped so a failure shows up on screen instead of dying
-- silently, which is what an executor normally gives you
local ok, fatal = xpcall(main, function(e)
    return tostring(e) .. "\n" .. debug.traceback("", 2)
end)

if not ok then
    -- don't leave a half-built window behind the error panel
    pcall(function()
        if _G.__PSH_GUI then _G.__PSH_GUI:Destroy() end
    end)
    _G.__PSH_GUI = nil
    showFatal(fatal)
end
