--[[ CA Hub v1.0 : Auto Farm + Teleport Manual (pilih nest sendiri), UI tab modern ]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer

local CFG = {
    running = false, steal = true, claimSell = true, sell = true, upgrade = true, rebirth = false,
    zone = "SEMUA", delay = 1.1, sellEvery = 3, upEvery = 5,
    stolen = 0, secured = 0, sold = 0, errors = 0, cycles = 0, ready = 0, rebInfo = "", sellInfo = "",
}
local TP = { nestKey = Enum.KeyCode.G, baseKey = Enum.KeyCode.H, matureOnly = true, zone = "SEMUA", sel = nil, listening = nil, spdLock = false, spdT = nil }
local ZONES = {"SEMUA","forest","lake","desert","jungle","volcano","cosmic","snow","beach","abyss","crystal","candy","alien","magma","bluelava"}
local TIERS = {5000, 22000, 185000, 3000000, 100000000, 3200000000, 100000000000, 3200000000000, 90000000000000, 700000000000000}
local MULTS = {1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6}

local function parseNum(s)
    if type(s) ~= "string" then return 0 end
    s = s:gsub(",", "")
    local num, suf = s:match("([%d%.]+)(%a*)")
    num = tonumber(num) or 0
    local m = {K=1e3, M=1e6, B=1e9, T=1e12, qd=1e15, Qd=1e15, Qn=1e18, Sx=1e21, Sp=1e24}
    return num * (m[suf] or 1)
end

local CONTAINER = nil
pcall(function() CONTAINER = RS.packages._Index["littensy_remo@1.5.3"].remo.container end)
local function remote(name)
    if not CONTAINER then return nil end
    local r = CONTAINER:FindFirstChild(name)
    if r then return r end
end
local function safeFire(name, ...)
    local r = remote(name)
    if not r then return false, "no-remote" end
    local args = {...}
    local ok, res
    if r:IsA("RemoteFunction") then
        ok, res = pcall(function() return r:InvokeServer(table.unpack(args)) end)
    else
        ok, res = pcall(function() r:FireServer(table.unpack(args)) end)
    end
    if not ok then CFG.errors += 1 end
    return ok, res
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function tp(pos)
    local h = hrp()
    if not h then return false end
    pcall(function()
        h.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0))
        h.Velocity = Vector3.zero
    end)
    return true
end
local function myBase()
    local bases = WS.Game.Map.Lobby.Bases
    if not bases then return nil end
    local fallback = nil
    for _, b in ipairs(bases:GetChildren()) do
        local bill = b:FindFirstChild("BaseBillb", true)
        local mine = false
        if bill then
            for _, x in ipairs(bill:GetDescendants()) do
                if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.Text == "YOUR BASE" then mine = true break end
            end
        end
        if mine then
            fallback = fallback or b
            if b:FindFirstChild("UpgradePrompt", true) then return b end
        end
    end
    return fallback or bases:FindFirstChild("4")
end
local function baseSpawnPos()
    local b = myBase()
    local sp = b and b:FindFirstChild("Spawn", true)
    if sp and sp:IsA("BasePart") then return sp.Position end
    return Vector3.new(-120, 32, -375)
end
local function hopStep()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    local ws = hum and hum.WalkSpeed or 16
    if ws < 16 then ws = 16 end
    local s = ws * 3
    if s < 40 then s = 40 end
    if s > 900 then s = 900 end
    return s
end
local function hopTo(pos)
    local bs = baseSpawnPos()
    for i = 1, 150 do
        if not CFG.running then return false end
        local h = hrp()
        if not h then return false end
        local cur = h.Position
        if i > 3 and (cur - bs).Magnitude < 150 and (pos - bs).Magnitude > 300 then return false end
        local d = (pos - cur).Magnitude
        if d <= 35 then return true end
        local step = (pos - cur).Unit * math.min(hopStep(), d)
        local ok = pcall(function()
            h.CFrame = CFrame.new(cur + step)
            h.Velocity = Vector3.zero
        end)
        if not ok then return false end
        task.wait(0.28)
    end
    local h2 = hrp()
    return h2 and (h2.Position - pos).Magnitude <= 35 or false
