--[[
    SpeurtochtNL - Vocabulary saver and Anki export

    SpeurtochtNLVocab[lowercaseWord] = {
        word, meaning, sentence, quest, qid, added (time()), seen (count), exported (bool)
    }
    Export produces Anki-ready tab separated text (Anki 2.1.54+ reads the
    #headers automatically: File > Import, pick the .txt). tools/anki_export.py
    builds the same file straight from the SavedVariables.
]]
local _, NQ = ...

local function Key(word) return NQ:NormalizeWord(word) end

function NQ:IsSaved(word)
    return self.vocab and self.vocab[Key(word)] ~= nil
end

-- Names, Warcraft words and your own name never go into the word list.
-- Lowercase names count too unless the word is also ordinary Dutch (ram, vest, stout...).
function NQ:NotVocab(word)
    local kind, info = self:WordKind(word)
    if kind then return kind, info end
    local k = Key(word)
    if self.names[k] and not self.dict[k] then return "name", "Naam uit de Warcraft-wereld (blijft Engels)" end
end

function NQ:SaveWord(word, meaning, sentence, quest, qid)
    local k = Key(word)
    if k == "" then return false end
    local kind = self:NotVocab(word)
    if kind then
        self:Print("|cffff5a4a%s|r is %s en wordt niet opgeslagen.", word,
            kind == "term" and "een Blizzard-woord" or kind == "player" and "jouw naam" or "een naam")
        return false
    end
    local e = self.vocab[k]
    if e then
        e.seen = (e.seen or 1) + 1
        if meaning and (not e.meaning or e.meaning == "") then e.meaning = meaning end
        self:Print("'%s' stond al in je lijst (%dx gezien).", word, e.seen)
        self:Fire("VocabChanged")
        return false
    end
    self.vocab[k] = {
        word = k, meaning = meaning or "", sentence = sentence or "",
        quest = quest or "", qid = qid, added = time(), seen = 1,
    }
    self:Fire("VocabChanged")
    return true
end

function NQ:RemoveWord(word)
    local k = Key(word)
    if self.vocab[k] then
        self.vocab[k] = nil
        self:Fire("VocabChanged")
        return true
    end
end

function NQ:VocabList()
    local list = {}
    for _, e in pairs(self.vocab) do table.insert(list, e) end
    table.sort(list, function(a, b) return (a.added or 0) > (b.added or 0) end)
    return list
end

local function Clean(s)
    return (tostring(s or ""):gsub("[\t\r]", " "):gsub("\n", "<br>"))
end

function NQ:BuildAnkiText(onlyNew)
    local lines = {
        "#separator:tab",
        "#html:true",
        "#columns:Nederlands\tEnglish\tZin\tTags",
        "#tags column:4",
    }
    local n = 0
    local list = self:VocabList()
    for i = #list, 1, -1 do -- oldest first
        local e = list[i]
        if not onlyNew or not e.exported then
            local back = Clean(e.sentence)
            if e.quest ~= "" then back = back .. "<br><i>" .. Clean(e.quest) .. "</i>" end
            table.insert(lines, table.concat({ Clean(e.word), Clean(e.meaning), back, "SpeurtochtNL WoW" }, "\t"))
            n = n + 1
        end
    end
    return table.concat(lines, "\n"), n
end

------------------------------------------------------------------------
-- Vocabulary window
------------------------------------------------------------------------
local V = {}
local ROW_H = 18

local function MakeWindow(name, w, h, titleText)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:SetPoint("CENTER")
    f:Hide()
    tinsert(UISpecialFrames, name)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -14)
    t:SetText(titleText)
    f.titleText = t
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    return f
end
NQ.MakeWindow = MakeWindow

