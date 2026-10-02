--[[ Curi Ayam - Auto Farm Pro v1.0
   Data-driven: scan nest prompt saat jalan, tanpa hardcode posisi.
   Remote zero-arg aman (pcall + hitung error): claimAllEggs, equipBestChickens,
   sellAllItems, upgradeBase. Steal = teleport + fireproximityprompt (Hold 0.5).
   Base sendiri = plot "4" (Spawn -120,31,-375). Toggle RightShift. ]]

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
local ZONES = {"SEMUA","forest","lake","desert","jungle","volcano","cosmic","snow","beach","abyss","crystal","candy","alien","magma","bluelava"}

local CONTAINER = nil
pcall(function()
    CONTAINER = RS.packages._Index["littensy_remo@1.5.3"].remo.container
end)

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
                if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.Text == "YOUR BASE" then
                    mine = true break
                end
            end
        end
        if mine then
            fallback = fallback or b
            if b:FindFirstChild("UpgradePrompt", true) then return b end
        end
    end
    return fallback or bases:FindFirstChild("4")
end

local function nestPrompts()
    local out = {}
    local pz = WS.Game.Map.PlayZones
    if not pz then return out end
    for _, z in ipairs(pz:GetChildren()) do
        if CFG.zone == "SEMUA" or z.Name:lower() == CFG.zone then
            local nests = z:FindFirstChild("Nests")
            if nests then
                for _, pr in ipairs(nests:GetDescendants()) do
                    if pr:IsA("ProximityPrompt") and pr.Enabled
                        and (pr.ActionText == "Steal Chicken") then
                        local anchor = pr.Parent
                        local part = nil
                        if anchor and anchor:IsA("BasePart") then part = anchor
                        elseif anchor then part = anchor:FindFirstChildWhichIsA("BasePart", true) end
                        if part then
                            table.insert(out, {prompt = pr, pos = part.Position})
                        end
                    end
                    if #out >= 120 then return out end
                end
            end
        end
    end
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

--// GUI
pcall(function()
    local cg = game:GetService("CoreGui")
    local o = cg:FindFirstChild("CAAutoFarmPro") if o then o:Destroy() end
end)
local parent
do
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    local probe = false
    if ok and cg then
        probe = pcall(function()
            local t = Instance.new("ScreenGui") t.Name = "__p2__"
            t.Parent = cg t:Destroy()
        end)
    end
    parent = (probe and cg) or LP:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "CAAutoFarmPro" gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling gui.Parent = parent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 250, 0, 330) main.Position = UDim2.new(0, 12, 0.5, -165)
main.BackgroundColor3 = Color3.fromRGB(16,18,24) main.BorderSizePixel = 0
main.Active = true main.Draggable = true main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -40, 0, 30) title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1 title.Font = Enum.Font.GothamBold title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left title.TextColor3 = Color3.fromRGB(255,220,150)
title.Text = "[CA] Auto Farm Pro"

local btnX = Instance.new("TextButton", main)
btnX.Size = UDim2.new(0, 26, 0, 22) btnX.Position = UDim2.new(1, -30, 0, 4)
btnX.Text = "X" btnX.Font = Enum.Font.GothamBold btnX.TextSize = 12
btnX.BackgroundColor3 = Color3.fromRGB(160,50,55) btnX.TextColor3 = Color3.new(1,1,1)
btnX.BorderSizePixel = 0
Instance.new("UICorner", btnX).CornerRadius = UDim.new(0, 5)

local status = Instance.new("TextLabel", main)
status.Size = UDim2.new(1, -20, 0, 86) status.Position = UDim2.new(0, 10, 0, 30)
status.BackgroundColor3 = Color3.fromRGB(24,27,36) status.Font = Enum.Font.Code
status.TextSize = 11 status.TextWrapped = true status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top status.TextColor3 = Color3.fromRGB(180,220,255)
status.BorderSizePixel = 0
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)

local function updStatus(extra)
    local eggN, unkN = mirrorCounts()
    local tail = extra or (CFG.running and "JALAN" or "BERHENTI")
    if CFG.rebInfo ~= "" then tail = tail .. "\n" .. CFG.rebInfo end
    if CFG.sell then tail = tail .. string.format("\nTelur:%d ?: %d %s", eggN, unkN, CFG.sellInfo) end
    status.Text = string.format("Speed %s | Money %s | Eggs %s\ncuri %d aman %d | sold %d | cyc %d | err %d | nest:%d\n%s",
        lsVal("Speed"), lsVal("Money"), lsVal("Eggs"),
        CFG.stolen, CFG.secured, CFG.sold, CFG.cycles, CFG.errors, CFG.ready, tail)
end

local y = 122
local function mkToggle(label, key)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(1, -20, 0, 24) b.Position = UDim2.new(0, 10, 0, y) y += 28
    b.Font = Enum.Font.GothamBold b.TextSize = 11 b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    local function ref()
        b.Text = (CFG[key] and "[ON] " or "[OFF] ") .. label
        b.BackgroundColor3 = CFG[key] and Color3.fromRGB(40,110,70) or Color3.fromRGB(45,50,65)
        b.TextColor3 = Color3.new(1,1,1)
    end
    b.MouseButton1Click:Connect(function() CFG[key] = not CFG[key] ref() updStatus() end)
    ref()
    return b
end

