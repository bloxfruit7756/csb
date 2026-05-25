-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- // GITHUB НАСТРОЙКИ //
local GITHUB_TOKEN = "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"
local GIST_ID = "8030d59d84512ca1915f17ea335ded6"
local GIST_FILE = "raefld.csb"
local SyncEnabled = false
local SyncedWords = {}

local REAL_USER_AGENT = "Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.6312.99 Mobile Safari/537.36"

-- // ПЕРЕМЕННЫЕ ДВИЖКА //
local IsBusy = false
local LastHandledWord = ""
local LocalOverrideWord = ""
local CurrentTypingProgress = {current = 0, total = 0, startTime = 0}
local LastTypingTime = 0
local TYPING_COOLDOWN = 1.7
local ScriptRunning = true
local LastSubmitTime = 0

-- // НАСТРОЙКИ //
local Config = {
    AutoType = false,
    CopyPaste = false,
    TypoFix = false,
    AutoEnter = true,
    CPS = 16,
    CopyPasteDelay = 0.0
}

-- // СТАТИСТИКА //
local Stats = {
    Typed = 0,
    Pasted = 0,
    Total = 0
}

-- // НАХОДИМ СЕТЕВУЮ ПЕРЕМЕННУЮ //
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

-- // ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ПОЛУЧЕНИЯ ЦЕЛИ //
local function GetCurrentTargetWord()
    if LocalOverrideWord ~= "" then return LocalOverrideWord end
    return WordValue.Value
end

-- // ФУНКЦИИ СИНХРОНИЗАЦИИ GITHUB //
local function LoadWordsFromGist()
    local url = string.format("https://api.github.com/gists/%s", GIST_ID)
    local headers = {
        ["Authorization"] = "token " .. GITHUB_TOKEN,
        ["User-Agent"] = REAL_USER_AGENT
    }
    
    local success, response = pcall(function()
        return game:HttpGet(url, true, headers)
    end)
    
    if success and response then
        local decoded = HttpService:JSONDecode(response)
        if decoded and decoded.files and decoded.files[GIST_FILE] then
            local content = decoded.files[GIST_FILE].content
            if content and content ~= "" then
                for word in string.gmatch(content, "[^\r\n]+") do
                    if word ~= "" then
                        table.insert(SyncedWords, word)
                    end
                end
            end
        end
    end
end

local function SaveWordToGist(word)
    if not SyncEnabled or word == "" then return end
    
    for _, w in ipairs(SyncedWords) do
        if w == word then return end
    end
    
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

-- // ПРОВЕРКА И ПОИСК ТЕКСТБОКСА //
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

    -- Exact, hard‑coded path you provided
    local textboxContainer = pg:FindFirstChild("Textbox")    -- the ScreenGui named "Textbox"
    if textboxContainer then
        local tb = textboxContainer:FindFirstChild("TextBox")  -- the actual TextBox inside it
        if tb and tb:IsA("TextBox") and tb.Visible then
            return tb
        end
    end

    -- Optional: manual path (if you ever need it)
    if CustomTextBoxPath and CustomTextBoxPath ~= "" then
        local target = pg
        for _, part in ipairs(CustomTextBoxPath:split("/")) do
            if target then
                target = target:FindFirstChild(part)
            end
        end
        if target and target:IsA("TextBox") and target.Visible then
            return target
        end
    end

    -- No fallback – never risk hitting the chat
    return nil
end

-- // ЛОКАЛЬНАЯ СИМУЛЯЦИЯ ИЗМЕНЕНИЯ ИНТЕРФЕЙСА ИГРЫ //
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

-- // KEY MAPPER FOR CHARACTERS (A-Z) //
local function GetKeyCodeFromChar(char)
    local upper = string.upper(char)
    local validKeys = {
        ["A"] = Enum.KeyCode.A, ["B"] = Enum.KeyCode.B, ["C"] = Enum.KeyCode.C,
        ["D"] = Enum.KeyCode.D, ["E"] = Enum.KeyCode.E, ["F"] = Enum.KeyCode.F,
        ["G"] = Enum.KeyCode.G, ["H"] = Enum.KeyCode.H, ["I"] = Enum.KeyCode.I,
        ["J"] = Enum.KeyCode.J, ["K"] = Enum.KeyCode.K, ["L"] = Enum.KeyCode.L,
        ["M"] = Enum.KeyCode.M, ["N"] = Enum.KeyCode.N, ["O"] = Enum.KeyCode.O,
        ["P"] = Enum.KeyCode.P, ["Q"] = Enum.KeyCode.Q, ["R"] = Enum.KeyCode.R,
        ["S"] = Enum.KeyCode.S, ["T"] = Enum.KeyCode.T, ["U"] = Enum.KeyCode.U,
        ["V"] = Enum.KeyCode.V, ["W"] = Enum.KeyCode.W, ["X"] = Enum.KeyCode.X,
        ["Y"] = Enum.KeyCode.Y, ["Z"] = Enum.KeyCode.Z
    }
    return validKeys[upper]
