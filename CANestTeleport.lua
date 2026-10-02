--[[ CA Nest Teleport v1.0 : teleport ke nest target + ke base via hotkey atur-sendiri ]]

local Players = game:GetService("Players")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local CFG = { nestKey = Enum.KeyCode.G, baseKey = Enum.KeyCode.H, matureOnly = true, idx = 0, zone = "SEMUA" }
local ZONES = {"SEMUA","forest","lake","desert","jungle","volcano","cosmic","snow","beach","abyss","crystal","candy","alien","magma","bluelava"}
local targets = {}
local SAVE = "CANestTp.txt"

pcall(function()
    if readfile and isfile and isfile(SAVE) then
        local a, b = readfile(SAVE):match("^(%S+)%s+(%S+)")
        if a then local ok, kc = pcall(function() return Enum.KeyCode[a] end) if ok then CFG.nestKey = kc end end
        if b then local ok, kc = pcall(function() return Enum.KeyCode[b] end) if ok then CFG.baseKey = kc end end
    end
end)
local function save()
    pcall(function()
        if writefile then writefile(SAVE, CFG.nestKey.Name .. " " .. CFG.baseKey.Name) end
    end)
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function myBaseSpawn()
    local bases = WS.Game.Map.Lobby.Bases
    if bases then
        local fb = nil
        for _, b in ipairs(bases:GetChildren()) do
            local bill = b:FindFirstChild("BaseBillb", true)
            local mine = false
            if bill then
                for _, x in ipairs(bill:GetDescendants()) do
                    if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.Text == "YOUR BASE" then mine = true break end
                end
            end
            if mine then
                fb = fb or b
                if b:FindFirstChild("UpgradePrompt", true) then
                    local sp = b:FindFirstChild("Spawn", true)
                    if sp and sp:IsA("BasePart") then return sp.Position end
                end
            end
        end
        if fb then local sp = fb:FindFirstChild("Spawn", true) if sp then return sp.Position end end
    end
    return Vector3.new(-120, 32, -375)
end

local function scan()
    targets = {}
    local h = hrp()
    local pz = WS.Game.Map.PlayZones
    if pz then
        for _, z in ipairs(pz:GetChildren()) do
        if CFG.zone == "SEMUA" or string.lower(z.Name) == CFG.zone then
            local ns = z:FindFirstChild("Nests")
            if ns then
                for _, pr in ipairs(ns:GetDescendants()) do
                    if pr:IsA("ProximityPrompt") and pr.ActionText == "Steal Chicken"
                        and (not CFG.matureOnly or pr.Enabled) then
                        local a = pr.Parent
                        local part = a and (a:IsA("BasePart") and a or a:FindFirstChildWhichIsA("BasePart", true))
                        if part then
                            table.insert(targets, {prompt = pr, pos = part.Position,
                                label = z.Name .. "/" .. pr.Parent.Name .. (pr.Enabled and " [matang]" or "")})
                        end
                    end
                end
            end
        end
        end
    end
    if h then
        table.sort(targets, function(a, b) return (a.pos - h.Position).Magnitude < (b.pos - h.Position).Magnitude end)
    end
    if CFG.idx > #targets then CFG.idx = 0 end
end

local function wsStep()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    local ws = hum and hum.WalkSpeed or 16
    if ws < 16 then ws = 16 end
    local s = ws * 3
    if s < 40 then s = 40 end
    if s > 900 then s = 900 end
    return s
end

local function tp(pos)
    local h = hrp()
    if not h then return end
    pcall(function()
        h.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0))
        h.Velocity = Vector3.zero
    end)
    task.wait(0.8)
    local h2 = hrp()
    if h2 and (h2.Position - pos).Magnitude > 60 then
        local st = wsStep()
        for i = 1, 120 do
            local hh = hrp()
            if not hh then break end
            local cur = hh.Position
            local dd = (pos - cur).Magnitude
            if dd <= 40 then break end
            local step = (pos - cur).Unit * math.min(st, dd)
            pcall(function()
                hh.CFrame = CFrame.new(cur + step)
                hh.Velocity = Vector3.zero
            end)
            task.wait(0.25)
        end
    end
end

pcall(function()
    local cg = game:GetService("CoreGui")
    local o = cg:FindFirstChild("CANestTp") if o then o:Destroy() end
end)
local parent
do
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    local probe = false
    if ok and cg then probe = pcall(function()
        local t = Instance.new("ScreenGui") t.Name = "__p3__"
        t.Parent = cg t:Destroy()
    end) end
    parent = (probe and cg) or LP:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "CANestTp" gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling gui.Parent = parent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 250, 0, 272) main.Position = UDim2.new(0, 12, 0.5, -136)
