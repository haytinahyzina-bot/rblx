-- Iron Soul Hub (Obsidian UI) - Kill Aura / Auto Attack
-- Game: Iron Soul: Dungeon | PlaceId: 117533937949084 | UniverseId: 9910245722
-- Executor: SolaraV3
-- UI: Obsidian (https://github.com/deividcomsono/Obsidian)
-- WARNING: "Cheating will result in PERMANENT BAN". Test di private server / alt dulu.

local ObsidianURL = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"
local Library = loadstring(game:HttpGet(ObsidianURL))()

-- Config (disimpan di getgenv biar tahan re-Execute dalam 1 sesi)
getgenv().KillAuraConfig = getgenv().KillAuraConfig or {
    Enabled = false,        -- Auto Attack: pukul kalau target masuk jarak senjata
    AutoMobs = false,       -- Auto Mobs: terbang datangi target (tiduran di atasnya)
    UnlimitedRange = true,  -- true = deteksi target seluruh map (datangi otomatis)
    Radius = 60,            -- dipakai hanya kalau UnlimitedRange = false
    AttackRange = 12,       -- jarak natural senjata: pukulan keluar hanya kalau target sedekat ini
    AttackDelay = 0.25,     -- jeda antar serangan (detik)
    PositionMode = "Above", -- "Above" = melayang tiduran di atas target, "Inside" = di dalam target sejajar tanah
    Distance = 5,           -- jarak player dari target (mode Inside)
    HeightOffset = 3,       -- jarak melayang di atas pivot target (mode Above); yg work ~1, naikkan kalau kena damage
    FlySpeed = 120,         -- kecepatan meluncur studs/detik (yg work geraknya mulus, bukan teleport instan)
    AutoEquip = true,       -- auto equip Weapon dari Backpack
    MaxTargets = 10,        -- max musuh per tick (cegah lag)
    AutoSkill = false,      -- auto pakai skill Q/E/R bergantian
    SkillDelay = 3,         -- jeda antar skill (detik)
    WalkSpeedLock = false,  -- kunci WalkSpeed
    WalkSpeed = 16,         -- nilai WalkSpeed
    FindChestEgg = false,   -- auto ambil Chest & Dragon Egg (jalan kalau tidak ada musuh)
}
local Config = getgenv().KillAuraConfig
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function getCharacter()
    local c = LocalPlayer.Character
    if c and c:FindFirstChildOfClass("Humanoid") and c:FindFirstChildOfClass("Humanoid").Health > 0 then
        return c
    end
    return nil
end

local function getHRP(char)
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function ensureWeapon()
    local char = getCharacter()
    if not char then return nil end
    -- sudah ada Tool di character?
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name == "Weapon" then return t end
    end
    if Config.AutoEquip then
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            local tool = bp:FindFirstChild("Weapon")
            if tool then
                -- equip: pindah ke character via Humanoid:EquipTool
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(tool) end) end
                return tool
            end
        end
    end
    return nil
end

local function getEnemyPivot(model)
    -- WAJIB HumanoidRootPart biar lengket di kepala (jangan fallback ke Pivot 0,-1jt yg bikin ke dimensi lain)
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp.CFrame, hrp.Position, hrp end
    return nil, nil, nil
end

