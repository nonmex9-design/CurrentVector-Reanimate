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

local FORCE_REFRESH = true

pcall(function()
    if isfolder and not isfolder("CurrentVector") then makefolder("CurrentVector") end
    if isfolder and not isfolder("CurrentVector/Animations") then makefolder("CurrentVector/Animations") end
    if isfolder and not isfolder("CurrentVector/Music") then makefolder("CurrentVector/Music") end
end)
print("Ready!")

local baseURL = "https://github.com/nonmex9-design/CurrentVector-Reanimate/raw/refs/heads/main/CurrentVector/Animations/"
local animList = {
    "Backflip", "Bang2", "BreakDance", "Floss", "Fresh", "Groovv",
    "Helicopter", "Kazotsky Kick (Spy)", "Parrot", "RickRoll",
    "Idle", "Walk", "Run", "WalkV2", "RunV2", "Jump", "Fall", "Land", "Poop",
}

local function isValidRbxm(data)
    if not data or #data < 20 then return false end
    local head = string.sub(data, 1, 7)
    if head == "<roblox" then return true end
    local head2 = string.sub(data, 1, 6)
    if head2 == "<roblo" then return true end
    if string.sub(data, 1, 1) == "<" then return true end
    return false
end

local function downloadAnim(name)
    local path = "CurrentVector/Animations/" .. name .. ".rbxm"
    local url = baseURL .. name:gsub(" ", "%%20") .. ".rbxm"
    print("[CurrentVector-Dances V1] Downloading " .. name .. " from " .. url)

    local ok, data = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or not data then
        warn("[CurrentVector-Dances V1] HTTP failed for " .. name .. ": " .. tostring(data))
        if isfile(path) then
            warn("[CurrentVector-Dances V1] Keeping existing file for " .. name)
        end
        return
    end

    if not isValidRbxm(data) then
        warn("[CurrentVector-Dances V1] " .. name .. " is not a valid .rbxm (probably a 404 page). Size: " .. tostring(#data))
        local preview = string.sub(data, 1, 120)
        warn("[CurrentVector-Dances V1] Preview: " .. preview)
        if isfile(path) then
            warn("[CurrentVector-Dances V1] Keeping existing file for " .. name)
        end
        return
    end

    local wrote = pcall(function()
        writefile(path, data)
    end)
    if wrote then
        print("[CurrentVector-Dances V1] Downloaded " .. name .. " (" .. tostring(#data) .. " bytes)")
    else
        warn("[CurrentVector-Dances V1] Failed to write " .. name)
    end
end

for _, name in ipairs(animList) do
    local path = "CurrentVector/Animations/" .. name .. ".rbxm"
    if FORCE_REFRESH or not isfile(path) then
        downloadAnim(name)
    else
        print("[CurrentVector-Dances V1] Skipping " .. name .. " (already exists)")
    end
end
print("[CurrentVector-Dances V1] Animations ready")

local favPath = "CurrentVector/favorites.json"
local favorites = {}
if isfile(favPath) then
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(favPath))
    end)
    if ok and type(data) == "table" then favorites = data end
end

local function saveFavorites()
    pcall(function()
        writefile(favPath, HttpService:JSONEncode(favorites))
    end)
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
    if not isfile or not getcustomasset then
        return "rbxassetid://1837879082"
    end
    local path = "CurrentVector/Music/" .. id
    if not isfile(path) then
        local ok = pcall(function()
            writefile(path, game:HttpGet("https://github.com/nonmex9-design/CurrentVector-Reanimate/raw/refs/heads/main/CurrentVector/Music/" .. id))
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
                        self:Stop()
                        return
                    end
                end
            else
                if pos > self.Length then
                    if self.Looped then
                        pos = pos - self.Length
                    else
                        pos = self.Length
                        self:Stop()
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

local wheelPages = {
    { "Backflip", "Bang2", "BreakDance", "Floss", "Fresh", "Groovv", "Helicopter", "Kazotsky Kick (Spy)" },
    { "Parrot", "RickRoll", "Backflip", "Bang2", "BreakDance", "Floss", "Fresh", "Groovv" },
    { "Helicopter", "Kazotsky Kick (Spy)", "Parrot", "RickRoll", "Backflip", "Bang2", "BreakDance", "Floss" },
}

local dancePages = {}
for _, page in ipairs(wheelPages) do
    local row = {}
    for i = 1, 3 do
        table.insert(row, page[i])
    end
    table.insert(dancePages, row)
end

local allDances = {}
for _, page in ipairs(wheelPages) do
    for _, name in ipairs(page) do
        local exists = false
        for _, n in ipairs(allDances) do
            if n == name then exists = true break end
        end
        if not exists then table.insert(allDances, name) end
    end
end

local particleDances = { Groovv = true, RickRoll = true, Backflip = true, Bang2 = true }
local platformDances = { Backflip = true, Helicopter = true }

local player = Players.LocalPlayer
local currentPage = 1
local wheelPlayRef = { fn = nil }
local wheelNavRef = { pageLabel = nil, total = #wheelPages }

local music = Instance.new("Sound")
music.Name = "CurrentVectorMusic"
music.SoundId = customasset("background.mp3")
music.Looped = true
music.Volume = 0.4
music.Parent = SoundService

local bgMusicOn = true

local connections = {}

local function disconnectAll()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    connections = {}
end

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

local wheelHooked = false
local wheelSlots = {}

local function loadKFForPreview(name)
    local path = "CurrentVector/Animations/" .. name .. ".rbxm"
    if not isfile(path) then return nil end
    local ok, assetId = pcall(getcustomasset, path)
    if not ok then return nil end
    local ok2, obj = pcall(function()
        return InsertService:LoadLocalAsset(assetId)
    end)
    if not ok2 or not obj then return nil end
    if obj:IsA("Model") then
        obj = obj:FindFirstChildOfClass("KeyframeSequence")
    end
    return obj
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
            if motor then
                motor.C0 = motor.C0 * pose.CFrame
            end
        end
    end
end

local function buildPreviewForSlot(slot, danceName, character)
    if not character then return end

    for _, child in ipairs(slot.viewport:GetChildren()) do
        if not child:IsA("Camera") then
            child:Destroy()
        end
    end

    local ok, clone = pcall(function()
        return character:Clone()
    end)
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
    if hrp then
        hrp.CFrame = CFrame.new(0, 0, 0)
    end

    clone.Parent = slot.viewport
end

local function refreshWheelSlot(index, danceName, character)
    local slot = wheelSlots[index]
    if not slot then return end
    slot.danceName = danceName
    slot.text.Text = danceName or ""
    if danceName then
        buildPreviewForSlot(slot, danceName, character)
    end
end

local function refreshWheelPage(page)
    if not wheelHooked then return end
    local character = player.Character
    local pageDances = wheelPages[page] or wheelPages[1]
    for i = 1, 8 do
        refreshWheelSlot(i, pageDances[i], character)
    end
    if wheelNavRef.pageLabel then
        wheelNavRef.pageLabel.Text = "Page " .. tostring(page) .. " / " .. tostring(wheelNavRef.total)
    end
    print("[CurrentVector-Dances V1] Wheel refreshed for page " .. tostring(page))
end

local function hookRobloxEmoteWheel()
    if wheelHooked then return end

    local ok1, RobloxGui = pcall(function()
        return CoreGui:WaitForChild("RobloxGui", 15)
    end)
    if not ok1 or not RobloxGui then
        warn("[CurrentVector-Dances V1] RobloxGui not found")
        return
    end

    local ok2, EmotesMenu = pcall(function()
        return RobloxGui:WaitForChild("EmotesMenu", 15)
    end)
    if not ok2 or not EmotesMenu then
        warn("[CurrentVector-Dances V1] EmotesMenu not found")
        return
    end

    local wheel, emotesButtons, slotNumbers
    local ok3 = pcall(function()
        wheel = EmotesMenu.Children.Main.EmotesWheel
        emotesButtons = wheel.Front.EmotesButtons
        slotNumbers = wheel.Front.SlotNumbers
    end)
    if not ok3 or not emotesButtons or not slotNumbers then
        warn("[CurrentVector-Dances V1] Wheel structure not found")
        return
    end

    for i = 1, 8 do
        local img = emotesButtons:FindFirstChild(tostring(i))
        if img and img:IsA("ImageLabel") then
            img.ImageTransparency = 1
            img.BackgroundTransparency = 1

            for _, child in ipairs(img:GetChildren()) do
                if string.sub(child.Name, 1, 2) == "CV" then
                    child:Destroy()
                end
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

            local slot = {
                img = img,
                viewport = viewport,
                text = text,
                button = btn,
                danceName = nil,
            }

            btn.MouseButton1Click:Connect(function()
                if wheelPlayRef.fn and slot.danceName then
                    wheelPlayRef.fn(slot.danceName)
                end
            end)

            wheelSlots[i] = slot
        end

        local num = slotNumbers:FindFirstChild(tostring(i))
        if num and num:IsA("TextLabel") then
            num.Text = tostring(i)
        end
    end

    for _, child in ipairs(wheel:GetChildren()) do
        if child.Name == "CVNav" then
            child:Destroy()
        end
    end

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

    backBtn.MouseButton1Click:Connect(function()
        currentPage = currentPage - 1
        if currentPage < 1 then currentPage = #wheelPages end
        refreshWheelPage(currentPage)
    end)

    forwardBtn.MouseButton1Click:Connect(function()
        currentPage = currentPage + 1
        if currentPage > #wheelPages then currentPage = 1 end
        refreshWheelPage(currentPage)
    end)

    backBtn.MouseEnter:Connect(function()
        backBtn.BackgroundTransparency = 0
    end)
    backBtn.MouseLeave:Connect(function()
        backBtn.BackgroundTransparency = 0.3
    end)
    forwardBtn.MouseEnter:Connect(function()
        forwardBtn.BackgroundTransparency = 0
    end)
    forwardBtn.MouseLeave:Connect(function()
        forwardBtn.BackgroundTransparency = 0.3
    end)

    wheelHooked = true
    print("[CurrentVector-Dances V1] Roblox emotes wheel hooked")
    refreshWheelPage(currentPage)
end

pcall(hookRobloxEmoteWheel)

local function setupCharacter(character)
    print("[CurrentVector-Dances V1] Setting up character")
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
        local ok2, obj = pcall(function()
            return InsertService:LoadLocalAsset(assetId)
        end)
        if not ok2 or not obj then return nil end
        if obj:IsA("Model") then
            obj = obj:FindFirstChildOfClass("KeyframeSequence")
        end
        return obj
    end

    local function applyPlatformStand(state)
        if state then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
            hum.PlatformStand = true
        else
            hum.PlatformStand = false
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        end
    end

    local function playAnim(name, speed, looped)
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

        if platformDances[name] then
            applyPlatformStand(true)
        else
            applyPlatformStand(false)
        end
    end

    local function stopDance()
        if currentAnim then
            currentAnim:Stop()
            currentAnim = nil
        end
        currentAnimName = nil
        isDancing = false
        removeParticles(character)
        applyPlatformStand(false)
        for _, m in pairs(rigTable) do
            m.C0 = ORIGINAL_C0[m.Name] or m.C0
        end
        for k in pairs(LAST_POSE) do LAST_POSE[k] = nil end
        for k in pairs(EXTRA_TILT) do EXTRA_TILT[k] = nil end
        updateMovementAnim()
    end

    local function playDance(name)
        isDancing = true
        playAnim(name, 1, true)
    end

    local function playOnce(name)
        isDancing = true
        playAnim(name, 1, false)
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
                if currentAnim == played then
                    stopDance()
                end
            end)
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
                    playAnim("WalkV2", -1, true)
                elseif currentAnim then
                    currentAnim.Speed = -1
                end
            elseif sprinting then
                hum.WalkSpeed = 18
                if currentAnimName ~= "RunV2" then playAnim("RunV2", 1, true) end
            else
                hum.WalkSpeed = 10
                if currentAnimName ~= "WalkV2" then
                    playAnim("WalkV2", 1, true)
                elseif currentAnim then
                    currentAnim.Speed = 1
                end
            end
        else
            walkingBackward = false
            if currentAnimName ~= "Idle" then playAnim("Idle", 1, true) end
        end
    end

    local function playLand()
        landPlaying = true
        playAnim("Land", 1, false)
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

    table.insert(connections, hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
        if not inAir and not jumpPlaying and not landPlaying then updateMovementAnim() end
    end))

    table.insert(connections, hum.StateChanged:Connect(function(_, newState)
        if isDancing then return end
        if newState == Enum.HumanoidStateType.Jumping then
            inAir = true
            jumpPlaying = true
            landPlaying = false
            playAnim("Jump", 1, false)
            local jumpAnim = currentAnim
            task.spawn(function()
                while jumpAnim.IsPlaying and jumpAnim == currentAnim do
                    RunService.RenderStepped:Wait()
                end
                if currentAnim == jumpAnim and inAir and not jumpPlaying then
                    playAnim("Fall", 1, true)
                end
            end)
        elseif newState == Enum.HumanoidStateType.Freefall then
            inAir = true
            if not jumpPlaying then
                playAnim("Fall", 1, true)
            end
            freefallStart = tick()
        elseif newState == Enum.HumanoidStateType.Landed
            or newState == Enum.HumanoidStateType.Running
            or newState == Enum.HumanoidStateType.RunningNoPhysics then
            if inAir then
                local fallTime = tick() - freefallStart
                inAir = false
                jumpPlaying = false
                if fallTime >= 0.35 then
                    playLand()
                else
                    updateMovementAnim()
                end
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

        if key == "q" or key == "e" or key == "r" then
            local idx = (key == "q" and 1) or (key == "e" and 2) or 3
            local dance = dancePages[currentPage][idx]
            if dance then
                if isDancing and currentAnimName == dance then
                    stopDance()
                else
                    playDance(dance)
                end
            end
        elseif key == "m" then
            currentPage = currentPage + 1
            if currentPage > #wheelPages then currentPage = 1 end
            notify("Page " .. currentPage)
            refreshWheelPage(currentPage)
        elseif key == "equals" then
            bgMusicOn = not bgMusicOn
            if bgMusicOn then
                music:Play()
                notify("Music ON")
            else
                music:Stop()
                notify("Music OFF")
            end
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
            local dance = wheelPages[currentPage][map[key]]
            if dance then
                if isDancing and currentAnimName == dance then
                    stopDance()
                else
                    playDance(dance)
                end
            end
        elseif key == "f" then
            if currentAnimName and not (currentAnimName == "Idle" or currentAnimName == "WalkV2" or currentAnimName == "RunV2") then
                local added = toggleFavorite(currentAnimName)
                notify(added and ("Favorited " .. currentAnimName) or ("Unfavorited " .. currentAnimName))
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
                RootJoint = CFrame.new(),
                Neck = CFrame.new(),
                RightShoulder = CFrame.new(),
                LeftShoulder = CFrame.new(),
                RightHip = CFrame.new(),
                LeftHip = CFrame.new(),
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
            if sprinting and moving and not isDancing and not walkingBackward then
                targetFov = baseFov + 10
            end
            camera.FieldOfView = camera.FieldOfView + (targetFov - camera.FieldOfView) * math.min(dt * 4, 1)
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

    playAnim("Idle", 1, true)
    if bgMusicOn then music:Play() end
    print("[CurrentVector-Dances V1] Character ready")
    notify("CurrentVector-Dances V1 loaded")

    task.delay(1, function()
        refreshWheelPage(currentPage)
    end)
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end

print("==========================================")
print("[CurrentVector-Dances V1] Ready")
print("Dances: Q / E / R")
print("Page: M | Music: =")
print("Stop: Backspace | Speed: [ ]")
print("Favorite: F | Sprint: Hold LeftControl")
print("Wheel: 1-8 keys or click Roblox emotes wheel")
print("Chat: /dance <name> | /poop | /stop | /cv")
print("==========================================")
