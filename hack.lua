local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local wordValue = ReplicatedStorage:WaitForChild("WordValue", 10)

local state = {
    autoType = false,
    autoSay = false,
    autoCopy = false,
    speed = 0,
    randomSpeed = false,
    minSpeed = 0.01,
    maxSpeed = 0.04,
    lastWord = "",
    lastWordAttempt = 0,
    typosEnabled = false,
    isTyping = false,
    typoChance = 15,
    dieMode = false,
    dieChance = 15,
    currentTextbox = nil,
    liveWordUpdate = false,          -- NEW: controls live update from in‑game textbox
    liveUpdateConnection = nil
}

local typingProgress = {
    current = 0,
    total = 0
}

local wordOccurrence = 0
local menuVisible = true

local nearbyKeys = {
    ["a"] = {"s", "q", "w", "z"}, ["b"] = {"v", "g", "h", "n"}, ["c"] = {"x", "v", "d", "f"},
    ["d"] = {"s", "f", "e", "r", "c", "x"}, ["e"] = {"w", "r", "d", "s"}, ["f"] = {"d", "g", "r", "t", "v", "c"},
    ["g"] = {"f", "h", "t", "y", "b", "v"}, ["h"] = {"g", "j", "y", "u", "n", "b"}, ["i"] = {"u", "o", "k", "j"},
    ["j"] = {"h", "k", "u", "i", "n", "m"}, ["k"] = {"j", "l", "i", "o", "m"}, ["l"] = {"k", "o", "p"},
    ["m"] = {"n", "j", "k"}, ["n"] = {"b", "m", "h", "j"}, ["o"] = {"i", "p", "k", "l"},
    ["p"] = {"o", "l"}, ["q"] = {"w", "a"}, ["r"] = {"e", "t", "f", "d"},
    ["s"] = {"a", "d", "w", "e", "z", "x"}, ["t"] = {"r", "y", "g", "f"}, ["u"] = {"y", "i", "j", "h"},
    ["v"] = {"c", "b", "f", "g"}, ["w"] = {"q", "e", "s", "a"}, ["x"] = {"z", "c", "s", "d"},
    ["y"] = {"t", "u", "h", "g"}, ["z"] = {"a", "s", "x"}
}

local function makeDraggable(frame, dragHandle)
    local dragging, dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

local function copyToClipboard(text)
    local ok = pcall(function()
        if setclipboard then
            setclipboard(text)
        elseif toclipboard then
            toclipboard(text)
        end
    end)
    return ok
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LunarX_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 360, 0, 650)
Main.Position = UDim2.new(0.5, -180, 0.5, -325)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(70, 140, 255)
MainStroke.Thickness = 2
MainStroke.Transparency = 0.5
MainStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 60)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Header.BorderSizePixel = 0
Header.Parent = Main

makeDraggable(Main, Header)

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 14)
HeaderCorner.Parent = Header

local HeaderBlock = Instance.new("Frame")
HeaderBlock.Size = UDim2.new(1, 0, 0, 14)
HeaderBlock.Position = UDim2.new(0, 0, 1, -14)
HeaderBlock.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
HeaderBlock.BorderSizePixel = 0
HeaderBlock.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 24, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🌙 LUNAR X"
Title.TextColor3 = Color3.fromRGB(70, 140, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 50, 0, 50)
CloseBtn.Position = UDim2.new(1, -58, 0.5, -25)
CloseBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 32
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 10)
CloseBtnCorner.Parent = CloseBtn

CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
end)
CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 45, 52)}):Play()
end)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -48, 1, -80)
Content.Position = UDim2.new(0, 24, 0, 70)
Content.BackgroundTransparency = 1
Content.Parent = Main

local function createToggle(name, position, callback)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 52)
    Container.Position = position
    Container.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    Container.BorderSizePixel = 0
    Container.Parent = Content

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Container

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(50, 50, 60)
    Stroke.Thickness = 1
    Stroke.Transparency = 0.8
    Stroke.Parent = Container

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, -20, 1, 0)
    Label.Position = UDim2.new(0, 16, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(240, 240, 245)
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = 15
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container

    local Toggle = Instance.new("TextButton")
    Toggle.Size = UDim2.new(0, 52, 0, 28)
    Toggle.Position = UDim2.new(1, -64, 0.5, -14)
    Toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    Toggle.BorderSizePixel = 0
    Toggle.Text = ""
    Toggle.AutoButtonColor = false
    Toggle.Parent = Container

    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(1, 0)
    ToggleCorner.Parent = Toggle

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 22, 0, 22)
    Knob.Position = UDim2.new(0, 3, 0.5, -11)
    Knob.BackgroundColor3 = Color3.fromRGB(200, 200, 205)
    Knob.BorderSizePixel = 0
    Knob.Parent = Toggle

    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob

    local isOn = false

    Toggle.MouseButton1Click:Connect(function()
        isOn = not isOn
        local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        if isOn then
            TweenService:Create(Toggle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(70, 140, 255)}):Play()
            TweenService:Create(Knob, tweenInfo, {
                Position = UDim2.new(1, -25, 0.5, -11),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            }):Play()
        else
            TweenService:Create(Toggle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
            TweenService:Create(Knob, tweenInfo, {
                Position = UDim2.new(0, 3, 0.5, -11),
                BackgroundColor3 = Color3.fromRGB(200, 200, 205)
            }):Play()
        end
        callback(isOn)
    end)