local function findEnemies(myPos)
    local list = {}
    -- Prioritas 1: folder dungeon (cepat + tidak kena NPC lobby)
    local priorityRoots = {}
    local we = workspace:FindFirstChild("WorldEnemys")
    if we then table.insert(priorityRoots, we) end
    local en = workspace:FindFirstChild("EnemyNpc")
    if en then table.insert(priorityRoots, en) end
    local scopes = (#priorityRoots > 0) and priorityRoots or { workspace }
    for _, scope in ipairs(scopes) do
        for _, v in ipairs(scope:GetDescendants()) do
            local ok, info = pcall(function()
                if not v:IsA("Humanoid") then return nil end
                if v.Health <= 0 then return nil end
                local model = v.Parent
                if not model or not model:IsA("Model") then return nil end
                if model == LocalPlayer.Character then return nil end
                if Players:GetPlayerFromCharacter(model) then return nil end
                local cf, pos, part = getEnemyPivot(model)
                if not pos then return nil end
                local dist = (pos - myPos).Magnitude
                -- UnlimitedRange = true -> radius mati, selagi map ada musuh langsung target
                if not Config.UnlimitedRange and dist > Config.Radius then return nil end
                return { Model = model, Humanoid = v, Root = part, Pos = pos, Dist = dist, Kind = "mob" }
            end)
            if ok and info then
                table.insert(list, info)
                if #list >= Config.MaxTargets then break end
            end
        end
        if #list >= Config.MaxTargets then break end
    end
    table.sort(list, function(a, b) return a.Dist < b.Dist end)
    return list
end

-- Target gabungan: monster dulu (urut jarak), lalu prop (chest/egg).
-- Auto Attack mukul apa pun yg bisa diserang dalam Jarak Serangan.
-- (Prop pakai ProximityPrompt, bukan Humanoid, jadi tidak dicampur ke mobs - biar Auto Mobs lengket ke kepala mob)
local function findTargets(myPos)
    return findEnemies(myPos)
end

-- Gerak CEPAT tiap frame (Heartbeat): biar pose tiduran stabil seperti script yg work.
-- (Update 0.25s terlalu lambat -> badan sempat balik berdiri / jatuh.)
-- CACHE target: scan berat (GetDescendants) hanya 1x/detik oleh thread lambat.
-- Mover tiap frame PAKAI CACHE (tanpa scan) biar tidak mencekik game.
getgenv().KillAuraCache = getgenv().KillAuraCache or {}
getgenv().KillAuraTpCount = getgenv().KillAuraTpCount or 0
getgenv().KillAuraScanCount = getgenv().KillAuraScanCount or 0

local function refreshTargets()
    local char = getCharacter()
    local myRoot = char and getHRP(char)
    if not myRoot then return {} end
    local list = findTargets(myRoot.Position)
    getgenv().KillAuraCache = list
    getgenv().KillAuraFound = #list
    getgenv().KillAuraScanCount = getgenv().KillAuraScanCount + 1
    return list
end

local function moveStep()
    if not Config.AutoMobs then return 0 end
    local char = getCharacter()
    local myRoot = char and getHRP(char)
    if not myRoot then return 0 end
    local enemies = getgenv().KillAuraCache or {}
    if #enemies == 0 then return 0 end
    -- Find Chest & Egg jalan di loop sendiri (tidak blokir Mobs) - mirip pola mereka
    local first = enemies[1]
    -- PENGAMAN target: skip target void/NaN biar tidak ikut nyemplung.
    if first and first.Pos then
        local fp = first.Pos
        if fp.Y < -200 or fp.Y ~= fp.Y or fp.X ~= fp.X or fp.Z ~= fp.Z then
            return #enemies
        end
        -- Recovery: kalau kita nyangkut di void/staging, snap SEKALI ke arena
        -- (1x lompat jauh ditoleransi; yg dihukum server = teleport spam tiap frame)
        local mp = myRoot.Position
        if mp.Y < -200 then
            pcall(function()
                myRoot.CFrame = CFrame.new(fp + Vector3.new(0, Config.HeightOffset, 0))
                myRoot.Velocity = Vector3.new(0, 0, 0)
            end)
            return #enemies
        end
        if Config.PositionMode == "Above" then
            pcall(function()
                -- TELEPORT instan ke atas target (sesuai permintaan: mobs = teleport, bukan lari/gliding)
                -- Pose tiduran horizontal (roll 90Â°).
                local above = fp + Vector3.new(0, Config.HeightOffset, 0)
                myRoot.CFrame = CFrame.new(above, Vector3.new(fp.X, above.Y, fp.Z))
                    * CFrame.Angles(0, 0, math.rad(90))
                myRoot.Velocity = Vector3.new(0, 0, 0)
            end)
        else
            pcall(function()
                local dir = myRoot.Position - first.Pos
                dir = Vector3.new(dir.X, 0, dir.Z)
                if dir.Magnitude < 0.5 then dir = Vector3.new(0, 0, 1) else dir = dir.Unit end
                local targetPos = first.Pos + dir * Config.Distance
                -- samakan tinggi pivot target + hadap target biar natural
                myRoot.CFrame = CFrame.new(Vector3.new(targetPos.X, first.Pos.Y, targetPos.Z), first.Pos)
                myRoot.Velocity = Vector3.new(0, 0, 0)
            end)
        end
    end
    return #enemies
end

local function attackOnce()
    -- return: jumlah target di map, jumlah yg diserang
    local char = getCharacter()
    if not char then return 0, 0 end
    local myRoot = getHRP(char)
    if not myRoot then return 0, 0 end
    local tool = ensureWeapon()
    -- saat stay di egg/chest, attack tetap jalan tapi tanpa teleport tambahan
    if getgenv().KillAuraStayEgg then
        -- pukul prop/egg di depan kita saja (tanpa pindah)
    end
    -- pakai cache (di-refresh thread lambat); scan langsung hanya kalau cache kosong
    local enemies = getgenv().KillAuraCache or {}
    if #enemies == 0 then enemies = findTargets(myRoot.Position) end
    if #enemies == 0 then return 0, 0 end
    -- AUTO ATTACK (bisa ON/OFF sendiri): pukul hanya target yg masuk jarak senjata.
    if not Config.Enabled then return #enemies, 0 end
    -- Serangan NATURAL: pukul hanya target yg masuk jarak senjata (bisa diatur jauh-dekat).
    -- Biar ayunan tidak keluar saat target masih jauh (kelihatan bot).
    local myPos = myRoot.Position
    local inRange = {}
    for _, e in ipairs(enemies) do
        local d = (e.Pos - myPos).Magnitude
        if d <= Config.AttackRange then table.insert(inRange, e) end
    end
    if #inRange == 0 then return #enemies, 0 end
    -- Auto hit: pakai cara mereka (firetouch) biar damage masuk - Tool:Activate saja 0 damage di game ini
    -- Coba sentuh fisik HRP musuh dengan Handle senjata
    pcall(function()
        if tool and tool:FindFirstChild("Handle") then
            for _, e in ipairs(inRange) do
                if e.Root and e.Humanoid and e.Humanoid.Health>0 then
                    firetouchinterest(tool.Handle, e.Root, 0)
                    firetouchinterest(tool.Handle, e.Root, 1)
                end
            end
        end
    end)
    if tool then pcall(function() tool:Activate() end) end
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local remotes = rs:FindFirstChild("Remotes")
        local act = remotes and remotes:FindFirstChild("PlayerActionRE")
        if act then act:FireServer() end
    end)
    -- fallback: kalau ada fungsi Attack asli mereka, panggil juga biar mirip 1:1
    pcall(function() if getgenv().Attack and type(getgenv().Attack)=="function" then getgenv().Attack(true) end end)
    return #enemies, #inRange
