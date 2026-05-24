-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "✨ Spelling Bee | Complete Engine",
    LoadingTitle = "Initializing...",
    ConfigurationSaving = {Enabled = true, FolderName = "SpellingBee", FileName = "Config"},
    KeySystem = false
})

local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- GitHub settings
local GITHUB_TOKEN = "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"
local GIST_ID = "8030d59d84512ca1915f17ea335ded6"
local GIST_FILE = "raefld.csb"
local SyncEnabled = false
local SyncedWords = {}

local REAL_USER_AGENT = "Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.6312.99 Mobile Safari/537.36"

-- Engine variables
local IsBusy = false
local LastHandledWord = ""
local LocalOverrideWord = ""
local CurrentTypingProgress = {current = 0, total = 0, startTime = 0}
local LastTypingTime = 0
local TYPING_COOLDOWN = 1.7
local ScriptRunning = true
local LastSubmitTime = 0

-- Configuration
local Config = {
    AutoType = false,
    CopyPaste = false,
    TypoFix = false,
    AutoInject = false,
    AutoEnter = true,
    CPS = 16,
    CopyPasteDelay = 0.0
}

local Stats = {
    Typed = 0,
    Pasted = 0,
    Total = 0
}

-- Find WordValue
local WordValue = nil
for _, obj in ipairs(game:GetDescendants()) do
    if obj.Name == "WordValue" and obj:IsA("StringValue") then
        WordValue = obj
        break
    end
end
if not WordValue then
    WordValue = Instance.new("StringValue")
    WordValue.Name = "WordValue"
    WordValue.Parent = game:GetService("ReplicatedStorage")
end

local function GetCurrentTargetWord()
    if LocalOverrideWord ~= "" then return LocalOverrideWord end
    return WordValue.Value
end

-- GitHub functions
local function LoadWordsFromGist()
    local url = string.format("https://api.github.com/gists/%s", GIST_ID)
    local headers = {["Authorization"] = "token " .. GITHUB_TOKEN, ["User-Agent"] = REAL_USER_AGENT}
    local success, response = pcall(function() return game:HttpGet(url, true, headers) end)
    if success and response then
        local decoded = HttpService:JSONDecode(response)
        if decoded and decoded.files and decoded.files[GIST_FILE] then
            local content = decoded.files[GIST_FILE].content
            if content and content ~= "" then
                for word in string.gmatch(content, "[^\r\n]+") do
                    if word ~= "" then table.insert(SyncedWords, word) end
                end
            end
        end
    end
end

local function SaveWordToGist(word)
    if not SyncEnabled or word == "" then return end
    for _, w in ipairs(SyncedWords) do if w == word then return end end
    table.insert(SyncedWords, word)
    local content = table.concat(SyncedWords, "\n")
    local patchData = {files = {[GIST_FILE] = {content = content}}}
    local url = string.format("https://api.github.com/gists/%s", GIST_ID)
    local headers = {
        ["Authorization"] = "token " .. GITHUB_TOKEN,
        ["User-Agent"] = REAL_USER_AGENT,
        ["Content-Type"] = "application/json"
    }
    pcall(function()
        game:HttpGet(url, true, headers, "PATCH", HttpService:JSONEncode(patchData))
    end)
end

-- Find textbox
local function isRealTurnTextbox(obj)
    if not obj:IsA("TextBox") then return false end
    local sg = obj:FindFirstAncestorOfClass("ScreenGui")
    if not sg or not sg.Enabled then return false end
    if not obj.Visible then return false end
    local isChat = obj.Name:lower():find("chat") or (obj.Parent and obj.Parent.Name:lower():find("chat"))
    if isChat then return false end
    return true
end

local function findMyTextbox()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    if pg:FindFirstChild("Textbox") and pg.Textbox:FindFirstChild("TextBox") then
        local tb = pg.Textbox.TextBox
        if isRealTurnTextbox(tb) then return tb end
    end
    for _, obj in ipairs(pg:GetDescendants()) do
        if isRealTurnTextbox(obj) then return obj end
    end
    return nil
