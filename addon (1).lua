-- ==============================================================================
-- CANDY HUB — TRICK OR TREAT v5.9.0
-- fix: offset aumentado + Y raycast al suelo real para no spawear en el porche
-- ==============================================================================

local Players    = game:GetService("Players")
local CoreGui    = game:GetService("CoreGui")

local lp = Players.LocalPlayer

getgenv().CandyHubRunning = false

local visited      = {}
local totalVisited = 0

if CoreGui:FindFirstChild("CandyHubFarm5") then
    CoreGui.CandyHubFarm5:Destroy()
end

-- ── GUI ──────────────────────────────────────────────────────────────────────

local sg = Instance.new("ScreenGui")
sg.Name         = "CandyHubFarm5"
sg.ResetOnSpawn = false
sg.Parent       = CoreGui

local fr = Instance.new("Frame")
fr.Size             = UDim2.new(0,230,0,130)
fr.Position         = UDim2.new(0.05,0,0.4,0)
fr.BackgroundColor3 = Color3.fromRGB(20,20,20)
fr.BorderSizePixel  = 0
fr.Active           = true
fr.Draggable        = true
fr.Parent           = sg
Instance.new("UICorner",fr).CornerRadius = UDim.new(0,10)

local stk = Instance.new("UIStroke",fr)
stk.Color     = Color3.fromRGB(255,140,0)
stk.Thickness = 1

local titleL = Instance.new("TextLabel")
titleL.Size             = UDim2.new(1,0,0,30)
titleL.BackgroundColor3 = Color3.fromRGB(35,35,35)
titleL.TextColor3       = Color3.fromRGB(255,165,0)
titleL.TextSize         = 13
titleL.Font             = Enum.Font.SourceSansBold
titleL.Text             = "🎃 Candy Hub Farm v5.9.0"
titleL.Parent           = fr
Instance.new("UICorner",titleL).CornerRadius = UDim.new(0,10)

local statusL = Instance.new("TextLabel")
statusL.Size               = UDim2.new(1,-10,0,20)
statusL.Position           = UDim2.new(0,5,0,33)
statusL.BackgroundTransparency = 1
statusL.TextXAlignment     = Enum.TextXAlignment.Left
statusL.TextColor3         = Color3.fromRGB(180,180,180)
statusL.TextSize           = 11
statusL.Font               = Enum.Font.SourceSansItalic
statusL.Text               = "Estado: en espera..."
statusL.Parent             = fr

local infoL = Instance.new("TextLabel")
infoL.Size               = UDim2.new(1,-10,0,18)
infoL.Position           = UDim2.new(0,5,0,54)
infoL.BackgroundTransparency = 1
infoL.TextXAlignment     = Enum.TextXAlignment.Left
infoL.TextColor3         = Color3.fromRGB(120,220,120)
infoL.TextSize           = 11
infoL.Font               = Enum.Font.SourceSans
infoL.Text               = "Visitadas: 0"
infoL.Parent             = fr

local btn = Instance.new("TextButton")
btn.Size             = UDim2.new(0.88,0,0,32)
btn.Position         = UDim2.new(0.06,0,0,88)
btn.BackgroundColor3 = Color3.fromRGB(190,0,0)
btn.TextColor3       = Color3.new(1,1,1)
btn.TextSize         = 13
btn.Font             = Enum.Font.SourceSansBold
btn.Text             = "Auto-Farm: OFF"
btn.Parent           = fr
Instance.new("UICorner",btn).CornerRadius = UDim.new(0,7)

local function setS(s) pcall(function() statusL.Text = "Estado: "..s end) end
local function setI(s) pcall(function() infoL.Text   = s end) end

-- ── PERSONAJE ────────────────────────────────────────────────────────────────

local function getChar()
    local c = lp.Character
    if not c then return nil end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChildOfClass("Humanoid")
    if not r or not h or h.Health <= 0 then return nil end
    return c, h, r
end

-- ── HELPERS ──────────────────────────────────────────────────────────────────

local function dXZ(a, b)
    return math.sqrt((a.X-b.X)^2 + (a.Z-b.Z)^2)
end

local function isLightOn(houseNum)
    local hf = workspace:FindFirstChild("TrickOrTreatDecor")
    if not hf then return false end
    local houses = hf:FindFirstChild("Houses")
    if not houses then return false end
    local folder = houses:FindFirstChild(tostring(houseNum))
    if not folder then return false end
    for _, d in ipairs(folder:GetDescendants()) do
        if (d:IsA("PointLight") or d:IsA("SurfaceLight") or d:IsA("SpotLight"))
            and d.Enabled then
            return true
        end
    end
    return false