end

-- Auto skill Q/E/R bergantian (tombol skill di HUD). Pakai VirtualInput, tanpa remote khusus.
local SkillKeys = { Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R }
local SkillIndex = 1
local function castNextSkill()
    local vim = game:GetService("VirtualInputManager")
    local key = SkillKeys[SkillIndex]
    SkillIndex = SkillIndex % #SkillKeys + 1
    pcall(function()
        vim:SendKeyEvent(true, key, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, key, false, game)
    end)
end

-- Find Chest & Dragon Egg: datangi yg terdekat + fire semua ProximityPrompt di dalamnya.
-- Punya prioritas teleport sendiri kalau toggle-nya ON (Auto Mobs mengalah).
local function collectChestEgg()
    local char = getCharacter()
    local myRoot = char and getHRP(char)
    if not myRoot then return false end
    local myPos = myRoot.Position
    local best, bestDist = nil, math.huge
    local roots = {}
    local tc = workspace:FindFirstChild("TreasureChests")
    if tc then table.insert(roots, tc) end
    local de = workspace:FindFirstChild("DragonEggs")
    if de then table.insert(roots, de) end
    if #roots == 0 then roots = { workspace } end
    for _, scope in ipairs(roots) do
        for _, v in ipairs(scope:GetDescendants()) do
            -- catat semua prompt (walau belum Enabled: ada yg baru nyala pas didekati)
            if v:IsA("ProximityPrompt") then
                local holder = v.Parent
                local part = holder and (holder:IsA("BasePart") and holder or holder:FindFirstChildWhichIsA("BasePart", true))
                if part then
                    local d = (part.Position - myPos).Magnitude
                    if d < bestDist then best, bestDist, bestPrompt = part, d, v end
                end
            end
        end
    end
    if not best then return false end
    -- Stay di dekat prompt (3 studs), tunggu prompt ke-stream, lalu fire.
    -- Tetap berdiri di situ seperti script mereka (tidak balik ke mob).
    pcall(function()
        myRoot.CFrame = CFrame.new(best.Position + Vector3.new(0, 3, 0))
        myRoot.Velocity = Vector3.new(0, 0, 0)
    end)
    getgenv().KillAuraStayEgg = true
    task.spawn(function()
        local tries = 0
        while tries < 12 and getgenv().KillAuraStayEgg do
            tries = tries + 1
            pcall(function()
                -- target utama dulu (tahan-F di-skip oleh fireproximityprompt)
                if bestPrompt and bestPrompt.Enabled then
                    fireproximityprompt(bestPrompt)
                end
                local holder = best.Parent
                local scope = holder and holder.Parent or workspace
                for _, p in ipairs(scope:GetDescendants()) do
                    if p:IsA("ProximityPrompt") and p.Enabled then
                        local pp = p.Parent
                        local part = pp and (pp:IsA("BasePart") and pp or pp:FindFirstChildWhichIsA("BasePart", true))
                        if part and (part.Position - myRoot.Position).Magnitude < 20 then
                            fireproximityprompt(p)
                        end
                    end
                end
            end)
            task.wait(1)
            -- kalau sudah tidak ada prompt chest/egg di sini, anggap selesai dan keluar stay
            local still = false
            pcall(function()
                local holder = best.Parent
                local scope = holder and holder.Parent or workspace
                for _, p in ipairs(scope:GetDescendants()) do
                    if p:IsA("ProximityPrompt") and p.Enabled then still = true; break end
                end
            end)
            if not still then getgenv().KillAuraStayEgg = false; break end
            -- kalau musuh baru muncul dan Auto Mobs ON, biarin loop utama yg atur; stay tetap jalan sampai prompt habis
        end
        if tries >= 12 then getgenv().KillAuraStayEgg = false end
    end)
    return true