end

local function ForceUpdateGameUI(newWord)
    if newWord == "" then return end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, obj in ipairs(pg:GetDescendants()) do
        if obj:IsA("TextLabel") and (obj.Name:lower():find("word") or obj.Name:lower():find("target") or obj.Name:lower():find("display")) then
            if #obj.Text > 0 and not obj.Text:find(":") then
                obj.Text = newWord
            end
        end
    end
end

-- Letter-by-letter typing with repair and final verification
local function TypeWord(textbox, word, cps, pressEnter, modeName)
    if not textbox or not word or word == "" then return false end
    local delay = math.max(1 / cps, 0.001)
    local typingId = tostring(tick()) .. tostring(math.random(1000,9999))
    CurrentTypingId = typingId

    CurrentTypingProgress.current = 0
    CurrentTypingProgress.total = #word
    CurrentTypingProgress.startTime = tick()

    local lastGoodText = ""
    local lastRepair = 0
    local repairCooldown = 0.015

    textbox:CaptureFocus()

    local function IsValid()
        return ScriptRunning and textbox and textbox.Parent and isRealTurnTextbox(textbox)
            and GetCurrentTargetWord() == word and CurrentTypingId == typingId
            and (
                (modeName == "AutoType" and Config.AutoType) or
                (modeName == "CopyPaste" and Config.CopyPaste) or
                (modeName == "AutoInject" and Config.AutoInject)
            )
    end

    local function ForceText(text)
        if textbox.Text ~= text then textbox.Text = text end
        local desired = #text + 1
        if textbox.CursorPosition ~= desired then textbox.CursorPosition = desired end
    end

    local function RepairText(expected)
        local now = tick()
        if now - lastRepair < repairCooldown then return end
        lastRepair = now
        local current = textbox.Text
        if current == expected then return end
        if #current > #expected then ForceText(expected); return end
        if #current > 0 and word:sub(1, #current) == current then
            lastGoodText = current
            return
        end
        ForceText(expected)
    end

    ForceText("")
    local i = 1
    while i <= #word do
        if not IsValid() then return false end
        local expected = word:sub(1, i)
        RepairText(expected)
        ForceText(expected)
        lastGoodText = expected
        CurrentTypingProgress.current = i
        local started = tick()
        while tick() - started < delay do
            if not IsValid() then return false end
            RepairText(expected)
            task.wait()
        end
        local current = textbox.Text
        if current ~= expected then
            if #current > 0 and word:sub(1, #current) == current then i = #current end
        end
        i += 1
    end

    -- Final verification
    ForceText(word)
    task.wait(0.05)
    if textbox.Text ~= word then
        ForceText(word)
        Rayfield:Notify({Title = "Text restored", Content = "Game tried to clear the answer.", Duration = 1.5})
    end

    if pressEnter and Config.AutoEnter and IsValid() then
        textbox:CaptureFocus()
        task.wait()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.015)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        task.delay(0.03, function()
            if textbox and textbox.Parent and textbox.Text == word then
                textbox.Text = ""; textbox.CursorPosition = 1
            end
        end)
    end
    CurrentTypingProgress.current = #word
    return true
end

