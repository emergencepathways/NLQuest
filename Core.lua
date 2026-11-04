--[[
    SpeurtochtNL - Core
    Shared namespace, saved settings, quest data registry and lookups.

    Quest data entries (see Data\*.lua):
        [questID] = {
            en   = "English title",        -- used to match by title and detect changed text
            tier = 1..4,                    -- difficulty: 1 A1-A2, 2 A2-A2+, 3 A2-B1, 4 B1-B2
            t = "Titel", d = "Beschrijving", o = "Doelen",
            p = "Voortgang (progress)", c = "Voltooiing (completion)",
            g = { {"woord", "meaning"}, ... }  -- optional per-quest glossary
        }
    Placeholders follow the game's own format: $n $c $r $b and $gman:vrouw;
]]
local addonName, NQ = ...
_G.SpeurtochtNL = NQ

NQ.version = "0.3.1"
NQ.Q = {}           -- questID -> translation
NQ.byTitle = {}     -- lowercase English title -> questID (fallback when IDs differ)
NQ.dict = {}        -- shared dictionary: lowercase Dutch word -> English meaning
NQ.names = {}       -- lowercase names that stay English (only when capitalised in the text)
NQ.terms = {}       -- lowercase Warcraft fantasy terms -> explanation

NQ.TIER_LABEL = { "A1–A2", "A2–A2+", "A2–B1", "B1–B2" }

NQ.defaults = {
    enabled        = true,
    translateFrame = true,   -- Dutch text inside the quest dialog
    translateLog   = true,   -- Dutch text in the quest log details
    logTitles      = false,  -- Dutch titles in the quest log list (experimental)
    hoverEnglish   = true,   -- "NLQuest" button: hover to see the English original
    altPeek        = true,   -- hold Alt to temporarily show English
    reader         = true,   -- side-by-side reader panel
    readerEnglish  = true,   -- show the English column in the reader
    readerAutoOpen = true,   -- open the reader when a quest window opens
    clickWords     = true,   -- words in the reader are clickable (vocab saver)
    markSaved      = true,   -- highlight words already saved
    capture        = true,   -- record untranslated quests for future batches
    flagged        = {},     -- names / Blizzard words you clicked (shown red)
    readerScale    = 1.0,
    readerFontSize = 13,
    readerPos      = nil,
    vocabPos       = nil,
}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = v end
    end
end

function NQ:Print(msg, ...)
    if select("#", ...) > 0 then msg = msg:format(...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00Speurtocht.NL|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Data registration (called by Data\*.lua)
------------------------------------------------------------------------
NQ.glossAll = {}    -- every quest word-list entry, so a word explained once is known everywhere
function NQ:AddQuests(tbl)
    for id, q in pairs(tbl) do
        self.Q[id] = q
        for _, pair in ipairs(q.g or {}) do
            local k = pair[1]:lower()
            if not self.glossAll[k] then self.glossAll[k] = pair[2] end
        end
        if q.en then
            local key = q.en:lower()
            if not self.byTitle[key] then self.byTitle[key] = id end
        end
    end
end

function NQ:AddWords(tbl)
    for nl, en in pairs(tbl) do
        self.dict[nl:lower()] = en
    end
end

-- Returns translation table and the id it was found under.
-- matchedBy is "id" or "title"; mismatch is true if the stored English
-- title differs from what the client shows (text changed in Forever).
function NQ:Lookup(questID, englishTitle)
    local q = questID and questID > 0 and self.Q[questID]
    if q then
        local mismatch = englishTitle and q.en and q.en:lower() ~= englishTitle:lower()
        return q, questID, "id", mismatch
    end
    if englishTitle and englishTitle ~= "" then
        local id = self.byTitle[englishTitle:lower()]
        if id then return self.Q[id], id, "title", false end
    end
end

function NQ:AddNames(list)
    for _, n in ipairs(list) do self.names[n:lower()] = true end
end

function NQ:AddTerms(tbl)
    for k, v in pairs(tbl) do self.terms[k:lower()] = v end
end

function NQ:CountQuests()
    local n = 0
    for _ in pairs(self.Q) do n = n + 1 end
    return n
end

------------------------------------------------------------------------
-- Simple callback bus so modules stay independent
------------------------------------------------------------------------
NQ.callbacks = {}
function NQ:On(event, fn)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], fn)
end
function NQ:Fire(event, ...)
    for _, fn in ipairs(self.callbacks[event] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok and self.db and self.db.debug then self:Print("|cffff4040error|r %s", err) end
    end
end

------------------------------------------------------------------------
-- Startup
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        SpeurtochtNLDB = SpeurtochtNLDB or {}
        SpeurtochtNLVocab = SpeurtochtNLVocab or {}
        SpeurtochtNLCapture = SpeurtochtNLCapture or { quests = {}, changed = {} }
        SpeurtochtNLCapture.quests = SpeurtochtNLCapture.quests or {}
        SpeurtochtNLCapture.changed = SpeurtochtNLCapture.changed or {}
        CopyDefaults(SpeurtochtNLDB, NQ.defaults)
        NQ.db = SpeurtochtNLDB
        NQ.vocab = SpeurtochtNLVocab
        NQ.capture = SpeurtochtNLCapture
        NQ:Fire("Loaded")
    elseif event == "PLAYER_LOGIN" then
        local _, build, _, toc = GetBuildInfo()
        NQ.build, NQ.toc = build, toc
        NQ:Fire("Login")
        NQ:Print("v%s geladen — %d quests in het Nederlands. Typ |cffffd100/speur|r voor instellingen.",
            NQ.version, NQ:CountQuests())
    end
end)
