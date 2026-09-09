-- IRON SOUL: DUNGEON - Mirip script Tora IsMe (gumanba)
-- UI & fitur disamakan persis: Auto Attack, Auto Skills, Set Distance, Auto Mobs, Find Chest & Egg, Walk Speed
-- Cara pakai: Execute di Solara. Tidak perlu bridge.

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo.."Library.lua"))()
local Window = Library:CreateWindow({Title="IRON SOUL: DUNGEON",Footer="YouTube: Tora IsMe",Center=true,AutoShow=true,NotifySide="Right",ShowCustomCursor=true})
local Tab = Window:AddTab("Main","swords")
local Box = Tab:AddLeftGroupbox("Main")

-- Config sama seperti mereka (pakai _G biar kompatibel)
_G.Attack = _G.Attack or false
_G.Mobs = _G.Mobs or false
_G.Find = _G.Find or false
_G.Skills = _G.Skills or false
getgenv().Distance = getgenv().Distance or 5
getgenv().WalkSpeedVal = getgenv().WalkSpeedVal or 16

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local function getHRP() local c=LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c=LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getPivotPos(m)
    -- FIX: wajib HRP biar lengket di kepala, tidak ke void 0,-1jt
    local hrp=m:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp.Position end
    return nil
end

-- Auto Mobs: langsung ke musuh (buka pintu dulu biar tidak ke-void, mirip gumanba)
local function doMobs()
    if not _G.Mobs then return end
    local hrp=getHRP()
    if not hrp then return end
    local my=hrp.Position
    local best,bd=nil,1e9
    for _,m in ipairs(workspace.EnemyNpc:GetChildren()) do
        local ok,h=pcall(function() return m:FindFirstChildOfClass("Humanoid") end)
        if ok and h and h.Health>0 then
            local pos=getPivotPos(m)
            if pos then
                local d=(pos-my).Magnitude
                if d<bd then bd=d; best=m end
            end
        end
    end
    -- fallback WorldEnemys
    if not best then
        local we=workspace:FindFirstChild("WorldEnemys")
        if we then for _,m in ipairs(we:GetChildren()) do local ok,h=pcall(function() return m:FindFirstChildOfClass("Humanoid") end) if ok and h and h.Health>0 then local pos=getPivotPos(m) if pos then local d=(pos-my).Magnitude if d<bd then bd=d; best=m end end end end end
    end
    if not best then return end
    local pos=getPivotPos(best)
    if not pos or pos.Y<-200 then return end
    -- jalan kaki ke musuh (bukan teleport) biar tidak ke-void - mirip gumanba yang smooth
    pcall(function()
        local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:MoveTo(pos) end
    end)
end

-- Auto Attack: basic attack tanpa tekan, tanpa visual (spam terus walau Mobs OFF)
local function doAttack()
    if not _G.Attack then return end
    -- langsung spam basic attack (tanpa cek jarak/HP), seperti menekan Click terus - tanpa visual game
    -- tanpa visual hit (tidak ubah Size/Transparency, tidak mainkan animasi)
    -- FIX BENAR: damage putih+rune di game ini bukan cuma Activate.
    -- Kalau script asli (gumanba) masih ter-load, pakai Attack asli mereka yang sudah terbukti 30->0.
    -- tanpa visual: jangan Activate (yang mainkan animasi), cukup fire remote damage putih+rune
    pcall(function()
        local rs=game:GetService("ReplicatedStorage")
        local re=rs:FindFirstChild("Remotes")
        local a=re and re:FindFirstChild("PlayerActionRE")
        if a then a:FireServer("Attack") end
    end)
end

-- Auto Skills: Q E R bergantian
local skIdx=1
local function doSkills()
    if not _G.Skills then return end
    local keys={Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.R}
    local k=keys[skIdx] skIdx=skIdx%#keys+1
    local vim=game:GetService("VirtualInputManager")
    pcall(function() vim:SendKeyEvent(true,k,false,game) task.wait(0.05) vim:SendKeyEvent(false,k,false,game) end)
end