end
local function nestList(zone, matureOnly)
    local out = {}
    local pz = WS.Game.Map.PlayZones
    if pz then
        for _, z in ipairs(pz:GetChildren()) do
        if zone == "SEMUA" or string.lower(z.Name) == zone then
            local ns = z:FindFirstChild("Nests")
            if ns then
                for _, pr in ipairs(ns:GetDescendants()) do
                    if pr:IsA("ProximityPrompt") and pr.ActionText == "Steal Chicken"
                        and (not matureOnly or pr.Enabled) then
                        local a = pr.Parent
                        local part = a and (a:IsA("BasePart") and a or a:FindFirstChildWhichIsA("BasePart", true))
                        if part then
                            table.insert(out, {prompt = pr, pos = part.Position,
                                label = z.Name .. "/" .. pr.Parent.Name, mature = pr.Enabled})
                        end
                    end
                end
            end
        end
        end
    end
    local h = hrp()
    if h then table.sort(out, function(a, b) return (a.pos - h.Position).Magnitude < (b.pos - h.Position).Magnitude end) end
    return out
end
local function lsVal(name)
    local ls = LP:FindFirstChild("leaderstats")
    if not ls then return "?" end
    for _, v in ipairs(ls:GetChildren()) do
        if v.Name:find(name, 1, true) then return tostring(v.Value) end
    end
    return "?"
end

local MIRROR = {}
local UNKSCHEMA = {}
local function isEggItem(data)
    if type(data) ~= "table" then return nil end
    local egg, chick = false, false
    local function scan(t, depth)
        for k, v in pairs(t) do
            local kl = string.lower(tostring(k))
            if kl == "egg" or kl:find("eggid") or kl:find("eggtype") or kl:find("hatch") then egg = true end
            if kl:find("chicken") or kl == "speed" or kl:find("variant") or kl:find("insane") or kl:find("walkto") then chick = true end
            if type(v) == "table" and depth < 2 then scan(v, depth + 1) end
        end
    end
    pcall(scan, data, 0)
    if egg and not chick then return true end
    return nil
end
local function mirrorCounts()
    local e, u = 0, 0
    for _, v in pairs(MIRROR) do
        if v.egg == true then e += 1 elseif v.egg == nil then u += 1 end
    end
    return e, u
end
local HELD = {uid = nil}
local function heldUid()
    local c = LP.Character
    if not c then return nil end
    for _, x in ipairs(c:GetDescendants()) do
        local id = x:GetAttribute("id")
        if type(id) == "string" and id ~= "" then return id end
    end
    return nil
end
local function stillHolding()
    if HELD.uid and HELD.uid ~= "" then return true end
    return heldUid() ~= nil
end
local function myPlacedCount()
    local n = 0
    local pen = WS.Game:FindFirstChild("PenChickens")
    if not pen then return 0 end
    for _, m in ipairs(pen:GetChildren()) do
        if m:GetAttribute("owner") == LP.Name then n += 1 end
    end
    return n
end
local function curWS()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.WalkSpeed or 16
end
local function applySpd(t)
    if t then pcall(function() LP.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = t end) end
end
pcall(function()
    if readfile and isfile and isfile("CAHubKeys.txt") then
        local a, b = readfile("CAHubKeys.txt"):match("^(%S+)%s+(%S+)")
        if a then local ok, kc = pcall(function() return Enum.KeyCode[a] end) if ok then TP.nestKey = kc end end
        if b then local ok, kc = pcall(function() return Enum.KeyCode[b] end) if ok then TP.baseKey = kc end end
    end
end)
local function saveKeys()
    pcall(function()
        if writefile then writefile("CAHubKeys.txt", TP.nestKey.Name .. " " .. TP.baseKey.Name) end
    end)
end

--// MODERN UI : sidebar + pages
pcall(function()
    local cg = game:GetService("CoreGui")
    local o = cg:FindFirstChild("CAHub") if o then o:Destroy() end
end)
local parent
do
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    local probe = false
    if ok and cg then probe = pcall(function()
        local t = Instance.new("ScreenGui") t.Name = "__ph__"
        t.Parent = cg t:Destroy()
    end) end
    parent = (probe and cg) or LP:WaitForChild("PlayerGui")
