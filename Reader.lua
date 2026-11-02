--[[
    SpeurtochtNL - Reader
    A movable side-by-side panel: Dutch on the left (every word clickable for
    the vocabulary saver), English original on the right (can be hidden).
]]
local _, NQ = ...

local COL_W = 280
local PAD = 12
local GOLD = "|cffffd100"
local SAVED_COLOR = "ff7fe07f"
local SECTION_NL = { desc = "Beschrijving", obj = "Doelen", progress = "Voortgang", reward = "Voltooiing" }
local SECTION_EN = { desc = "Description", obj = "Objectives", progress = "Progress", reward = "Completion" }
local ORDER = { "desc", "obj", "progress", "reward" }
local FIELD = { desc = "d", obj = "o", progress = "p", reward = "c" }

local R = {}         -- reader frame and widgets
NQ.reader = R

------------------------------------------------------------------------
-- Fonts
------------------------------------------------------------------------
local fontNL = CreateFont("SpeurtochtNLReaderFontNL")
local fontEN = CreateFont("SpeurtochtNLReaderFontEN")
local function UpdateFonts()
    local size = NQ.db and NQ.db.readerFontSize or 13
    local face = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    fontNL:SetFont(face, size, "")
    fontNL:SetTextColor(1, 0.96, 0.86)
    fontNL:SetJustifyH("LEFT")
    fontEN:SetFont(face, size - 1, "")
    fontEN:SetTextColor(0.72, 0.72, 0.72)
    fontEN:SetJustifyH("LEFT")
end