end

-- Existing toggles
createToggle("Auto Type", UDim2.new(0, 0, 0, 0), function(enabled) state.autoType = enabled end)
createToggle("Auto Say", UDim2.new(0, 0, 0, 62), function(enabled) state.autoSay = enabled end)
createToggle("Auto Copy", UDim2.new(0, 0, 0, 124), function(enabled) state.autoCopy = enabled end)

-- NEW: Live Word Update toggle (after Auto Copy)
createToggle("Live Word Update", UDim2.new(0, 0, 0, 186), function(enabled)
    state.liveWordUpdate = enabled
    if enabled then
        -- Connect to current textbox if exists
        if state.currentTextbox then
            if state.liveUpdateConnection then state.liveUpdateConnection:Disconnect() end
            state.liveUpdateConnection = state.currentTextbox:GetPropertyChangedSignal("Text"):Connect(function()
                -- Only update if Live Update is ON AND Auto Type is OFF
                if state.liveWordUpdate and not state.autoType then
                    local txt = state.currentTextbox.Text
                    wordValue.Value = txt
                end
            end)
            -- Also update immediately with current text (if Auto Type is off)
            if not state.autoType then
                wordValue.Value = state.currentTextbox.Text
            end
        end
    else
        if state.liveUpdateConnection then
            state.liveUpdateConnection:Disconnect()
            state.liveUpdateConnection = nil
        end
    end
end)

-- SpeedContainer shifted down (was 186 -> now 238)
local SpeedContainer = Instance.new("Frame")
SpeedContainer.Size = UDim2.new(1, 0, 0, 148)
SpeedContainer.Position = UDim2.new(0, 0, 0, 238)
SpeedContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
SpeedContainer.BorderSizePixel = 0
SpeedContainer.Parent = Content

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 10)
SpeedCorner.Parent = SpeedContainer

local SpeedStroke = Instance.new("UIStroke")
SpeedStroke.Color = Color3.fromRGB(50, 50, 60)
SpeedStroke.Thickness = 1
SpeedStroke.Transparency = 0.8
SpeedStroke.Parent = SpeedContainer

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0.5, 0, 0, 32)
SpeedLabel.Position = UDim2.new(0, 16, 0, 10)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "Type Speed"
SpeedLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
SpeedLabel.Font = Enum.Font.GothamSemibold
SpeedLabel.TextSize = 14
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = SpeedContainer

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(0, 85, 0, 30)
SpeedInput.Position = UDim2.new(1, -95, 0, 11)
SpeedInput.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
SpeedInput.BorderSizePixel = 0
SpeedInput.Text = "0"
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedInput.Font = Enum.Font.GothamMedium
SpeedInput.TextSize = 14
SpeedInput.Parent = SpeedContainer

local SpeedInputCorner = Instance.new("UICorner")
SpeedInputCorner.CornerRadius = UDim.new(0, 8)
SpeedInputCorner.Parent = SpeedInput

SpeedInput.FocusLost:Connect(function()
    local num = tonumber(SpeedInput.Text)
    if num and num >= 0 then state.speed = num else SpeedInput.Text = tostring(state.speed) end
end)

local RandomLabel = Instance.new("TextLabel")
RandomLabel.Size = UDim2.new(0.6, 0, 0, 32)
RandomLabel.Position = UDim2.new(0, 16, 0, 48)
RandomLabel.BackgroundTransparency = 1
RandomLabel.Text = "Random Speed"
RandomLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
RandomLabel.Font = Enum.Font.GothamSemibold
RandomLabel.TextSize = 14
RandomLabel.TextXAlignment = Enum.TextXAlignment.Left
RandomLabel.Parent = SpeedContainer

local RandomToggle = Instance.new("TextButton")
RandomToggle.Size = UDim2.new(0, 52, 0, 28)
RandomToggle.Position = UDim2.new(1, -64, 0, 50)
RandomToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
RandomToggle.BorderSizePixel = 0
RandomToggle.Text = ""
RandomToggle.AutoButtonColor = false
RandomToggle.Parent = SpeedContainer