end
local ACC = Color3.fromRGB(88, 140, 255)
local BG = Color3.fromRGB(15, 17, 23)
local PAN = Color3.fromRGB(22, 25, 33)
local gui = Instance.new("ScreenGui")
gui.Name = "CAHub" gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling gui.Parent = parent
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 560, 0, 400) main.Position = UDim2.new(0.5, -280, 0.5, -200)
main.BackgroundColor3 = BG main.BorderSizePixel = 0
main.Active = true main.Draggable = true main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local mstroke = Instance.new("UIStroke", main)
mstroke.Color = Color3.fromRGB(55, 62, 80) mstroke.Thickness = 1
local side = Instance.new("Frame", main)
side.Size = UDim2.new(0, 130, 1, 0) side.BackgroundColor3 = PAN side.BorderSizePixel = 0
Instance.new("UICorner", side).CornerRadius = UDim.new(0, 10)
local sideTitle = Instance.new("TextLabel", side)
sideTitle.Size = UDim2.new(1, 0, 0, 44) sideTitle.BackgroundTransparency = 1
sideTitle.Font = Enum.Font.GothamBlack sideTitle.TextSize = 16
sideTitle.TextColor3 = Color3.fromRGB(255, 220, 150) sideTitle.Text = "CA HUB"
local function sideBtn(txt, y)
    local b = Instance.new("TextButton", side)
    b.Size = UDim2.new(1, -16, 0, 34) b.Position = UDim2.new(0, 8, 0, y)
    b.Font = Enum.Font.GothamBold b.TextSize = 13
    b.BackgroundColor3 = Color3.fromRGB(32, 37, 48) b.TextColor3 = Color3.fromRGB(200, 210, 225)
    b.BorderSizePixel = 0 b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    return b
end
local tabFarm = sideBtn("FARM", 52)
local tabTp = sideBtn("TELEPORT", 92)
local body = Instance.new("Frame", main)
body.Size = UDim2.new(1, -142, 1, -16) body.Position = UDim2.new(0, 134, 0, 8)
body.BackgroundTransparency = 1
local function page()
    local f = Instance.new("Frame", body)
    f.Size = UDim2.new(1, 0, 1, 0) f.BackgroundTransparency = 1 f.Visible = false
    return f
end
local pgFarm, pgTp = page(), page()
pgFarm.Visible = true
local function selTab(which)
    pgFarm.Visible = which == "farm"
    pgTp.Visible = which == "tp"
    tabFarm.BackgroundColor3 = which == "farm" and ACC or Color3.fromRGB(32, 37, 48)
    tabTp.BackgroundColor3 = which == "tp" and ACC or Color3.fromRGB(32, 37, 48)
    tabFarm.TextColor3 = Color3.new(1, 1, 1)
    tabTp.TextColor3 = Color3.new(1, 1, 1)
end
tabFarm.MouseButton1Click:Connect(function() selTab("farm") end)
tabTp.MouseButton1Click:Connect(function() selTab("tp") end)
local function secTitle(parent, txt, y)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(1, 0, 0, 20) l.Position = UDim2.new(0, 0, 0, y)
    l.BackgroundTransparency = 1 l.Font = Enum.Font.GothamBold l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left l.TextColor3 = Color3.fromRGB(140, 160, 190)
    l.Text = txt:upper()
    return l
end
local function btn(parent, txt, y, h)
    h = h or 26
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, 0, 0, h) b.Position = UDim2.new(0, 0, 0, y)
    b.Font = Enum.Font.GothamBold b.TextSize = 12
    b.BackgroundColor3 = Color3.fromRGB(35, 41, 54) b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0 b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end
local function halfBtn(parent, txt, y, left)
    local b = Instance.new("TextButton", parent)
    if left then b.Size = UDim2.new(0.5, -3, 0, 26) b.Position = UDim2.new(0, 0, 0, y)
    else b.Size = UDim2.new(0.5, -3, 0, 26) b.Position = UDim2.new(0.5, 3, 0, y) end
    b.Font = Enum.Font.GothamBold b.TextSize = 11
    b.BackgroundColor3 = Color3.fromRGB(35, 41, 54) b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0 b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