------------------------------------------------------------------------
-- Building the panel
------------------------------------------------------------------------
local function Build()
    local f = CreateFrame("Frame", "SpeurtochtNLReader", UIParent, "BackdropTemplate")
    R.frame = f
    f:SetSize(COL_W * 2 + PAD * 3, 440)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        NQ.db.readerPos = { p, rp, x, y }
    end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:Hide()
    tinsert(UISpecialFrames, "SpeurtochtNLReader") -- Esc closes it

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD + 4, -PAD - 2)
    title:SetPoint("RIGHT", f, "RIGHT", -150, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    R.title = title

    local badge = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    badge:SetJustifyH("LEFT")
    R.badge = badge

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() NQ:ToggleReader(false) end)

    local enBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    enBtn:SetSize(44, 20)
    enBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)
    enBtn:SetScript("OnClick", function()
        NQ.db.readerEnglish = not NQ.db.readerEnglish
        NQ:UpdateReader()
    end)
    enBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Engelse kolom tonen / verbergen")
        GameTooltip:AddLine("Show / hide the English column", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    enBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    R.enBtn = enBtn

    local vocabBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    vocabBtn:SetSize(60, 20)
    vocabBtn:SetPoint("RIGHT", enBtn, "LEFT", -4, 0)
    vocabBtn:SetText("Woorden")
    vocabBtn:SetScript("OnClick", function() NQ:ToggleVocab() end)
    R.vocabBtn = vocabBtn

    local scroll = CreateFrame("ScrollFrame", "SpeurtochtNLReaderScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -54)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 22, PAD + 18)
    R.scroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(COL_W * 2 + PAD, 400)
    scroll:SetScrollChild(child)
    R.child = child

    -- Dutch column: SimpleHTML so words can be hyperlinks
    local nl = CreateFrame("SimpleHTML", nil, child)
    nl:SetPoint("TOPLEFT", 0, 0)
    nl:SetWidth(COL_W)
    pcall(nl.SetFontObject, nl, fontNL)
    pcall(nl.SetFontObject, nl, "p", fontNL)
    pcall(nl.SetHyperlinksEnabled, nl, true)
    -- Hyperlinks only receive clicks when the widget itself takes mouse input
    nl:EnableMouse(true)
    pcall(nl.SetMouseClickEnabled, nl, true)
    pcall(nl.SetMouseMotionEnabled, nl, true)
    nl:SetScript("OnHyperlinkClick", function(_, link, _, button)
        if NQ.db.debug then NQ:Print("klik: %s (%s)", tostring(link), tostring(button)) end
        NQ:OnWordClick(link, button)
    end)
    nl:SetScript("OnHyperlinkEnter", function(self, link)
        if NQ.db.debug then NQ:Print("hover: %s", tostring(link)) end
        NQ:OnWordEnter(self, link)
    end)
    nl:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
    R.nl = nl

    -- English column: plain text
    local en = child:CreateFontString(nil, "OVERLAY")
    en:SetFontObject(fontEN)
    en:SetPoint("TOPLEFT", nl, "TOPRIGHT", PAD, 0)
    en:SetWidth(COL_W)
    en:SetJustifyH("LEFT")
    en:SetJustifyV("TOP")
    en:SetNonSpaceWrap(true)
    R.en = en

    -- Hidden font string used to measure the Dutch column's height
    local measure = child:CreateFontString(nil, "OVERLAY")
    measure:SetFontObject(fontNL)
    measure:SetWidth(COL_W)
    measure:SetJustifyH("LEFT")
    measure:SetNonSpaceWrap(true)
    measure:SetAlpha(0)
    R.measure = measure

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", PAD + 4, PAD - 2)
    hint:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Klik = opslaan · rechtsklik = verwijderen · |cffff5a4arood|r = naam/Blizzard-woord · Alt = Engels")
    R.hint = hint
end

local function Position()
    local f = R.frame
    f:ClearAllPoints()
    local pos = NQ.db.readerPos
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    elseif QuestFrame and QuestFrame:IsShown() then
        f:SetPoint("TOPLEFT", QuestFrame, "TOPRIGHT", -30, -12)
    elseif QuestLogFrame and QuestLogFrame:IsShown() then
        f:SetPoint("TOPLEFT", QuestLogFrame, "TOPRIGHT", -30, -12)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end
end

------------------------------------------------------------------------
-- Filling it
------------------------------------------------------------------------
function NQ:UpdateReader()
    if not R.frame or not R.frame:IsShown() then return end
    UpdateFonts()
    local cur = self.current
    local showEN = self.db.readerEnglish
    R.frame:SetWidth(showEN and (COL_W * 2 + PAD * 3 + 22) or (COL_W + PAD * 2 + 22))
    R.en:SetShown(showEN)
    R.enBtn:SetText(showEN and "- EN" or "+ EN")
    R.frame:SetScale(self.db.readerScale or 1)

    R.sections = {}
    if not cur then
        R.title:SetText("Speurtocht.NL")
        R.badge:SetText("Open een quest om te beginnen.")
        R.nl:SetText(" ")
        R.en:SetText("")
        return
    end

    local q, en = cur.q, cur.en
    R.title:SetText(q and q.t and self:Expand(q.t) or en.title or "")
    local badge = {}
    if q then
        table.insert(badge, ("Niveau %s"):format(self.TIER_LABEL[q.tier or 1] or "?"))
    else
        table.insert(badge, "|cffff9040Nog niet vertaald|r")
    end
    table.insert(badge, "|cff999999" .. (en.title or "") .. "|r")
    if cur.mismatch then table.insert(badge, "|cffff9040tekst gewijzigd|r") end
    R.badge:SetText(table.concat(badge, "  ·  "))

    -- Which sections are on screen right now
    local keys = {}
    if cur.source == "detail" or cur.source == "log" then keys = { "desc", "obj" }
    elseif cur.source == "progress" then keys = { "progress" }
    elseif cur.source == "reward" then keys = { "reward" } end

    local linked, plain, english = {}, {}, {}
    for _, k in ipairs(keys) do
        local nlText = q and q[FIELD[k]] and self:Expand(q[FIELD[k]])
        local enText = en[k]
        if nlText and nlText ~= "" then
            table.insert(R.sections, nlText)
            local idx = #R.sections
            local head = GOLD .. SECTION_NL[k] .. "|r\n"
            table.insert(linked, head .. (self.db.clickWords
                and self:Linkify(nlText, idx, self.db.markSaved and SAVED_COLOR) or nlText:gsub("|", "||")))
            table.insert(plain, head .. nlText)
        end
        if enText and enText ~= "" then
            table.insert(english, GOLD .. SECTION_EN[k] .. "|r\n" .. enText)
        end
    end

    if q and q.g and #q.g > 0 then
        local lines = { GOLD .. "Woorden in deze quest|r" }
        for i, pair in ipairs(q.g) do
            local w = pair[1]
            local color = self:IsSaved(w) and "|cff7fe07f" or "|cff9fd0ff"
            table.insert(lines, ("|Hnqg:%d|h%s%s|r|h  —  %s"):format(i, color, w, pair[2]))
        end
        local block = table.concat(lines, "\n")
        table.insert(linked, block)
        table.insert(plain, block)
    end

    if #linked == 0 then
        local msg = "Deze quest is nog niet vertaald. De Engelse tekst is bewaard, zodat hij in een volgende versie vertaald kan worden.\n\nThis quest has no Dutch translation yet. Its English text has been saved for the next batch (/speur capture)."
        linked, plain = { msg }, { msg }
    end

    local nlText = table.concat(linked, "\n\n")
    local enText = table.concat(english, "\n\n")
    R.nl:SetText(nlText)
    R.en:SetText(enText)

    R.measure:SetText(table.concat(plain, "\n\n"))
    local h = math.max(R.measure:GetStringHeight(), showEN and R.en:GetStringHeight() or 0) + 20
    R.nl:SetHeight(h + 40)
    R.child:SetHeight(h + 40)
    R.child:SetWidth(showEN and (COL_W * 2 + PAD) or COL_W)
    local key = tostring(cur.id) .. cur.source
    if R.lastKey ~= key then
        R.scroll:SetVerticalScroll(0)
        R.lastKey = key
    end
end

------------------------------------------------------------------------
-- Word clicks
------------------------------------------------------------------------
local function ParseLink(link)
    local kind, a, b = link:match("^(nq[wg]):(%d+):?(%d*)")
    return kind, tonumber(a), tonumber(b)
end

function NQ:OnWordEnter(owner, link)
    local kind, a, b = ParseLink(link)
    local q = self.current and self.current.q
    local word, meaning
    if kind == "nqw" then
        local text = R.sections and R.sections[a]
        word = text and self:WordAt(text, b)
        meaning = word and self:Meaning(word, q)
    elseif kind == "nqg" and q and q.g and q.g[a] then
        word, meaning = q.g[a][1], q.g[a][2]
    end
    if not word then return end
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    local wkind, info = self:WordKind(word)
    if wkind then
        GameTooltip:AddLine(word, 1, 0.36, 0.29)
        if wkind == "term" then
            GameTooltip:AddLine("Blizzard-woord · geen Nederlands", 1, 0.6, 0.5)
            GameTooltip:AddLine(info, 1, 1, 1, true)
        else
            GameTooltip:AddLine(info, 1, 1, 1, true)
        end
        GameTooltip:AddLine("Wordt niet opgeslagen in je woordenlijst", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    GameTooltip:AddLine(word, 1, 0.82, 0)
    GameTooltip:AddLine(meaning or "(nog geen betekenis — je kunt hem zelf invullen in Anki)", 1, 1, 1, true)
    if self:IsSaved(word) then
        GameTooltip:AddLine("Opgeslagen · rechtsklik om te verwijderen", 0.5, 0.88, 0.5)
    else
        GameTooltip:AddLine("Klik om op te slaan", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

function NQ:OnWordClick(link, button)
    local kind, a, b = ParseLink(link)
    local cur = self.current
    if not kind or not cur then return end
    local q = cur.q
    local word, meaning, sentence
    if kind == "nqw" then
        local text = R.sections and R.sections[a]
        if not text then return end
        word = self:WordAt(text, b)
        meaning = word and self:Meaning(word, q)
        sentence = self:SentenceAt(text, b)
    elseif kind == "nqg" and q and q.g and q.g[a] then
        word, meaning = q.g[a][1], q.g[a][2]
        -- find the first sentence that uses the glossary word
        for _, text in ipairs(R.sections or {}) do
            local s = text:lower():find(word:lower(), 1, true)
            if s then sentence = self:SentenceAt(text, s) break end
        end
    end
    if not word then return end

    local wkind, info = self:WordKind(word)
    if wkind then
        -- Names and Warcraft words aren't Dutch vocabulary: mark red, don't save
        self.db.flagged[self:NormalizeWord(word)] = true
        if wkind == "term" then
            self:Print("|cffff5a4a%s|r is een Blizzard-woord, geen Nederlands — %s. Niet opgeslagen.", word, info)
        elseif wkind == "player" then
            self:Print("|cffff5a4a%s|r — dat ben jij! Niet opgeslagen.", word)
        else
            self:Print("|cffff5a4a%s|r is een naam uit de Warcraft-wereld en blijft Engels. Niet opgeslagen.", word)
        end
        self:UpdateReader()
        return
    end

    if button == "RightButton" then
        if self:RemoveWord(word) then self:Print("'%s' verwijderd.", word) end
    else
        local title = q and q.t and self:Expand(q.t) or cur.en.title
        if self:SaveWord(word, meaning, sentence, title, cur.id) then
            self:Print("'%s' opgeslagen%s", word, meaning and (" — " .. meaning) or "")
        end
    end
    self:UpdateReader()
end

------------------------------------------------------------------------
-- Show / hide
------------------------------------------------------------------------
function NQ:ToggleReader(show)
    if not R.frame then Build() end
    if show == nil then show = not R.frame:IsShown() end
    if show then
        if not R.frame:IsShown() then Position() end
        R.frame:Show()
        self:UpdateReader()
    else
        R.frame:Hide()
        R.autoOpened = false
    end
end

NQ:On("QuestShown", function(cur)
    if not NQ.db.enabled or not NQ.db.reader then return end
    if R.frame and R.frame:IsShown() then
        NQ:UpdateReader()
    elseif NQ.db.readerAutoOpen and cur and cur.source ~= "log" then
        NQ:ToggleReader(true)
        R.autoOpened = true
    end
end)

NQ:On("QuestHidden", function(which)
    if R.frame and R.frame:IsShown() and R.autoOpened and which == "frame" then
        NQ:ToggleReader(false)
    end
end)

NQ:On("VocabChanged", function() NQ:UpdateReader() end)