local RandomToggleCorner = Instance.new("UICorner")
RandomToggleCorner.CornerRadius = UDim.new(1, 0)
RandomToggleCorner.Parent = RandomToggle

local RandomKnob = Instance.new("Frame")
RandomKnob.Size = UDim2.new(0, 22, 0, 22)
RandomKnob.Position = UDim2.new(0, 3, 0.5, -11)
RandomKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 205)
RandomKnob.BorderSizePixel = 0
RandomKnob.Parent = RandomToggle

local RandomKnobCorner = Instance.new("UICorner")
RandomKnobCorner.CornerRadius = UDim.new(1, 0)
RandomKnobCorner.Parent = RandomKnob

if state.randomSpeed then
    RandomToggle.BackgroundColor3 = Color3.fromRGB(70, 140, 255)
    RandomKnob.Position = UDim2.new(1, -25, 0.5, -11)
    RandomKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
else
    RandomToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    RandomKnob.Position = UDim2.new(0, 3, 0.5, -11)
    RandomKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 205)
end

RandomToggle.MouseButton1Click:Connect(function()
    state.randomSpeed = not state.randomSpeed
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    if state.randomSpeed then
        TweenService:Create(RandomToggle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(70, 140, 255)}):Play()
        TweenService:Create(RandomKnob, tweenInfo, {
            Position = UDim2.new(1, -25, 0.5, -11),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
    else
        TweenService:Create(RandomToggle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
        TweenService:Create(RandomKnob, tweenInfo, {
            Position = UDim2.new(0, 3, 0.5, -11),
            BackgroundColor3 = Color3.fromRGB(200, 200, 205)
        }):Play()
    end
end)

local MinLabel = Instance.new("TextLabel")
MinLabel.Size = UDim2.new(0.4, 0, 0, 26)
MinLabel.Position = UDim2.new(0, 16, 0, 86)
MinLabel.BackgroundTransparency = 1
MinLabel.Text = "Min"
MinLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
MinLabel.Font = Enum.Font.Gotham
MinLabel.TextSize = 13
MinLabel.TextXAlignment = Enum.TextXAlignment.Left
MinLabel.Parent = SpeedContainer

local MinInput = Instance.new("TextBox")
MinInput.Size = UDim2.new(0, 85, 0, 28)
MinInput.Position = UDim2.new(1, -95, 0, 85)
MinInput.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
MinInput.BorderSizePixel = 0
MinInput.Text = tostring(state.minSpeed)
MinInput.TextColor3 = Color3.fromRGB(255, 255, 255)
MinInput.Font = Enum.Font.Gotham
MinInput.TextSize = 13
MinInput.Parent = SpeedContainer

local MinInputCorner = Instance.new("UICorner")
MinInputCorner.CornerRadius = UDim.new(0, 8)
MinInputCorner.Parent = MinInput

MinInput.FocusLost:Connect(function()
    local v = tonumber(MinInput.Text)
    if v and v >= 0 then state.minSpeed = v else MinInput.Text = tostring(state.minSpeed) end
end)

local MaxLabel = Instance.new("TextLabel")
MaxLabel.Size = UDim2.new(0.4, 0, 0, 26)
MaxLabel.Position = UDim2.new(0, 16, 0, 116)
MaxLabel.BackgroundTransparency = 1
MaxLabel.Text = "Max"
MaxLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
MaxLabel.Font = Enum.Font.Gotham
MaxLabel.TextSize = 13
MaxLabel.TextXAlignment = Enum.TextXAlignment.Left
MaxLabel.Parent = SpeedContainer

local MaxInput = Instance.new("TextBox")
MaxInput.Size = UDim2.new(0, 85, 0, 28)
MaxInput.Position = UDim2.new(1, -95, 0, 115)
MaxInput.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
MaxInput.BorderSizePixel = 0
MaxInput.Text = tostring(state.maxSpeed)
MaxInput.TextColor3 = Color3.fromRGB(255, 255, 255)
MaxInput.Font = Enum.Font.Gotham
MaxInput.TextSize = 13
MaxInput.Parent = SpeedContainer

local MaxInputCorner = Instance.new("UICorner")
MaxInputCorner.CornerRadius = UDim.new(0, 8)
MaxInputCorner.Parent = MaxInput

MaxInput.FocusLost:Connect(function()
    local v = tonumber(MaxInput.Text)
    if v and v >= 0 then state.maxSpeed = v else MaxInput.Text = tostring(state.maxSpeed) end
end)

-- ===== CUSTOM WORD PANEL (only manual set) =====
-- Shifted down (was 344 -> now 396)
local CustomWordContainer = Instance.new("Frame")
CustomWordContainer.Size = UDim2.new(1, 0, 0, 60)
CustomWordContainer.Position = UDim2.new(0, 0, 0, 396)
CustomWordContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
CustomWordContainer.BorderSizePixel = 0
CustomWordContainer.Parent = Content

local CustomCorner = Instance.new("UICorner")
CustomCorner.CornerRadius = UDim.new(0, 10)
CustomCorner.Parent = CustomWordContainer

local CustomStroke = Instance.new("UIStroke")
CustomStroke.Color = Color3.fromRGB(50, 50, 60)
CustomStroke.Thickness = 1
CustomStroke.Transparency = 0.8
CustomStroke.Parent = CustomWordContainer

local CustomLabel = Instance.new("TextLabel")
CustomLabel.Size = UDim2.new(0.35, 0, 0, 24)
CustomLabel.Position = UDim2.new(0, 12, 0, 8)
CustomLabel.BackgroundTransparency = 1
CustomLabel.Text = "Manual Word"
CustomLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
CustomLabel.Font = Enum.Font.GothamSemibold
CustomLabel.TextSize = 14
CustomLabel.TextXAlignment = Enum.TextXAlignment.Left
CustomLabel.Parent = CustomWordContainer

local CustomInput = Instance.new("TextBox")
CustomInput.Size = UDim2.new(0.6, -20, 0, 28)
CustomInput.Position = UDim2.new(0, 12, 0, 28)
CustomInput.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
CustomInput.BorderSizePixel = 0
CustomInput.Text = ""
CustomInput.PlaceholderText = "Type a word..."
CustomInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
CustomInput.TextColor3 = Color3.fromRGB(255, 255, 255)
CustomInput.Font = Enum.Font.Gotham
CustomInput.TextSize = 14
CustomInput.Parent = CustomWordContainer

local CustomInputCorner = Instance.new("UICorner")
CustomInputCorner.CornerRadius = UDim.new(0, 8)
CustomInputCorner.Parent = CustomInput

local SetBtn = Instance.new("TextButton")
SetBtn.Size = UDim2.new(0, 56, 0, 28)
SetBtn.Position = UDim2.new(1, -68, 0, 28)
SetBtn.BackgroundColor3 = Color3.fromRGB(70, 140, 255)
SetBtn.BorderSizePixel = 0
SetBtn.Text = "Set"
SetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SetBtn.Font = Enum.Font.GothamSemibold
SetBtn.TextSize = 14
SetBtn.AutoButtonColor = false
SetBtn.Parent = CustomWordContainer

local SetBtnCorner = Instance.new("UICorner")
SetBtnCorner.CornerRadius = UDim.new(0, 8)
SetBtnCorner.Parent = SetBtn

SetBtn.MouseButton1Click:Connect(function()
    local word = CustomInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if word ~= "" then
        wordValue.Value = word
        CustomInput.Text = word
    end
end)

CustomInput.FocusLost:Connect(function(enter)
    if enter then
        local word = CustomInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if word ~= "" then
            wordValue.Value = word
            CustomInput.Text = word
        end
    end
end)
-- ===== END CUSTOM WORD PANEL =====

-- Console shifted down (was 414 -> now 466)
local Console = Instance.new("Frame")
Console.Size = UDim2.new(1, 0, 0, 125)
Console.Position = UDim2.new(0, 0, 0, 466)
Console.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Console.BorderSizePixel = 0
Console.Parent = Content

local ConsoleCorner = Instance.new("UICorner")
ConsoleCorner.CornerRadius = UDim.new(0, 10)
ConsoleCorner.Parent = Console

local ConsoleStroke = Instance.new("UIStroke")
ConsoleStroke.Color = Color3.fromRGB(70, 140, 255)
ConsoleStroke.Thickness = 1
ConsoleStroke.Transparency = 0.7
ConsoleStroke.Parent = Console

local ConsoleTitle = Instance.new("TextLabel")
ConsoleTitle.Size = UDim2.new(1, -84, 0, 24)
ConsoleTitle.Position = UDim2.new(0, 10, 0, 8)
ConsoleTitle.BackgroundTransparency = 1
ConsoleTitle.Text = "CURRENT WORD"
ConsoleTitle.TextColor3 = Color3.fromRGB(120, 120, 130)
ConsoleTitle.Font = Enum.Font.GothamBold
ConsoleTitle.TextSize = 11
ConsoleTitle.TextXAlignment = Enum.TextXAlignment.Left
ConsoleTitle.Parent = Console

local CopyBtn = Instance.new("TextButton")
CopyBtn.Size = UDim2.new(0, 56, 0, 20)
CopyBtn.Position = UDim2.new(1, -64, 0, 7)
CopyBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
CopyBtn.BorderSizePixel = 0
CopyBtn.Text = "Copy"
CopyBtn.TextColor3 = Color3.fromRGB(70, 140, 255)
CopyBtn.Font = Enum.Font.GothamSemibold
CopyBtn.TextSize = 11
CopyBtn.AutoButtonColor = false
CopyBtn.Parent = Console

local CopyBtnCorner = Instance.new("UICorner")
CopyBtnCorner.CornerRadius = UDim.new(0, 6)
CopyBtnCorner.Parent = CopyBtn

CopyBtn.MouseEnter:Connect(function()
    TweenService:Create(CopyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(70, 140, 255)}):Play()
end)
CopyBtn.MouseLeave:Connect(function()
    TweenService:Create(CopyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 45, 52)}):Play()