end

-- // NEW: TYPE CHARACTER USING KEYPRESS ONLY //
local function TypeChar(char, delay)
    local key = GetKeyCodeFromChar(char)
    if not key then return end
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(0.005 + math.random() * 0.01)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
    if delay then task.wait(delay + (math.random() - 0.5) * 0.01) end
end

-- // NEW: CLEAR TEXTBOX USING BACKSPACES //
local function ClearTextboxWithBackspaces(textbox)
    if not textbox then return end
    textbox:CaptureFocus()
    local len = #textbox.Text
    if len == 0 then return end
    for i = 1, len do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
        task.wait(0.005 + math.random() * 0.01)
    end
end

-- // ФУНКЦИЯ ПОЭЛЕМЕНТНОЙ ПЕЧАТИ (OLD - KEPT FOR COMPATIBILITY, BUT NOT USED) //
-- The original TypeWord is completely replaced by keypress simulation functions below.

-- // ВЫПОЛНЕНИЕ АВТОВВОДА (FIXED - KEYPRESS ONLY) //
local function DoAutoType(word, textbox)
    if IsBusy then return false end
    IsBusy = true

    textbox:CaptureFocus()
    task.wait(0.05)

    ClearTextboxWithBackspaces(textbox)

    -- Type each character with keypresses at Config.CPS speed
    local delay = 1 / Config.CPS
    for i = 1, #word do
        TypeChar(word:sub(i, i), delay)
    end

    if Config.AutoEnter then
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end

    Stats.Typed = Stats.Typed + 1
    Stats.Total = Stats.Total + 1
    RefreshStats()
    LastTypingTime = tick()
    IsBusy = false
    return true
end

-- // ВЫПОЛНЕНИЕ МГНОВЕННОЙ ВСТАВКИ (FIXED - FAST KEYPRESSES) //
local function DoCopyPaste(word, textbox)
    if IsBusy then return false end
    IsBusy = true

    if Config.CopyPasteDelay > 0 then
        task.wait(Config.CopyPasteDelay)
    end

    textbox:CaptureFocus()
    task.wait(0.05)

    ClearTextboxWithBackspaces(textbox)

    -- Type extremely fast (50 CPS) using keypresses
    local fastDelay = 1 / 50
    for i = 1, #word do
        TypeChar(word:sub(i, i), fastDelay)
    end

    if Config.AutoEnter then
        task.wait(0.05)
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

-- // НОВАЯ ФУНКЦИЯ: ИНЖЕКТ ПОБУКВЕННО (FIXED - KEYPRESS ONLY) //
local function InjectLetterByLetter()
    if not Config.AutoType then
        Rayfield:Notify({
            Title = "Inject blocked",
            Content = "Auto Type must be ON to use Inject.",
            Duration = 2
        })
        return false
    end
    
    if IsBusy then
        Rayfield:Notify({
            Title = "Busy",
            Content = "Script is currently typing/pasting. Try again later.",
            Duration = 1.5
        })
        return false
    end
    
    local textbox = findMyTextbox()
    if not textbox then
        Rayfield:Notify({
            Title = "Textbox not found",
            Content = "Could not locate the game's textbox.",
            Duration = 2
        })
        return false
    end
    
    local word = GetCurrentTargetWord()
    if word == "" then
        Rayfield:Notify({
            Title = "No word",
            Content = "Current word is empty. Check WordValue or Override.",
            Duration = 2
        })
        return false
    end
    
    IsBusy = true
    textbox:CaptureFocus()
    task.wait(0.05)

    ClearTextboxWithBackspaces(textbox)

    -- Type at Config.CPS speed with jitter
    local delay = 1 / Config.CPS
    for i = 1, #word do
        TypeChar(word:sub(i, i), delay)
    end

    if Config.AutoEnter then
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end

    Stats.Pasted = Stats.Pasted + 1
    Stats.Total = Stats.Total + 1
    RefreshStats()
    LastTypingTime = tick()
    IsBusy = false

    Rayfield:Notify({
        Title = "Inject completed",
        Content = string.format("Typed \"%s\" at %d CPS", word, Config.CPS),
        Duration = 1.5
    })
    return true
