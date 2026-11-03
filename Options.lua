--[[
    SpeurtochtNL - Settings window and slash commands
    /speur, /nlquest  settings
    /speur reader     open / close the reader
    /speur vocab      saved words
    /speur export     Anki export
    /speur save w     save a word by typing it (/speur save woord = meaning)
    /speur check      diagnose the reader / clickable words
    /speur report     report the open quest (missing or translation fix) on GitHub
    /speur capture    how many untranslated quests have been recorded
    /speur status     version, build and coverage
]]
local _, NQ = ...

local O = {}

local OPTIONS = {
    { header = "Weergave · Display" },
    { key = "enabled",        nl = "Speurtocht.NL aan",                          en = "Turn the addon on/off" },
    { key = "translateFrame", nl = "Nederlands in het questvenster",          en = "Dutch text in the quest dialog with NPCs" },
    { key = "translateLog",   nl = "Nederlands in het questlogboek",          en = "Dutch text in the quest log details" },
    { key = "logTitles",      nl = "Nederlandse titels in de questlijst (test)", en = "Dutch titles in the quest log list (experimental)" },
    { header = "Engels als hulp · English support" },
    { key = "hoverEnglish",   nl = "NLQuest-knop: Engels tonen bij aanwijzen", en = "Hover the NLQuest button to see the English original" },
    { key = "altPeek",        nl = "Alt ingedrukt houden = Engels",           en = "Hold Alt to temporarily show English" },
    { header = "Lezer · Side-by-side reader" },
    { key = "reader",         nl = "Lezer gebruiken",                         en = "Use the side-by-side reader panel" },
    { key = "readerAutoOpen", nl = "Lezer automatisch openen",                en = "Open the reader whenever you talk to a quest giver" },
    { key = "readerEnglish",  nl = "Engelse kolom tonen",                     en = "Show the English column next to the Dutch" },
    { key = "clickWords",     nl = "Klikbare woorden (woordenlijst)",         en = "Click words in the reader to save them" },
    { key = "markSaved",      nl = "Opgeslagen woorden groen kleuren",        en = "Colour words you already saved" },
    { header = "Overig · Other" },
    { key = "capture",        nl = "Onvertaalde quests bewaren",              en = "Record untranslated quests for future translation batches" },
}

local PRESETS = {
    { label = "Alleen Nederlands", tip = "Dutch only: no reader, no English help",
      set = { translateFrame = true, translateLog = true, hoverEnglish = false, altPeek = false, reader = false } },
    { label = "NL + Engels bij hover", tip = "Dutch in the quest window, English on hover / Alt",
      set = { translateFrame = true, translateLog = true, hoverEnglish = true, altPeek = true, reader = false } },
    { label = "Naast elkaar", tip = "Dutch in the quest window plus the side-by-side reader",
      set = { translateFrame = true, translateLog = true, hoverEnglish = true, altPeek = true,
              reader = true, readerAutoOpen = true, readerEnglish = true } },
}

