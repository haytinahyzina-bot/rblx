-- GaliTelur_Hub.lua v1.1 (Gali Telur 121831322352666) - read-mostly + movement + prompt
-- Filosofi: ESP + teleport + prompt, TANPA spoof remote / tanpa ubah stat.
-- Auto-gali via remote BELUM retak (35+ kombinasi args diuji live, semua di-ignore
-- server; executor tanpa UNC sehingga hook/spy mustahil) -> pakai Dig-Assist:
-- script membidik (karakter + kamera), kamu TAHAN klik (HoldToDig asli game).
-- Pakai: select semua -> execute di Solara.
local Players = game:GetService("Players")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer

local Cfg = {
  ESP_Egg = true, ESP_Block = true, MaxDist = 400,
  Assist = false,          -- teleport + aim ke blok terdekat (kamu tahan klik)
  AutoSellPrompt = false,  -- fire prompt jual/beli yg dalam jangkauan
  Speed = 32, SpeedLock = false,
  AntiAFK = true,
}
_G.GTHub = _G.GTHub or Cfg
Cfg = _G.GTHub

-- GUI
pcall(function() game.CoreGui:FindFirstChild("GT_HUB"):Destroy() end)
local gui = Instance.new("ScreenGui")
gui.Name = "GT_HUB"
gui.ResetOnSpawn = false
pcall(function() gui.Parent = game.CoreGui end)
if not gui.Parent then gui.Parent = LP.PlayerGui end
local fr = Instance.new("Frame", gui)
fr.Size = UDim2.new(0, 230, 0, 330)
fr.Position = UDim2.new(0, 20, 0, 120)
fr.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
fr.Active = true fr.Draggable = true
Instance.new("UICorner", fr)
local function mkBtn(txt, y, cb)
  local b = Instance.new("TextButton", fr)
  b.Size = UDim2.new(1, -16, 0, 28) b.Position = UDim2.new(0, 8, 0, y)
  b.Text = txt b.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
  b.TextColor3 = Color3.new(1,1,1) b.Font = Enum.Font.SourceSansBold b.TextSize = 14
  Instance.new("UICorner", b)
  b.MouseButton1Click:Connect(function() cb(b) end)
  return b
end
local function tag(b, on) b.Text = b.Text:gsub(" : .*", "") .. (on and " : ON" or " : OFF") end

local function hrp()
  local ch = LP.Character
  return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end
local function go(pos)
  local h = hrp() if not h then return end
  h.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
  h.Velocity = Vector3.new() h.RotVelocity = Vector3.new()
end

-- Cari blok diggable terdekat
local function bestBlock()
  local h = hrp() if not h then return nil, 1e9 end
  local cm = WS:FindFirstChild("RuntimeMap") and WS.RuntimeMap:FindFirstChild("CommunalMine")
  if not cm then return nil, 1e9 end
  local best, bd = nil, 1e9
  for _, c in ipairs(cm:GetChildren()) do
    if c:IsA("Part") and c:GetAttribute("Diggable") then
      local d = (c.Position - h.Position).Magnitude
      if d < bd then bd, best = d, c end
    end
  end
  return best, bd
end

-- ESP telur liar + planted + blok CommunalMine
local function clearESP(root, tagName)
  for _, d in ipairs(root:GetDescendants()) do
    if d:IsA("BillboardGui") and d.Name == tagName then d:Destroy() end
  end
end
local function mkBB(part, name, text, color)
  local g = part:FindFirstChild(name)
  if not g then
    g = Instance.new("BillboardGui")
    g.Name = name g.Size = UDim2.new(0, 200, 0, 40)
    g.AlwaysOnTop = true g.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    local t = Instance.new("TextLabel", g)
    t.Name = "T" t.Size = UDim2.new(1, 0, 1, 0) t.BackgroundTransparency = 1
    t.TextScaled = true t.Font = Enum.Font.SourceSansBold
    t.TextStrokeTransparency = 0.3
    g.Parent = part
  end
  local t = g:FindFirstChild("T")
  if t then t.Text = text t.TextColor3 = color end
  return g
end