end

-- ── Y REAL DEL SUELO via Raycast ─────────────────────────────────────────────
-- tira un ray desde arriba hacia abajo en la posicion XZ objetivo
-- devuelve el Y del suelo real para no flotar ni enterrarse

local function getGroundY(xzPos, refY)
    local origin = Vector3.new(xzPos.X, refY + 20, xzPos.Z)
    local dir    = Vector3.new(0, -50, 0)

    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    -- excluir el personaje del ray
    local char = lp.Character
    if char then rp.FilterDescendantsInstances = {char} end

    local result = workspace:Raycast(origin, dir, rp)
    if result then
        return result.Position.Y + 3  -- +3 = mitad del humanoid encima del suelo
    end
    return refY  -- fallback: Y del prompt si el ray no pega nada
end

-- ── SCAN ─────────────────────────────────────────────────────────────────────

local function scanTodasLasCasas()
    local hf = workspace:FindFirstChild("TrickOrTreatDecor")
    if not hf then return {} end
    local housesFolder = hf:FindFirstChild("Houses")
    if not housesFolder then return {} end
    local ms = workspace:FindFirstChild("TrickOrTreatMapState")
    if not ms then return {} end

    local prompts = {}
    for _, child in ipairs(ms:GetChildren()) do
        local p = child:FindFirstChildOfClass("ProximityPrompt")
        if p and child:IsA("BasePart") then
            table.insert(prompts, { Part = child, Prompt = p })
        end
    end

    local result = {}

    for _, folder in ipairs(housesFolder:GetChildren()) do
        local num = tonumber(folder.Name)
        if not num then continue end

        local lightPart = nil
        for _, d in ipairs(folder:GetDescendants()) do
            if (d:IsA("PointLight") or d:IsA("SurfaceLight") or d:IsA("SpotLight"))
                and d.Parent:IsA("BasePart") then
                lightPart = d.Parent
                break
            end
        end
        if not lightPart then continue end

        local best, bestD = nil, 999999
        for _, pd in ipairs(prompts) do
            local d = dXZ(lightPart.Position, pd.Part.Position)
            if d < bestD then bestD = d; best = pd end
        end
        if not best or bestD > 50 then continue end

        table.insert(result, {
            Num        = num,
            Prompt     = best.Prompt,
            PromptPart = best.Part,
            LightPart  = lightPart,
        })
    end

    return result
end

-- ── DIRECCIÓN REAL hacia la calle ────────────────────────────────────────────
-- lightPart (dentro/arriba de la casa) → promptPart (puerta)
-- extender más allá = calle

local function getOutDir(house)
    local a  = house.LightPart.Position
    local b  = house.PromptPart.Position
    local dx = b.X - a.X
    local dz = b.Z - a.Z
    local len = math.sqrt(dx*dx + dz*dz)
    if len < 0.01 then return Vector3.new(0,0,1) end
    return Vector3.new(dx/len, 0, dz/len)
end

-- ── TELEPORT ESCALERAS ───────────────────────────────────────────────────────
--
-- STEP_OFFSET 10: suficiente para quedar al pie de escaleras, no en el porche
-- MaxActivationDistance del prompt suele ser 10-12 studs, a 10 entramos justo
-- Y: raycast al suelo real — no usamos pPos.Y que es el Y del porche elevado

local STEP_OFFSET = 10  -- studs desde el prompt hacia la calle