local function Build()
    local f = NQ.MakeWindow("SpeurtochtNLOptions", 520, 610, "Speurtocht.NL — instellingen")
    O.frame, O.checks = f, {}

    local y = -46
    local presetLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    presetLabel:SetPoint("TOPLEFT", 18, y)
    presetLabel:SetText("Snel kiezen · Presets")
    y = y - 22
    local prev
    for _, p in ipairs(PRESETS) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(156, 22)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 18, y) end
        b:SetText(p.label)
        b:SetScript("OnClick", function()
            for k, v in pairs(p.set) do NQ.db[k] = v end
            NQ:UpdateOptions()
            NQ:Refresh()
            if not NQ.db.reader then NQ:ToggleReader(false) end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(p.tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        prev = b
    end
    y = y - 34

    for _, opt in ipairs(OPTIONS) do
        if opt.header then
            local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            h:SetPoint("TOPLEFT", 18, y - 4)
            h:SetText(opt.header)
            y = y - 24
        else
            local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            cb:SetSize(24, 24)
            cb:SetPoint("TOPLEFT", 22, y)
            local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            label:SetText(opt.nl)
            cb:SetScript("OnClick", function(self)
                NQ.db[opt.key] = self:GetChecked() and true or false
                NQ:Refresh()
                if opt.key == "reader" and not NQ.db.reader then NQ:ToggleReader(false) end
            end)
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(opt.nl, 1, 0.82, 0)
                GameTooltip:AddLine(opt.en, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            O.checks[opt.key] = cb
            y = y - 24
        end
    end

    -- Reader font size
    y = y - 6
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 22, y - 4)
    O.fontLabel = fs
    local minus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    minus:SetSize(28, 20)
    minus:SetPoint("LEFT", fs, "RIGHT", 10, 0)
    minus:SetText("-")
    minus:SetScript("OnClick", function()
        NQ.db.readerFontSize = math.max(10, NQ.db.readerFontSize - 1)
        NQ:UpdateOptions(); NQ:UpdateReader()
    end)
    local plus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    plus:SetSize(28, 20)
    plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    plus:SetText("+")
    plus:SetScript("OnClick", function()
        NQ.db.readerFontSize = math.min(20, NQ.db.readerFontSize + 1)
        NQ:UpdateOptions(); NQ:UpdateReader()
    end)
    local resetPos = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetPos:SetSize(150, 20)
    resetPos:SetPoint("LEFT", plus, "RIGHT", 12, 0)
    resetPos:SetText("Lezer terugzetten")
    resetPos:SetScript("OnClick", function()
        NQ.db.readerPos = nil
        NQ:ToggleReader(false)
        NQ:ToggleReader(true)
    end)

    -- Bottom buttons
    local function Btn(text, w, fn, anchor, rel, x)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        if anchor then b:SetPoint("LEFT", anchor, "RIGHT", x or 6, 0) else b:SetPoint("BOTTOMLEFT", 18, 16) end
        b:SetText(text)
        b:SetScript("OnClick", fn)
        return b
    end
    local b1 = Btn("Lezer", 90, function() NQ:ToggleReader() end)
    local b2 = Btn("Mijn woorden", 120, function() NQ:ToggleVocab() end, b1)
    Btn("Naar Anki", 110, function() StaticPopup_Show("SPEURTOCHTNL_SYNC") end, b2)

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("BOTTOMLEFT", 18, 46)
    O.status = status
end

function NQ:UpdateOptions()
    if not O.frame then return end
    for key, cb in pairs(O.checks) do cb:SetChecked(self.db[key]) end
    O.fontLabel:SetText(("Lettergrootte lezer: %d"):format(self.db.readerFontSize))
    local n, c = self:CaptureStats()
    O.status:SetText(("v%s · %d vertaalde quests · %d bewaard voor vertaling%s"):format(
        self.version, self:CountQuests(), n, c > 0 and (" · %d gewijzigd"):format(c) or ""))
end

function NQ:ToggleOptions()
    if not O.frame then Build() end
    O.frame:SetShown(not O.frame:IsShown())
    self:UpdateOptions()
end

------------------------------------------------------------------------
-- Entry in the game's AddOns settings list
------------------------------------------------------------------------
NQ:On("Login", function()
    local panel = CreateFrame("Frame")
    panel.name = "SpeurtochtNL"
    local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("Speurtocht.NL")
    local d = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetText("Nederlandse questteksten. Typ /speur of klik hieronder.")
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(180, 24)
    b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
    b:SetText("Instellingen openen")
    b:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        NQ:ToggleOptions()
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "Speurtocht.NL")
        Settings.RegisterAddOnCategory(cat)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_SPEURTOCHTNL1 = "/speur"
SLASH_SPEURTOCHTNL2 = "/stnl"
SLASH_SPEURTOCHTNL3 = "/nlquest"
SlashCmdList.SPEURTOCHTNL = function(msg)
    local cmd = (msg or ""):lower():match("^(%S*)")
    if cmd == "reader" or cmd == "lezer" then
        NQ:ToggleReader()
    elseif cmd == "vocab" or cmd == "woorden" then
        NQ:ToggleVocab()
    elseif cmd == "export" then
        NQ:ShowExport(false)
    elseif cmd == "capture" then
        local n, c = NQ:CaptureStats()
        NQ:Print("%d onvertaalde quests bewaard, %d met gewijzigde Engelse tekst. Ze worden opgeslagen bij /reload of uitloggen.", n, c)
    elseif cmd == "status" then
        local proj = WOW_PROJECT_ID or "?"
        NQ:Print("v%s · build %s · interface %s · project %s · %d quests vertaald",
            NQ.version, tostring(NQ.build), tostring(NQ.toc), tostring(proj), NQ:CountQuests())
        if NQ.current then
            NQ:Print("Huidige quest: %s (ID %s, %s)", NQ.current.en.title or "?", tostring(NQ.current.id),
                NQ.current.q and ("vertaald via " .. (NQ.current.matchedBy or "?")) or "niet vertaald")
        end
    elseif cmd == "save" or cmd == "bewaar" then
        -- /speur save woord            -> saves with the meaning if known
        -- /speur save woord = meaning  -> saves with your own meaning
        local rest = strtrim((msg or ""):match("^%S+%s*(.*)$") or "")
        local word, meaning = rest:match("^(.-)%s*=%s*(.+)$")
        word = strtrim(word or rest)
        if word == "" then
            NQ:Print("Gebruik: /speur save woord   of   /speur save woord = betekenis")
            return
        end
        local cur = NQ.current
        local q = cur and cur.q
        meaning = meaning or NQ:Meaning(word, q)
        local sentence
        if q then
            for _, f in ipairs({ "d", "o", "p", "c" }) do
                local text = q[f] and NQ:Expand(q[f])
                local s = text and text:lower():find(word:lower(), 1, true)
                if s then sentence = NQ:SentenceAt(text, s) break end
            end
        end
        local title = q and q.t and NQ:Expand(q.t) or (cur and cur.en.title)
        if NQ:SaveWord(word, meaning, sentence, title, cur and cur.id) then
            NQ:Print("'%s' opgeslagen%s", word, meaning and (" — " .. meaning) or "")
        end
    elseif cmd == "report" or cmd == "melden" then
        NQ:ShowReport()
    elseif cmd == "check" then
        local R = NQ.reader
        local shown = R.frame and R.frame:IsShown()
        local text = R.nl and R.nl:GetText() or ""
        local _, links = text:gsub("|Hnq[wg]:", "")
        NQ:Print("lezer open: %s · klikbare woorden: %s · links in tekst: %d · muis: %s · woorden opgeslagen: %d",
            tostring(shown), tostring(NQ.db.clickWords), links,
            tostring(R.nl and R.nl.IsMouseEnabled and R.nl:IsMouseEnabled()),
            #NQ:VocabList())
    elseif cmd == "debug" then
        NQ.db.debug = not NQ.db.debug
        NQ:Print("debug %s", NQ.db.debug and "aan" or "uit")
    elseif cmd == "help" then
        NQ:Print("/speur of /nlquest · /speur reader · /speur vocab · /speur save woord · /speur report · /speur export · /speur capture · /speur status · /speur check")
    else
        NQ:ToggleOptions()
    end
end
