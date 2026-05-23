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
local TYPING_COOLDOWN = 1.7 -- Слегка уменьшен для более агрессивной реакции на новые слова
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
    
    if pg:FindFirstChild("Textbox") and pg.Textbox:FindFirstChild("TextBox") then
        local tb = pg.Textbox.TextBox
        if isRealTurnTextbox(tb) then return tb end
    end
    
    for _, obj in ipairs(pg:GetDescendants()) do
        if isRealTurnTextbox(obj) then return obj end
    end
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

        -- If textbox already correct
        if current == expected then
            return
        end

        -- If textbox contains extra garbage
        if #current > #expected then
            ForceText(expected)
            return
        end

        -- If current text is valid partial prefix
        if #current > 0 and word:sub(1, #current) == current then
            lastGoodText = current
            return
        end

        -- Restore latest known good text
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

        -- Dynamic recovery if textbox got partially reset
        local current = textbox.Text

        if current ~= expected then
            if #current > 0 and word:sub(1, #current) == current then
                i = #current
            end
        end

        i += 1
    end

    -- Final hard enforcement
    ForceText(word)

    -- Prevent extra key bleed
    task.wait()

    ForceText(word)

    if pressEnter and Config.AutoEnter and IsValid() then
        textbox:CaptureFocus()

        task.wait()

        VirtualInputManager:SendKeyEvent(
            true,
            Enum.KeyCode.Return,
            false,
            game
        )

        task.wait(0.015)

        VirtualInputManager:SendKeyEvent(
            false,
            Enum.KeyCode.Return,
            false,
            game
        )

        -- Remove accidental trailing letters after submit
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

TabHome:CreateDivider()

TabHome:CreateToggle({
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
            LastHandledWord = "" -- Мгновенный сброс памяти для форсирования повторного ввода
            UpdateCurrentWord()
            ForceUpdateGameUI(LocalOverrideWord)
        end
    end
})

TabWords:CreateButton({
    Name = "❌ Clear Override",
    Callback = function()
        LocalOverrideWord = ""
        LastHandledWord = "" -- Сброс памяти для возврата к игровому слову
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
    
    -- Мгновенно сбрасываем состояние старого слова при получении нового из сети
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

-- // ГЛАВНЫЙ ПОТОК ОБРАБОТКИ АВТО-МАКРОСОВ //
task.spawn(function()
    while ScriptRunning do
        local textbox = findMyTextbox()
        local curWord = GetCurrentTargetWord()
        
        if textbox and textbox.Text ~= "" and not Config.TypoFix and LocalOverrideWord == "" then
            if WordValue.Value ~= textbox.Text then
                WordValue.Value = textbox.Text
            end
        end
        
        -- Условие срабатывает сразу, как только curWord перестает быть равен LastHandledWord
        if textbox and not IsBusy and curWord ~= "" and curWord ~= LastHandledWord then
            if Config.CopyPaste and #textbox.Text > 0 then
                LabelStatus:Set("📋 Status: Copy Pasting...")
                local success = DoCopyPaste(curWord, textbox)
                if success then LastHandledWord = curWord end
                LabelStatus:Set("⚡ Status: Idle")
            elseif Config.AutoType then
                if (tick() - LastTypingTime) >= TYPING_COOLDOWN then
                    LabelStatus:Set("🚀 Status: Auto Typing...")
                    local success = DoAutoType(curWord, textbox)
                    if success then 
                        LastHandledWord = curWord -- Закрепляем слово, чтобы не спамить его повторно
                    end
                    LabelStatus:Set("⚡ Status: Idle")
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

Rayfield:LoadConfiguration()