mkToggle("Auto Steal (nest prompt)", "steal")
mkToggle("Auto Claim Telur", "claimSell")
mkToggle("Auto Sell SEMUA [risiko]", "sell")
mkToggle("Auto Upgrade Base", "upgrade")
mkToggle("Auto Rebirth (bahaya)", "rebirth")

local zoneBtn = Instance.new("TextButton", main)
zoneBtn.Size = UDim2.new(1, -20, 0, 24) zoneBtn.Position = UDim2.new(0, 10, 0, y) y += 28
zoneBtn.Font = Enum.Font.GothamBold zoneBtn.TextSize = 11
zoneBtn.BackgroundColor3 = Color3.fromRGB(50,70,110) zoneBtn.TextColor3 = Color3.new(1,1,1)
zoneBtn.BorderSizePixel = 0
Instance.new("UICorner", zoneBtn).CornerRadius = UDim.new(0, 5)
local zi = 1
zoneBtn.MouseButton1Click:Connect(function()
    zi = zi % #ZONES + 1 CFG.zone = ZONES[zi]
    zoneBtn.Text = "Zone: " .. CFG.zone updStatus()
end)
zoneBtn.Text = "Zone: SEMUA"

local btnRun = Instance.new("TextButton", main)
btnRun.Size = UDim2.new(1, -20, 0, 30) btnRun.Position = UDim2.new(0, 10, 0, y)
btnRun.Font = Enum.Font.GothamBold
btnRun.TextSize = 13 btnRun.BorderSizePixel = 0
Instance.new("UICorner", btnRun).CornerRadius = UDim.new(0, 6)
local function refRun()
    btnRun.Text = CFG.running and "STOP" or "START"
    btnRun.BackgroundColor3 = CFG.running and Color3.fromRGB(160,60,55) or Color3.fromRGB(40,110,70)
    btnRun.TextColor3 = Color3.new(1,1,1)
end
btnRun.MouseButton1Click:Connect(function() CFG.running = not CFG.running refRun() updStatus() end)
refRun()
btnX.MouseButton1Click:Connect(function() CFG.running = false gui:Destroy() end)
UIS.InputBegan:Connect(function(i, g)
    if not g and i.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible end
end)

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

--// ENGINE
task.spawn(function()
    local lastJump = os.clock()
    while gui.Parent do
        task.wait(0.25)
        if not CFG.running then updStatus() continue end
        if CFG.errors >= 15 then CFG.running = false refRun() updStatus("AUTO-STOP: 15 error") continue end
        if not hrp() then updStatus("menunggu karakter...") task.wait(2) continue end
        CFG.cycles += 1
        -- anti-afk loncat berkala
        if os.clock() - lastJump > 50 then
            lastJump = os.clock()
            pcall(function() LP.Character:FindFirstChildOfClass("Humanoid").Jump = true end)
        end
        -- 1) claim di base sendiri
        if CFG.claimSell then
            local b = myBase()
            local sp = b and b:FindFirstChild("Spawn", true)
            if sp and sp:IsA("BasePart") then
                tp(sp.Position)
                task.wait(0.6)
                -- jalan kecil agar telur tersentuh
                for _, off in ipairs({Vector3.new(6,0,0), Vector3.new(-6,0,6), Vector3.new(0,0,-6)}) do
                    if not CFG.running then break end
                    tp(sp.Position + off) task.wait(0.35)
                end
                safeFire("data.base.claimAllEggs")
                safeFire("data.base.equipBestChickens")
            end
        end
        -- 2) steal-carry MODE-MANUAL: teleport, pastikan sampai, TAHAN E asli
        if CFG.steal and CFG.running then
            local nests = nestPrompts()
            CFG.ready = #nests
            for _, n in ipairs(nests) do
                if not CFG.running then break end
                if n.prompt.Enabled and tp(n.pos) then
                    task.wait(0.7)
                    local h0 = hrp()
                    local dist = h0 and (h0.Position - n.pos).Magnitude or 999
                    if dist > 30 then
                        tp(n.pos) task.wait(0.7)
                        h0 = hrp()
                        dist = h0 and (h0.Position - n.pos).Magnitude or 999
                    end
                    if dist <= 30 and n.prompt.Enabled then
                        local uid = nil
                        for attempt = 1, 3 do
                            if not CFG.running then break end
                            if not n.prompt.Enabled then break end
                            local hh = hrp()
                            local dd = hh and (hh.Position - n.pos).Magnitude or 999
                            if dd > 30 then
                                tp(n.pos) task.wait(0.7)
                            end
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
                            if not uid and n.prompt.Enabled and attempt >= 2 then
                                pcall(function() fireproximityprompt(n.prompt) end)
                                task.wait(0.9)
                                uid = HELD.uid or heldUid()
                            end
                            if uid then break end
                            task.wait(0.3)
                        end
                        if uid then
                            CFG.stolen += 1
                            local b = myBase()
                            local sp = b and b:FindFirstChild("Spawn", true)
                            if sp then tp(sp.Position) task.wait(0.5) end
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
                    end
                    task.wait(CFG.delay)
                end
                if CFG.errors >= 15 then break end
            end
            if CFG.ready == 0 then task.wait(2) end
        else
            CFG.ready = 0
        end
        -- 3) sell HANYA telur (egg-only, default-deny)
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
        -- 4) upgrade berkala (prompt + remote)
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
        -- 5) rebirth: hanya jika syarat speed terpenuhi
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

updStatus("siap. START untuk jalan.")
print("[CAAutoFarmPro] loaded.")
