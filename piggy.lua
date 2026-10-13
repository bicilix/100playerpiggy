--[[
═══════════════════════════════════════════════════
    100 player piggy key getter idk
    built by bicilix
═══════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local isCollecting = false
local currentEntries = {}

local hasTouch = (firetouchinterest ~= nil)
local hasTouch2 = (firetouchtouch ~= nil)
local hasPrompt = (fireproximityprompt ~= nil)
local hasClick = (fireclickdetector ~= nil)

--// HELPERS
local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getItemCFrame(item)
    if item:IsA("BasePart") then return item.CFrame end
    if item:IsA("Model") then
        local part = item:FindFirstChildWhichIsA("BasePart", true)
        if part then return part.CFrame end
        if item.PrimaryPart then return item.PrimaryPart.CFrame end
        local ok, cf = pcall(function() return item:GetBoundingBox() end)
        if ok then return cf end
    end
    return nil
end

local function getDistance(item)
    local hrp = getHRP()
    if not hrp then return 0 end
    local cf = getItemCFrame(item)
    if not cf then return 0 end
    return (hrp.Position - cf.Position).Magnitude
end

--// SCAN ItemFolder
local function scanItems()
    local found = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return found end
    local folder = map:FindFirstChild("ItemFolder")
    if not folder then return found end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") or child:IsA("Model") then
            found[child.Name] = child
        end
    end
    return found
end

--// BRUTE FORCE COLLECT — continuous overlap + rapid touch firing
local function bruteCollect(item)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local charParts = {}
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") then
            table.insert(charParts, desc)
        end
    end

    local itemParts = {}
    if item:IsA("BasePart") then
        table.insert(itemParts, item)
    end
    for _, desc in ipairs(item:GetDescendants()) do
        if desc:IsA("BasePart") then
            table.insert(itemParts, desc)
        end
    end

    local targetCFrame = getItemCFrame(item)
    if not targetCFrame then return false end

    if hasPrompt then
        for _, desc in ipairs(item:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                pcall(fireproximityprompt, desc, 0)
            end
        end
    end

    if hasClick then
        for _, desc in ipairs(item:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                pcall(fireclickdetector, desc, targetCFrame.Position)
            end
        end
    end

    local elapsed = 0
    while elapsed < 0.3 do
        hrp.CFrame = targetCFrame

        for _, cp in ipairs(charParts) do
            for _, ip in ipairs(itemParts) do
                if hasTouch then
                    pcall(firetouchinterest, cp, ip, 0)
                    pcall(firetouchinterest, cp, ip, 1)
                elseif hasTouch2 then
                    pcall(firetouchtouch, cp, ip)
                end
            end
        end

        if hasTouch then
            for _, ip in ipairs(itemParts) do
                pcall(firetouchinterest, hrp, ip, 0)
                pcall(firetouchinterest, hrp, ip, 1)
            end
        end

        task.wait(0.03)
        elapsed = elapsed + 0.03
    end

    return true
end

--// TP → BRUTE COLLECT → RETURN
local function teleportAndCollect(item)
    local hrp = getHRP()
    if not hrp then return end
    if isCollecting then return end
    isCollecting = true

    local originalCFrame = hrp.CFrame
    local targetCFrame = getItemCFrame(item)

    if not targetCFrame then
        isCollecting = false
        return
    end

    hrp.CFrame = targetCFrame
    task.wait(0.05)

    bruteCollect(item)

    task.wait(0.05)

    local currentHRP = getHRP()
    if currentHRP then
        currentHRP.CFrame = originalCFrame
    end

    isCollecting = false
end

--// VIEWPORT SETUP
local function setupViewport(vpFrame, itemModel)
    local renderObj
    local ok = pcall(function()
        if itemModel:IsA("Model") then
            renderObj = itemModel:Clone()
        elseif itemModel:IsA("BasePart") then
            renderObj = itemModel:Clone()
        end
    end)
    if not renderObj then return end

    for _, child in ipairs(renderObj:GetDescendants()) do
        if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("Sound") then
            child:Destroy()
        end
    end

    renderObj.Parent = vpFrame

    local size, cf
    if renderObj:IsA("Model") then
        pcall(function()
            size, cf = renderObj:GetBoundingBox()
        end)
        if not cf then
            local part = renderObj:FindFirstChildWhichIsA("BasePart", true)
            if part then
                cf = part.CFrame
                size = part.Size
            end
        end
    else
        cf = renderObj.CFrame
        size = renderObj.Size
    end

    if not cf or not size then return end

    local maxDim = math.max(size.X, size.Y, size.Z, 1)
    local camDist = maxDim * 2.5
    local lookAtPos = cf.Position
    local camPos = lookAtPos + Vector3.new(camDist, camDist * 0.6, camDist)

    local cam = Instance.new("Camera")
    cam.CFrame = CFrame.new(camPos, lookAtPos)
    vpFrame.CurrentCamera = cam
    cam.Parent = vpFrame

    local angle = 0
    local rotationConnection
    rotationConnection = RunService.RenderStepped:Connect(function()
        if not vpFrame.Parent or not vpFrame.Parent.Parent then
            rotationConnection:Disconnect()
            return
        end
        angle = angle + 0.5
        local rotCF = CFrame.new(lookAtPos) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, camDist)
        cam.CFrame = CFrame.new(rotCF.Position, lookAtPos)
    end)

    return rotationConnection
end

--// ═══════════════ GUI ═══════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PiggyKeyTracker"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 290, 0, 440)
mainFrame.Position = UDim2.new(0, 20, 0.5, -220)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleBottom = Instance.new("Frame")
titleBottom.Size = UDim2.new(1, 0, 0, 10)
titleBottom.Position = UDim2.new(0, 0, 1, -10)
titleBottom.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
titleBottom.BorderSizePixel = 0
titleBottom.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "PIGGY KEY TRACKER"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0.5, -15)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 22)
statusLabel.Position = UDim2.new(0, 10, 0, 50)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Scanning for items..."
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local sep = Instance.new("Frame")
sep.Size = UDim2.new(1, -20, 0, 1)
sep.Position = UDim2.new(0, 10, 0, 75)
sep.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
sep.BorderSizePixel = 0
sep.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -85)
scrollFrame.Position = UDim2.new(0, 10, 0, 82)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

