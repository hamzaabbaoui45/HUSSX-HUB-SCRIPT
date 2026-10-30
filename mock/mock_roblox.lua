-- Mock Roblox environment, just enough to run the launcher UI for real.
-- The goal is to catch nil-index / wrong-property / logic errors, not to
-- emulate rendering.

local M = {}

-- ---------------------------------------------------------------- signal
local function newSignal()
    local s = { fns = {} }
    function s:Connect(fn)
        local c = { fn = fn, on = true }
        table.insert(self.fns, c)
        return {
            Disconnect = function() c.on = false end,
            disconnect = function() c.on = false end,
            Connected = true,
        }
    end
    s.connect = s.Connect
    function s:Fire(...)
        for _, c in ipairs(self.fns) do
            if c.on then c.fn(...) end
        end
    end
    function s:Wait() end
    return s
end
M.newSignal = newSignal

-- ---------------------------------------------------------------- datatypes
local function c3(r, g, b) return { R = r or 0, G = g or 0, B = b or 0 } end
M.Color3 = setmetatable({
    fromRGB = function(r, g, b) return c3(r, g, b) end,
    new     = function(r, g, b) return c3(r, g, b) end,
}, { __call = function(_, r, g, b) return c3(r, g, b) end })

local function udim(s, o) return { Scale = s or 0, Offset = o or 0 } end
M.UDim = setmetatable({ new = udim }, { __call = function(_, s, o) return udim(s, o) end })

local function ud2(xs, xo, ys, yo)
    return {
        X = { Scale = xs or 0, Offset = xo or 0 },
        Y = { Scale = ys or 0, Offset = yo or 0 },
    }
end
M.UDim2 = setmetatable({
    fromOffset = function(x, y) return ud2(0, x, 0, y) end,
    fromScale  = function(x, y) return ud2(x, 0, y, 0) end,
    new        = function(xs, xo, ys, yo) return ud2(xs, xo, ys, yo) end,
}, { __call = function(_, xs, xo, ys, yo) return ud2(xs, xo, ys, yo) end })

local function cseq(kps) return { keypoints = kps } end
M.ColorSequence = setmetatable({}, { __call = function(_, k) return cseq(k) end })
M.ColorSequence.new = cseq
M.ColorSequenceKeypoint = setmetatable({}, {
    __call = function(_, t, c) return { Time = t, Value = c } end,
})
M.ColorSequenceKeypoint.new = function(t, c) return { Time = t, Value = c } end
M.NumberSequence = setmetatable({}, { __call = function() return {} end })
M.NumberSequence.new = function() return {} end

local function vec2(x, y) return { X = x or 0, Y = y or 0 } end
M.Vector2 = setmetatable({ new = vec2 }, { __call = function(_, x, y) return vec2(x, y) end })

local V3 = {}
V3.__index = V3
V3.__sub = function(a, b)
    return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = (a.Z or 0) - (b.Z or 0) }, V3)
end
V3.__add = function(a, b)
    return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = (a.Z or 0) + (b.Z or 0) }, V3)
end
M.Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }

local function tinfo(t, e, d) return { Time = t, EasingStyle = e, EasingDirection = d } end
M.TweenInfo = setmetatable({}, { __call = function(_, t, e, d) return tinfo(t, e, d) end })
M.TweenInfo.new = tinfo

-- ---------------------------------------------------------------- enum
local function enumGroup(names)
    local g = {}
    for _, n in ipairs(names) do g[n] = { Name = n, Value = n } end
    return g
end
M.Enum = {
    Font          = enumGroup({ 'Gotham', 'GothamBold', 'GothamMedium', 'GothamBlack', 'SourceSans', 'SourceSansBold', 'Code' }),
    TextXAlignment = enumGroup({ 'Left', 'Center', 'Right' }),
    TextYAlignment = enumGroup({ 'Top', 'Center', 'Bottom' }),
    TextTruncate  = enumGroup({ 'None', 'AtEnd' }),
    ApplyStrokeMode = enumGroup({ 'Border', 'Contextual' }),
    AutomaticSize = enumGroup({ 'None', 'X', 'Y', 'XY' }),
    ScrollingDirection = enumGroup({ 'X', 'Y', 'XY' }),
    SortOrder     = enumGroup({ 'LayoutOrder', 'Name', 'Custom' }),
    ZIndexBehavior = enumGroup({ 'Sibling', 'Global' }),
    EasingStyle   = enumGroup({ 'Linear', 'Quad', 'Back' }),
    EasingDirection = enumGroup({ 'In', 'Out', 'InOut' }),
    UserInputType = enumGroup({ 'MouseButton1', 'MouseMovement', 'Touch', 'Keyboard', 'Focus' }),
    KeyCode       = enumGroup({
        'RightShift', 'LeftShift', 'Unknown', 'X', 'Z', 'C', 'E', 'F', 'Q', 'T',
        'Escape', 'Space', 'RightControl', 'Insert', 'Home',
    }),
    CoreGuiType   = enumGroup({ 'Health', 'PlayerList', 'Backpack', 'All' }),
    HumanoidStateType = enumGroup({ 'Running', 'Physics', 'Ragdoll', 'GettingUp', 'FallingDown' }),
}