end)
CopyBtn.MouseButton1Click:Connect(function()
    local word = wordValue.Value
    if word ~= "" then
        if copyToClipboard(word) then
            CopyBtn.Text = "Copied!"
            task.delay(0.8, function() CopyBtn.Text = "Copy" end)
        end
    end
end)

local ConsoleText = Instance.new("TextLabel")
ConsoleText.Size = UDim2.new(1, -24, 1, -48)
ConsoleText.Position = UDim2.new(0, 12, 0, 36)
ConsoleText.BackgroundTransparency = 1
ConsoleText.Text = "Waiting..."
ConsoleText.TextColor3 = Color3.fromRGB(70, 140, 255)
ConsoleText.Font = Enum.Font.GothamBold
ConsoleText.TextSize = 28
ConsoleText.TextWrapped = true
ConsoleText.TextYAlignment = Enum.TextYAlignment.Top
ConsoleText.Parent = Console

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 18)
StatusLabel.Position = UDim2.new(0, 10, 1, -26)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "● Ready"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Console

local LetterLabel = Instance.new("TextLabel")
LetterLabel.Size = UDim2.new(0, 80, 0, 16)
LetterLabel.AnchorPoint = Vector2.new(1, 1)
LetterLabel.Position = UDim2.new(1, -10, 1, -8)
LetterLabel.BackgroundTransparency = 1
LetterLabel.Text = "0/0"
LetterLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
LetterLabel.Font = Enum.Font.Gotham
LetterLabel.TextSize = 12
LetterLabel.TextXAlignment = Enum.TextXAlignment.Right
LetterLabel.Parent = Console

