-- CurrentVector-Dances V1
print("[CurrentVector-Dances V1] Loading...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local InsertService = game:GetService("InsertService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local RESET_GUI_NAME = "refreshtestyescurrent"
local FORCE_REFRESH = true
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local shared = (getgenv and getgenv()) or _G

if shared.CurrentVectorCleanup then
    pcall(shared.CurrentVectorCleanup)
    shared.CurrentVectorCleanup = nil
end

local existingResetGui = CoreGui:FindFirstChild(RESET_GUI_NAME)
if existingResetGui then existingResetGui:Destroy() end

local existingBlur = Lighting:FindFirstChild("CVWheelBlur")
if existingBlur then existingBlur:Destroy() end

pcall(function()
    if isfolder and not isfolder("CurrentVector") then makefolder("CurrentVector") end
    if isfolder and not isfolder("CurrentVector/Animations") then makefolder("CurrentVector/Animations") end
    if isfolder and not isfolder("CurrentVector/Music") then makefolder("CurrentVector/Music") end
end)
print("Ready!")

local primaryBase = "https://raw.githubusercontent.com/nonmex9-design/CurrentVector-Reanimate/refs/heads/main/CurrentVector/Animations/"
local fallbackBase = "https://github.com/nonmex9-design/CurrentVector-Reanimate/raw/refs/heads/main/CurrentVector/Animations/"
local animList = {
    "Backflip", "Bang2", "Bang3", "Banged1", "BreakDance", "Floss", "Fresh", "Groovv",
    "Helicopter", "Kazotsky Kick (Spy)", "Parrot", "RickRoll", "Twerk",
    "Idle", "Walk", "Run", "WalkV2", "RunV2", "Jump", "Fall", "Land", "Poop",
    "Sit2", "Sitting", "PP", "Wave3",
}

local function isValidRbxm(data)
    if not data or #data < 20 then return false end
    if string.sub(data, 1, 1) == "<" then return true end
    return false
end

local function tryHttpGet(url)
    local ok, data = pcall(function() return game:HttpGet(url) end)
    if ok and data then return data end
    return nil
end

local function downloadAnim(name)
    local path = "CurrentVector/Animations/" .. name .. ".rbxm"
    local encoded = name:gsub(" ", "%%20")
    local data = tryHttpGet(primaryBase .. encoded .. ".rbxm")
    if not data or not isValidRbxm(data) then
        data = tryHttpGet(fallbackBase .. encoded .. ".rbxm")
    end
    if not data or not isValidRbxm(data) then
        warn("[CurrentVector-Dances V1] " .. name .. " failed")
        return
    end
    pcall(function() writefile(path, data) end)
end

for _, name in ipairs(animList) do
    local path = "CurrentVector/Animations/" .. name .. ".rbxm"
    if FORCE_REFRESH or not isfile(path) then downloadAnim(name) end
end

local favPath = "CurrentVector/favorites.json"
local favorites = {}
if isfile(favPath) then
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(favPath)) end)
    if ok and type(data) == "table" then favorites = data end
end

local function saveFavorites()
    pcall(function() writefile(favPath, HttpService:JSONEncode(favorites)) end)
end

local function isFavorite(name)
    for _, v in ipairs(favorites) do
        if v == name then return true end
    end
    return false
end

local function toggleFavorite(name)
    for i, v in ipairs(favorites) do
        if v == name then
            table.remove(favorites, i)
            saveFavorites()
            return false
        end
    end
    table.insert(favorites, name)
    saveFavorites()
    return true
end

local function notify(text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "CurrentVector-Dances V1",
            Text = text,
            Duration = dur or 3,
        })
    end)
end

local function customasset(id)
    if not isfile or not getcustomasset then return "rbxassetid://1837879082" end
    local path = "CurrentVector/Music/" .. id
    if not isfile(path) then
        local ok = pcall(function()
            writefile(path, game:HttpGet("https://raw.githubusercontent.com/nonmex9-design/CurrentVector-Reanimate/refs/heads/main/CurrentVector/Music/" .. id))
        end)
        if not ok then return "rbxassetid://1837879082" end
    end
    local ok, asset = pcall(getcustomasset, path)
    if ok and asset then return asset end
    return "rbxassetid://1837879082"
end

local LAST_POSE = {}
local EXTRA_TILT = {}