--// PAGE FARM
secTitle(pgFarm, "Status", 0)
local fStatus = Instance.new("TextLabel", pgFarm)
fStatus.Size = UDim2.new(1, 0, 0, 86) fStatus.Position = UDim2.new(0, 0, 0, 20)
fStatus.BackgroundColor3 = PAN fStatus.Font = Enum.Font.Code fStatus.TextSize = 11
fStatus.TextWrapped = true fStatus.TextXAlignment = Enum.TextXAlignment.Left
fStatus.TextYAlignment = Enum.TextYAlignment.Top fStatus.TextColor3 = Color3.fromRGB(180, 220, 255)
fStatus.BorderSizePixel = 0 fStatus.Text = "..."
Instance.new("UICorner", fStatus).CornerRadius = UDim.new(0, 6)
local function updStatus(extra)
    local eggN, unkN = mirrorCounts()
    local tail = extra or (CFG.running and "JALAN" or "BERHENTI")
    if CFG.rebInfo ~= "" then tail = tail .. "\n" .. CFG.rebInfo end
    if CFG.sell then tail = tail .. string.format("\nTelur:%d ?: %d %s", eggN, unkN, CFG.sellInfo) end
    fStatus.Text = string.format("Speed %s | Money %s | Eggs %s\ncuri %d aman %d | sold %d | cyc %d | err %d | nest:%d\n%s",
        lsVal("Speed"), lsVal("Money"), lsVal("Eggs"),
        CFG.stolen, CFG.secured, CFG.sold, CFG.cycles, CFG.errors, CFG.ready, tail)
end
secTitle(pgFarm, "Otomatis", 110)
local function tog(parent, label, key, y)
    local b = btn(parent, "", y)
    local function ref()
        b.Text = (CFG[key] and "[ON] " or "[OFF] ") .. label
        b.BackgroundColor3 = CFG[key] and Color3.fromRGB(40, 110, 70) or Color3.fromRGB(35, 41, 54)
    end
    b.MouseButton1Click:Connect(function() CFG[key] = not CFG[key] ref() updStatus() end)
    ref()
    return b
end
tog(pgFarm, "Auto Steal", "steal", 130)
tog(pgFarm, "Auto Claim Telur", "claimSell", 160)
tog(pgFarm, "Auto Sell Telur Saja", "sell", 190)
tog(pgFarm, "Auto Upgrade Base", "upgrade", 220)
tog(pgFarm, "Auto Rebirth", "rebirth", 250)
local fZone = btn(pgFarm, "", 280)
local zi = 1
fZone.MouseButton1Click:Connect(function()
    zi = zi % #ZONES + 1 CFG.zone = ZONES[zi]
    fZone.Text = "Zone farm: " .. CFG.zone updStatus()
end)
fZone.Text = "Zone farm: SEMUA"
local fRun = btn(pgFarm, "", 310, 32)
local function refRun()
    fRun.Text = CFG.running and "STOP" or "START"
    fRun.BackgroundColor3 = CFG.running and Color3.fromRGB(160, 60, 55) or Color3.fromRGB(40, 110, 70)
end
fRun.MouseButton1Click:Connect(function() CFG.running = not CFG.running refRun() updStatus() end)
refRun()

--// PAGE TELEPORT MANUAL
secTitle(pgTp, "Target", 0)
local tInfo = Instance.new("TextLabel", pgTp)
tInfo.Size = UDim2.new(1, 0, 0, 44) tInfo.Position = UDim2.new(0, 0, 0, 20)
tInfo.BackgroundColor3 = PAN tInfo.Font = Enum.Font.Code tInfo.TextSize = 11
tInfo.TextWrapped = true tInfo.TextXAlignment = Enum.TextXAlignment.Left
tInfo.TextColor3 = Color3.fromRGB(180, 220, 255) tInfo.BorderSizePixel = 0 tInfo.Text = "..."
Instance.new("UICorner", tInfo).CornerRadius = UDim.new(0, 6)
secTitle(pgTp, "Pilih Nest", 68)
local tList = Instance.new("ScrollingFrame", pgTp)
tList.Size = UDim2.new(1, 0, 0, 132) tList.Position = UDim2.new(0, 0, 0, 88)
tList.BackgroundColor3 = PAN tList.BorderSizePixel = 0 tList.ScrollBarThickness = 5
tList.AutomaticCanvasSize = Enum.AutomaticSize.Y tList.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", tList).CornerRadius = UDim.new(0, 6)
local tLayout = Instance.new("UIListLayout", tList)
tLayout.Padding = UDim.new(0, 3) tLayout.SortOrder = Enum.SortOrder.LayoutOrder
local function tpSel(t)
    TP.sel = t
    tp(t.pos)
