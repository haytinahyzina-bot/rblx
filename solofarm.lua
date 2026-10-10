-- SoloFarm Profesional — Pecahkan dan Curi Telur
-- Fokus: farming sendiri (tanpa steal PvP). Aman: hormati cooldown + range server.
-- Cara pakai: execute sebagai LocalScript executor. Toggle via _G.SoloFarm.*
-- Tested state: Pickaxe T11 dmg 1M, Zone5 1-hit, Satchel 1, Plot 8/9.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer

_G.SoloFarm = _G.SoloFarm or {
  Enabled = true,
  Zone = 5,            -- auto-override di bawah kalau damage kurang
  HitCooldown = 0.55,  -- server SwingCooldown 0.5 + margin
  HitRange = 6.5,      -- server HitRange 8 - margin 1.5
  BankAfter = 1,       -- satchel cuma 1, bank tiap 1 pickup
  UpgradePickaxe = true,
  ChasePickup = true,
  StatusPrint = true,
  Fly = false,         -- toggle terbang (tombol F)
  FlySpeed = 50,       -- 40-60 aman, >100 rubber
  FlyKey = "F",
}
local Cfg = _G.SoloFarm

local Shared = RS:WaitForChild("Shared")
local function req(name)
  local m = Shared:FindFirstChild(name)
  if not m then return nil end
  local ok, r = pcall(require, m)
  return ok and r or nil
end

local PickCfg = req("PickaxeConfig")
local EggReq = RS:WaitForChild("EggHitRequest")
local Chase = req("ChaseState")

local function dmg()
  if not PickCfg then return 1 end
  local t = LP:GetAttribute("PickaxeTier") or 1
  local ok, d = pcall(function() return PickCfg.GetDamage(t) end)
  return (ok and tonumber(d)) or 1
end

local function myHRP()
  local c = LP.Character
  return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function myHum()
  local c = LP.Character
  return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function unanchor()
  local h = myHRP()
  if h and h.Anchored then pcall(function() h.Anchored = false end) end
end

local function equipPickaxe()
  local ch = LP.Character
  if not ch then return end
  for _, t in ipairs(ch:GetChildren()) do
    if t:IsA("Tool") and t.Name == "Pickaxe" then return end
  end
  local tool = LP.Backpack:FindFirstChild("Pickaxe")
  local hum = myHum()
  if tool and hum then pcall(function() hum:EquipTool(tool) end) end
end