--// GUI UPDATE
local function updateGUI(items)
    for name, entry in pairs(currentEntries) do
        if not items[name] then
            if entry.rotConn then
                entry.rotConn:Disconnect()
            end
            if entry.button and entry.button.Parent then
                entry.button:Destroy()
            end
            currentEntries[name] = nil
        end
    end

    local order = 0
    for name, item in pairs(items) do
        if not currentEntries[name] then
            local btn = Instance.new("TextButton")
            btn.Name = name
            btn.Size = UDim2.new(1, 0, 0, 56)
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.LayoutOrder = order
            btn.Parent = scrollFrame

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = btn

            local hoverFrame = Instance.new("Frame")
            hoverFrame.Size = UDim2.new(1, 0, 1, 0)
            hoverFrame.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
            hoverFrame.BackgroundTransparency = 1
            hoverFrame.BorderSizePixel = 0
            hoverFrame.ZIndex = 1
            hoverFrame.Parent = btn

            local hoverCorner = Instance.new("UICorner")
            hoverCorner.CornerRadius = UDim.new(0, 6)
            hoverCorner.Parent = hoverFrame

            btn.MouseEnter:Connect(function()
                hoverFrame.BackgroundTransparency = 0.7
            end)
            btn.MouseLeave:Connect(function()
                hoverFrame.BackgroundTransparency = 1
            end)

            local vp = Instance.new("ViewportFrame")
            vp.Size = UDim2.new(0, 44, 0, 44)
            vp.Position = UDim2.new(0, 6, 0.5, -22)
            vp.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            vp.BorderSizePixel = 0
            vp.ZIndex = 3
            vp.Parent = btn

            local vpCorner = Instance.new("UICorner")
            vpCorner.CornerRadius = UDim.new(0, 6)
            vpCorner.Parent = vp

            local rotConn = setupViewport(vp, item)

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -60, 0, 20)
            nameLabel.Position = UDim2.new(0, 58, 0, 8)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = name
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextSize = 13
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.ZIndex = 3
            nameLabel.Parent = btn

            local distLabel = Instance.new("TextLabel")
            distLabel.Size = UDim2.new(1, -60, 0, 14)
            distLabel.Position = UDim2.new(0, 58, 0, 30)
            distLabel.BackgroundTransparency = 1
            distLabel.Text = "--- studs"
            distLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
            distLabel.Font = Enum.Font.Gotham
            distLabel.TextSize = 10
            distLabel.TextXAlignment = Enum.TextXAlignment.Left
            distLabel.ZIndex = 3
            distLabel.Parent = btn

            local arrow = Instance.new("TextLabel")
            arrow.Size = UDim2.new(0, 20, 0, 20)
            arrow.Position = UDim2.new(1, -28, 0.5, -10)
            arrow.BackgroundTransparency = 1
            arrow.Text = ">"
            arrow.TextColor3 = Color3.fromRGB(100, 100, 120)
            arrow.Font = Enum.Font.GothamBold
            arrow.TextSize = 18
            arrow.ZIndex = 3
            arrow.Parent = btn

            btn.MouseButton1Click:Connect(function()
                if isCollecting then return end
                local currentScan = scanItems()
                local currentItem = currentScan[name]
                if not currentItem then return end

                nameLabel.Text = name .. " — GRABBING..."
                nameLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                arrow.TextColor3 = Color3.fromRGB(100, 255, 100)

                teleportAndCollect(currentItem)

                task.wait(0.2)
                nameLabel.Text = name
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                arrow.TextColor3 = Color3.fromRGB(100, 100, 120)
            end)

            currentEntries[name] = {
                button = btn,
                nameLabel = nameLabel,
                distLabel = distLabel,
                rotConn = rotConn,
            }
        end

        local entry = currentEntries[name]
        if entry then
            local dist = getDistance(item)
            entry.distLabel.Text = string.format("%.0f studs", dist)
            entry.button.LayoutOrder = order
        end
        order = order + 1
    end
end

--// MAIN LOOP
task.spawn(function()
    while true do
        local hrp = getHRP()
        if hrp then
            local items = scanItems()
            local count = 0
            for _ in pairs(items) do count = count + 1 end

            if count > 0 then
                statusLabel.Text = string.format("%d item(s) found — click to collect", count)
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                statusLabel.Text = "No items spawned"
                statusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
            end

            updateGUI(items)
        end
        task.wait(0.5)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
end)

print("[K]vk Piggy Key Tracker loaded.")
print(string.format("Touch: %s | Prompt: %s | Click: %s",
    tostring(hasTouch or hasTouch2),
    tostring(hasPrompt),
    tostring(hasClick)))