local CmdFrame = Instance.new("Frame")
CmdFrame.Size = UDim2.new(0, 520, 0, 320)
CmdFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
CmdFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
CmdFrame.BorderSizePixel = 0
CmdFrame.Visible = false
CmdFrame.Active = true
CmdFrame.Parent = ScreenGui

local CmdTitle = Instance.new("TextLabel")
CmdTitle.Size = UDim2.new(1, 0, 0, 30)
CmdTitle.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
CmdTitle.Text = "  🌙 Command Prompt - Lunar X"
CmdTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
CmdTitle.Font = Enum.Font.Code
CmdTitle.TextSize = 14
CmdTitle.TextXAlignment = Enum.TextXAlignment.Left
CmdTitle.Parent = CmdFrame

makeDraggable(CmdFrame, CmdTitle)

local CmdCorner = Instance.new("UICorner")
CmdCorner.CornerRadius = UDim.new(0, 8)
CmdCorner.Parent = CmdFrame

local CmdStroke = Instance.new("UIStroke")
CmdStroke.Color = Color3.fromRGB(70, 140, 255)
CmdStroke.Thickness = 2
CmdStroke.Parent = CmdFrame

local CmdTitleCorner = Instance.new("UICorner")
CmdTitleCorner.CornerRadius = UDim.new(0, 8)
CmdTitleCorner.Parent = CmdTitle

local CmdTitleBlock = Instance.new("Frame")
CmdTitleBlock.Size = UDim2.new(1, 0, 0, 8)
CmdTitleBlock.Position = UDim2.new(0, 0, 1, -8)
CmdTitleBlock.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
CmdTitleBlock.BorderSizePixel = 0
CmdTitleBlock.Parent = CmdTitle

local CmdScroll = Instance.new("ScrollingFrame")
CmdScroll.Size = UDim2.new(1, -16, 1, -70)
CmdScroll.Position = UDim2.new(0, 8, 0, 36)
CmdScroll.BackgroundTransparency = 1
CmdScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
CmdScroll.ScrollBarThickness = 5
CmdScroll.Parent = CmdFrame

local CmdList = Instance.new("UIListLayout")
CmdList.Parent = CmdScroll

local CmdInputBox = Instance.new("TextBox")
CmdInputBox.Size = UDim2.new(1, -16, 0, 24)
CmdInputBox.Position = UDim2.new(0, 8, 1, -30)
CmdInputBox.BackgroundTransparency = 1
CmdInputBox.Text = ""
CmdInputBox.PlaceholderText = "C:\\Users\\" .. player.DisplayName .. "> "
CmdInputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
CmdInputBox.TextColor3 = Color3.fromRGB(70, 140, 255)
CmdInputBox.Font = Enum.Font.Code
CmdInputBox.TextSize = 14
CmdInputBox.TextXAlignment = Enum.TextXAlignment.Left
CmdInputBox.Parent = CmdFrame