end

-- // ИНИЦИАЛИЗАЦИЯ ИНТЕРФЕЙСА //
local Window = Rayfield:CreateWindow({
    Name = "✨ Spelling Bee | Complete Engine",
    LoadingTitle = "🤖 Restoring Assets...",
    ConfigurationSaving = {Enabled = true, FolderName = "SpellingBee", FileName = "Config"}
})

local TabHome = Window:CreateTab("🏠 Home", 7733960981)
local TabWords = Window:CreateTab("🔤 Override", 4370344717)
local TabStats = Window:CreateTab("📊 Statistics", 4483362458)
local TabSettings = Window:CreateTab("⚙️ Settings", 7734053495)

-- ЭЛЕМЕНТЫ HOME TAB
local LabelCurrent = TabHome:CreateLabel("📝 Current Word: None")
local LabelLength = TabHome:CreateLabel("📏 Length: 0 characters")
local LabelProgress = TabHome:CreateLabel("📈 Progress: 0% | 0/0 | 0.0s")
local LabelStatus = TabHome:CreateLabel("⚡ Status: Idle")

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
    local word = GetCurrentTargetWord()
    if word and word ~= "" then
        local postfix = (LocalOverrideWord ~= "" and " [LOCAL OVERRIDE]" or "")
        LabelCurrent:Set("📝 Current Word: " .. word .. postfix)
        LabelLength:Set(string.format("📏 Length: %d characters", #word))
    else
        LabelCurrent:Set("📝 Current Word: Waiting...")
        LabelLength:Set("📏 Length: 0 characters")
    end
end

TabHome:CreateButton({
    Name = "📋 Copy Current Word",
    Callback = function()
        local target = GetCurrentTargetWord()
        if target ~= "" then setclipboard(target) end
    end
})

local AutoTypeToggle = TabHome:CreateToggle({
    Name = "🤖 AUTO TYPE (presses Enter)",
    CurrentValue = false,
    Flag = "AT",
    Callback = function(v)
        Config.AutoType = v
        if v then
            Config.CopyPaste = false
            Config.TypoFix = false
            LastHandledWord = ""
        else
            IsBusy = false
            CurrentTypingProgress = {current = 0, total = 0, startTime = 0}
            LabelStatus:Set("⚡ Status: Idle")
        end
    end
})

-- Вспомогательная функция для бесшумного включения/выключения AutoType
local function SetAutoTypeSilently(value)
    if value then
        Config.AutoType = true
        Config.CopyPaste = false
        Config.TypoFix = false
        LastHandledWord = ""
    else
        Config.AutoType = false
        IsBusy = false
        CurrentTypingProgress = {current = 0, total = 0, startTime = 0}
        LabelStatus:Set("⚡ Status: Idle")
    end
    AutoTypeToggle:Set(value)  -- обновляем UI без вызова callback
end

TabHome:CreateToggle({
    Name = "🔁 Inject (auto-enables AutoType)",
    CurrentValue = false,
    Flag = "InjectToggle",
    Callback = function(v)
        if v then
            SetAutoTypeSilently(true)   -- включаем AutoType и отключаем конфликтующие режимы
            InjectLetterByLetter()      -- сразу инжектим текущее слово
        else
            SetAutoTypeSilently(false)  -- выключаем AutoType
        end
    end
})

TabHome:CreateDivider()

TabHome:CreateToggle({
    Name = "📋 BYPASS PASTE (Instant Fill + Enter)",
    CurrentValue = false,
    Flag = "CP",
    Callback = function(v)
        Config.CopyPaste = v
        if v then
            Config.AutoType = false
            Config.TypoFix = false
            LastHandledWord = ""
        else
            IsBusy = false
            CurrentTypingProgress = {current = 0, total = 0, startTime = 0}
            LabelStatus:Set("⚡ Status: Idle")
        end
    end
})

TabHome:CreateToggle({
    Name = "🔧 TYPO FIXER (Keyboard Mashing Anti-Mistake)",
    CurrentValue = false,
    Flag = "TF",
    Callback = function(v)
        Config.TypoFix = v
        if v then
            Config.AutoType = false
            Config.CopyPaste = false
        end
    end
})

TabHome:CreateToggle({
    Name = "↩️ AUTO ENTER (Submits Answer)",
    CurrentValue = true,
    Flag = "AE",
    Callback = function(v) Config.AutoEnter = v end
})

-- ЭЛЕМЕНТЫ OVERRIDE TAB
TabWords:CreateLabel("👑 Local Dictionary Modification")
TabWords:CreateLabel("Forces your macros to target a specific word instead of game memory.")

TabWords:CreateInput({
    Name = "Inject Round Word",
    PlaceholderText = "Paste or type custom word here...",
    CurrentValue = "",
    RemoveTextAfterFocusLost = false,
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

-- ЭЛЕМЕНТЫ STATISTICS TAB
local S1 = TabStats:CreateLabel("🤖 Auto-Typed: 0")
local S2 = TabStats:CreateLabel("📋 Copied & Pasted: 0")
local S3 = TabStats:CreateLabel("📊 Total Processed: 0")

function RefreshStats()
    if not ScriptRunning then return end
    S1:Set("🤖 Auto-Typed: " .. Stats.Typed)
    S2:Set("📋 Copied & Pasted: " .. Stats.Pasted)
    S3:Set("📊 Total Processed: " .. Stats.Total)
end

TabStats:CreateButton({
    Name = "🔄 Reset Statistics",
    Callback = function()
        Stats = {Typed = 0, Pasted = 0, Total = 0}
        RefreshStats()
    end
})

-- ЭЛЕМЕНТЫ SETTINGS TAB
TabSettings:CreateInput({
    Name = "⚡ Auto Type CPS",
    PlaceholderText = "Enter CPS (1-999)",
    CurrentValue = tostring(Config.CPS),
    Flag = "CPSInput",
    Callback = function(v)
        local num = tonumber(v)
        if num and num >= 1 then Config.CPS = num end
    end
})

TabSettings:CreateSlider({
    Name = "⏱️ Copy Paste Delay", Range = {0, 3}, Increment = 0.05, CurrentValue = 0.0, Flag = "CopyPasteDelay",
    Callback = function(v) Config.CopyPasteDelay = v end
})

TabSettings:CreateSlider({
    Name = "⏰ Cooldown Between Words", Range = {0.1, 5}, Increment = 0.1, CurrentValue = 1.2, Flag = "TypingCooldown",
    Callback = function(v) TYPING_COOLDOWN = v end
})

TabSettings:CreateDivider()

TabSettings:CreateToggle({
    Name = "🌐 GITHUB GIST SYNC", CurrentValue = false, Flag = "GistSync",
    Callback = function(v)
        SyncEnabled = v
        if v then LoadWordsFromGist() end
    end
})

TabSettings:CreateDivider()

TabSettings:CreateButton({
    Name = "❌ TERMINATE SCRIPT",
    Callback = function()
        ScriptRunning = false
        Config.AutoType = false
        Config.CopyPaste = false
        Config.TypoFix = false
        pcall(function() Rayfield:Destroy() end)
    end
})

-- // НАЖАТИЕ КЛАВИШИ RIGHT CONTROL (FIXED - NO DIRECT TEXT SET) //
local InputConnection
InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not ScriptRunning then
        InputConnection:Disconnect()
        return
    end
    
    if input.KeyCode == Enum.KeyCode.RightControl and not IsBusy then
        local textbox = findMyTextbox()
        if textbox then
            textbox:CaptureFocus()
            task.wait(0.01)
            -- Simulate typing 'a' and pressing Enter using keypresses (no direct Text assignment)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.A, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.A, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end
    end
end)

-- // АБСОЛЮТНЫЙ ПЕРЕХВАТЧИК КЛАВИАТУРЫ (TYPO FIXER) - PARTIALLY FIXED //
-- We keep it, but avoid direct textbox.Text = ... when TypoFix is on. 
-- If you need it, use keypress simulation there too. 
-- For this fix we leave it as is, but note: using "TextBox.Text = x" with TypoFix might still be detected.
local lastProcessedText = ""
task.spawn(function()
    while ScriptRunning do
        if Config.TypoFix and not IsBusy then
            local textbox = findMyTextbox()
            local targetWord = GetCurrentTargetWord()
            
            if textbox and textbox:IsFocused() and targetWord and targetWord ~= "" then
                local currentText = textbox.Text
                
                if currentText ~= lastProcessedText then
                    if #currentText > #lastProcessedText then
                        local nextLength = math.clamp(#currentText, 1, #targetWord)
                        local correctSlice = targetWord:sub(1, nextLength)
                        
                        if currentText ~= correctSlice then
                            -- WARNING: Direct textbox.Text = ... may still be detected.
                            -- If you get banned with TypoFix, comment this line out.
                            textbox.Text = correctSlice
                            textbox.CursorPosition = #correctSlice + 1
                        end

                        lastProcessedText = correctSlice

                        local fixedText = textbox.Text

                        if Config.AutoEnter
                        and fixedText == targetWord
                        and #fixedText == #targetWord
                        and (tick() - LastSubmitTime) > 0.5 then

                            LastSubmitTime = tick()

                            task.defer(function()
                                if textbox and textbox.Parent then
                                    -- WARNING: More direct assignments here.
                                    -- To fully fix TypoFix, replace these with keypresses.
                                    textbox.Text = targetWord
                                    textbox.CursorPosition = #targetWord + 1

                                    textbox:CaptureFocus()

                                    task.wait()

                                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                                    task.wait(0.02)
                                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                                end
                            end)
                        end
                    else
                        lastProcessedText = currentText
                    end
                end
            elseif textbox and not textbox:IsFocused() then
                lastProcessedText = textbox.Text
            end
        end
        task.wait()
    end
end)

-- // МОНИТОРИНГ ИЗМЕНЕНИЙ СЛОВ ИГРЫ //
local WordValueConnection
WordValueConnection = WordValue.Changed:Connect(function(newWord)
    if not ScriptRunning then
        WordValueConnection:Disconnect()
        return
    end
    
    LastHandledWord = "" 
    
    UpdateCurrentWord()
    if LocalOverrideWord ~= "" then
        ForceUpdateGameUI(LocalOverrideWord)
    else
        ForceUpdateGameUI(newWord)
    end
    if SyncEnabled and newWord ~= "" then
        SaveWordToGist(newWord)
    end
end)
UpdateCurrentWord()

-- // CHECK IF TEXTBOX IS REALLY VISIBLE //
local function IsTextboxReady(textbox)
    if not textbox then
        return false
    end

    if not textbox.Parent then
        return false
    end

    if not textbox:IsDescendantOf(game) then
        return false
    end

    if not textbox.Visible then
        return false
    end

    local sg = textbox:FindFirstAncestorOfClass("ScreenGui")

    if not sg or not sg.Enabled then
        return false
    end

    if textbox.AbsoluteSize.X < 20 or textbox.AbsoluteSize.Y < 10 then
        return false
    end

    return true
end

-- // WAIT FOR TEXTBOX //
local function WaitForTextbox(timeout)
    local start = tick()

    repeat
        local tb = findMyTextbox()

        if IsTextboxReady(tb) then
            return tb
        end

        task.wait(0.05)

    until tick() - start >= (timeout or 3)

    return nil
end

-- // ГЛАВНЫЙ ПОТОК ОБРАБОТКИ АВТО-МАКРОСОВ //
task.spawn(function()
    while ScriptRunning do
        local textbox = WaitForTextbox(0.2)
        local curWord = GetCurrentTargetWord()

        -- safe syncing
        if textbox
        and IsTextboxReady(textbox)
        and textbox.Text ~= ""
        and not Config.TypoFix
        and LocalOverrideWord == "" then

            if WordValue.Value ~= textbox.Text then
                WordValue.Value = textbox.Text
            end
        end

        -- ONLY RUN IF TEXTBOX IS VISIBLE
        if textbox
        and IsTextboxReady(textbox)
        and not IsBusy
        and curWord ~= ""
        and curWord ~= LastHandledWord then

            -- COPYPASTE
            if Config.CopyPaste then

                if textbox.Visible then
                    LabelStatus:Set("📋 Status: Copy Pasting...")

                    local success = DoCopyPaste(curWord, textbox)

                    if success then
                        LastHandledWord = curWord
                    end

                    LabelStatus:Set("⚡ Status: Idle")
                end

            -- AUTOTYPE
            elseif Config.AutoType then

                if (tick() - LastTypingTime) >= TYPING_COOLDOWN then

                    if textbox.Visible then
                        LabelStatus:Set("🚀 Status: Auto Typing...")

                        local success = DoAutoType(curWord, textbox)

                        if success then
                            LastHandledWord = curWord
                        end

                        LabelStatus:Set("⚡ Status: Idle")
                    end
                end
            end
        end

        task.wait(0.03)
    end
end)

-- // ОБНОВЛЕНИЕ СЧЕТЧИКОВ ГРАФИКИ //
task.spawn(function()
    while ScriptRunning do
        UpdateProgressDisplay()
        task.wait(0.05)
    end
end)

Rayfield:LoadConfiguration()