end

getgenv().KillAuraLoopRunning = getgenv().KillAuraLoopRunning or false
getgenv().KillAuraTotalHits = getgenv().KillAuraTotalHits or 0
getgenv().KillAuraVer = "v10-glide-obsidian"

-- Forward declarations buat UI handles (diisi setelah window jadi)
local ui = {
    targetsLabel = nil,
    hitsLabel = nil,
    statusLabel = nil,
}
local windowRef = nil

local function logLine(s)
    print("[KillAura] " .. tostring(s))
end

local function startLoop()
    if getgenv().KillAuraLoopRunning then return end
    getgenv().KillAuraLoopRunning = true
    -- MOVER CEPAT tiap frame: teleport instan (stay di target)
    task.spawn(function()
        local rs = game:GetService("RunService")
        while getgenv().KillAuraLoopRunning do
            if not getgenv().KillAuraStayEgg then
                pcall(moveStep)
            else
                -- Stay mode: jangan teleport lagi kalau sudah di dekat chest/egg (3 studs)
                local char = getCharacter()
                local myRoot = char and getHRP(char)
                if myRoot then
                    local e = getgenv().KillAuraCache and getgenv().KillAuraCache[1]
                    if not e or (e.Pos - myRoot.Position).Magnitude > 8 then
                        pcall(moveStep)
                    end
                end
            end
            rs.Heartbeat:Wait()
        end
    end)
    -- ATTACKER LAMBAT: serang + skill + chest + stat
    task.spawn(function()
        local tick = 0
        while getgenv().KillAuraLoopRunning do
            -- Kunci WalkSpeed (game suka reset)
            if Config.WalkSpeedLock then
                pcall(function()
                    local c = getCharacter()
                    local h = c and c:FindFirstChildOfClass("Humanoid")
                    if h and h.WalkSpeed ~= Config.WalkSpeed then h.WalkSpeed = Config.WalkSpeed end
                end)
            end
            local didAttack = false
            local foundCount = 0
            if Config.Enabled or Config.AutoMobs then
                local ok, found, n = pcall(attackOnce)
                if ok and found then
                    foundCount = found
                    if n > 0 then
                        getgenv().KillAuraTotalHits = getgenv().KillAuraTotalHits + n
                        didAttack = true
                    end
                end
            end
            -- Find Chest & Egg: jalan sendiri kalau ON (mobs mengalah soal teleport).
            -- Attack tetap mukul oportunis dalam jarak.
            if Config.FindChestEgg then
                local now = os.clock()
                getgenv().KillAuraNextChest = getgenv().KillAuraNextChest or 0
                if now >= getgenv().KillAuraNextChest then
                    getgenv().KillAuraNextChest = now + 2
                    pcall(collectChestEgg)
                end
            end
            tick = tick + 1
            -- Refresh cache target 1x/detik (scan berat cukup di sini, mover pakai cache)
            if tick % 4 == 1 then
                pcall(refreshTargets)
            end
            -- Auto skill tiap SkillDelay detik (toggle sendiri, tidak ikut Auto Attack)
            if Config.AutoSkill then
                local now = os.clock()
                getgenv().KillAuraNextSkill = getgenv().KillAuraNextSkill or 0
                if now >= getgenv().KillAuraNextSkill then
                    getgenv().KillAuraNextSkill = now + Config.SkillDelay
                    pcall(castNextSkill)
                end
            end
            -- update Stat tiap ~1 detik (AttackDelay 0.25 -> tiap 4 tick)
            if tick % 4 == 0 then
                pcall(function()
                    local char = getCharacter()
                    local myPos = char and getHRP(char) and getHRP(char).Position or nil
                    local count, mobs = 0, 0
                    if myPos then
                        local t = findTargets(myPos)
                        count = #t
                        for _, e in ipairs(t) do
                            if e.Kind == "mob" then mobs = mobs + 1 end
                        end
                    end
                    if ui.targetsLabel then ui.targetsLabel:SetText("Targets: " .. tostring(count) .. " (mob " .. tostring(mobs) .. ")") end
                    if ui.hitsLabel then ui.hitsLabel:SetText("Total Hits: " .. tostring(getgenv().KillAuraTotalHits)) end
                    if ui.statusLabel then
                        local scope = Config.UnlimitedRange and "map" or (tostring(Config.Radius) .. " studs")
                        local anyOn = Config.Enabled or Config.AutoMobs
                        if not anyOn then
                            ui.statusLabel:SetText("Idle. ON-kan Auto Mobs / Auto Attack.")
                        elseif count == 0 then
                            ui.statusLabel:SetText("ON - 0 target di " .. scope .. ". Masuk dungeon biar spawn.")
                        else
                            ui.statusLabel:SetText("ON - " .. tostring(count) .. " target (" .. scope .. "). Hits: " .. tostring(getgenv().KillAuraTotalHits))
                        end
                    end
                end)
            end
            task.wait(Config.AttackDelay)
        end
    end)