local function setLetterCount(current, total)
    LetterLabel.Text = current .. "/" .. total
    typingProgress.current = current
    typingProgress.total = total
end

local dotRunning = false
local dotBaseText = ""

local function startDots(baseText, color)
    dotBaseText = baseText
    if dotRunning then return end
    dotRunning = true
    if color then
        StatusLabel.TextColor3 = color
    end
    task.spawn(function()
        local d = 1
        while dotRunning do
            StatusLabel.Text = "● " .. dotBaseText .. string.rep(".", d)
            d = d % 3 + 1
            task.wait(0.45)
        end
    end)
end

local function stopDots(text, color)
    dotRunning = false
    StatusLabel.Text = text
    if color then
        StatusLabel.TextColor3 = color
    end
end

local function startTypingAnimator()
    startDots("Typing", Color3.fromRGB(70, 140, 255))
end

local function stopTypingAnimator(text, color)
    stopDots(text, color)
end

local function addCmdLine(txt, color)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.fromRGB(200, 200, 205)
    l.Font = Enum.Font.Code
    l.TextSize = 13
    l.Text = txt
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = CmdScroll
    CmdScroll.CanvasSize = UDim2.new(0, 0, 0, CmdList.AbsoluteContentSize.Y)
    CmdScroll.CanvasPosition = Vector2.new(0, CmdList.AbsoluteContentSize.Y)
end

addCmdLine("Microsoft Windows [Version 10.0.19045.4291]", Color3.fromRGB(150, 150, 160))
addCmdLine("(c) Lunar X Corporation. All rights reserved.", Color3.fromRGB(150, 150, 160))
addCmdLine("")
addCmdLine("Type .helpx for help", Color3.fromRGB(100, 255, 100))
addCmdLine("")

local function sayWord(word)
    local msg = "word : " .. word
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if channel then channel:SendAsync(msg) end
        else
            local chatEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            if chatEvent and chatEvent:FindFirstChild("SayMessageRequest") then
                chatEvent:FindFirstChild("SayMessageRequest"):FireServer(msg, "All")
            end
        end
    end)
end

local function handleCommand(msg)
    local args = msg:split(" ")
    local cmd = args[1] and args[1]:lower() or ""
    local prefix = "C:\\Users\\" .. player.DisplayName .. "> "

    local function getBool()
        if args[2] == "true" or args[2] == "on" then return true
        elseif args[2] == "false" or args[2] == "off" then return false
        end
        return nil
    end

    if cmd == ".helpx" then
        addCmdLine("=== AVAILABLE COMMANDS ===", Color3.fromRGB(70, 140, 255))
        addCmdLine(".typo [true/false] - Toggle typos")
        addCmdLine(".typochance [num] - Set typo chance %")
        addCmdLine(".die [true/false] - Toggle instant fail mode")
        addCmdLine(".diechance [num] - Set fail chance %")
        addCmdLine(".copy - Copy current word to clipboard")
        addCmdLine(".autocopy [true/false] - Toggle auto copy")
        addCmdLine(".cls - Clear console")
        addCmdLine(".checkplayers - Check other players for LunarX_UI")
        addCmdLine(".checkword - Show current word")
        addCmdLine(".type <word> - Set a custom word (updates WordValue, auto-enters)")
    elseif cmd == ".type" then
        if args[2] then
            local w = table.concat(args, " ", 2)
            wordValue.Value = w
            addCmdLine(prefix .. "Word set to: " .. w, Color3.fromRGB(100, 255, 100))
        else
            addCmdLine(prefix .. "Usage: .type <word>", Color3.fromRGB(255, 100, 100))
        end
    elseif cmd == ".typo" then
        local b = getBool()
        state.typosEnabled = (b ~= nil) and b or not state.typosEnabled
        addCmdLine(prefix .. "Typos: " .. tostring(state.typosEnabled), Color3.fromRGB(100, 255, 100))
    elseif cmd == ".die" then
        local b = getBool()
        state.dieMode = (b ~= nil) and b or not state.dieMode
        addCmdLine(prefix .. "Die Mode: " .. tostring(state.dieMode), Color3.fromRGB(100, 255, 100))
    elseif cmd == ".typochance" and args[2] then
        state.typoChance = tonumber(args[2]) or state.typoChance
        addCmdLine(prefix .. "Typo Chance: " .. state.typoChance .. "%", Color3.fromRGB(100, 255, 100))
    elseif cmd == ".diechance" and args[2] then
        state.dieChance = tonumber(args[2]) or state.dieChance
        addCmdLine(prefix .. "Die Chance: " .. state.dieChance .. "%", Color3.fromRGB(100, 255, 100))
    elseif cmd == ".copy" then
        local cur = wordValue.Value
        if cur ~= "" and copyToClipboard(cur) then
            addCmdLine(prefix .. "Copied: " .. cur, Color3.fromRGB(100, 255, 100))
        else
            addCmdLine(prefix .. "Nothing to copy.", Color3.fromRGB(255, 100, 100))
        end
    elseif cmd == ".autocopy" then
        local b = getBool()
        state.autoCopy = (b ~= nil) and b or not state.autoCopy
        addCmdLine(prefix .. "Auto Copy: " .. tostring(state.autoCopy), Color3.fromRGB(100, 255, 100))
    elseif cmd == ".cls" then
        for _, v in ipairs(CmdScroll:GetChildren()) do
            if v:IsA("TextLabel") then
                v:Destroy()
            end
        end
    elseif cmd == ".checkplayers" then
        startDots("Scanning", Color3.fromRGB(70,140,255))
        local found = {}
        local conn
        conn = TextChatService.MessageReceived:Connect(function(m)
            if m.Text == "[lxp]" then
                table.insert(found, m.TextSource.Name)
            end
        end)
        sayWord("[lxp]")
        task.wait(1)
        conn:Disconnect()
        stopDots("● Ready", Color3.fromRGB(100,255,100))
        if #found == 0 then
            addCmdLine("No Lunar X users detected.", Color3.fromRGB(150,150,160))
        else
            addCmdLine("Detected Lunar X users:", Color3.fromRGB(70,140,255))
            for _, name in ipairs(found) do
                addCmdLine(" - " .. name)
            end
        end
    elseif cmd == ".checkword" then
        local cur = wordValue.Value
        if cur == "" then cur = "Waiting..." end
        addCmdLine(prefix .. "Current Word: " .. cur, Color3.fromRGB(70, 140, 255))
    end