task.spawn(function()
  while true do
    pcall(function()
      local h = hrp()
      -- Telur liar top-level (Relic/Honey/Crystal/Prism/Amber...)
      if Cfg.ESP_Egg then
        for _, m in ipairs(WS:GetChildren()) do
          if m:IsA("Model") and m.Name:find("Egg") and m.Name ~= "EggEventAnchors" then
            local ok, cf = pcall(function() return m:GetPivot() end)
            if ok then
              local d = h and math.floor((cf.Position - h.Position).Magnitude) or -1
              if d < 0 or d <= Cfg.MaxDist then
                local anchor = m:FindFirstChildWhichIsA("BasePart", true) or m:FindFirstChild("Shell", true)
                if anchor and anchor:IsA("BasePart") then
                  mkBB(anchor, "GT_EGG", m.Name .. "\n" .. tostring(d) .. "m", Color3.fromRGB(255, 210, 80))
                end
              end
            end
          end
        end
        -- Planted eggs
        local pe = WS:FindFirstChild("RuntimeEggs") and WS.RuntimeEggs:FindFirstChild("Planted")
        if pe then
          for _, e in ipairs(pe:GetChildren()) do
            local st = e:GetAttribute("HatchState") or "?"
            local et = e:GetAttribute("EggType") or e.Name
            local ok, cf = pcall(function() return e:GetPivot() end)
            if ok then
              local d = h and math.floor((cf.Position - h.Position).Magnitude) or -1
              local anchor = e:FindFirstChild("Shell", true)
              if anchor and anchor:IsA("BasePart") then
                local col = (st == "Ready" or st == "Hatched") and Color3.fromRGB(80,255,120) or Color3.fromRGB(120,200,255)
                mkBB(anchor, "GT_EGG", et .. " [" .. tostring(st) .. "]\n" .. tostring(d) .. "m", col)
              end
            end
          end
        end
      end
      -- Blok tambang umum (cull jauh biar ringan)
      if Cfg.ESP_Block then
        local cm = WS:FindFirstChild("RuntimeMap") and WS.RuntimeMap:FindFirstChild("CommunalMine")
        if cm and h then
          local n = 0
          for _, c in ipairs(cm:GetChildren()) do
            if c:IsA("Part") and c:GetAttribute("Diggable") then
              local d = (c.Position - h.Position).Magnitude
              if d <= 120 then
                n += 1
                if n <= 60 then
                  mkBB(c, "GT_BLK", tostring(c:GetAttribute("MaterialName") or "Block")
                    .. " " .. tostring(c:GetAttribute("Health")) .. "/" .. tostring(c:GetAttribute("MaxHealth"))
                    .. " | " .. tostring(math.floor(d)) .. "m", Color3.fromRGB(255, 170, 60))
                end
              else
                local g = c:FindFirstChild("GT_BLK") if g then g:Destroy() end
              end
            end
          end
        end
      end
    end)
    task.wait(2)
  end
end)

-- Dig-Assist: hadapkan karakter + bidik kamera ke blok terdekat.
-- Kamu TAHAN klik (HoldToDig asli game). Script yg membidik, kamu yg menggali.
task.spawn(function()
  while true do
    pcall(function()
      if Cfg.Assist then
        local b, d = bestBlock()
        if b then
          local h = hrp()
          if h and d > 13 then
            go(b.Position)
          elseif h then
            h.CFrame = CFrame.lookAt(h.Position, b.Position)
            local cam = WS.CurrentCamera
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, b.Position)
          end
        end
      end
    end)
    task.wait(0.3)
  end
end)

-- Auto prompt (jual/beli/event) dalam 14 stud
task.spawn(function()
  while true do
    pcall(function()
      if Cfg.AutoSellPrompt then
        local h = hrp()
        if h then
          for _, d in ipairs(WS:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
              local m = d:FindFirstAncestorOfClass("Model")
              local pp = m and m:GetPivot() or nil
              local bp = d.Parent and d.Parent:IsA("BasePart") and d.Parent or nil
              local pos = bp and bp.Position or (pp and pp.Position)
              if pos and (pos - h.Position).Magnitude <= 14 then
                fireproximityprompt(d)
              end
            end
          end
        end
      end
    end)
    task.wait(1)
  end
end)

-- Speed lock + anti AFK
task.spawn(function()
  while true do
    pcall(function()
      local ch = LP.Character
      local hum = ch and ch:FindFirstChildOfClass("Humanoid")
      if hum and Cfg.SpeedLock and hum.WalkSpeed ~= Cfg.Speed then hum.WalkSpeed = Cfg.Speed end
    end)
    task.wait(0.5)
  end
end)
if Cfg.AntiAFK then
  pcall(function()
    LP.Idled:Connect(function()
      pcall(function() VIM:CaptureController() VIM:ClickButton2(Vector2.new()) end)
    end)
  end)
end

-- Tombol
local y = 8
mkBtn("ESP Telur : ON", y, function(b) Cfg.ESP_Egg = not Cfg.ESP_Egg tag(b, Cfg.ESP_Egg)
  if not Cfg.ESP_Egg then pcall(function() clearESP(WS, "GT_EGG") end) end end) y += 32
mkBtn("ESP Blok : ON", y, function(b) Cfg.ESP_Block = not Cfg.ESP_Block tag(b, Cfg.ESP_Block) end) y += 32
mkBtn("Dig-Assist : OFF", y, function(b) Cfg.Assist = not Cfg.Assist tag(b, Cfg.Assist) end) y += 32
mkBtn("Auto-Prompt : OFF", y, function(b) Cfg.AutoSellPrompt = not Cfg.AutoSellPrompt tag(b, Cfg.AutoSellPrompt) end) y += 32
mkBtn("SpeedLock(32) : OFF", y, function(b) Cfg.SpeedLock = not Cfg.SpeedLock tag(b, Cfg.SpeedLock) end) y += 32
mkBtn("TP Tambang", y, function() go(Vector3.new(-12, 8, 20)) end) y += 32
mkBtn("TP Plot saya", y, function()
  local idx = LP:GetAttribute("AssignedPlotIndex") or 7
  local p = WS.RuntimeMap.Plots:FindFirstChild("Plot" .. string.format("%02d", idx))
  if p then go(p:GetPivot().Position) end
end) y += 32
mkBtn("TP Jual (SellLoot)", y, function()
  local m = WS.RuntimeMap.Markets:FindFirstChild("SellLoot")
  if m then go(m:GetPivot().Position) end
end) y += 32
mkBtn("TP Sekop (Shovels)", y, function()
  local m = WS.RuntimeMap.Markets:FindFirstChild("Shovels")
  if m then go(m:GetPivot().Position) end
end) y += 32
print("[GT_HUB v1] jalan. Dig-Assist ON lalu TAHAN klik di blok.")