local function BuildVocab()
    local f = MakeWindow("SpeurtochtNLVocabFrame", 460, 420, "Mijn woorden")
    V.frame = f

    local count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("TOPLEFT", f.titleText, "BOTTOMLEFT", 0, -4)
    V.count = count

    local scroll = CreateFrame("ScrollFrame", "SpeurtochtNLVocabScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -58)
    scroll:SetPoint("BOTTOMRIGHT", -34, 46)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(400, 10)
    scroll:SetScrollChild(child)
    V.child, V.rows = child, {}

    local sync = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    sync:SetSize(130, 22)
    sync:SetPoint("BOTTOMLEFT", 14, 14)
    sync:SetText("Naar Anki")
    sync:SetScript("OnClick", function() StaticPopup_Show("SPEURTOCHTNL_SYNC") end)
    sync:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Naar Anki", 1, 0.82, 0)
        GameTooltip:AddLine("Saves your words to disk (a quick /reload). With the Speurtocht Anki sync running on your computer, they appear in Anki a few seconds later. Logging out does the same.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    sync:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local copy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copy:SetSize(120, 22)
    copy:SetPoint("LEFT", sync, "RIGHT", 6, 0)
    copy:SetText("Kopieer tekst")
    copy:SetScript("OnClick", function() NQ:ShowExport(true) end)
    copy:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Kopieer tekst", 1, 0.82, 0)
        GameTooltip:AddLine("Manual alternative: words you haven't copied before, as text to paste into Anki's import.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    copy:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clear:SetSize(100, 22)
    clear:SetPoint("BOTTOMRIGHT", -14, 14)
    clear:SetText("Alles wissen")
    clear:SetScript("OnClick", function() StaticPopup_Show("SPEURTOCHTNL_CLEAR_VOCAB") end)
end

StaticPopupDialogs["SPEURTOCHTNL_SYNC"] = {
    text = "Woorden opslaan voor Anki?\nDe interface wordt even herladen (/reload).\n\n(Save your words for Anki? The UI reloads for a moment.)",
    button1 = YES, button2 = NO,
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["SPEURTOCHTNL_CLEAR_VOCAB"] = {
    text = "Alle opgeslagen woorden wissen?\n(Delete every saved word?)",
    button1 = YES, button2 = NO,
    OnAccept = function()
        wipe(NQ.vocab)
        NQ:Fire("VocabChanged")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function RowFor(i)
    local row = V.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, V.child)
    row:SetSize(400, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.word = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.word:SetPoint("LEFT", 4, 0)
    row.word:SetWidth(130)
    row.word:SetJustifyH("LEFT")
    row.word:SetWordWrap(false)
    row.meaning = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.meaning:SetPoint("LEFT", row.word, "RIGHT", 6, 0)
    row.meaning:SetPoint("RIGHT", -4, 0)
    row.meaning:SetJustifyH("LEFT")
    row.meaning:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(e.word, 1, 0.82, 0)
        if e.meaning ~= "" then GameTooltip:AddLine(e.meaning, 1, 1, 1, true) end
        if e.sentence ~= "" then GameTooltip:AddLine(e.sentence, 0.8, 0.8, 0.8, true) end
        if e.quest ~= "" then GameTooltip:AddLine(e.quest, 0.6, 0.8, 1) end
        GameTooltip:AddLine("Rechtsklik om te verwijderen", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.entry then NQ:RemoveWord(self.entry.word) end
    end)
    V.rows[i] = row
    return row
end

function NQ:UpdateVocab()
    if not V.frame or not V.frame:IsShown() then return end
    local list = self:VocabList()
    local new = 0
    for i, e in ipairs(list) do
        local row = RowFor(i)
        row.entry = e
        row.word:SetText(e.word)
        row.meaning:SetText(e.meaning ~= "" and e.meaning or "|cff777777—|r")
        row:Show()
        if not e.exported then new = new + 1 end
    end
    for i = #list + 1, #V.rows do V.rows[i]:Hide() end
    V.child:SetHeight(math.max(10, #list * ROW_H))
    V.count:SetText(("%d woorden"):format(#list))
end

function NQ:ToggleVocab(show)
    if not V.frame then BuildVocab() end
    if show == nil then show = not V.frame:IsShown() end
    if show and not V.frame:IsShown() then
        V.frame:ClearAllPoints()
        local reader = self.reader and self.reader.frame
        if reader and reader:IsShown() then
            V.frame:SetPoint("TOPLEFT", reader, "TOPRIGHT", 4, 0)
        else
            V.frame:SetPoint("CENTER", UIParent, "CENTER", 240, 0)
        end
    end
    V.frame:SetShown(show)
    self:UpdateVocab()
end

------------------------------------------------------------------------
-- Export window: copy the text with Ctrl+A, Ctrl+C
------------------------------------------------------------------------
local E = {}
local function BuildExport()
    local f = MakeWindow("SpeurtochtNLExportFrame", 560, 400, "Anki export")
    E.frame = f
    local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", f.titleText, "BOTTOMLEFT", 0, -4)
    help:SetPoint("RIGHT", -20, 0)
    help:SetJustifyH("LEFT")
    help:SetText("Ctrl+C om te kopiëren. Plak in een leeg .txt-bestand en importeer het in Anki (Bestand › Importeren).")

    local scroll = CreateFrame("ScrollFrame", "SpeurtochtNLExportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -62)
    scroll:SetPoint("BOTTOMRIGHT", -36, 48)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(500)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    box:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(E.text or "") self:HighlightText() end -- read-only
    end)
    scroll:SetScrollChild(box)
    E.box = box

    local mark = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    mark:SetSize(210, 22)
    mark:SetPoint("BOTTOMLEFT", 16, 14)
    mark:SetText("Markeer als geëxporteerd")
    mark:SetScript("OnClick", function()
        for _, e in pairs(NQ.vocab) do e.exported = true end
        NQ:Print("Alle woorden gemarkeerd als geëxporteerd.")
        NQ:Fire("VocabChanged")
        f:Hide()
    end)
end

function NQ:ShowExport(onlyNew)
    if not E.frame then BuildExport() end
    local text, n = self:BuildAnkiText(onlyNew)
    E.text = text
    E.box:SetText(text)
    E.frame:Show()
    E.box:SetFocus()
    E.box:HighlightText()
    self:Print("%d woorden klaar om te kopiëren.", n)
end

NQ:On("VocabChanged", function() NQ:UpdateVocab() end)

-- On login: drop names/Warcraft words saved by earlier versions and fill in
-- meanings that the dictionary now knows.
NQ:On("Login", function()
    local removed, filled = {}, 0
    for k, e in pairs(NQ.vocab) do
        if NQ:NotVocab(e.word or k) then
            table.insert(removed, e.word or k)
            NQ.vocab[k] = nil
            NQ.db.flagged[k] = true
        elseif (not e.meaning or e.meaning == "") and NQ.dict[k] then
            e.meaning = NQ.dict[k]
            filled = filled + 1
        end
    end
    if #removed > 0 then
        table.sort(removed)
        NQ:Print("Namen uit je woordenlijst gehaald: %s", table.concat(removed, ", "))
    end
    if filled > 0 then NQ:Print("%d woorden kregen een betekenis.", filled) end
end)