-- Auto Type (full simulation)
local function DoAutoType(word, textbox)
    if IsBusy then return false end
    IsBusy = true
    CurrentTypingProgress = {current = 0, total = #word, startTime = tick()}
    textbox:CaptureFocus()
    task.wait(0.04)
    textbox.Text = ""
    task.wait(0.01)
    local success = TypeWord(textbox, word, Config.CPS, true, "AutoType")
    if success and Config.AutoType and ScriptRunning then
        Stats.Typed = Stats.Typed + 1
        LastTypingTime = tick()
    end
    Stats.Total = Stats.Total + 1
    RefreshStats()
    CurrentTypingProgress = {current = 0, total = 0, startTime = 0}
    IsBusy = false
    return success
end

-- Copy Paste (instant fill)
local function DoCopyPaste(word, textbox)
    if IsBusy then return false end
    IsBusy = true
    if Config.CopyPasteDelay > 0 then task.wait(Config.CopyPasteDelay) end
    if not Config.CopyPaste or not ScriptRunning or GetCurrentTargetWord() ~= word then
        IsBusy = false; return false
    end
    textbox.Text = word
    if Config.AutoEnter then
        textbox:CaptureFocus()
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end
    Stats.Pasted = Stats.Pasted + 1
    Stats.Total = Stats.Total + 1
    RefreshStats()
    LastTypingTime = tick()
    IsBusy = false
    return true
end

-- Auto Inject (letter-by-letter, respects CPS)
local function DoAutoInject(word, textbox)
    if IsBusy then return false end
    if not Config.AutoInject or not Config.AutoType then return false end
    if not word or word == "" then return false
    IsBusy = true
    textbox:CaptureFocus()
    textbox.Text = ""
    task.wait(0.05)
    local delay = 1 / Config.CPS
    local typed = ""
    for i = 1, #word do
        if not Config.AutoInject or not Config.AutoType then break end
        typed = typed .. string.sub(word, i, i)
        textbox.Text = typed
        textbox.CursorPosition = i + 1
        if i < #word then task.wait(delay) end
    end
    if typed == word and Config.AutoEnter and Config.AutoInject and Config.AutoType then
        task.wait(0.05)
        textbox:CaptureFocus()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end
    Stats.Pasted = Stats.Pasted + 1
    Stats.Total = Stats.Total + 1
    RefreshStats()
    LastTypingTime = tick()
    IsBusy = false
    return true
end

-- UI functions
local function UpdateProgressDisplay()
    if not ScriptRunning then return end
    if CurrentTypingProgress.total > 0 then
        local percent = (CurrentTypingProgress.current / CurrentTypingProgress.total) * 100
        local remaining = (CurrentTypingProgress.total - CurrentTypingProgress.current) / Config.CPS
        LabelProgress:Set(string.format("📈 Progress: %.1f%% | %d/%d | %.1fs",
            percent, CurrentTypingProgress.current, CurrentTypingProgress.total, remaining))
    else
        LabelProgress:Set("📈 Progress: 0% | 0/0 | 0.0s")
    end
end

local function UpdateCurrentWord()
    if not ScriptRunning then return end
    local w = GetCurrentTargetWord()
    if w and w ~= "" then
        local postfix = (LocalOverrideWord ~= "" and " [LOCAL OVERRIDE]" or "")
        LabelCurrent:Set("📝 Current Word: " .. w .. postfix)
        LabelLength:Set(string.format("📏 Length: %d characters", #w))
    else
        LabelCurrent:Set("📝 Current Word: Waiting...")
        LabelLength:Set("📏 Length: 0 characters")
    end
end

function RefreshStats()
    if not ScriptRunning then return end
    S1:Set("🤖 Auto-Typed: " .. Stats.Typed)
    S2:Set("📋 Copied & Pasted: " .. Stats.Pasted)
    S3:Set("📊 Total Processed: " .. Stats.Total)
end

-- Create tabs
local TabHome = Window:CreateTab("🏠 Home", 7733960981)
local TabWords = Window:CreateTab("🔤 Override", 4370344717)
local TabStats = Window:CreateTab("📊 Statistics", 4483362458)
local TabSettings = Window:CreateTab("⚙️ Settings", 7734053495)

-- Home tab elements
local LabelCurrent = TabHome:CreateLabel("📝 Current Word: None")
local LabelLength = TabHome:CreateLabel("📏 Length: 0 characters")
local LabelProgress = TabHome:CreateLabel("📈 Progress: 0% | 0/0 | 0.0s")
local LabelStatus = TabHome:CreateLabel("⚡ Status: Idle")

TabHome:CreateButton({
    Name = "📋 Copy Current Word",
    Callback = function()
        local w = GetCurrentTargetWord()
        if w ~= "" then setclipboard(w) end
    end
})

TabHome:CreateDivider()

-- Auto Inject toggle (primary)
TabHome:CreateToggle({
    Name = "⚡ AUTO INJECT (letter‑by‑letter when word changes)",
    CurrentValue = false,
    Callback = function(v)
        Config.AutoInject = v
        if v then
            if not Config.AutoType then Config.AutoType = true end
            Config.CopyPaste = false
            Config.TypoFix = false
            LastHandledWord = ""
            Rayfield:Notify({Title = "Auto Inject", Content = "Enabled. Auto Type turned ON.", Duration = 2})
        end
    end
})

TabHome:CreateToggle({
    Name = "🤖 AUTO TYPE (full simulation, repairs mistakes)",
    CurrentValue = false,
    Callback = function(v)
        Config.AutoType = v
        if v then
            Config.CopyPaste = false
            Config.TypoFix = false
            Config.AutoInject = false
            LastHandledWord = ""
        else
            IsBusy = false
            CurrentTypingProgress = {current = 0, total = 0, startTime = 0}
            LabelStatus:Set("⚡ Status: Idle")
        end
    end
})

TabHome:CreateToggle({
    Name = "📋 BYPASS PASTE (Instant Fill + Enter)",
    CurrentValue = false,
    Callback = function(v)
        Config.CopyPaste = v
        if v then
            Config.AutoType = false
            Config.TypoFix = false
            Config.AutoInject = false
            LastHandledWord = ""
        else
            IsBusy = false
            CurrentTypingProgress = {current = 0, total = 0, startTime = 0}
            LabelStatus:Set("⚡ Status: Idle")
        end
    end
})

TabHome:CreateToggle({
    Name = "🔧 TYPO FIXER (auto‑correct while typing)",
    CurrentValue = false,
    Callback = function(v)
        Config.TypoFix = v
        if v then
            Config.AutoType = false
            Config.CopyPaste = false
            Config.AutoInject = false
        end
    end
})

TabHome:CreateToggle({
    Name = "↩️ AUTO ENTER (submits answer)",
    CurrentValue = true,
    Callback = function(v) Config.AutoEnter = v end
})

-- Override tab
TabWords:CreateLabel("👑 Local Dictionary Override")
TabWords:CreateInput({
    Name = "Force Word",
    PlaceholderText = "Type a custom word here...",
    CurrentValue = "",
    Callback = function(v)
        if v and v ~= "" then
            LocalOverrideWord = tostring(v)
            LastHandledWord = ""
            UpdateCurrentWord()
            ForceUpdateGameUI(LocalOverrideWord)
        end
    end
})
TabWords:CreateButton({
    Name = "❌ Clear Override",
    Callback = function()
        LocalOverrideWord = ""
        LastHandledWord = ""
        UpdateCurrentWord()
    end
})

-- Stats tab
local S1 = TabStats:CreateLabel("🤖 Auto-Typed: 0")
local S2 = TabStats:CreateLabel("📋 Copied & Pasted: 0")
local S3 = TabStats:CreateLabel("📊 Total Processed: 0")
TabStats:CreateButton({
    Name = "🔄 Reset Statistics",
    Callback = function()
        Stats = {Typed = 0, Pasted = 0, Total = 0}
        RefreshStats()
    end
})

-- Settings tab
TabSettings:CreateInput({
    Name = "⚡ CPS (1-100)",
    PlaceholderText = "Enter CPS",
    CurrentValue = tostring(Config.CPS),
    Callback = function(v)
        local n = tonumber(v)
        if n and n >= 1 then Config.CPS = n end
    end
})
TabSettings:CreateSlider({
    Name = "⏱️ Copy Paste Delay (sec)",
    Range = {0, 3}, Increment = 0.05, CurrentValue = 0,
    Callback = function(v) Config.CopyPasteDelay = v end
})
TabSettings:CreateSlider({
    Name = "⏰ Cooldown Between Words (sec)",
    Range = {0.1, 5}, Increment = 0.1, CurrentValue = 1.2,
    Callback = function(v) TYPING_COOLDOWN = v end
})
TabSettings:CreateDivider()
TabSettings:CreateToggle({
    Name = "🌐 GitHub Gist Sync",
    CurrentValue = false,
    Callback = function(v)
        SyncEnabled = v
        if v then LoadWordsFromGist() end
    end
})
TabSettings:CreateDivider()
TabSettings:CreateButton({
    Name = "❌ Terminate Script",
    Callback = function()
        ScriptRunning = false
        Config.AutoType = false
        Config.CopyPaste = false
        Config.TypoFix = false
        Config.AutoInject = false
        pcall(function() Window:Destroy() end)
    end
})

-- Update loop for progress display
task.spawn(function()
    while ScriptRunning do
        UpdateProgressDisplay()
        task.wait(0.05)
    end
end)

-- Word change listener
WordValue.Changed:Connect(function(newWord)
    if not ScriptRunning then return end
    LastHandledWord = ""
    UpdateCurrentWord()
    if LocalOverrideWord == "" then ForceUpdateGameUI(newWord) end
    if SyncEnabled and newWord ~= "" then SaveWordToGist(newWord) end
end)
UpdateCurrentWord()

-- Main automation loop
task.spawn(function()
    while ScriptRunning do
        local textbox = findMyTextbox()
        local curWord = GetCurrentTargetWord()

        -- Sync game word back if needed
        if textbox and textbox.Text ~= "" and not Config.TypoFix and LocalOverrideWord == "" then
            if WordValue.Value ~= textbox.Text then WordValue.Value = textbox.Text end
        end

        if textbox and not IsBusy and curWord ~= "" and curWord ~= LastHandledWord then
            if Config.AutoInject and Config.AutoType then
                LabelStatus:Set("💉 Status: Auto Injecting...")
                local ok = DoAutoInject(curWord, textbox)
                if ok then LastHandledWord = curWord end
                LabelStatus:Set("⚡ Status: Idle")
            elseif Config.CopyPaste then
                LabelStatus:Set("📋 Status: Copy Pasting...")
                local ok = DoCopyPaste(curWord, textbox)
                if ok then LastHandledWord = curWord end
                LabelStatus:Set("⚡ Status: Idle")
            elseif Config.AutoType then
                if (tick() - LastTypingTime) >= TYPING_COOLDOWN then
                    LabelStatus:Set("🚀 Status: Auto Typing...")
                    local ok = DoAutoType(curWord, textbox)
                    if ok then LastHandledWord = curWord end
                    LabelStatus:Set("⚡ Status: Idle")
                end
            end
        end
        task.wait(0.01)
    end
end)

-- Typo Fixer (keyboard mashing protection)
task.spawn(function()
    local lastText = ""
    while ScriptRunning do
        if Config.TypoFix and not IsBusy then
            local textbox = findMyTextbox()
            local target = GetCurrentTargetWord()
            if textbox and textbox:IsFocused() and target and target ~= "" then
                local current = textbox.Text
                if current ~= lastText then
                    if #current > 0 then
                        local correct = target:sub(1, #current)
                        if current ~= correct then
                            textbox.Text = correct
                            textbox.CursorPosition = #correct + 1
                        end
                        if #current == #target and current == target and Config.AutoEnter then
                            if (tick() - LastSubmitTime) > 0.5 then
                                LastSubmitTime = tick()
                                textbox:CaptureFocus()
                                task.wait()
                                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                                task.wait(0.02)
                                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                            end
                        end
                    end
                    lastText = textbox.Text
                end
            elseif textbox then
                lastText = textbox.Text
            end
        end
        task.wait()
    end
end)

-- Right Control shortcut (sends 'a' + Enter)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not ScriptRunning then return end
    if input.KeyCode == Enum.KeyCode.RightControl and not IsBusy then
        local tb = findMyTextbox()
        if tb then
            tb:CaptureFocus()
            task.wait(0.01)
            tb.Text = "a"
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end
    end
end)

Rayfield:Notify({Title = "✅ Ready", Content = "All features restored – Auto Inject toggle ready", Duration = 3})