-- ---------------------------------------------------------------- instance
local INSTANCES = 0
local SIGNAL_NAMES = {
    MouseEnter = true, MouseLeave = true, MouseButton1Click = true,
    MouseButton1Down = true, MouseButton1Up = true, Activated = true,
    Focused = true, FocusLost = true, InputBegan = true, InputEnded = true,
    InputChanged = true, Changed = true, ChildAdded = true, ChildRemoved = true,
    AncestryChanged = true, DescendantAdded = true, Destroying = true,
}

local InstanceClass = {}
InstanceClass.__index = function(self, k)
    if k == 'Parent' then return rawget(self, '_parent') end
    if SIGNAL_NAMES[k] then
        local sigs = rawget(self, '_sigs')
        local s = sigs[k]
        if not s then s = newSignal(); sigs[k] = s end
        return s
    end
    local m = rawget(self, '_m')
    if m and m[k] then return m[k] end
    local rv = rawget(self, k)
    if rv ~= nil then return rv end
    return rawget(self, '_props')[k]
end
InstanceClass.__newindex = function(self, k, v)
    if k == 'Parent' then
        local old = rawget(self, '_parent')
        if old then
            local kids = rawget(old, '_kids')
            for i, c in ipairs(kids) do
                if c == self then table.remove(kids, i) break end
            end
        end
        rawset(self, '_parent', v)
        if v then
            table.insert(rawget(v, '_kids'), self)
            local sig = rawget(v, '_sigs').ChildAdded
            if sig then sig:Fire(self) end
        end
        return
    end
    rawget(self, '_props')[k] = v
    local s = rawget(self, '_psigs')[k]
    if s then s:Fire(v) end
end

local function newInstance(class)
    INSTANCES = INSTANCES + 1
    local inst = setmetatable({
        ClassName = class,
        _props = { Name = class },
        _kids = {},
        _sigs = {},
        _psigs = {},
        _parent = nil,
        _m = {},
    }, InstanceClass)

    function inst._m.GetChildren(self)
        local t = {}
        for i, c in ipairs(self._kids) do t[i] = c end
        return t
    end
    function inst._m.GetDescendants(self)
        local t = {}
        local function walk(n)
            for _, c in ipairs(n._kids) do t[#t + 1] = c; walk(c) end
        end
        walk(self)
        return t
    end
    function inst._m.IsA(self, c) return self.ClassName == c end
    function inst._m.FindFirstChild(self, name) 
        for _, c in ipairs(self._kids) do if c._props.Name == name then return c end end
    end
    function inst._m.FindFirstChildOfClass(self, c)
        for _, ch in ipairs(self._kids) do if ch.ClassName == c then return ch end end
    end
    function inst._m.FindFirstChildWhichIsA(self, c)
        for _, ch in ipairs(self._kids) do if ch.ClassName == c then return ch end end
    end
    function inst._m.WaitForChild(self, name) return self._m.FindFirstChild(self, name) end
    function inst._m.GetPropertyChangedSignal(self, prop)
        local s = self._psigs[prop]
        if not s then s = newSignal(); self._psigs[prop] = s end
        return s
    end
    function inst._m.Destroy(self)
        self._destroyed = true
        if self.Parent then self.Parent = nil end
    end
    function inst._m.ClearAllChildren(self)
        for _, c in ipairs(self._kids) do c._parent = nil end
        self._kids = {}
    end
    function inst._m.SetAttribute() end
    function inst._m.GetAttribute() return nil end
    function inst._m.TweenSize() end
    return inst
end
M.Instance = { new = newInstance }

-- ---------------------------------------------------------------- services
local game = newInstance('DataModel')

local Players = newInstance('Players')
local UIS = newInstance('UserInputService')
local TS = newInstance('TweenService')
local CoreGui = newInstance('CoreGui')
local HttpS = newInstance('HttpService')
local StarterGui = newInstance('StarterGui')
local RunService = newInstance('RunService')

function HttpS.JSONEncode(_, t) return tostring(t) end
function HttpS.JSONDecode(_, s) return nil end

function TS:Create(inst, info, props)
    return {
        Play = function()
            for k, v in pairs(props) do inst[k] = v end
        end,
    }
end

local playerGui = newInstance('PlayerGui')
playerGui._isPlayerGui = true
playerGui.Parent = Players

local LocalPlayer = newInstance('Player')
LocalPlayer.Parent = Players
playerGui.Parent = LocalPlayer

Players.LocalPlayer = LocalPlayer

local camera = newInstance('Camera')
camera.ViewportSize = { X = 1920, Y = 1080 }
local workspace = newInstance('Workspace')
workspace.CurrentCamera = camera

local services = {
    Players = Players, UserInputService = UIS, TweenService = TS,
    CoreGui = CoreGui, HttpService = HttpS, StarterGui = StarterGui,
    RunService = RunService, Workspace = workspace,
}

function game:GetService(name)
    return services[name] or newInstance(name)
end

M.game = game
M.workspace = workspace
M.UIS = UIS
M.Players = Players
M.playerGui = playerGui
M.CoreGui = CoreGui
M.Services = services

return M