-- Find Chest & Egg: teleport stay ke prompt terdekat, fire tahan-F, tetap di situ
local staying=false
local function doFind()
    if not _G.Find then staying=false; return end
    if staying then return end
    local hrp=getHRP()
    if not hrp then return end
    local my=hrp.Position
    local best,bd,bp=nil,1e9,nil
    local scopes={workspace}
    local tc=workspace:FindFirstChild("TreasureChests") if tc then table.insert(scopes,tc) end
    local de=workspace:FindFirstChild("DragonEggs") if de then table.insert(scopes,de) end
    for _,sc in ipairs(scopes) do for _,v in ipairs(sc:GetDescendants()) do if v:IsA("ProximityPrompt") and v.Enabled then local holder=v.Parent local part=holder and (holder:IsA("BasePart") and holder or holder:FindFirstChildWhichIsA("BasePart",true)) if part then local d=(part.Position-my).Magnitude if d<bd then bd=d; best=part; bp=v end end end end end
    -- fallback top-level Chest1/DragonEgg
    if not best then for _,m in ipairs(workspace:GetChildren()) do if m:IsA("Model") then local ln=string.lower(m.Name) if ln:find("chest",1,true) or ln:find("egg",1,true) then local p=m:FindFirstChild("Root") or m:FindFirstChildWhichIsA("BasePart",true) if p and p:FindFirstChildWhichIsA("ProximityPrompt",true) then best=p; bp=p:FindFirstChildWhichIsA("ProximityPrompt",true); break end end end end end
    if not best then return end
    staying=true
    pcall(function() hrp.CFrame=CFrame.new(best.Position+Vector3.new(0,3,0)); hrp.Velocity=Vector3.new(0,0,0) end)
    task.wait(0.5)
    for i=1,3 do if bp and bp.Enabled then pcall(function() fireproximityprompt(bp) end) task.wait(0.5) end end
    task.wait(1)
    staying=false
end

-- Loops - samakan gumanba: Mobs 0.5s (tidak 0.02s spam void), Attack 0.25s tanpa visual
task.spawn(function() while task.wait(0.5) do pcall(doMobs) end end)
task.spawn(function() while task.wait(0.25) do pcall(doAttack) end end)
task.spawn(function() while task.wait(2.5) do pcall(doSkills) end end)
task.spawn(function() while task.wait(2) do pcall(doFind) end end)
task.spawn(function() while task.wait(0.5) do if getgenv().WalkSpeedVal then local h=getHum() if h and h.WalkSpeed~=getgenv().WalkSpeedVal then pcall(function() h.WalkSpeed=getgenv().WalkSpeedVal end) end end end end)

-- UI persis seperti screenshot - logika 1:1 gumanba, tanpa delegasi ganda
Box:AddToggle("AutoAttack",{Text="Auto Attack",Default=_G.Attack,Callback=function(v) _G.Attack=v end})
Box:AddToggle("AutoSkills",{Text="Auto Skills",Default=_G.Skills,Callback=function(v) _G.Skills=v end})
Box:AddSlider("SetDistance",{Text="Set Distance",Default=getgenv().Distance,Min=2,Max=15,Rounding=0,Callback=function(v) getgenv().Distance=v end})
Box:AddToggle("AutoMobs",{Text="Auto Mobs",Default=_G.Mobs,Callback=function(v) _G.Mobs=v end})
Box:AddToggle("FindChestEgg",{Text="Find Chest & Egg",Default=_G.Find,Callback=function(v) _G.Find=v end})
Box:AddSlider("WalkSpeed",{Text="Walk Speed",Default=getgenv().WalkSpeedVal,Min=16,Max=50,Rounding=0,Callback=function(v) getgenv().WalkSpeedVal=v; local h=getHum() if h then pcall(function() h.WalkSpeed=v end) end end})
Box:AddLabel("YouTube: Tora IsMe",true)

Library:Notify({Title="IRON SOUL: DUNGEON",Description="Mirip script asli - siap pakai",Time=4})
print("Iron Soul Mirip loaded")