local function makeanimlibrary()
    local __EasingStyles__ = Enum.EasingStyle
    local __EasingDirections__ = Enum.EasingDirection
    local __Enum__PoseEasingStyle__ = #'Enum.PoseEasingStyle.'
    local __Enum__PoseEasingDirection__ = #'Enum.PoseEasingDirection.'

    local function EasingStyleFix(style)
        local name = string.sub(tostring(style), __Enum__PoseEasingStyle__ + 1)
        local suc, res = pcall(function() return __EasingStyles__[name] end)
        if suc then return res end
        return Enum.EasingStyle.Linear
    end

    local function EasingDirectionFix(dir)
        local name = string.sub(tostring(dir), __Enum__PoseEasingDirection__ + 1)
        return __EasingDirections__[name] or Enum.EasingDirection.In
    end

    local function ConvertToTable(animationInstance)
        assert(animationInstance and typeof(animationInstance) == 'Instance' and animationInstance:IsA('KeyframeSequence'))
        local keyframes = animationInstance:GetKeyframes()
        local sequence = {}
        for i, frame in ipairs(keyframes) do
            local entry = { Time = frame.Time, Data = {} }
            for _, child in ipairs(frame:GetDescendants()) do
                if child:IsA('Pose') and child.Weight > 0 then
                    entry.Data[child.Name] = {
                        CFrame = child.CFrame,
                        EasingStyle = EasingStyleFix(child.EasingStyle),
                        EasingDirection = EasingDirectionFix(child.EasingDirection),
                        Weight = child.Weight,
                    }
                end
            end
            sequence[i] = entry
        end
        table.sort(sequence, function(a, b) return a.Time < b.Time end)
        return sequence, animationInstance.Loop
    end

    local function AutoGetMotor6D(model)
        local motors = {}
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA('BasePart') then
                for _, joint in ipairs(part:GetJoints()) do
                    if joint:IsA('Motor6D') and joint.Part1 == part then
                        motors[part.Name] = joint
                        break
                    end
                end
            end
        end
        return motors
    end

    local UpdateEvent = RunService.RenderStepped

    local AnimLibrary = {}
    AnimLibrary.__index = AnimLibrary

    function AnimLibrary.new(target, keyframeSeq)
        local self = setmetatable({}, AnimLibrary)
        self.Looped = false
        self.TimePosition = 0
        self.IsPlaying = false
        self.Speed = 1
        self.OnStopped = nil
        if typeof(target) == 'Instance' and target:IsA('Model') then
            self.Motor6D = AutoGetMotor6D(target)
        else
            self.Motor6D = target
        end
        self.OriginalC0 = {}
        for name, motor in pairs(self.Motor6D) do
            self.OriginalC0[name] = motor.C0
        end
        if typeof(keyframeSeq) == 'Instance' then
            local seq, looped = ConvertToTable(keyframeSeq)
            self.Animation = seq
            self.Looped = looped
        elseif type(keyframeSeq) == 'table' then
            self.Animation = keyframeSeq
        else
            error('Invalid keyframe sequence')
        end
        self.Length = self.Animation[#self.Animation].Time
        return self
    end

    local function getSurrounding(seq, t)
        local prev, next = seq[1], seq[#seq]
        for i = 1, #seq - 1 do
            if seq[i].Time <= t and seq[i + 1].Time >= t then
                prev, next = seq[i], seq[i + 1]
                break
            end
        end
        return prev, next
    end

    function AnimLibrary:Play()
        if self.IsPlaying then return end
        self.IsPlaying = true
        if self.TimePosition >= self.Length then self.TimePosition = 0 end

        local startPoses = {}
        for joint, motor in pairs(self.Motor6D) do
            startPoses[joint] = LAST_POSE[joint] or CFrame.new()
        end
        local blendElapsed = 0
        local blendTime = 0.15

        self._conn = UpdateEvent:Connect(function(delta)
            if not self.IsPlaying then return end
            local dt = delta * (self.Speed or 1)
            local pos = self.TimePosition + dt

            if dt < 0 then
                if pos < 0 then
                    if self.Looped then
                        pos = pos + self.Length
                    else
                        pos = 0
                        local cb = self.OnStopped
                        self:Stop()
                        if cb then cb() end
                        return
                    end
                end
            else
                if pos > self.Length then
                    if self.Looped then
                        pos = pos - self.Length
                    else
                        pos = self.Length
                        local cb = self.OnStopped
                        self:Stop()
                        if cb then cb() end
                        return
                    end
                end
            end
            self.TimePosition = pos

            local prev, next = getSurrounding(self.Animation, pos)
            local span = next.Time - prev.Time
            local alpha = span > 0 and (pos - prev.Time) / span or 0

            blendElapsed = blendElapsed + math.abs(delta)
            local blendAlpha = math.min(blendElapsed / blendTime, 1)

            for joint, prevData in pairs(prev.Data) do
                local nextData = next.Data[joint] or prevData
                local ease = TweenService:GetValue(alpha, nextData.EasingStyle, nextData.EasingDirection)
                local target = prevData.CFrame:Lerp(nextData.CFrame, ease)
                local motor = self.Motor6D[joint]
                if motor then
                    if blendAlpha < 1 and startPoses[joint] then
                        target = startPoses[joint]:Lerp(target, blendAlpha)
                    end
                    local tilt = EXTRA_TILT[joint] or CFrame.new()
                    if joint == "Head" then
                        motor.C0 = self.OriginalC0[joint] * target * tilt
                    else
                        motor.C0 = tilt * self.OriginalC0[joint] * target
                    end
                    LAST_POSE[joint] = target
                end
            end
        end)
    end

    function AnimLibrary:Stop()
        self.IsPlaying = false
        if self._conn then
            self._conn:Disconnect()
            self._conn = nil
        end
        for joint, motor in pairs(self.Motor6D) do
            motor.C0 = self.OriginalC0[joint]
        end
    end

    AnimLibrary.AutoGetMotor6D = AutoGetMotor6D
    AnimLibrary.KeyFrameSequanceToTable = ConvertToTable
    return AnimLibrary
end

local allDances = {
    "Backflip", "Bang2", "Bang3", "Banged1", "BreakDance", "Floss", "Fresh",
    "Groovv", "Helicopter", "Kazotsky Kick (Spy)", "Parrot", "RickRoll", "Twerk",
}

local PER_PAGE = 8
local wheelPages = {}
do
    local i = 1
    while i <= #allDances do
        local page = {}
        for j = i, math.min(i + PER_PAGE - 1, #allDances) do
            table.insert(page, allDances[j])
        end
        table.insert(wheelPages, page)
        i = i + PER_PAGE
    end
end

local searchQuery = ""
local inFavoritesView = false

local particleDances = { Groovv = true, RickRoll = true, Backflip = true, Bang2 = true, Bang3 = true, Banged1 = true }

local player = Players.LocalPlayer
local currentPage = 1
local wheelPlayRef = { fn = nil }
local wheelNavRef = { pageLabel = nil, total = #wheelPages, refresh = nil }
local searchBoxRef = { box = nil }
local favBtnRef = { btn = nil }

local music = Instance.new("Sound")
music.Name = "CurrentVectorMusic"
music.SoundId = customasset("background.mp3")
music.Looped = true
music.Volume = 0.4
music.Parent = SoundService

local bgMusicOn = true

local connections = {}
local characterConn = nil
local wheelHooked = false
local wheelSlots = {}
local mobileGui = nil
local mobilePanel = nil
local mobileSearchQuery = ""
local mobileGrid = nil

local function disconnectAll()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    connections = {}
    if characterConn then
        pcall(function() characterConn:Disconnect() end)
        characterConn = nil
    end
end

local function fullCleanup()
    disconnectAll()
    pcall(function() music:Stop() end)
    pcall(function() music:Destroy() end)

    local char = player.Character
    if char then
        local torso = char:FindFirstChild("Torso")
        if torso then
            local p = torso:FindFirstChild("CVParticles")
            if p then p:Destroy() end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.PlatformStand = false end)
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function() hrp.Anchored = false end)
        end
    end

    for k in pairs(LAST_POSE) do LAST_POSE[k] = nil end
    for k in pairs(EXTRA_TILT) do EXTRA_TILT[k] = nil end

    local existingBlur2 = Lighting:FindFirstChild("CVWheelBlur")
    if existingBlur2 then existingBlur2:Destroy() end

    local cam = workspace.CurrentCamera
    if cam then
        cam.FieldOfView = 70
    end

    local rg = CoreGui:FindFirstChild(RESET_GUI_NAME)
    if rg then rg:Destroy() end
    if mobileGui then
        pcall(function() mobileGui:Destroy() end)
        mobileGui = nil
        mobilePanel = nil
        mobileGrid = nil
    end
end

shared.CurrentVectorCleanup = fullCleanup

local resetGui = Instance.new("ScreenGui")
resetGui.Name = RESET_GUI_NAME
resetGui.ResetOnSpawn = false
resetGui.IgnoreGuiInset = true
resetGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
resetGui.Parent = CoreGui

local function attachParticles(character)
    local torso = character:FindFirstChild("Torso")
    if not torso then return end
    if torso:FindFirstChild("CVParticles") then return end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "CVParticles"
    emitter.Texture = "rbxassetid://243660364"
    emitter.Rate = 20
    emitter.Lifetime = NumberRange.new(0.5, 1)
    emitter.Speed = NumberRange.new(1, 2)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Parent = torso
end

local function removeParticles(character)
    local torso = character:FindFirstChild("Torso")
    if torso then
        local p = torso:FindFirstChild("CVParticles")
        if p then p:Destroy() end
    end
end

local function findKF(obj)
    if not obj then return nil end
    if obj:IsA("KeyframeSequence") then return obj end
    if obj:IsA("Folder") or obj:IsA("Model") then
        local found = obj:FindFirstChildOfClass("KeyframeSequence")
        if found then return found end
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("KeyframeSequence") then return child end
        end
    end
    return nil
end

local function loadKFForPreview(name)
    local path = "CurrentVector/Animations/" .. name .. ".rbxm"
    if not isfile(path) then return nil end
    local ok, assetId = pcall(getcustomasset, path)
    if not ok then return nil end
    local ok2, obj = pcall(function() return InsertService:LoadLocalAsset(assetId) end)
    if not ok2 or not obj then return nil end
    return findKF(obj)
end

local function poseClone(clone, danceName)
    local kf = loadKFForPreview(danceName)
    if not kf then return end
    local motors = {}
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            for _, joint in ipairs(part:GetJoints()) do
                if joint:IsA("Motor6D") and joint.Part1 == part then
                    motors[part.Name] = joint
                    break
                end
            end
        end
    end
    local kfs = kf:GetKeyframes()
    if #kfs == 0 then return end
    local kfIndex = math.max(1, math.floor(#kfs * 0.4))
    local chosen = kfs[kfIndex]
    for _, pose in ipairs(chosen:GetDescendants()) do
        if pose:IsA("Pose") and pose.Weight > 0 then
            local motor = motors[pose.Name]
            if motor then motor.C0 = motor.C0 * pose.CFrame end
        end
    end
end

local function buildPreviewForSlot(slot, danceName, character)
    if not character then return end
    for _, child in ipairs(slot.viewport:GetChildren()) do
        if not child:IsA("Camera") then child:Destroy() end
    end
    local ok, clone = pcall(function() return character:Clone() end)
    if not ok or not clone then return end
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
            d:Destroy()
        elseif d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
        end
    end
    clone.Name = "Preview_" .. danceName
    pcall(poseClone, clone, danceName)
    local hrp = clone:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(0, 0, 0) end
    clone.Parent = slot.viewport
end

local function refreshWheelSlot(index, danceName, character)
    local slot = wheelSlots[index]
    if not slot then return end
    if slot.danceName == danceName then return end
    slot.danceName = danceName
    slot.text.Text = danceName or ""
    if danceName then
        buildPreviewForSlot(slot, danceName, character)
    end
end

local function getDisplayedEmotes()
    if searchQuery ~= "" then
        local q = string.lower(searchQuery)
        local filtered = {}
        for _, name in ipairs(allDances) do
            if string.find(string.lower(name), q, 1, true) then
                table.insert(filtered, name)
            end
        end
        return filtered, "Search: " .. searchQuery
    end
    if inFavoritesView then
        return favorites, "Favorites (" .. tostring(#favorites) .. ")"
    end
    local page = wheelPages[currentPage] or {}
    return page, "Page " .. currentPage .. " / " .. #wheelPages
end

local function refreshWheelPage()
    if not wheelHooked then return end
    local emotes, label = getDisplayedEmotes()
    local character = player.Character
    for i = 1, 8 do
        refreshWheelSlot(i, emotes[i], character)
    end
    if wheelNavRef.pageLabel then
        wheelNavRef.pageLabel.Text = label
    end
    if favBtnRef.btn then
        if inFavoritesView then
            favBtnRef.btn.Text = "★"
            favBtnRef.btn.TextColor3 = Color3.fromRGB(255, 200, 60)
        else
            favBtnRef.btn.Text = "☆"
            favBtnRef.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end

local wheelBlur = nil
local wheelSavedFov = nil

local function setWheelEffects(on)
    if on then
        if not wheelBlur then
            wheelBlur = Instance.new("BlurEffect")
            wheelBlur.Name = "CVWheelBlur"
            wheelBlur.Size = 18
            wheelBlur.Parent = Lighting
        end
        local cam = workspace.CurrentCamera
        if cam then
            if not wheelSavedFov then wheelSavedFov = cam.FieldOfView end
            cam.FieldOfView = wheelSavedFov - 20
        end
    else
        if wheelBlur then
            pcall(function() wheelBlur:Destroy() end)
            wheelBlur = nil
        end
        local cam = workspace.CurrentCamera
        if cam and wheelSavedFov then
            cam.FieldOfView = wheelSavedFov
        end
        wheelSavedFov = nil
    end
end

local function hookRobloxEmoteWheel()
    if wheelHooked then return end
    local ok1, RobloxGui = pcall(function() return CoreGui:WaitForChild("RobloxGui", 15) end)
    if not ok1 or not RobloxGui then return end
    local ok2, EmotesMenu = pcall(function() return RobloxGui:WaitForChild("EmotesMenu", 15) end)
    if not ok2 or not EmotesMenu then return end
    local wheel, emotesButtons, slotNumbers
    local ok3 = pcall(function()
        wheel = EmotesMenu.Children.Main.EmotesWheel
        emotesButtons = wheel.Front.EmotesButtons
        slotNumbers = wheel.Front.SlotNumbers
    end)
    if not ok3 or not emotesButtons or not slotNumbers then return end

    local slotPositions = {
        UDim2.new(0.5, 0, 0.1125, 0),
        UDim2.new(0.774, 0, 0.226, 0),
        UDim2.new(0.8875, 0, 0.5, 0),
        UDim2.new(0.774, 0, 0.774, 0),
        UDim2.new(0.5, 0, 0.8875, 0),
        UDim2.new(0.226, 0, 0.774, 0),
        UDim2.new(0.1125, 0, 0.5, 0),
        UDim2.new(0.226, 0, 0.226, 0),
    }

    for i = 1, 8 do
        local img = emotesButtons:FindFirstChild(tostring(i))

        if not img or not img:IsA("ImageLabel") then
            img = Instance.new("ImageLabel")
            img.Name = tostring(i)
            img.AnchorPoint = Vector2.new(0.5, 0.5)
            img.Size = UDim2.new(0.15, 0, 0.15, 0)
            img.Position = slotPositions[i]
            img.BackgroundTransparency = 1
            img.ImageTransparency = 1
            img.ZIndex = 2
            img.Parent = emotesButtons
            local ar = Instance.new("UIAspectRatioConstraint")
            ar.Parent = img
        end

        img.ImageTransparency = 1
        img.BackgroundTransparency = 1
        for _, child in ipairs(img:GetChildren()) do
            if string.sub(child.Name, 1, 2) == "CV" then child:Destroy() end
        end

        local viewport = Instance.new("ViewportFrame")
        viewport.Name = "CVViewport"
        viewport.Size = UDim2.fromScale(2.2, 2.2)
        viewport.AnchorPoint = Vector2.new(0.5, 0.5)
        viewport.Position = UDim2.fromScale(0.5, 0.4)
        viewport.BackgroundTransparency = 1
        viewport.LightDirection = Vector3.new(-1, -1, -1)
        viewport.Ambient = Color3.fromRGB(180, 180, 180)
        viewport.ZIndex = 5
        viewport.Parent = img

        local cam = Instance.new("Camera")
        cam.FieldOfView = 50
        cam.CFrame = CFrame.new(Vector3.new(0, -0.5, 5), Vector3.new(0, -0.5, 0))
        cam.Parent = viewport
        viewport.CurrentCamera = cam

        local text = Instance.new("TextLabel")
        text.Name = "CVText"
        text.Size = UDim2.fromScale(2.0, 0.6)
        text.AnchorPoint = Vector2.new(0.5, 0.5)
        text.Position = UDim2.fromScale(0.5, 1.4)
        text.BackgroundTransparency = 1
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.TextStrokeTransparency = 0.5
        text.Font = Enum.Font.GothamBold
        text.TextScaled = true
        text.ZIndex = 6
        text.Parent = img

        local btn = Instance.new("TextButton")
        btn.Name = "CVButton"
        btn.Size = UDim2.fromScale(1.7, 1.7)
        btn.AnchorPoint = Vector2.new(0.5, 0.5)
        btn.Position = UDim2.fromScale(0.5, 0.5)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.ZIndex = 10
        btn.Parent = img

        local slot = { img = img, viewport = viewport, text = text, button = btn, danceName = nil }
        btn.MouseButton1Click:Connect(function()
            if wheelPlayRef.fn and slot.danceName then wheelPlayRef.fn(slot.danceName) end
        end)
        btn.TouchTap:Connect(function()
            if wheelPlayRef.fn and slot.danceName then wheelPlayRef.fn(slot.danceName) end
        end)
        wheelSlots[i] = slot

        local num = slotNumbers:FindFirstChild(tostring(i))
        if num and num:IsA("TextLabel") then num.Text = tostring(i) end
    end

    for _, child in ipairs(wheel:GetChildren()) do
        if child.Name == "CVTopBar" then child:Destroy() end
        if child.Name == "CVNav" then child:Destroy() end
    end

    local topBar = Instance.new("Frame")
    topBar.Name = "CVTopBar"
    topBar.Size = UDim2.new(1, 0, 0, 44)
    topBar.AnchorPoint = Vector2.new(0.5, 1)
    topBar.Position = UDim2.new(0.5, 0, 0, -14)
    topBar.BackgroundTransparency = 1
    topBar.ZIndex = 30
    topBar.Parent = wheel

    local searchFrame = Instance.new("Frame")
    searchFrame.Name = "CVSearchFrame"
    searchFrame.Size = UDim2.new(0.7, -5, 1, 0)
    searchFrame.Position = UDim2.new(0, 0, 0, 0)
    searchFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    searchFrame.BackgroundTransparency = 0.15
    searchFrame.BorderSizePixel = 0
    searchFrame.ZIndex = 30
    searchFrame.Active = true
    searchFrame.Parent = topBar
    local sfCorner = Instance.new("UICorner")
    sfCorner.CornerRadius = UDim.new(0, 10)
    sfCorner.Parent = searchFrame
    local sfStroke = Instance.new("UIStroke")
    sfStroke.Color = Color3.fromRGB(90, 90, 130)
    sfStroke.Thickness = 2
    sfStroke.Parent = searchFrame

    local searchIcon = Instance.new("TextLabel")
    searchIcon.Size = UDim2.new(0, 32, 1, 0)
    searchIcon.Position = UDim2.new(0, 6, 0, 0)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "🔍"
    searchIcon.TextColor3 = Color3.fromRGB(180, 180, 200)
    searchIcon.Font = Enum.Font.GothamBold
    searchIcon.TextSize = 20
    searchIcon.ZIndex = 31
    searchIcon.Parent = searchFrame

    local searchBox = Instance.new("TextBox")
    searchBox.Name = "CVSearchInput"
    searchBox.Size = UDim2.new(1, -46, 1, 0)
    searchBox.Position = UDim2.new(0, 40, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search emotes..."
    searchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 155)
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 16
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false
    searchBox.TextEditable = true
    searchBox.MultiLine = false
    searchBox.ZIndex = 31
    searchBox.Parent = searchFrame

    searchBoxRef.box = searchBox

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchQuery = searchBox.Text
        if wheelNavRef.refresh then wheelNavRef.refresh() end
    end)

    local favBtn = Instance.new("TextButton")
    favBtn.Name = "CVFavBtn"
    favBtn.Size = UDim2.new(0.28, -5, 1, 0)
    favBtn.Position = UDim2.new(0.72, 0, 0, 0)
    favBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    favBtn.BackgroundTransparency = 0.15
    favBtn.BorderSizePixel = 0
    favBtn.Text = "☆"
    favBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    favBtn.TextStrokeTransparency = 0.4
    favBtn.Font = Enum.Font.GothamBold
    favBtn.TextScaled = true
    favBtn.ZIndex = 30
    favBtn.Parent = topBar
    local fbCorner = Instance.new("UICorner")
    fbCorner.CornerRadius = UDim.new(0, 10)
    fbCorner.Parent = favBtn
    local fbStroke = Instance.new("UIStroke")
    fbStroke.Color = Color3.fromRGB(90, 90, 130)
    fbStroke.Thickness = 2
    fbStroke.Parent = favBtn

    favBtnRef.btn = favBtn

    local function toggleFavView()
        inFavoritesView = not inFavoritesView
        if wheelNavRef.refresh then wheelNavRef.refresh() end
    end

    favBtn.MouseButton1Click:Connect(toggleFavView)
    favBtn.TouchTap:Connect(toggleFavView)

    local navFrame = Instance.new("Frame")
    navFrame.Name = "CVNav"
    navFrame.Size = UDim2.fromScale(0.7, 0.09)
    navFrame.AnchorPoint = Vector2.new(0.5, 0)
    navFrame.Position = UDim2.fromScale(0.5, 1.02)
    navFrame.BackgroundTransparency = 1
    navFrame.ZIndex = 20
    navFrame.Parent = wheel

    local backBtn = Instance.new("TextButton")
    backBtn.Name = "CVBack"
    backBtn.Size = UDim2.fromScale(0.22, 1)
    backBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    backBtn.Position = UDim2.fromScale(0.11, 0.5)
    backBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    backBtn.BackgroundTransparency = 0.3
    backBtn.BorderSizePixel = 0
    backBtn.Text = "◀"
    backBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    backBtn.TextStrokeTransparency = 0.4
    backBtn.Font = Enum.Font.GothamBold
    backBtn.TextScaled = true
    backBtn.ZIndex = 21
    backBtn.Parent = navFrame
    local backCorner = Instance.new("UICorner")
    backCorner.CornerRadius = UDim.new(0.3, 0)
    backCorner.Parent = backBtn

    local pageLabel = Instance.new("TextLabel")
    pageLabel.Name = "CVPageLabel"
    pageLabel.Size = UDim2.fromScale(0.5, 1)
    pageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    pageLabel.Position = UDim2.fromScale(0.5, 0.5)
    pageLabel.BackgroundTransparency = 1
    pageLabel.Text = "Page 1 / " .. tostring(#wheelPages)
    pageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    pageLabel.TextStrokeTransparency = 0.4
    pageLabel.Font = Enum.Font.GothamBold
    pageLabel.TextScaled = true
    pageLabel.ZIndex = 21
    pageLabel.Parent = navFrame

    local forwardBtn = Instance.new("TextButton")
    forwardBtn.Name = "CVForward"
    forwardBtn.Size = UDim2.fromScale(0.22, 1)
    forwardBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    forwardBtn.Position = UDim2.fromScale(0.89, 0.5)
    forwardBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    forwardBtn.BackgroundTransparency = 0.3
    forwardBtn.BorderSizePixel = 0
    forwardBtn.Text = "▶"
    forwardBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    forwardBtn.TextStrokeTransparency = 0.4
    forwardBtn.Font = Enum.Font.GothamBold
    forwardBtn.TextScaled = true
    forwardBtn.ZIndex = 21
    forwardBtn.Parent = navFrame
    local forwardCorner = Instance.new("UICorner")
    forwardCorner.CornerRadius = UDim.new(0.3, 0)
    forwardCorner.Parent = forwardBtn

    wheelNavRef.pageLabel = pageLabel
    wheelNavRef.refresh = refreshWheelPage

    local function goBack()
        if searchQuery ~= "" or inFavoritesView then return end
        currentPage = currentPage - 1
        if currentPage < 1 then currentPage = #wheelPages end
        refreshWheelPage()
    end

    local function goForward()
        if searchQuery ~= "" or inFavoritesView then return end
        currentPage = currentPage + 1
        if currentPage > #wheelPages then currentPage = 1 end
        refreshWheelPage()
    end

    backBtn.MouseButton1Click:Connect(goBack)
    forwardBtn.MouseButton1Click:Connect(goForward)
    backBtn.TouchTap:Connect(goBack)
    forwardBtn.TouchTap:Connect(goForward)
    backBtn.MouseEnter:Connect(function() backBtn.BackgroundTransparency = 0 end)
    backBtn.MouseLeave:Connect(function() backBtn.BackgroundTransparency = 0.3 end)
    forwardBtn.MouseEnter:Connect(function() forwardBtn.BackgroundTransparency = 0 end)
    forwardBtn.MouseLeave:Connect(function() forwardBtn.BackgroundTransparency = 0.3 end)

    wheel:GetPropertyChangedSignal("Visible"):Connect(function()
        if wheel.Visible then
            setWheelEffects(true)
        else
            setWheelEffects(false)
            if searchBoxRef.box then searchBoxRef.box.Text = "" end
            searchQuery = ""
            inFavoritesView = false
            refreshWheelPage()
        end
    end)

    if wheel.Visible then
        setWheelEffects(true)
    end

    wheelHooked = true
    refreshWheelPage()
end

pcall(hookRobloxEmoteWheel)

local mobileBlur = nil
local mobileSavedFov = nil

local function setMobileEffects(on)
    if on then
        if not mobileBlur then
            mobileBlur = Instance.new("BlurEffect")
            mobileBlur.Name = "CVWheelBlur"
            mobileBlur.Size = 18
            mobileBlur.Parent = Lighting
        end
        local cam = workspace.CurrentCamera
        if cam then
            if not mobileSavedFov then mobileSavedFov = cam.FieldOfView end
            cam.FieldOfView = mobileSavedFov - 20
        end
    else
        if mobileBlur then
            pcall(function() mobileBlur:Destroy() end)
            mobileBlur = nil
        end
        local cam = workspace.CurrentCamera
        if cam and mobileSavedFov then
            cam.FieldOfView = mobileSavedFov
        end
        mobileSavedFov = nil
    end
end

local function buildMobileUI(character, ctx)
    local playerGui = player:WaitForChild("PlayerGui")
    if mobileGui then pcall(function() mobileGui:Destroy() end) end

    mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "CurrentVectorMobile"
    mobileGui.ResetOnSpawn = false
    mobileGui.IgnoreGuiInset = true
    mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mobileGui.DisplayOrder = 100
    mobileGui.Parent = playerGui

    local toggle = Instance.new("TextButton")
    toggle.Name = "CVToggle"
    toggle.Size = UDim2.fromOffset(60, 60)
    toggle.Position = UDim2.new(1, -76, 0.5, -30)
    toggle.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    toggle.BackgroundTransparency = 0.15
    toggle.BorderSizePixel = 0
    toggle.Text = "CV"
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextScaled = true
    toggle.ZIndex = 100
    toggle.Active = true
    toggle.Draggable = true
    toggle.Parent = mobileGui
    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(1, 0)
    tCorner.Parent = toggle
    local tStroke = Instance.new("UIStroke")
    tStroke.Color = Color3.fromRGB(90, 90, 130)
    tStroke.Thickness = 2
    tStroke.Parent = toggle

    local panel = Instance.new("Frame")
    panel.Name = "CVPanel"
    panel.Size = UDim2.new(0, 340, 0, 520)
    panel.Position = UDim2.new(0.5, -170, 0.5, -260)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.ZIndex = 99
    panel.Active = true
    panel.Parent = mobileGui
    mobilePanel = panel
    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(0, 14)
    pCorner.Parent = panel
    local pStroke = Instance.new("UIStroke")
    pStroke.Color = Color3.fromRGB(80, 80, 120)
    pStroke.Thickness = 2
    pStroke.Parent = panel

    local titleBar = Instance.new("TextLabel")
    titleBar.Name = "Title"
    titleBar.Size = UDim2.new(1, -50, 0, 30)
    titleBar.Position = UDim2.new(0, 12, 0, 8)
    titleBar.BackgroundTransparency = 1
    titleBar.Text = "CurrentVector"
    titleBar.TextColor3 = Color3.fromRGB(235, 235, 245)
    titleBar.Font = Enum.Font.GothamBold
    titleBar.TextSize = 22
    titleBar.TextXAlignment = Enum.TextXAlignment.Left
    titleBar.ZIndex = 101
    titleBar.Parent = panel

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "Close"
    closeBtn.Size = UDim2.fromOffset(36, 36)
    closeBtn.Position = UDim2.new(1, -44, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(140, 35, 45)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 20
    closeBtn.ZIndex = 102
    closeBtn.Parent = panel
    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 8)
    cCorner.Parent = closeBtn

    local searchFrame = Instance.new("Frame")
    searchFrame.Name = "SearchFrame"
    searchFrame.Size = UDim2.new(1, -24, 0, 40)
    searchFrame.Position = UDim2.new(0, 12, 0, 52)
    searchFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
    searchFrame.BorderSizePixel = 0
    searchFrame.ZIndex = 101
    searchFrame.Active = true
    searchFrame.Parent = panel
    local sfCorner = Instance.new("UICorner")
    sfCorner.CornerRadius = UDim.new(0, 10)
    sfCorner.Parent = searchFrame
    local sfStroke = Instance.new("UIStroke")
    sfStroke.Color = Color3.fromRGB(80, 80, 120)
    sfStroke.Thickness = 2
    sfStroke.Parent = searchFrame

    local searchIcon = Instance.new("TextLabel")
    searchIcon.Size = UDim2.new(0, 34, 1, 0)
    searchIcon.Position = UDim2.new(0, 6, 0, 0)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "🔍"
    searchIcon.TextColor3 = Color3.fromRGB(180, 180, 200)
    searchIcon.Font = Enum.Font.GothamBold
    searchIcon.TextSize = 20
    searchIcon.ZIndex = 102
    searchIcon.Parent = searchFrame

    local mobileSearchBox = Instance.new("TextBox")
    mobileSearchBox.Name = "SearchInput"
    mobileSearchBox.Size = UDim2.new(1, -50, 1, 0)
    mobileSearchBox.Position = UDim2.new(0, 42, 0, 0)
    mobileSearchBox.BackgroundTransparency = 1
    mobileSearchBox.Text = ""
    mobileSearchBox.PlaceholderText = "Search emotes..."
    mobileSearchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 155)
    mobileSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    mobileSearchBox.Font = Enum.Font.Gotham
    mobileSearchBox.TextSize = 16
    mobileSearchBox.TextXAlignment = Enum.TextXAlignment.Left
    mobileSearchBox.ClearTextOnFocus = false
    mobileSearchBox.TextEditable = true
    mobileSearchBox.MultiLine = false
    mobileSearchBox.ZIndex = 102
    mobileSearchBox.Parent = searchFrame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "EmoteScroll"
    scroll.Size = UDim2.new(1, -24, 0, 240)
    scroll.Position = UDim2.new(0, 12, 0, 100)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 130)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = 101
    scroll.Parent = panel

    local scrollLayout = Instance.new("UIGridLayout")
    scrollLayout.CellSize = UDim2.new(0.5, -6, 0, 44)
    scrollLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Parent = scroll
    mobileGrid = scrollLayout

    local controlsFrame = Instance.new("Frame")
    controlsFrame.Name = "Controls"
    controlsFrame.Size = UDim2.new(1, -24, 0, 155)
    controlsFrame.Position = UDim2.new(0, 12, 1, -167)
    controlsFrame.BackgroundTransparency = 1
    controlsFrame.ZIndex = 101
    controlsFrame.Parent = panel

    local ctrlLayout = Instance.new("UIGridLayout")
    ctrlLayout.CellSize = UDim2.new(0.333, -6, 0, 36)
    ctrlLayout.CellPadding = UDim2.new(0, 6, 0, 6)
    ctrlLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ctrlLayout.Parent = controlsFrame

    local function makeCtrl(text, order, color, onClick)
        local b = Instance.new("TextButton")
        b.Name = text:gsub("%s", "")
        b.LayoutOrder = order
        b.BackgroundColor3 = color or Color3.fromRGB(45, 45, 65)
        b.BackgroundTransparency = 0.05
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamBold
        b.TextScaled = true
        b.TextWrapped = true
        b.ZIndex = 102
        b.Parent = controlsFrame
        local cor = Instance.new("UICorner")
        cor.CornerRadius = UDim.new(0, 8)
        cor.Parent = b
        b.MouseButton1Click:Connect(onClick)
        b.TouchTap:Connect(onClick)
        return b
    end

    local sitBtn = makeCtrl("Sit", 1, Color3.fromRGB(60, 90, 60), function()
        if ctx.isSitting() then
            ctx.unsit()
            sitBtn.Text = "Sit"
            notify("Stood up")
        else
            ctx.sit()
            sitBtn.Text = "Unsit"
            notify("Sitting")
        end
    end)
    local sprintBtn = makeCtrl("Sprint", 2, Color3.fromRGB(90, 60, 60), function()
        ctx.toggleSprint()
        sprintBtn.Text = ctx.isSprinting() and "Sprint ON" or "Sprint"
    end)
    makeCtrl("Stop", 3, Color3.fromRGB(120, 40, 50), function()
        ctx.stop()
        sitBtn.Text = "Sit"
        notify("Stopped")
    end)
    makeCtrl("PP", 4, Color3.fromRGB(90, 40, 90), function()
        ctx.pp()
    end)
    makeCtrl("Wave", 5, Color3.fromRGB(40, 90, 110), function()
        ctx.wave()
    end)
    makeCtrl("Twerk", 6, Color3.fromRGB(120, 60, 100), function()
        ctx.twerk()
    end)
    makeCtrl("Speed -", 7, Color3.fromRGB(70, 60, 90), function()
        if ctx.currentAnim() then
            ctx.currentAnim().Speed = math.max(0.1, ctx.currentAnim().Speed - 0.1)
            notify("Speed: " .. string.format("%.1f", ctx.currentAnim().Speed))
        end
    end)
    makeCtrl("Speed +", 8, Color3.fromRGB(70, 60, 90), function()
        if ctx.currentAnim() then
            ctx.currentAnim().Speed = math.min(5, ctx.currentAnim().Speed + 0.1)
            notify("Speed: " .. string.format("%.1f", ctx.currentAnim().Speed))
        end
    end)
    local musicBtn = makeCtrl("Music ON", 9, Color3.fromRGB(60, 80, 60), function()
        bgMusicOn = not bgMusicOn
        if bgMusicOn then music:Play() notify("Music ON")
        else music:Stop() notify("Music OFF") end
        musicBtn.Text = bgMusicOn and "Music ON" or "Music OFF"
    end)
    makeCtrl("Favorite", 10, Color3.fromRGB(90, 70, 40), function()
        local name = ctx.getName()
        if name and not (name == "Idle" or name == "WalkV2" or name == "RunV2") then
            local added = toggleFavorite(name)
            notify(added and ("Favorited " .. name) or ("Unfavorited " .. name))
            if searchQuery == "" and not inFavoritesView then
                rebuildMobileGrid("")
            end
        end
    end)
    makeCtrl("Random", 11, Color3.fromRGB(80, 60, 120), function()
        if #allDances > 0 then
            local pick = allDances[math.random(1, #allDances)]
            if ctx.isDancing and ctx.getName() == pick then ctx.stop() else ctx.play(pick) end
        end
    end)
    makeCtrl("Favs", 12, Color3.fromRGB(80, 90, 40), function()
        inFavoritesView = not inFavoritesView
        rebuildMobileGrid(mobileSearchBox.Text)
    end)

    function rebuildMobileGrid(filter)
        mobileSearchQuery = filter or ""
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        local list
        if inFavoritesView then
            list = favorites
        elseif mobileSearchQuery ~= "" then
            list = {}
            local q = string.lower(mobileSearchQuery)
            for _, name in ipairs(allDances) do
                if string.find(string.lower(name), q, 1, true) then
                    table.insert(list, name)
                end
            end
        else
            list = allDances
        end

        for i, name in ipairs(list) do
            local b = Instance.new("TextButton")
            b.Name = "Emote_" .. name
            b.LayoutOrder = i
            b.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
            b.BackgroundTransparency = 0.05
            b.BorderSizePixel = 0
            b.Text = name
            b.TextColor3 = Color3.fromRGB(255, 255, 255)
            b.Font = Enum.Font.GothamBold
            b.TextScaled = true
            b.TextWrapped = true
            b.ZIndex = 102
            b.Parent = scroll
            local cor = Instance.new("UICorner")
            cor.CornerRadius = UDim.new(0, 8)
            cor.Parent = b
            if isFavorite(name) then
                local star = Instance.new("TextLabel")
                star.Size = UDim2.new(0, 16, 0, 16)
                star.Position = UDim2.new(1, -20, 0, 4)
                star.BackgroundTransparency = 1
                star.Text = "★"
                star.TextColor3 = Color3.fromRGB(255, 200, 60)
                star.Font = Enum.Font.GothamBold
                star.TextScaled = true
                star.ZIndex = 103
                star.Parent = b
            end
            b.MouseButton1Click:Connect(function()
                if ctx.isDancing and ctx.getName() == name then ctx.stop() else ctx.play(name) end
            end)
            b.TouchTap:Connect(function()
                if ctx.isDancing and ctx.getName() == name then ctx.stop() else ctx.play(name) end
            end)
        end
    end

    mobileSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        inFavoritesView = false
        rebuildMobileGrid(mobileSearchBox.Text)
    end)

    local function togglePanel()
        panel.Visible = not panel.Visible
        setMobileEffects(panel.Visible)
        if panel.Visible then
            rebuildMobileGrid(mobileSearchBox.Text)
        end
    end

    toggle.MouseButton1Click:Connect(togglePanel)
    toggle.TouchTap:Connect(togglePanel)
    closeBtn.MouseButton1Click:Connect(function() panel.Visible = false; setMobileEffects(false) end)
    closeBtn.TouchTap:Connect(function() panel.Visible = false; setMobileEffects(false) end)

    rebuildMobileGrid("")
end

local function setupCharacter(character)
    disconnectAll()

    local hum = character:WaitForChild("Humanoid")
    local hrp = character:WaitForChild("HumanoidRootPart")
    if character:FindFirstChild("Animate") then character.Animate.Enabled = false end
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do track:Stop() end

    local animplayer = makeanimlibrary()
    local rigTable = animplayer.AutoGetMotor6D(character)

    local ORIGINAL_C0 = {}
    for name, motor in pairs(rigTable) do
        ORIGINAL_C0[name] = motor.C0
    end

    for k in pairs(EXTRA_TILT) do EXTRA_TILT[k] = nil end

    local currentAnim = nil
    local currentAnimName = nil
    local isDancing = false
    local isSitting = false
    local isPPing = false
    local sprinting = false
    local inAir = false
    local jumpPlaying = false
    local landPlaying = false
    local freefallStart = 0
    local walkingBackward = false

    local head = character:FindFirstChild("Head")
    local torso = character:FindFirstChild("Torso")
    local neckMotor = rigTable["Head"]

    local tiltRoot = CFrame.new()
    local tiltNeck = CFrame.new()
    local tiltRShoulder = CFrame.new()
    local tiltLShoulder = CFrame.new()
    local tiltRHip = CFrame.new()
    local tiltLHip = CFrame.new()

    local headLookTilt = CFrame.new()
    local bobTime = 0
    local bobActive = false
    local camera = workspace.CurrentCamera
    local baseFov = camera and camera.FieldOfView or 70

    local function loadKF(name)
        local path = "CurrentVector/Animations/" .. name .. ".rbxm"
        if not isfile(path) then return nil end
        local ok, assetId = pcall(getcustomasset, path)
        if not ok then return nil end
        local ok2, obj = pcall(function() return InsertService:LoadLocalAsset(assetId) end)
        if not ok2 or not obj then return nil end
        return findKF(obj)
    end

    local function freezeInPlace(state)
        hrp.Anchored = state
        if state then
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
            hum.PlatformStand = false
        end
    end

    local function playAnim(name, speed, looped, freeze)
        if currentAnim then
            currentAnim:Stop()
            currentAnim = nil
        end
        local kf = loadKF(name)
        if not kf then
            warn("[CurrentVector-Dances V1] Could not load: " .. name)
            return
        end
        currentAnim = animplayer.new(rigTable, kf)
        currentAnim.Speed = speed or 1
        currentAnim.Looped = looped ~= false
        currentAnim:Play()
        currentAnimName = name

        if particleDances[name] then
            attachParticles(character)
        else
            removeParticles(character)
        end

        freezeInPlace(freeze == true)
    end

    local function stopDance()
        if currentAnim then
            currentAnim:Stop()
            currentAnim = nil
        end
        currentAnimName = nil
        isDancing = false
        isSitting = false
        isPPing = false
        removeParticles(character)
        freezeInPlace(false)
        for _, m in pairs(rigTable) do
            m.C0 = ORIGINAL_C0[m.Name] or m.C0
        end
        for k in pairs(LAST_POSE) do LAST_POSE[k] = nil end
        for k in pairs(EXTRA_TILT) do EXTRA_TILT[k] = nil end
        updateMovementAnim()
    end

    local function playDance(name)
        isDancing = true
        isSitting = false
        isPPing = false
        playAnim(name, 1, true, true)
    end

    local function playOnce(name)
        isDancing = true
        isSitting = false
        isPPing = false
        playAnim(name, 1, false, true)
        local played = currentAnim
        if played then
            local len = played.Length or 2
            task.spawn(function()
                local elapsed = 0
                while elapsed < len + 0.1 do
                    RunService.RenderStepped:Wait()
                    elapsed = elapsed + 0.016
                    if currentAnim ~= played then return end
                    if not played.IsPlaying then break end
                end
                if currentAnim == played then stopDance() end
            end)
        end
    end

    local function playPP()
        if isPPing then
            stopDance()
            return
        end
        isDancing = true
        isSitting = false
        isPPing = true
        playAnim("PP", 1, true, false)
    end

    local function playWave()
        isDancing = true
        isSitting = false
        isPPing = false
        playAnim("Wave3", 1, false, false)
        local waveAnim = currentAnim
        if waveAnim then
            waveAnim.OnStopped = function()
                if currentAnim == waveAnim or currentAnim == nil then
                    stopDance()
                end
            end
        end
    end

    local function playTwerk()
        if isDancing and currentAnimName == "Twerk" then
            stopDance()
            return
        end
        playDance("Twerk")
    end

    local function playSit()
        isDancing = true
        isSitting = true
        isPPing = false

        task.spawn(function()
            pcall(function() loadKF("Sitting") end)
        end)

        playAnim("Sit2", 1, false, true)
        local sitAnim = currentAnim
        if sitAnim then
            sitAnim.OnStopped = function()
                if currentAnim == sitAnim or currentAnim == nil then
                    playAnim("Sitting", 1, true, true)
                    currentAnimName = "Sitting"
                end
            end
        end
    end

    local function unsit()
        if not isSitting then
            notify("Not sitting")
            return
        end

        isDancing = true
        isSitting = false
        isPPing = false

        task.spawn(function()
            pcall(function() loadKF("Sitting") end)
        end)

        playAnim("Sit2", -1, false, true)
        local unsitAnim = currentAnim
        if unsitAnim then
            unsitAnim.TimePosition = unsitAnim.Length
            unsitAnim.OnStopped = function()
                if currentAnim == unsitAnim or currentAnim == nil then
                    stopDance()
                end
            end
        end
    end

    function updateMovementAnim()
        if isDancing or inAir or jumpPlaying or landPlaying then return end
        if hum.MoveDirection.Magnitude > 0 then
            local dot = hum.MoveDirection.Unit:Dot(hrp.CFrame.LookVector)
            walkingBackward = dot < -0.5
            if walkingBackward then
                hum.WalkSpeed = 10
                if currentAnimName ~= "WalkV2" then
                    playAnim("WalkV2", -1, true, false)
                elseif currentAnim then
                    currentAnim.Speed = -1
                end
            elseif sprinting then
                hum.WalkSpeed = 18
                if currentAnimName ~= "RunV2" then playAnim("RunV2", 1, true, false) end
            else
                hum.WalkSpeed = 10
                if currentAnimName ~= "WalkV2" then
                    playAnim("WalkV2", 1, true, false)
                elseif currentAnim then
                    currentAnim.Speed = 1
                end
            end
        else
            walkingBackward = false
            if currentAnimName ~= "Idle" then playAnim("Idle", 1, true, false) end
        end
    end

    local function playLand()
        landPlaying = true
        playAnim("Land", 1, false, false)
        local landAnim = currentAnim
        task.spawn(function()
            if landAnim then
                while landAnim.IsPlaying and landAnim == currentAnim do
                    RunService.RenderStepped:Wait()
                end
            end
            if currentAnim == landAnim then
                landPlaying = false
                updateMovementAnim()
            end
        end)
    end

    wheelPlayRef.fn = function(name)
        if isDancing and currentAnimName == name then
            stopDance()
        else
            playDance(name)
        end
    end

    if IS_MOBILE then
        buildMobileUI(character, {
            play = playDance,
            stop = stopDance,
            sit = playSit,
            unsit = unsit,
            pp = playPP,
            wave = playWave,
            twerk = playTwerk,
            isDancing = isDancing,
            isSitting = function() return isSitting end,
            isSprinting = function() return sprinting end,
            toggleSprint = function()
                sprinting = not sprinting
                updateMovementAnim()
            end,
            getName = function() return currentAnimName end,
            currentAnim = function() return currentAnim end,
        })
    end

    table.insert(connections, hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
        if not inAir and not jumpPlaying and not landPlaying then updateMovementAnim() end
    end))

    table.insert(connections, hum.StateChanged:Connect(function(_, newState)
        if isDancing then return end
        if newState == Enum.HumanoidStateType.Jumping then
            inAir = true
            jumpPlaying = true
            landPlaying = false
            playAnim("Jump", 1, false, false)
            local jumpAnim = currentAnim
            task.spawn(function()
                while jumpAnim.IsPlaying and jumpAnim == currentAnim do
                    RunService.RenderStepped:Wait()
                end
                if currentAnim == jumpAnim and inAir and not jumpPlaying then
                    playAnim("Fall", 1, true, false)
                end
            end)
        elseif newState == Enum.HumanoidStateType.Freefall then
            inAir = true
            if not jumpPlaying then playAnim("Fall", 1, true, false) end
            freefallStart = tick()
        elseif newState == Enum.HumanoidStateType.Landed
            or newState == Enum.HumanoidStateType.Running
            or newState == Enum.HumanoidStateType.RunningNoPhysics then
            if inAir then
                local fallTime = tick() - freefallStart
                inAir = false
                jumpPlaying = false
                if fallTime >= 0.35 then playLand() else updateMovementAnim() end
            end
        end
    end))

    table.insert(connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = string.lower(string.gsub(tostring(input.KeyCode), "Enum.KeyCode.", ""))

        if key == "leftcontrol" then
            sprinting = true
            if not walkingBackward then updateMovementAnim() end
            return
        end

        if key == "t" then
            playTwerk()
            return
        end

        if key == "q" or key == "e" or key == "r" then
            local emotes = getDisplayedEmotes()
            local idx = (key == "q" and 1) or (key == "e" and 2) or 3
            local dance = emotes[idx]
            if dance then
                if isDancing and currentAnimName == dance then stopDance() else playDance(dance) end
            end
        elseif key == "m" then
            if searchQuery == "" and not inFavoritesView then
                currentPage = currentPage + 1
                if currentPage > #wheelPages then currentPage = 1 end
                notify("Page " .. currentPage)
                refreshWheelPage()
            end
        elseif key == "equals" then
            bgMusicOn = not bgMusicOn
            if bgMusicOn then music:Play() notify("Music ON") else music:Stop() notify("Music OFF") end
        elseif key == "backspace" then
            stopDance()
            notify("Stopped")
        elseif key == "leftbracket" then
            if currentAnim then
                currentAnim.Speed = math.max(0.1, currentAnim.Speed - 0.1)
                notify("Speed: " .. string.format("%.1f", currentAnim.Speed))
            end
        elseif key == "rightbracket" then
            if currentAnim then
                currentAnim.Speed = math.min(5, currentAnim.Speed + 0.1)
                notify("Speed: " .. string.format("%.1f", currentAnim.Speed))
            end
        elseif key == "one" or key == "two" or key == "three" or key == "four"
            or key == "five" or key == "six" or key == "seven" or key == "eight" then
            local map = { one = 1, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8 }
            local emotes = getDisplayedEmotes()
            local dance = emotes[map[key]]
            if dance then
                if isDancing and currentAnimName == dance then stopDance() else playDance(dance) end
            end
        elseif key == "f" then
            if currentAnimName and not (currentAnimName == "Idle" or currentAnimName == "WalkV2" or currentAnimName == "RunV2") then
                local added = toggleFavorite(currentAnimName)
                notify(added and ("Favorited " .. currentAnimName) or ("Unfavorited " .. currentAnimName))
                if inFavoritesView then refreshWheelPage() end
            end
        end
    end))

    table.insert(connections, UserInputService.InputEnded:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = string.lower(string.gsub(tostring(input.KeyCode), "Enum.KeyCode.", ""))
        if key == "leftcontrol" then
            sprinting = false
            if not walkingBackward then updateMovementAnim() end
        end
    end))

    table.insert(connections, player.Chatted:Connect(function(msg)
        local lower = string.lower(msg)
        if string.sub(lower, 1, 7) == "/dance " then
            local name = string.sub(msg, 8)
            for _, d in ipairs(allDances) do
                if string.lower(d) == string.lower(name) then
                    playDance(d)
                    return
                end
            end
            notify("Unknown dance: " .. name)
        elseif lower == "/poop" then
            playOnce("Poop")
            notify("Poop!")
        elseif lower == "/pp" then
            playPP()
            notify(isPPing and "PP ON" or "PP OFF")
        elseif lower == "/wave" then
            playWave()
            notify("Waving")
        elseif lower == "/tw" or lower == "/twerk" then
            playTwerk()
            notify("Twerking")
        elseif lower == "/sit" then
            if isSitting then
                unsit()
                notify("Stood up")
            else
                playSit()
                notify("Sitting")
            end
        elseif lower == "/unsit" then
            unsit()
        elseif lower == "/stop" then
            stopDance()
        elseif lower == "/cv" then
            notify("CurrentVector-Dances V1 | Page " .. currentPage)
        end
    end))

    local mouse = player:GetMouse()

    table.insert(connections, RunService.RenderStepped:Connect(function(dt)
        local moveDirection = hrp.CFrame:VectorToObjectSpace(hum.MoveDirection)
        local moving = hum.MoveDirection.Magnitude > 0.1
        local threshold = 0.9

        if isDancing then
            tiltRoot = tiltRoot:Lerp(CFrame.new(), 0.15)
            tiltNeck = tiltNeck:Lerp(CFrame.new(), 0.15)
            tiltRShoulder = tiltRShoulder:Lerp(CFrame.new(), 0.15)
            tiltLShoulder = tiltLShoulder:Lerp(CFrame.new(), 0.15)
            tiltRHip = tiltRHip:Lerp(CFrame.new(), 0.15)
            tiltLHip = tiltLHip:Lerp(CFrame.new(), 0.15)
        elseif not moving then
            tiltRoot = tiltRoot:Lerp(CFrame.new(), 0.15)
            tiltNeck = tiltNeck:Lerp(CFrame.new(), 0.15)
            tiltRShoulder = tiltRShoulder:Lerp(CFrame.new(), 0.15)
            tiltLShoulder = tiltLShoulder:Lerp(CFrame.new(), 0.15)
            tiltRHip = tiltRHip:Lerp(CFrame.new(), 0.15)
            tiltLHip = tiltLHip:Lerp(CFrame.new(), 0.15)
        else
            local targets = {
                RootJoint = CFrame.new(), Neck = CFrame.new(),
                RightShoulder = CFrame.new(), LeftShoulder = CFrame.new(),
                RightHip = CFrame.new(), LeftHip = CFrame.new(),
            }
            if moveDirection:Dot(Vector3.new(1,0,-1).Unit) > threshold then
                targets.RootJoint = CFrame.Angles(math.rad(-moveDirection.Z) * 3, 0, math.rad(-moveDirection.X) * 10)
                targets.Neck = CFrame.Angles(math.rad(moveDirection.Z) * 3, 0, math.rad(moveDirection.X) * 6)
                targets.RightShoulder = CFrame.Angles(0, math.rad(-moveDirection.X) * 5, 0)
                targets.LeftShoulder = CFrame.Angles(0, math.rad(-moveDirection.X) * 5, 0)
                targets.RightHip = CFrame.Angles(0, math.rad(-moveDirection.X) * 5, 0)
                targets.LeftHip = CFrame.Angles(0, math.rad(-moveDirection.X) * 5, 0)
            elseif moveDirection:Dot(Vector3.new(1,0,1).Unit) > threshold then
                targets.RootJoint = CFrame.Angles(math.rad(-moveDirection.Z) * 3, 0, math.rad(moveDirection.X) * 10)
                targets.Neck = CFrame.Angles(math.rad(moveDirection.Z) * 3, 0, math.rad(-moveDirection.X) * 10)
                targets.RightShoulder = CFrame.Angles(0, math.rad(moveDirection.X) * 5, 0)
                targets.LeftShoulder = CFrame.Angles(0, math.rad(moveDirection.X) * 5, 0)
                targets.RightHip = CFrame.Angles(0, math.rad(moveDirection.X) * 5, 0)
                targets.LeftHip = CFrame.Angles(0, math.rad(moveDirection.X) * 5, 0)
            elseif moveDirection:Dot(Vector3.new(-1,0,1).Unit) > threshold then
                targets.RootJoint = CFrame.Angles(math.rad(-moveDirection.Z) * 3, 0, math.rad(moveDirection.X) * 10)
                targets.Neck = CFrame.Angles(math.rad(moveDirection.Z) * 3, 0, math.rad(-moveDirection.X) * 10)
                targets.RightShoulder = CFrame.Angles(0, math.rad(moveDirection.X) * 5, 0)
                targets.LeftShoulder = CFrame.Angles(0, math.rad(moveDirection.X) * 5, 0)
                targets.RightHip = CFrame.Angles(0, math.rad(moveDirection.X) * 5, 0)
                targets.LeftHip = CFrame.Angles(0, math.rad(moveDirection.X) * 5, 0)
            elseif moveDirection:Dot(Vector3.new(-1,0,-1).Unit) > threshold then
                targets.RootJoint = CFrame.Angles(math.rad(-moveDirection.Z) * 3, 0, math.rad(-moveDirection.X) * 10)
                targets.Neck = CFrame.Angles(math.rad(moveDirection.Z) * 3, 0, math.rad(moveDirection.X) * 6)
                targets.RightShoulder = CFrame.Angles(0, math.rad(-moveDirection.X) * 5, 0)
                targets.LeftShoulder = CFrame.Angles(0, math.rad(-moveDirection.X) * 5, 0)
                targets.RightHip = CFrame.Angles(0, math.rad(-moveDirection.X) * 5, 0)
                targets.LeftHip = CFrame.Angles(0, math.rad(-moveDirection.X) * 5, 0)
            elseif moveDirection:Dot(Vector3.new(0,0,-1).Unit) > threshold then
                targets.RootJoint = CFrame.Angles(math.rad(-moveDirection.Z) * 4, 0, 0)
                targets.Neck = CFrame.Angles(math.rad(moveDirection.Z) * 4, 0, 0)
            elseif moveDirection:Dot(Vector3.new(0,0,1).Unit) > threshold then
                targets.RootJoint = CFrame.Angles(math.rad(-moveDirection.Z) * 4, 0, 0)
                targets.Neck = CFrame.Angles(math.rad(moveDirection.Z) * 4, 0, 0)
            elseif moveDirection:Dot(Vector3.new(1,0,0).Unit) > threshold then
                targets.RootJoint = CFrame.Angles(0, 0, math.rad(-moveDirection.X) * 14)
                targets.Neck = CFrame.Angles(0, 0, math.rad(moveDirection.X) * 14)
                targets.RightShoulder = CFrame.Angles(0, math.rad(-moveDirection.X) * 7, 0)
                targets.LeftShoulder = CFrame.Angles(0, math.rad(-moveDirection.X) * 7, 0)
                targets.RightHip = CFrame.Angles(0, math.rad(-moveDirection.X) * 7, 0)
                targets.LeftHip = CFrame.Angles(0, math.rad(-moveDirection.X) * 7, 0)
            elseif moveDirection:Dot(Vector3.new(-1,0,0).Unit) > threshold then
                targets.RootJoint = CFrame.Angles(0, 0, math.rad(-moveDirection.X) * 14)
                targets.Neck = CFrame.Angles(0, 0, math.rad(moveDirection.X) * 14)
                targets.RightShoulder = CFrame.Angles(0, math.rad(-moveDirection.X) * 7, 0)
                targets.LeftShoulder = CFrame.Angles(0, math.rad(-moveDirection.X) * 7, 0)
                targets.RightHip = CFrame.Angles(0, math.rad(-moveDirection.X) * 7, 0)
                targets.LeftHip = CFrame.Angles(0, math.rad(-moveDirection.X) * 7, 0)
            end
            local alpha = 0.145
            tiltRoot = tiltRoot:Lerp(targets.RootJoint, alpha)
            tiltNeck = tiltNeck:Lerp(targets.Neck, alpha)
            tiltRShoulder = tiltRShoulder:Lerp(targets.RightShoulder, alpha)
            tiltLShoulder = tiltLShoulder:Lerp(targets.LeftShoulder, alpha)
            tiltRHip = tiltRHip:Lerp(targets.RightHip, alpha)
            tiltLHip = tiltLHip:Lerp(targets.LeftHip, alpha)
        end

        EXTRA_TILT["Torso"] = tiltRoot
        EXTRA_TILT["Right Arm"] = tiltRShoulder
        EXTRA_TILT["Left Arm"] = tiltLShoulder
        EXTRA_TILT["Right Leg"] = tiltRHip
        EXTRA_TILT["Left Leg"] = tiltLHip

        if not isDancing and not moving and neckMotor and head and torso then
            local headToMouse = mouse.Hit.Position - head.Position
            if headToMouse.Magnitude > 0.01 then
                local dir = headToMouse.Unit
                local localX = dir:Dot(torso.CFrame.RightVector)
                local localY = dir:Dot(torso.CFrame.UpVector)
                local localZ = dir:Dot(torso.CFrame.LookVector)
                if localZ > 0 then
                    local pitch = -math.atan2(localY, localZ)
                    local yaw = -math.atan2(localX, localZ)
                    pitch = math.clamp(pitch, -0.4, 0.4)
                    yaw = math.clamp(yaw, -1.0, 1.0)
                    headLookTilt = headLookTilt:Lerp(CFrame.Angles(pitch, yaw, 0), math.min(dt * 8, 1))
                else
                    headLookTilt = headLookTilt:Lerp(CFrame.new(), math.min(dt * 8, 1))
                end
            else
                headLookTilt = headLookTilt:Lerp(CFrame.new(), math.min(dt * 8, 1))
            end
        else
            headLookTilt = headLookTilt:Lerp(CFrame.new(), math.min(dt * 8, 1))
        end
        EXTRA_TILT["Head"] = headLookTilt

        if camera then
            local targetFov = baseFov
            local wheelOpen = (wheelBlur ~= nil) or (mobileBlur ~= nil)
            if not wheelOpen then
                if sprinting and moving and not isDancing and not walkingBackward then
                    targetFov = baseFov + 10
                end
                camera.FieldOfView = camera.FieldOfView + (targetFov - camera.FieldOfView) * math.min(dt * 4, 1)
            end
        end

        if not isDancing and not inAir and moving and not walkingBackward then
            bobActive = true
            bobTime = bobTime + dt * (sprinting and 16 or 10)
        elseif not isDancing and not inAir and moving and walkingBackward then
            bobActive = true
            bobTime = bobTime - dt * 10
        else
            bobActive = false
            bobTime = bobTime + (0 - bobTime) * math.min(dt * 6, 1)
        end

        local baseOffset = (hrp.CFrame * CFrame.new(0, 1.5, 0)):PointToObjectSpace(head.Position)
        local bobOffset = Vector3.new(0, 0, 0)
        if bobActive then
            local amp = (sprinting and not walkingBackward) and 0.14 or 0.08
            bobOffset = Vector3.new(
                math.cos(bobTime * math.pi) * amp * 0.4,
                math.sin(bobTime * math.pi * 2) * amp,
                0
            )
        end
        hum.CameraOffset = hum.CameraOffset:Lerp(baseOffset + bobOffset, math.min(dt * 8, 1))
    end))

    playAnim("Idle", 1, true, false)
    if bgMusicOn then music:Play() end
    notify("CurrentVector-Dances V1 loaded")

    task.delay(1, function() refreshWheelPage() end)
end

characterConn = player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end

print("==========================================")
print("[CurrentVector-Dances V1] Ready")
if IS_MOBILE then
    print("Mobile: Tap the CV button to open the mobile panel")
    print("Mobile has search bar, emote list, and full controls")
else
    print("Dances: Q / E / R | Twerk: T")
    print("Page: M | Music: =")
    print("Stop: Backspace | Speed: [ ]")
    print("Favorite: F | Sprint: Hold LeftControl")
end
print("Wheel: Search bar + Favorites button + 8 slots per page")
print("Chat: /dance <name> | /poop | /pp | /wave | /tw | /sit | /unsit | /stop | /cv")
print("==========================================")