end

CmdInputBox.FocusLost:Connect(function(enter)
    if enter then
        local t = CmdInputBox.Text
        if t ~= "" then
            addCmdLine("C:\\Users\\" .. player.Name .. "> " .. t, Color3.fromRGB(70, 140, 255))
            handleCommand(t)
        end
        CmdInputBox.Text = ""
    end
end)

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(m)
        if m.TextSource and m.TextSource.UserId == player.UserId then
            handleCommand(m.Text)
        end
    end)
else
    player.Chatted:Connect(handleCommand)
end

UserInputService.InputBegan:Connect(function(io, gp)
    if gp then return end
    if io.KeyCode == Enum.KeyCode.E and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        CmdFrame.Visible = not CmdFrame.Visible
        if CmdFrame.Visible then
            task.wait()
            CmdInputBox:CaptureFocus()
        end
    elseif io.KeyCode == Enum.KeyCode.LeftControl then
        menuVisible = not menuVisible
        Main.Visible = menuVisible
    end
end)

local function findValidTextbox()
    local textboxGui = playerGui:FindFirstChild("Textbox")
    if not textboxGui or not textboxGui:IsA("ScreenGui") or not textboxGui.Enabled then
        return nil
    end
    for _, v in ipairs(textboxGui:GetDescendants()) do
        if v:IsA("TextBox") and v.Visible then
            return v
        end
    end
    return nil
end

local textboxCache = nil
local lastTextboxCheck = 0

RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastTextboxCheck > 0.1 then
        lastTextboxCheck = now
        local found = findValidTextbox()
        if found ~= textboxCache then
            textboxCache = found
            state.currentTextbox = found
            -- If live update is on, reconnect to the new textbox
            if state.liveWordUpdate then
                if state.liveUpdateConnection then
                    state.liveUpdateConnection:Disconnect()
                    state.liveUpdateConnection = nil
                end
                if state.currentTextbox then
                    state.liveUpdateConnection = state.currentTextbox:GetPropertyChangedSignal("Text"):Connect(function()
                        if state.liveWordUpdate and not state.autoType then
                            local txt = state.currentTextbox.Text
                            wordValue.Value = txt
                        end
                    end)
                    -- Update immediately with current text if Auto Type is off
                    if not state.autoType then
                        wordValue.Value = state.currentTextbox.Text
                    end
                end
            end
        end
    end
end)

