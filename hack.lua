-- Load Rayfield (Updated with stable GitHub raw paths and fallback mirror)
local Rayfield = nil
local hudSuccess, hudError = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()
end)

if hudSuccess and hudError then
    Rayfield = hudError
else
    -- Fallback stable backup mirror if official repo times out
    local fallbackSuccess, fallbackError = pcall(function()
        return loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua'))()
    end)
    if fallbackSuccess then
        Rayfield = fallbackError
    else
        warn("Spelling Bee Engine: Failed to load Rayfield UI completely. Error: " .. tostring(hudError))
        return
    end
end

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
local CurrentTypingId = ""

-- Флаги предотвращения спама при обычной печати / Typo Fixer / Hotkey overrides
local LastCopiedWord = ""
local LastChattedWord = ""

-- // НАСТРОЙКИ //
local Config = {
    AutoType = false,
    CopyPaste = false,
    TypoFix = false,
    AutoCopy = false,
    AutoChat = false,
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

-- Определение функции до её вызова в методах
local function RefreshStats()
    if not ScriptRunning then return end
    if S1 and S2 and S3 then
        S1:Set("🤖 Auto-Typed: " .. Stats.Typed)
        S2:Set("📋 Copied & Pasted: " .. Stats.Pasted)
        S3:Set("📊 Total Processed: " .. Stats.Total)
    end
end

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

-- // ФУНКЦИЯ ОПРЕДЕЛЕНИЯ КЛАВИАТУРНОГО МАША (ОТКЛЮЧЕНА/ДЕАКТИВИРОВАНА ДЛЯ РУЧНОГО РЕЖИМА) //
local function IsKeyboardMash(str)
    return false
end

-- Вспомогательная функция автокопирования
local function HandleAutoCopy()
    if Config.AutoCopy then
        local target = GetCurrentTargetWord()
        if target and #target > 1 and target ~= LastCopiedWord then
            LastCopiedWord = target
            setclipboard(target)
        end
    end
end

-- Вспомогательная функция отправки в чат
local function HandleAutoChat()
    if Config.AutoChat then
        local target = GetCurrentTargetWord()
        if target and #target > 1 and target ~= LastChattedWord then
            LastChattedWord = target
            local formattedMessage = "Word : " .. target
            
            local TextChatService = game:GetService("TextChatService")
            if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                local generalChannel = TextChatService:FindFirstChild("RBXGeneral", true)
                if generalChannel and generalChannel:IsA("TextChannel") then
                    generalChannel:SendAsync(formattedMessage)
                    return
                end
            end
            
            local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            if chatEvents then
                local sayMessage = chatEvents:FindFirstChild("SayMessageRequest")
                if sayMessage and sayMessage:IsA("RemoteEvent") then
                    sayMessage:FireServer(formattedMessage, "All")
                end
            end
        end
    end
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
    if not SyncEnabled or word == "" or #word <= 1 then return end
    
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

    local textboxContainer = pg:FindFirstChild("Textbox")
    if textboxContainer then
        local tb = textboxContainer:FindFirstChild("TextBox")
        if tb and tb:IsA("TextBox") and tb.Visible then
            return tb
        end
    end

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

    return nil
end

-- // ЛОКАЛЬНАЯ СИМУЛЯЦИЯ ИЗМЕНЕНИЯ ИНТЕРФЕЙСА ИГРЫ //
local function ForceUpdateGameUI(newWord)
    if newWord == "" or #newWord <= 1 then return end
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

-- // ФУНКЦИЯ ПОЭЛЕМЕНТНОЙ ПЕЧАТИ //
local function TypeWord(textbox, word, cps, pressEnter, modeName)
    if not textbox or not word or word == "" then
        return false
    end

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
        return ScriptRunning
        and textbox
        and textbox.Parent
        and isRealTurnTextbox(textbox)
        and GetCurrentTargetWord() == word
        and CurrentTypingId == typingId
        and (
            (modeName == "AutoType" and Config.AutoType)
            or
            (modeName == "CopyPaste" and Config.CopyPaste)
        )
    end

    local function ForceText(text)
        if textbox.Text ~= text then
            textbox.Text = text
        end

        local desiredCursor = #text + 1

        if textbox.CursorPosition ~= desiredCursor then
            textbox.CursorPosition = desiredCursor
        end
    end

    local function RepairText(expected)
        local now = tick()

        if now - lastRepair < repairCooldown then
            return
        end

        lastRepair = now

        local current = textbox.Text

        if current == expected then
            return
        end

        if #current > #expected then
            ForceText(expected)
            return
        end

        if #current > 0 and word:sub(1, #current) == current then
            lastGoodText = current
            return
        end

        ForceText(expected)
    end

    ForceText("")

    local i = 1

    while i <= #word do
        if not IsValid() then
            return false
        end

        local expected = word:sub(1, i)

        RepairText(expected)
        ForceText(expected)

        lastGoodText = expected
        CurrentTypingProgress.current = i

        local started = tick()

        while tick() - started < delay do
            if not IsValid() then
                return false
            end

            RepairText(expected)
            task.wait()
        end

        local current = textbox.Text

        if current ~= expected then
            if #current > 0 and word:sub(1, #current) == current then
                i = #current
            end
        end

        i += 1
    end

    if not IsValid() then return false end

    ForceText(word)
    task.wait()
    ForceText(word)

    if pressEnter and Config.AutoEnter and IsValid() then
        textbox:CaptureFocus()
        task.wait()

        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.015)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)

        task.delay(0.03, function()
            if textbox
            and textbox.Parent
            and textbox.Text ~= ""
            and textbox.Text ~= word then
                textbox.Text = ""
                textbox.CursorPosition = 1
            end
        end)
    end

    CurrentTypingProgress.current = #word
    return true
