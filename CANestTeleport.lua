--[[ CA Nest Teleport v1.0 : teleport ke nest target + ke base via hotkey atur-sendiri ]]

local Players = game:GetService("Players")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local CFG = { nestKey = Enum.KeyCode.G, baseKey = Enum.KeyCode.H, matureOnly = true, idx = 0 }
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
    if h then
        table.sort(targets, function(a, b) return (a.pos - h.Position).Magnitude < (b.pos - h.Position).Magnitude end)
    end
    if CFG.idx > #targets then CFG.idx = 0 end
end

local function tp(pos)
    local h = hrp()
    if h then pcall(function()
        h.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0))
        h.Velocity = Vector3.zero
    end) end
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
main.Size = UDim2.new(0, 250, 0, 190) main.Position = UDim2.new(0, 12, 0.5, -95)
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
local bNest = mkBtn("", 72)
local bBase = mkBtn("", 100)
local bNext = mkBtn("Target berikut", 128)
local bMat = mkBtn("", 156)

local function ref()
    bNest.Text = "TP Nest [" .. CFG.nestKey.Name .. "] - klik utk ubah"
    bBase.Text = "TP Base [" .. CFG.baseKey.Name .. "] - klik utk ubah"
    bMat.Text = "Hanya matang: " .. (CFG.matureOnly and "ON" or "OFF")
    local h = hrp()
    local t = targets[1]
    if t then
        local d = h and math.floor((t.pos - h.Position).Magnitude) or -1
        info.Text = #targets .. " nest | target: " .. t.label .. "\n" .. d .. " stud"
    else
        info.Text = "0 nest (belum ada yg matang?)"
    end
end

bNest.MouseButton1Click:Connect(function() listening = "nest" bNest.Text = "tekan tombol..." end)
bBase.MouseButton1Click:Connect(function() listening = "base" bBase.Text = "tekan tombol..." end)
bNext.MouseButton1Click:Connect(function()
    if #targets > 1 then
        local f = table.remove(targets, 1)
        table.insert(targets, f)
    end
    ref()
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
scan() ref()
print("[CANestTp] loaded.")