local function getTypoChar(char)
    local lc = char:lower()
    if nearbyKeys[lc] then return nearbyKeys[lc][math.random(1, #nearbyKeys[lc])] end
    return char
end

local function completeWord(textbox)
    pcall(function()
        textbox:ReleaseFocus()
    end)
    task.wait(0.05)
    pcall(function()
        local remote = ReplicatedStorage:FindFirstChild("SpelledCorrectly")
            or ReplicatedStorage:FindFirstChild("CorrectSpelling")
        if remote then
            remote:FireServer()
        end
    end)
end

wordValue:GetPropertyChangedSignal("Value"):Connect(function()
    local newWord = wordValue.Value
    wordOccurrence += 1
    local thisOccurrence = wordOccurrence

    if newWord ~= "" then
        ConsoleText.Text = newWord
    else
        ConsoleText.Text = "Waiting..."
    end
    if newWord == "" then
        setLetterCount(0, 0)
        return
    end

    if state.autoCopy then
        task.spawn(function() copyToClipboard(newWord) end)
    end

    state.lastWord = newWord
    state.lastWordAttempt = thisOccurrence

    if state.autoSay then
        task.spawn(function()
            sayWord(newWord)
        end)
    end
    if not state.autoType then return end
    state.isTyping = true
    
    task.spawn(function()
        local targetWord = newWord
        local myOccurrence = thisOccurrence
        local wordLength = #targetWord
        setLetterCount(0, wordLength)
        typingProgress.current = 0
        typingProgress.total = wordLength
        startTypingAnimator()
        local success = false
        task.wait(1)
        
        if not state.autoType or wordOccurrence ~= myOccurrence then
            state.isTyping = false
            stopTypingAnimator("● Ready.", Color3.fromRGB(100, 255, 100))
            return
        end
        
        local textboxGui = nil
        local guiWaitStart = tick()
        while tick() - guiWaitStart < 3 do
            textboxGui = playerGui:FindFirstChild("Textbox")
            if textboxGui and textboxGui:IsA("ScreenGui") and textboxGui.Enabled then
                break
            end
            task.wait(0.1)
        end
        
        if not textboxGui or not textboxGui.Enabled then
            state.isTyping = false
            stopTypingAnimator("● Waiting for Textbox.", Color3.fromRGB(255, 100, 100))
            return
        end
        
        local waitStart = tick()
        while not textboxCache and tick() - waitStart < 2 do
            task.wait(0.05)
        end
        
        if not textboxCache then
            state.isTyping = false
            stopTypingAnimator("● No Textbox Found.", Color3.fromRGB(255, 100, 100))
            return
        end
        
        if not state.randomSpeed and state.speed == 0 then
            if textboxCache and wordOccurrence == myOccurrence then
                textboxCache.Text = targetWord
                completeWord(textboxCache)
                success = true
                setLetterCount(wordLength, wordLength)
            end
            state.isTyping = false
            stopTypingAnimator(success and "● Complete." or "● Ready.", Color3.fromRGB(100, 255, 100))
            return
        end

        local cur = ""
        local isDie = state.dieMode and math.random(1,100) <= state.dieChance
        local dieIdx = isDie and math.random(1, wordLength) or nil

        for i = 1, wordLength do
            if not state.autoType or wordOccurrence ~= myOccurrence then
                state.isTyping = false
                stopTypingAnimator("● Aborted.", Color3.fromRGB(255, 100, 100))
                return
            end

            if not textboxCache or not textboxCache.Parent or not textboxCache.Visible then
                textboxCache = findValidTextbox()
                if not textboxCache then
                    state.isTyping = false
                    stopTypingAnimator("● Lost Textbox.", Color3.fromRGB(255, 100, 100))
                    return
                end
            end

            local ch = targetWord:sub(i, i)
            
            if isDie and i == dieIdx then
                cur = cur .. getTypoChar(ch)
                textboxCache.Text = cur
                
                local remote = ReplicatedStorage:FindFirstChild("SpelledCorrectly") or ReplicatedStorage:FindFirstChild("CorrectSpelling")
                if remote then pcall(function() remote:FireServer() end) end
                
                setLetterCount(wordLength, wordLength)
                state.isTyping = false
                stopTypingAnimator("● Failed (Die Mode).", Color3.fromRGB(255, 80, 80))
                return
            else
                if state.typosEnabled and math.random(1,100) <= state.typoChance and i < wordLength then
                    textboxCache.Text = cur .. getTypoChar(ch)
                    setLetterCount(#cur + 1, wordLength)
                    task.wait(0.12)
                end
                cur = cur .. ch
            end
            
            textboxCache.Text = cur
            setLetterCount(i, wordLength)
            
            local waitTime = state.randomSpeed and (state.minSpeed + math.random()*(state.maxSpeed-state.minSpeed)) or state.speed
            task.wait(waitTime)
        end

        if wordOccurrence == myOccurrence and textboxCache then
            completeWord(textboxCache)
            success = true
            setLetterCount(wordLength, wordLength)
        end
        state.isTyping = false
        stopTypingAnimator(success and "● Complete." or "● Failed.", Color3.fromRGB(100, 255, 100))
    end)
end)