end

-- // ВЫПОЛНЕНИЕ АВТОВВОДА //
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

-- // ВЫПОЛНЕНИЕ МГНОВЕННОЙ ВСТАВКИ //
local function DoCopyPaste(word, textbox)
    if IsBusy then return false end
    IsBusy = true
    
    if Config.CopyPasteDelay > 0 then
        task.wait(Config.CopyPasteDelay)
    end
    
    if not Config.CopyPaste or not ScriptRunning or GetCurrentTargetWord() ~= word then 
        IsBusy = false
        return false 
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

-- // ИНЖЕКТ ПОБУКВЕННО //
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
    
    textbox.Text = ""
    task.wait(0.05)
    
    local delay = 1 / Config.CPS
    local typed = ""
    local cancelled = false
    
    for i = 1, #word do
        if not Config.AutoType or not ScriptRunning then
            cancelled = true
            break
        end
        typed = typed .. string.sub(word, i, i)
        textbox.Text = typed
        textbox.CursorPosition = i + 1
        if i < #word then
            task.wait(delay)
        end
    end
    
    if not cancelled and typed == word and Config.AutoEnter and Config.AutoType then
        task.wait(0.05)
        textbox:CaptureFocus()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        
        Stats.Pasted = Stats.Pasted + 1
        Stats.Total = Stats.Total + 1
        RefreshStats()
        LastTypingTime = tick()
        
        Rayfield:Notify({
            Title = "Inject completed",
            Content = string.format("Typed \"%s\" at %d CPS", word, Config.CPS),
            Duration = 1.5
        })
    else
        Rayfield:Notify({
            Title = "Inject stopped",
            Content = "Process cut short. Submission aborted.",
            Duration = 1.5
        })
    end
    
    IsBusy = false
    return not cancelled
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
    AutoTypeToggle:Set(value)
end

-- Тоггл "Inject"
TabHome:CreateToggle({
    Name = "🔁 Inject (auto-enables AutoType)",
    CurrentValue = false,
    Flag = "InjectToggle",
    Callback = function(v)
        if v then
            SetAutoTypeSilently(true)
            InjectLetterByLetter()
        else
            SetAutoTypeSilently(false)
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
    Name = "📋 AUTO COPY (Automatically Copies Current Word)",
    CurrentValue = false,
    Flag = "AC",
    Callback = function(v)
        Config.AutoCopy = v
        if v then
            HandleAutoCopy()
        end
    end
})