-- Pilih zona terbaik: med HP <= dmg*2 (maks 2 hit biar efisien)
local function bestZone()
  local d = dmg()
  local per = {}
  for _, e in ipairs(CS:GetTagged("BreakableEgg")) do
    local z = e:GetAttribute("ZoneIndex")
    local hp = e:GetAttribute("MaxHealth")
    if type(z) == "number" and type(hp) == "number" then
      per[z] = per[z] or {}
      table.insert(per[z], hp)
    end
  end
  local best = 1
  for z = 1, 9 do
    local arr = per[z]
    if arr and #arr > 0 then
      table.sort(arr)
      local med = arr[math.floor(#arr / 2)] or arr[1]
      if med <= d * 2 then best = z end
    end
  end
  return best
end

local function liveEggs(zone)
  local out = {}
  for _, e in ipairs(CS:GetTagged("BreakableEgg")) do
    if e.Parent and e:GetAttribute("ZoneIndex") == zone
      and e:GetAttribute("Broken") == false then
      local hp = e:GetAttribute("Health") or 0
      if hp > 0 then table.insert(out, e) end
    end
  end
  return out
end

local function nearestEgg(zone)
  local h = myHRP()
  if not h then return nil, math.huge end
  local bestE, bestD = nil, math.huge
  for _, e in ipairs(liveEggs(zone)) do
    local ok, pos = pcall(function() return e:GetPivot().Position end)
    if ok then
      local d = (pos - h.Position).Magnitude
      if d < bestD then bestD, bestE = d, e end
    end
  end
  return bestE, bestD
end

local function walkTo(pos, tol)
  local hum = myHum()
  if not hum then return end
  unanchor()
  if Cfg.Fly then
    -- saat terbang: geser 4 stud ke arah target (jangan MoveTo, konflik)
    local hrp = myHRP()
    if hrp then
      local d = pos - hrp.Position
      local step = math.min(4, d.Magnitude)
      if step > 0.5 then
        pcall(function() hrp.CFrame = hrp.CFrame + (d.Unit * step) end)
      end
    end
    return
  end
  pcall(function() hum:MoveTo(pos) end)
end

local function hitEgg(egg)
  equipPickaxe()
  local h = myHRP()
  if not h or not egg.Parent then return false end
  local ok, pos = pcall(function() return egg:GetPivot().Position end)
  if not ok then return false end
  local d = (pos - h.Position).Magnitude
  if d > Cfg.HitRange then
    walkTo(pos, Cfg.HitRange - 1)
    return "walk"
  end
  local okF = pcall(function() EggReq:FireServer(egg) end)
  return okF
end

local function tryUpgrade()
  if not Cfg.UpgradePickaxe or not PickCfg then return end
  local tier = LP:GetAttribute("PickaxeTier") or 1
  local cash = LP:GetAttribute("Cash") or 0
  local okP, price = pcall(function() return PickCfg.GetPrice(tier + 1) end)
  if okP and type(price) == "number" and cash >= price then
    local r = RS:FindFirstChild("PickaxeShopRequest")
    if r then pcall(function() r:FireServer(tier + 1) end) end
  end
end

local function isCarrying()
  if Chase then
    local ok, v = pcall(function() return Chase.IsCarrying(LP) end)
    if ok then return v end
  end
  return false
end

local function bankRun()
  -- Kembali ke base sendiri (bankable). Jalan kaki, jangan TP jauh (rubber).
  local plots = WS:FindFirstChild("Plots")
  local b7 = plots and plots:FindFirstChild("Base_7")
  local hb = b7 and b7:FindFirstChild("Hitbox")
  if hb and hb:IsA("BasePart") then
    walkTo(hb.Position + Vector3.new(0, 3, 0), 6)
  end
end

local function status(msg)
  if Cfg.StatusPrint then print("[SoloFarm] " .. tostring(msg)) end
end

-- Modul Terbang: hover rendah, step kecil biar lolos validasi (tes: +30Y cuma dapat +5Y kalau spam kasar).
-- Pakai RenderStepped 3-5 stud/frame + noclip + unanchor. Matikan saat mau hit (butuh stabil 6.5 stud).
local UIS = game:GetService("UserInputService")
local RunS = game:GetService("RunService")
local flyConn, noclipConn = nil, nil
local flyDir = {W = false, A = false, S = false, D = false, E = false, Q = false}

local function setNoclip(on)
  if on and not noclipConn then
    noclipConn = RunS.Stepped:Connect(function()
      if not Cfg.Fly then return end
      local ch = LP.Character
      if ch then
        for _, p in ipairs(ch:GetDescendants()) do
          if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
        end
      end
    end)
  elseif not on and noclipConn then
    pcall(function() noclipConn:Disconnect() end)
    noclipConn = nil
  end
end

local function setFly(on)
  Cfg.Fly = on
  setNoclip(on)
  local h = myHRP()
  if h then pcall(function() h.Anchored = false end) end
  if on and not flyConn then
    flyConn = RunS.RenderStepped:Connect(function(dt)
      if not Cfg.Fly then return end
      local hrp = myHRP()
      local hum = myHum()
      if not hrp or not hum then return end
      pcall(function() hrp.Anchored = false end)
      local cam = WS.CurrentCamera
      if not cam then return end
      -- arah dari kamera, step kecil: speed * dt, clamp 4 stud/frame
      local step = math.min(Cfg.FlySpeed * dt, 4)
      local cf = cam.CFrame
      local move = Vector3.new(0, 0, 0)
      if flyDir.W then move += cf.LookVector end
      if flyDir.S then move -= cf.LookVector end
      if flyDir.D then move += cf.RightVector end
      if flyDir.A then move -= cf.RightVector end
      if flyDir.E then move += Vector3.new(0, 1, 0) end
      if flyDir.Q then move -= Vector3.new(0, 1, 0) end
      if move.Magnitude > 0 then
        move = move.Unit * step
        -- pertahankan hover: counter gravity via velocity ringan
        pcall(function()
          hrp.CFrame = hrp.CFrame + move
          hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end)
      else
        -- diam: tahan posisi (anti jatuh), jangan tambah Y terus
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
      end
    end)
    status("Terbang ON (WASD+E/Q, speed " .. tostring(Cfg.FlySpeed) .. "). Matikan sebelum hit.")
  elseif not on and flyConn then
    pcall(function() flyConn:Disconnect() end)
    flyConn = nil
    status("Terbang OFF.")
  end
end

pcall(function()
  UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    local k = inp.KeyCode.Name
    if k == Cfg.FlyKey then
      setFly(not Cfg.Fly)
    end
    if flyDir[k] ~= nil then flyDir[k] = true end
  end)
  UIS.InputEnded:Connect(function(inp)
    local k = inp.KeyCode.Name
    if flyDir[k] ~= nil then flyDir[k] = false end
  end)
end)
-- API: _G.SoloFarm.SetFly(true/false)
Cfg.SetFly = setFly

-- Loop utama
task.spawn(function()
  task.wait(2)
  Cfg.Zone = bestZone()
  status("Damage " .. tostring(dmg()) .. " -> zona " .. tostring(Cfg.Zone) .. " (auto). Cash " .. tostring(LP:GetAttribute("Cash")))
  tryUpgrade()
  local hits = 0
  while Cfg.Enabled do
    local ok, err = pcall(function()
      unanchor()
      equipPickaxe()
      -- re-evaluasi zona tiap 30 hit (damage naik setelah upgrade)
      hits += 1
      if hits % 30 == 0 then
        local z = bestZone()
        if z ~= Cfg.Zone then
          Cfg.Zone = z
          status("Pindah zona " .. tostring(z) .. " (dmg " .. tostring(dmg()) .. ")")
        end
        tryUpgrade()
      end
      -- kalau lagi bawa hewan, bank dulu (satchel 1)
      if isCarrying() then
        bankRun()
        task.wait(1.2)
      else
        local egg, dist = nearestEgg(Cfg.Zone)
        if egg then
          local r = hitEgg(egg)
          if r == "walk" then
            task.wait(0.35)
          else
            task.wait(Cfg.HitCooldown)
          end
        else
          -- zona kosong / semua pecah, tunggu respawn 3 dtk
          task.wait(3)
        end
      end
    end)
    if not ok then
      warn("[SoloFarm] " .. tostring(err))
      task.wait(1)
    end
  end
end)

print("[SoloFarm] loaded. Toggle: _G.SoloFarm.Enabled = true/false, _G.SoloFarm.Zone = 1-9, _G.SoloFarm.SetFly(true/false) atau tombol F")