local function teleportToStairs(house)
    local _, _, root = getChar()
    if not root then return false end

    local dir  = getOutDir(house)
    local pPos = house.PromptPart.Position

    -- posicion XZ al pie de escaleras
    local targetX = pPos.X + dir.X * STEP_OFFSET
    local targetZ = pPos.Z + dir.Z * STEP_OFFSET

    -- Y real del suelo en esa posición, no el Y del prompt
    local groundY = getGroundY(Vector3.new(targetX, 0, targetZ), pPos.Y)

    local pos  = Vector3.new(targetX, groundY, targetZ)
    local look = Vector3.new(pPos.X,  groundY, pPos.Z)

    local ok = pcall(function()
        root.CFrame = CFrame.lookAt(pos, look)
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    -- esperar que el servidor vea la posición
    task.wait(0.8)
    return ok
end

-- ── FIRE PROMPT ──────────────────────────────────────────────────────────────

local function firePrompt(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then
        return false, "disabled_before"
    end

    local enabledBefore = prompt.Enabled
    local fired = false

    if typeof(fireproximityprompt) == "function" then
        fired = pcall(fireproximityprompt, prompt)
    else
        fired = pcall(function() prompt:FireServer() end)
    end

    task.wait(0.35)
    if enabledBefore and not prompt.Enabled then
        return true, "confirmed"
    end

    task.wait(0.65)
    if enabledBefore and not prompt.Enabled then
        return true, "confirmed_delayed"
    end

    if fired then return true, "fired_unknown" end
    return false, "fire_failed"
end

-- ── WAIT AND SCAN ────────────────────────────────────────────────────────────

local function waitAndScan(seconds)
    local finish = os.clock() + seconds
    while getgenv().CandyHubRunning and os.clock() < finish do
        local hs = scanTodasLasCasas()
        local lit = 0
        for _, h in ipairs(hs) do
            if isLightOn(h.Num) then lit += 1 end
        end
        setI(("Visitadas: %d | Lit: %d | Casas: %d"):format(totalVisited, lit, #hs))
        setS(("🍬 cooldown %ds..."):format(math.ceil(finish - os.clock())))
        task.wait(0.25)
    end
end

-- ── FARM ─────────────────────────────────────────────────────────────────────

local function farm()
    while getgenv().CandyHubRunning do

        local houses = scanTodasLasCasas()

        if #houses == 0 then
            setS("casas no encontradas")
            task.wait(1)
            continue
        end

        local lit = 0
        for _, h in ipairs(houses) do
            if isLightOn(h.Num) then lit += 1 end
        end
        setI(("Visitadas: %d | Lit: %d | Casas: %d"):format(totalVisited, lit, #houses))

        local _, _, root = getChar()
        if not root then task.wait(0.5) continue end

        -- casa más cercana no visitada
        local house, minD = nil, math.huge
        for _, h in ipairs(houses) do
            if not visited[h.Num] then
                local d = dXZ(root.Position, h.PromptPart.Position)
                if d < minD then minD = d; house = h end
            end
        end

        if not house then
            visited = {}
            setS("ciclo completo — reiniciando")
            task.wait(0.5)
            continue
        end

        if not isLightOn(house.Num) then
            setS(("🌑 #%d sin luz"):format(house.Num))
            visited[house.Num] = true
            task.wait(0.05)
            continue
        end

        setS(("→ #%d (%.0fst)"):format(house.Num, minD))

        if not teleportToStairs(house) then
            task.wait(0.2)
            continue
        end

        if not getgenv().CandyHubRunning then break end

        if not isLightOn(house.Num) then
            setS(("🌑 #%d luz off al llegar"):format(house.Num))
            visited[house.Num] = true
            task.wait(0.05)
            continue
        end

        setS(("🔔 #%d"):format(house.Num))
        local fired, reason = firePrompt(house.Prompt)

        print(("[CandyHub v5.9.0] #%d fired=%s reason=%s"):format(
            house.Num, tostring(fired), reason
        ))

        visited[house.Num] = true

        if fired then
            totalVisited += 1
            local tag = (reason == "confirmed" or reason == "confirmed_delayed") and "✅" or "🟡"
            setS(("%s #%d ok"):format(tag, house.Num))
            waitAndScan(10)
        else
            setS((reason == "disabled_before")
                and ("⏭ #%d ya off"):format(house.Num)
                or  ("❌ #%d %s"):format(house.Num, reason))
            task.wait(0.1)
        end
    end

    setS("apagado")
end

-- ── TOGGLE ───────────────────────────────────────────────────────────────────

btn.MouseButton1Click:Connect(function()
    getgenv().CandyHubRunning = not getgenv().CandyHubRunning

    if getgenv().CandyHubRunning then
        btn.Text             = "Auto-Farm: ON"
        btn.BackgroundColor3 = Color3.fromRGB(0,195,80)
        visited      = {}
        totalVisited = 0
        setS("iniciando...")

        task.spawn(function()
            local ok, err = pcall(farm)
            if not ok then
                getgenv().CandyHubRunning = false
                btn.Text             = "Auto-Farm: OFF"
                btn.BackgroundColor3 = Color3.fromRGB(190,0,0)
                setS("error: "..tostring(err))
                warn("[CandyHub v5.9.0] "..tostring(err))
            end
        end)
    else
        btn.Text             = "Auto-Farm: OFF"
        btn.BackgroundColor3 = Color3.fromRGB(190,0,0)
        setS("apagado")
    end
end)

lp.CharacterAdded:Connect(function()
    visited = {}
end)

print("[Candy Hub Farm v5.9.0] Loaded")