main.BackgroundColor3 = Color3.fromRGB(16, 18, 24) main.BorderSizePixel = 0
main.Active = true main.Draggable = true main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -40, 0, 26) title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1 title.Font = Enum.Font.GothamBold title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left title.TextColor3 = Color3.fromRGB(255, 220, 150)
title.Text = "Nest Teleport"
local btnX = Instance.new("TextButton", main)
btnX.Size = UDim2.new(0, 26, 0, 20) btnX.Position = UDim2.new(1, -30, 0, 3)
btnX.Text = "X" btnX.Font = Enum.Font.GothamBold btnX.TextSize = 12
btnX.BackgroundColor3 = Color3.fromRGB(160, 50, 55) btnX.TextColor3 = Color3.new(1, 1, 1)
btnX.BorderSizePixel = 0
Instance.new("UICorner", btnX).CornerRadius = UDim.new(0, 5)

local info = Instance.new("TextLabel", main)
info.Size = UDim2.new(1, -20, 0, 40) info.Position = UDim2.new(0, 10, 0, 28)
info.BackgroundColor3 = Color3.fromRGB(24, 27, 36) info.Font = Enum.Font.Code
info.TextSize = 11 info.TextWrapped = true info.TextXAlignment = Enum.TextXAlignment.Left
info.TextColor3 = Color3.fromRGB(180, 220, 255) info.BorderSizePixel = 0
Instance.new("UICorner", info).CornerRadius = UDim.new(0, 6)

local function mkBtn(txt, y)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(1, -20, 0, 24) b.Position = UDim2.new(0, 10, 0, y)
    b.Font = Enum.Font.GothamBold b.TextSize = 11
    b.BackgroundColor3 = Color3.fromRGB(45, 50, 65) b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0 b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local listening = nil
local spdLock, spdT = false, nil
local function curWS()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.WalkSpeed or 16
end
local function applySpd()
    if spdT then pcall(function() LP.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = spdT end) end
end
local bNest = mkBtn("", 72)
local bBase = mkBtn("", 100)
local bNext = mkBtn("Target berikut", 128)
local bZone = mkBtn("", 156)
local bMat = mkBtn("", 184)
local bSpd = mkBtn("", 212)
local bSpdM = mkBtn("- 25", 240)
local bSpdP = mkBtn("+ 25", 240)
bSpdM.Size = UDim2.new(0, 110, 0, 24)
bSpdP.Size = UDim2.new(0, 110, 0, 24)
bSpdP.Position = UDim2.new(0, 130, 0, 240)

local function ref()
    bNest.Text = "TP Nest [" .. CFG.nestKey.Name .. "] - klik utk ubah"
    bBase.Text = "TP Base [" .. CFG.baseKey.Name .. "] - klik utk ubah"
    bZone.Text = "Zone: " .. CFG.zone
    bMat.Text = "Hanya matang: " .. (CFG.matureOnly and "ON" or "OFF")
    bSpd.Text = "SpeedLock: " .. (spdLock and ("ON (" .. tostring(spdT) .. ")") or "OFF (" .. tostring(math.floor(curWS())) .. ")")
    local h = hrp()
    local t = targets[1]
    if t then
        local d = h and math.floor((t.pos - h.Position).Magnitude) or -1
        info.Text = #targets .. " nest [" .. CFG.zone .. "] | target: " .. t.label .. "\n" .. d .. " stud"
    else
        info.Text = "0 nest (belum ada yg matang?)"
    end
end

bNest.MouseButton1Click:Connect(function() listening = "nest" bNest.Text = "tekan tombol..." end)
bBase.MouseButton1Click:Connect(function() listening = "base" bBase.Text = "tekan tombol..." end)
bSpd.MouseButton1Click:Connect(function()
    spdLock = not spdLock
    if spdLock then spdT = math.floor(curWS()) applySpd() end
    ref()
end)
bSpdM.MouseButton1Click:Connect(function()
    spdT = math.max(16, (spdT or math.floor(curWS())) - 25)
    applySpd() ref()
end)
bSpdP.MouseButton1Click:Connect(function()
    spdT = math.min(2000, (spdT or math.floor(curWS())) + 25)
    applySpd() ref()
end)
bNext.MouseButton1Click:Connect(function()
    if #targets > 1 then
        local f = table.remove(targets, 1)
        table.insert(targets, f)
    end
    ref()
end)
local zi = 1
bZone.MouseButton1Click:Connect(function()
    zi = zi % #ZONES + 1 CFG.zone = ZONES[zi]
    scan() ref()
end)
bMat.MouseButton1Click:Connect(function() CFG.matureOnly = not CFG.matureOnly scan() ref() end)
btnX.MouseButton1Click:Connect(function() gui:Destroy() end)
UIS.InputBegan:Connect(function(i, g)
    if g then return end
    if listening then
        if listening == "nest" then CFG.nestKey = i.KeyCode else CFG.baseKey = i.KeyCode end
        listening = nil save() ref()
        return
    end
    if i.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible return end
    if i.KeyCode == CFG.nestKey then
        local t = targets[1]
        if t then tp(t.pos) end
    elseif i.KeyCode == CFG.baseKey then
        tp(myBaseSpawn())
    end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(2)
        pcall(scan)
        if not listening then pcall(ref) end
    end
end)
task.spawn(function()
    while gui.Parent do
        task.wait(0.4)
        if spdLock then pcall(applySpd) end
    end
end)
scan() ref()
print("[CANestTp] loaded.")