end
local function refList()
    for _, c in ipairs(tList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local list = nestList(TP.zone, TP.matureOnly)
    local h = hrp()
    local n = 0
    for _, t in ipairs(list) do
        n += 1
        if n > 60 then break end
        local d = h and math.floor((t.pos - h.Position).Magnitude) or -1
        local b = Instance.new("TextButton", tList)
        b.Size = UDim2.new(1, -8, 0, 22)
        b.Font = Enum.Font.Code b.TextSize = 11 b.TextXAlignment = Enum.TextXAlignment.Left
        b.BackgroundColor3 = t.mature and Color3.fromRGB(35, 80, 50) or Color3.fromRGB(40, 44, 55)
        b.TextColor3 = Color3.new(1, 1, 1) b.BorderSizePixel = 0
        b.Text = " " .. t.label .. (t.mature and " [M]" or "") .. " " .. d .. "st"
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        b.LayoutOrder = n
        b.MouseButton1Click:Connect(function() tpSel(t) refList() end)
    end
    local t = TP.sel
    if t then
        local d = h and math.floor((t.pos - h.Position).Magnitude) or -1
        tInfo.Text = #list .. " nest [" .. TP.zone .. "]\nTarget: " .. t.label .. " (" .. d .. " st)"
    else
        tInfo.Text = #list .. " nest [" .. TP.zone .. "]\nBelum pilih - klik daftar"
    end
end
local tZone = btn(pgTp, "", 224)
local tzi = 1
tZone.MouseButton1Click:Connect(function()
    tzi = tzi % #ZONES + 1 TP.zone = ZONES[tzi]
    tZone.Text = "Zone: " .. TP.zone refList()
end)
tZone.Text = "Zone: SEMUA"
local tMat = btn(pgTp, "", 254)
tMat.MouseButton1Click:Connect(function() TP.matureOnly = not TP.matureOnly tMat.Text = "Matang saja: " .. (TP.matureOnly and "ON" or "OFF") refList() end)
tMat.Text = "Matang saja: ON"
local tBindN = halfBtn(pgTp, "", 284, true)
local tBindB = halfBtn(pgTp, "", 284, false)
local tSpd = btn(pgTp, "", 314)
local tSpdM = halfBtn(pgTp, "- 25", 344, true)
local tSpdP = halfBtn(pgTp, "+ 25", 344, false)
local function refTp()
    tBindN.Text = "TP Nest [" .. TP.nestKey.Name .. "]"
    tBindB.Text = "TP Base [" .. TP.baseKey.Name .. "]"
    tSpd.Text = "SpeedLock: " .. (TP.spdLock and ("ON (" .. tostring(TP.spdT) .. ")") or "OFF (" .. tostring(math.floor(curWS())) .. ")")
end
tBindN.MouseButton1Click:Connect(function() TP.listening = "nest" tBindN.Text = "tekan tombol..." end)
tBindB.MouseButton1Click:Connect(function() TP.listening = "base" tBindB.Text = "tekan tombol..." end)
tSpd.MouseButton1Click:Connect(function()
    TP.spdLock = not TP.spdLock
    if TP.spdLock then TP.spdT = math.floor(curWS()) applySpd(TP.spdT) end
    refTp()
end)
tSpdM.MouseButton1Click:Connect(function()
    TP.spdT = math.max(16, (TP.spdT or math.floor(curWS())) - 25)
    applySpd(TP.spdT) refTp()
end)
tSpdP.MouseButton1Click:Connect(function()
    TP.spdT = math.min(2000, (TP.spdT or math.floor(curWS())) + 25)
    applySpd(TP.spdT) refTp()
end)
UIS.InputBegan:Connect(function(i, g)
    if g then return end
    if TP.listening then
        if TP.listening == "nest" then TP.nestKey = i.KeyCode else TP.baseKey = i.KeyCode end
        TP.listening = nil saveKeys() refTp()
        return
    end
    if i.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible return end
    if i.KeyCode == TP.nestKey then
        local t = TP.sel
        if t then tp(t.pos) end
    elseif i.KeyCode == TP.baseKey then
        tp(baseSpawnPos())
    end
end)
local function refAll()
    refList() refTp()
end

--// ENGINE FARM (sama: claim, steal-hop, sell telur, upgrade, rebirth)
local SELLMODE = {mode = "batch", fail = 0}
task.spawn(function()
    if not CONTAINER then return end
    local disp = CONTAINER:FindFirstChild("sync.dispatch")
    if not disp then return end
    disp.OnClientEvent:Connect(function(a)
        if type(a) ~= "table" or type(a[1]) ~= "table" then return end
        local act = a[1]
        if act.name == "addBackpackItem" and type(act.arguments) == "table" then
            local uid, data = act.arguments[1], act.arguments[2]
            if type(uid) == "string" then
                local cls = isEggItem(data)
                MIRROR[uid] = {egg = cls, t = os.clock()}
                if cls == nil and #UNKSCHEMA < 2 then
                    local ks = {}
                    if type(data) == "table" then
                        for k, _ in pairs(data) do table.insert(ks, tostring(k)) end
                    end
                    table.insert(UNKSCHEMA, table.concat(ks, ","):sub(1, 100))
                    CFG.sellInfo = "?skema: " .. UNKSCHEMA[#UNKSCHEMA]
                end
            end
        end
        if act.name == "setHoldingItem" and type(act.arguments) == "table" then
            local h = act.arguments[1]
            HELD.uid = (type(h) == "string" and h ~= "") and h or nil
        elseif act.name == "removeBackpackItem" and type(act.arguments) == "table" then
            local function drop(u) if type(u) == "string" then MIRROR[u] = nil end end
            for _, v in ipairs(act.arguments) do
                if type(v) == "string" then drop(v)
                elseif type(v) == "table" then for _, vv in ipairs(v) do drop(vv) end end
            end
            if type(act.arguments.uid) == "string" then drop(act.arguments.uid) end
        end
    end)
    while gui.Parent do task.wait(1) end
end)
task.spawn(function()
    local lastJump = os.clock()
    while gui.Parent do
        task.wait(0.25)
        if not CFG.running then updStatus() continue end
        if CFG.errors >= 15 then CFG.running = false refRun() updStatus("AUTO-STOP: 15 error") continue end
        if not hrp() then updStatus("menunggu karakter...") task.wait(2) continue end
        CFG.cycles += 1
        if os.clock() - lastJump > 50 then
            lastJump = os.clock()
            pcall(function() LP.Character:FindFirstChildOfClass("Humanoid").Jump = true end)
        end
        if CFG.claimSell then
            local b = myBase()
            local sp = b and b:FindFirstChild("Spawn", true)
            if sp and sp:IsA("BasePart") then
                tp(sp.Position)
                task.wait(0.6)
                for _, off in ipairs({Vector3.new(6,0,0), Vector3.new(-6,0,6), Vector3.new(0,0,-6)}) do
                    if not CFG.running then break end
                    tp(sp.Position + off) task.wait(0.35)
                end
                safeFire("data.base.claimAllEggs")
                safeFire("data.base.equipBestChickens")
            end
        end
        if CFG.steal and CFG.running then
            local nests = nestList(CFG.zone, true)
            CFG.ready = #nests
            for _, n in ipairs(nests) do
                if not CFG.running then break end
                if n.prompt.Enabled and hopTo(n.pos) then
                    if not n.prompt.Enabled then
                        task.wait(CFG.delay)
                    else
                        local uid = nil
                        for attempt = 1, 2 do
                            if not CFG.running then break end
                            if not n.prompt.Enabled then break end
                            HELD.uid = nil
                            local holdFor = (tonumber(n.prompt.HoldDuration) or 0.5) + 0.5
                            if holdFor < 0.8 then holdFor = 0.8 end
                            if holdFor > 3.0 then holdFor = 3.0 end
                            task.wait(0.4)
                            pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
                            task.wait(holdFor)
                            pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
                            task.wait(0.4)
                            uid = HELD.uid or heldUid()
                            if uid then break end
                            task.wait(0.3)
                        end
                        if uid then
                            CFG.stolen += 1
                            local sp2 = baseSpawnPos()
                            tp(sp2) task.wait(0.5)
                            local before = myPlacedCount()
                            safeFire("data.base.placeChicken", uid)
                            task.wait(1.0)
                            local okPlace = (myPlacedCount() > before) or (not stillHolding())
                            if not okPlace then
                                safeFire("game.backpack.unholdItem")
                                task.wait(0.8)
                                okPlace = (myPlacedCount() > before) or (not stillHolding())
                            end
                            if okPlace then CFG.secured += 1 end
                            HELD.uid = nil
                        end
                        task.wait(CFG.delay)
                    end
                end
                if CFG.errors >= 15 then break end
            end
            if CFG.ready == 0 then task.wait(2) end
        else
            CFG.ready = 0
        end
        if CFG.sell and CFG.running and CFG.cycles % CFG.sellEvery == 0 then
            local b = myBase()
            local sp = b and b:FindFirstChild("Spawn", true)
            if sp then tp(sp.Position) task.wait(0.4) end
            local uids = {}
            for uid, e in pairs(MIRROR) do
                if e.egg == true then table.insert(uids, uid) end
            end
            if #uids > 0 then
                local m0 = parseNum(lsVal("Money"))
                if SELLMODE.mode == "batch" then
                    safeFire("data.backpack.sellItems", uids)
                else
                    for _, u in ipairs(uids) do safeFire("data.backpack.sellItem", u) end
                end
                task.wait(1.5)
                local m1 = parseNum(lsVal("Money"))
                if m1 > m0 then
                    CFG.sold += #uids SELLMODE.fail = 0
                    CFG.sellInfo = "sold " .. #uids .. " telur"
                else
                    SELLMODE.fail += 1
                    CFG.sellInfo = "sell ROG (" .. SELLMODE.mode .. ")"
                    if SELLMODE.fail >= 2 and SELLMODE.mode == "batch" then
                        SELLMODE.mode = "single" SELLMODE.fail = 0
                    end
                end
            else
                CFG.sellInfo = "belum ada telur"
            end
            safeFire("data.base.equipBestChickens")
        end
        if CFG.upgrade and CFG.running and CFG.cycles % CFG.upEvery == 0 then
            local b = myBase()
            if b then
                for _, pr in ipairs(b:GetDescendants()) do
                    if pr:IsA("ProximityPrompt") and pr.Enabled and pr.Name == "UpgradePrompt" then
                        local anchor = pr.Parent
                        local part = anchor and (anchor:IsA("BasePart") and anchor or anchor:FindFirstChildWhichIsA("BasePart", true))
                        if part then tp(part.Position) task.wait(0.4) pcall(function() fireproximityprompt(pr) end) task.wait(0.5) end
                    end
                end
                safeFire("data.base.upgradeBase")
            end
        end
        do
            local spd = parseNum(lsVal("Speed"))
            local need, mi = nil, nil
            for i, cost in ipairs(TIERS) do
                if spd < cost then need, mi = cost, i break end
            end
            if not need then
                CFG.rebInfo = "Rebirth: MAX tier"
            else
                CFG.rebInfo = string.format("Rebirth t%d butuh %d [x%s], kamu %s", mi, need, tostring(MULTS[mi]), lsVal("Speed"))
                if CFG.rebirth and CFG.running and CFG.cycles % 10 == 0 then
                    safeFire("data.rebirth.doRebirth")
                end
            end
        end
        updStatus()
    end
end)
task.spawn(function()
    while gui.Parent do
        task.wait(3)
        pcall(refList)
    end
end)
task.spawn(function()
    while gui.Parent do
        task.wait(0.4)
        if TP.spdLock then pcall(function() applySpd(TP.spdT) end) end
    end
end)
updStatus() refAll() selTab("farm")
print("[CAHub] loaded.")