TabHome:CreateToggle({
    Name = "💬 AUTO CHAT (Sends 'Word : [word]' to Chat)",
    CurrentValue = false,
    Flag = "ACHAT",
    Callback = function(v)
        Config.AutoChat = v
        if v then
            HandleAutoChat()
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
            HandleAutoCopy()
            HandleAutoChat()
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
        HandleAutoCopy()
        HandleAutoChat()
    end
})

-- ЭЛЕМЕНТЫ STATISTICS TAB
S1 = TabStats:CreateLabel("🤖 Auto-Typed: 0")
S2 = TabStats:CreateLabel("📋 Copied & Pasted: 0")
S3 = TabStats:CreateLabel("📊 Total Processed: 0")

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
        Config.AutoCopy = false
        Config.AutoChat = false
        pcall(function() Rayfield:Destroy() end)
    end
})

-- // НАЖАТИЕ КЛАВИШИ RIGHT CONTROL //
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
            textbox.Text = "a"
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end
    end
end)

-- // АБСОЛЮТНЫЙ ПЕРЕХВАТЧИК КЛАВИАТУРЫ (TYPO FIXER) //
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
    HandleAutoCopy()
    HandleAutoChat()
    
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
    if not textbox then return false end
    if not textbox.Parent then return false end
    if not textbox:IsDescendantOf(game) then return false end
    if not textbox.Visible then return false end

    local sg = textbox:FindFirstAncestorOfClass("ScreenGui")
    if not sg or not sg.Enabled then return false end
    if textbox.AbsoluteSize.X < 20 or textbox.AbsoluteSize.Y < 10 then return false end

    return true
end

-- // WAIT FOR TEXTBOX //
local function WaitForTextbox(timeout)
    local start = tick()
    repeat
        local tb = findMyTextbox()
        if IsTextboxReady(tb) then return tb end
        task.wait(0.05)
    until tick() - start >= (timeout or 3)
    return nil
end

-- // ГЛАВНЫЙ ПОТОК ОБРАБОТКИ АВТО-МАКРОСОВ С ПЕРЕХВАТОМ ДЛЯ РУЧНОГО РЕЖИМА //
task.spawn(function()
    while ScriptRunning do
        local textbox = findMyTextbox()
        
        -- СТРОГИЙ СИНХРОНИЗАТОР: Срабатывает только когда всё остальное выключено!
        if not Config.AutoType and not Config.CopyPaste and not Config.TypoFix then
            if textbox and IsTextboxReady(textbox) and textbox:IsFocused() then
                local manualText = textbox.Text
                if manualText ~= "" and WordValue.Value ~= manualText and LocalOverrideWord == "" then
                    WordValue.Value = manualText
                end
            end
        end

        local curWord = GetCurrentTargetWord()

        if textbox
        and IsTextboxReady(textbox)
        and textbox.Text ~= ""
        and not Config.TypoFix
        and #textbox.Text > 1
        and LocalOverrideWord == "" then
            if WordValue.Value ~= textbox.Text and (Config.AutoType or Config.CopyPaste) then
                WordValue.Value = textbox.Text
            end
        end

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
                    if success then LastHandledWord = curWord end
                    LabelStatus:Set("⚡ Status: Idle")
                end

            -- AUTOTYPE
            elseif Config.AutoType then
                if (tick() - LastTypingTime) >= TYPING_COOLDOWN then
                    if textbox.Visible then
                        LabelStatus:Set("🚀 Status: Auto Typing...")
                        local success = DoAutoType(curWord, textbox)
                        if success then LastHandledWord = curWord end
                        LabelStatus:Set("⚡ Status: Idle")
                    end
                end
            end
        end
        task.wait(0.01)
    end
end)

-- // ОБНОВЛЕНИЕ СЧЕТЧИКОВ ГРАФИКИ //
task.spawn(function()
    while ScriptRunning do
        UpdateProgressDisplay()
        task.wait(0.05)
    end
end)

RefreshStats()
Rayfield:LoadConfiguration()