end

local function stopLoop(restore)
    getgenv().KillAuraLoopRunning = false
    Config.Enabled = false
    Config.AutoMobs = false
    -- balikin badan berdiri normal (matikan PlatformStand pose tiduran)
    pcall(function()
        local c = getCharacter()
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end)
    -- tidak ada visual yg diubah (tanpa visual hit), jadi tidak ada yg perlu di-restore
end

getgenv().KillAuraStart = function()
    Config.Enabled = true
    startLoop()
end
getgenv().KillAuraStop = function() stopLoop(true) end

-- ============ Obsidian UI ============
local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
    Title = "Iron Soul Hub",
    Footer = "Jiwa Besi: Dungeon | 117533937949084",
    Center = true,
    AutoShow = true,
    NotifySide = "Right",
    ShowCustomCursor = true,
})
windowRef = Window

local Tabs = {
    Combat = Window:AddTab("Combat", "swords"),
    Dungeon = Window:AddTab("Dungeon", "package"),
    Info = Window:AddTab("Info", "info"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

-- ---- Combat: Kill Aura ----
local CombatLeft = Tabs.Combat:AddLeftGroupbox("Kill Aura")
local CombatRight = Tabs.Combat:AddRightGroupbox("Serangan")

CombatLeft:AddLabel("StatusLabel", { Text = "Idle. Masuk dungeon biar target spawn." })
CombatLeft:AddLabel("TargetsLabel", { Text = "Targets: 0" })
CombatLeft:AddLabel("HitsLabel", { Text = "Total Hits: 0" })
ui.statusLabel = Options.StatusLabel
ui.targetsLabel = Options.TargetsLabel
ui.hitsLabel = Options.HitsLabel

CombatLeft:AddToggle("KillAuraEnabled", {
    Text = "Auto Attack",
    Tooltip = "Pukul otomatis apa pun yg bisa diserang (monster, chest, egg) dalam Jarak Serangan.",
    Default = Config.Enabled,
    Callback = function(v)
        Config.Enabled = v
        if v then
            startLoop()
            Library:Notify({ Title = "Auto Attack ON", Description = "Jarak " .. tostring(Config.AttackRange) .. " studs", Time = 4 })
        end
    end,
})

CombatLeft:AddToggle("KillAuraAutoMobs", {
    Text = "Auto Mobs",
    Tooltip = "Terbang datangi target + melayang TIDURAN di atasnya. Bisa ON/OFF sendiri.",
    Default = Config.AutoMobs,
    Callback = function(v)
        Config.AutoMobs = v
        if v then
            startLoop()
            Library:Notify({ Title = "Auto Mobs ON", Description = "Mode " .. tostring(Config.PositionMode), Time = 4 })
        else
            pcall(function()
                local c = getCharacter()
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if h then h.PlatformStand = false end
            end)
        end
    end,
})

CombatLeft:AddToggle("KillAuraUnlimited", {
    Text = "Unlimited Range",
    Tooltip = "ON = deteksi seluruh map. OFF = pakai Radius.",
    Default = Config.UnlimitedRange,
    Callback = function(v) Config.UnlimitedRange = v end,
})

CombatLeft:AddSlider("KillAuraRadius", {
    Text = "Radius (kalau Unlimited OFF)",
    Default = Config.Radius,
    Min = 20,
    Max = 200,
    Rounding = 0,
    Callback = function(v) Config.Radius = v end,
})

CombatLeft:AddDropdown("KillAuraPosMode", {
    Values = { "Di Dalam Musuh", "Di Atas Kepala" },
    Default = (Config.PositionMode == "Above") and "Di Atas Kepala" or "Di Dalam Musuh",
    Multi = false,
    Text = "Mode Posisi",
    Tooltip = "Di Atas Kepala = melayang tiduran (seperti yg work). Di Dalam Musuh = sejajar tanah.",
    Callback = function(v)
        local s = type(v) == "table" and v[1] or v
        Config.PositionMode = (s == "Di Atas Kepala") and "Above" or "Inside"
    end,
})

CombatRight:AddSlider("KillAuraAttackRange", {
    Text = "Jarak Serangan",
    Default = Config.AttackRange,
    Min = 5,
    Max = 40,
    Rounding = 0,
    Callback = function(v) Config.AttackRange = v end,
})

CombatRight:AddSlider("KillAuraDelay", {
    Text = "Attack Delay",
    Default = Config.AttackDelay,
    Min = 0.1,
    Max = 1,
    Rounding = 2,
    Callback = function(v) Config.AttackDelay = v end,
})

CombatRight:AddSlider("KillAuraDistance", {
    Text = "Set Distance (mode Dalam)",
    Default = Config.Distance,
    Min = 2,
    Max = 15,
    Rounding = 0,
    Callback = function(v) Config.Distance = v end,
})

CombatRight:AddSlider("KillAuraHeight", {
    Text = "Tinggi Di Atas Target",
    Default = Config.HeightOffset,
    Min = 1,
    Max = 25,
    Rounding = 0,
    Callback = function(v) Config.HeightOffset = v end,
})

CombatRight:AddSlider("KillAuraFlySpeed", {
    Text = "Fly Speed",
    Default = Config.FlySpeed,
    Min = 30,
    Max = 300,
    Rounding = 0,
    Callback = function(v) Config.FlySpeed = v end,
})

CombatRight:AddSlider("KillAuraMaxTargets", {
    Text = "Max Targets",
    Default = Config.MaxTargets,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Callback = function(v) Config.MaxTargets = math.floor(v) end,
})

CombatRight:AddToggle("KillAuraAutoEquip", {
    Text = "Auto Equip Weapon",
    Default = Config.AutoEquip,
    Callback = function(v) Config.AutoEquip = v end,
})

-- ---- Combat: Skill ----
local SkillBox = Tabs.Combat:AddLeftGroupbox("Skill")

SkillBox:AddToggle("KillAuraAutoSkill", {
    Text = "Auto Skill Q/E/R",
    Tooltip = "Pakai skill Q, E, R bergantian.",
    Default = Config.AutoSkill,
    Callback = function(v)
        Config.AutoSkill = v
        if v then
            startLoop()
            Library:Notify({ Title = "Auto Skill ON", Description = "Q/E/R tiap " .. tostring(Config.SkillDelay) .. "s", Time = 4 })
        end
    end,
})

SkillBox:AddSlider("KillAuraSkillDelay", {
    Text = "Jeda Skill",
    Default = Config.SkillDelay,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(v) Config.SkillDelay = v end,
})

SkillBox:AddButton({
    Text = "Stop Semua",
    Func = function()
        stopLoop(true)
        pcall(function() Toggles.KillAuraEnabled:SetValue(false) end)
        pcall(function() Toggles.KillAuraAutoMobs:SetValue(false) end)
        Library:Notify({ Title = "Stopped", Description = "Auto Mobs + Auto Attack mati.", Time = 4 })
    end,
})

-- ---- Dungeon tab ----
local DunLeft = Tabs.Dungeon:AddLeftGroupbox("Chest & Egg")
local DunRight = Tabs.Dungeon:AddRightGroupbox("Movement")

DunLeft:AddToggle("KillAuraChestEgg", {
    Text = "Find Chest & Egg",
    Tooltip = "Datangi Chest & Dragon Egg + fire prompt (tahan-F di-skip). Kalau ON, dia yg pegang teleport.",
    Default = Config.FindChestEgg,
    Callback = function(v)
        Config.FindChestEgg = v
        if v then
            startLoop()
            Library:Notify({ Title = "Chest & Egg ON", Description = "Otomatis ke chest/egg yg ada.", Time = 4 })
        end
    end,
})

DunRight:AddToggle("KillAuraWSLock", {
    Text = "Kunci Walk Speed",
    Default = Config.WalkSpeedLock,
    Callback = function(v)
        Config.WalkSpeedLock = v
        if v then startLoop() end
    end,
})

DunRight:AddSlider("KillAuraWS", {
    Text = "Walk Speed",
    Default = Config.WalkSpeed,
    Min = 16,
    Max = 120,
    Rounding = 0,
    Callback = function(v) Config.WalkSpeed = math.floor(v) end,
})

-- ---- Info tab ----
local InfoBox = Tabs.Info:AddLeftGroupbox("Game")

InfoBox:AddLabel("PlaceId: 117533937949084\nUniverseId: 9910245722\nTarget: monster, chest, egg, prop apa pun yg bisa diserang.\nCara pakai: masuk dungeon, ON-kan Auto Mobs + Auto Attack.", true)

InfoBox:AddButton({
    Text = "Copy PlaceId",
    Func = function()
        pcall(function() setclipboard("117533937949084") end)
        Library:Notify({ Title = "Copied", Description = "117533937949084", Time = 3 })
    end,
})

-- ---- UI Settings ----
local MenuBox = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
MenuBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuBox:AddButton("Unload", function() Library:Unload() end)
Library.ToggleKeybind = Options.MenuKeybind

-- Config save/load (opsional, gagal = UI tetap jalan)
pcall(function()
    local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
    local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
    local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    ThemeManager:SetFolder("IronSoulHub")
    SaveManager:SetFolder("IronSoulHub/dungeon")
    SaveManager:BuildConfigSection(Tabs["UI Settings"])
    ThemeManager:ApplyToTab(Tabs["UI Settings"])
    SaveManager:LoadAutoloadConfig()
end)

Library:OnUnload(function()
    pcall(function()
        getgenv().KillAuraLoopRunning = false
        Config.Enabled = false
        Config.AutoMobs = false
    end)
    print("[IronSoulHub] unloaded")
end)

print("[IronSoulHub] Obsidian UI loaded")
logLine("UI loaded. Mode " .. tostring(Config.PositionMode))
return "IronSoulHub Obsidian loaded"
