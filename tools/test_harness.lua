--[[
    SpeurtochtNL - offline test harness (Lua 5.1)
    Loads the addon in a fake WoW environment and exercises the main paths:
    quest dialog, quest log, reader, word saving, Anki export, capture, Alt-peek.

    Run from the addon folder:  lua5.1 tools/test_harness.lua
]]
local failures, checks = 0, 0
local function check(cond, msg)
    checks = checks + 1
    if not cond then failures = failures + 1; print("FAIL: " .. msg) end
end

------------------------------------------------------------------------
-- Fake WoW API
------------------------------------------------------------------------
local events = {}           -- frames registered per event
local allFrames = {}
local function newObject(kind, name)
    local o = { _kind = kind, _scripts = {}, _shown = kind ~= "Frame" or true, _text = "", _children = {} }
    local mt = {}
    mt.__index = function(t, k)
        local f = function(self, ...)
            -- generic no-op method
        end
        return f
    end
    setmetatable(o, mt)
    o.SetScript = function(self, s, fn) self._scripts[s] = fn end
    o.HookScript = function(self, s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end fn(...) end
    end
    o.GetScript = function(self, s) return self._scripts[s] end
    o.RegisterEvent = function(self, e) events[e] = events[e] or {}; table.insert(events[e], self) end
    o.SetText = function(self, t) self._text = t end
    o.GetText = function(self) return self._text end
    o.Show = function(self) self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
    o.Hide = function(self) self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
    o.SetShown = function(self, v) if v then self:Show() else self:Hide() end end
    o.IsShown = function(self) return self._shown end
    o.EnableMouse = function(self, v) self._mouse = v end
    o.IsMouseEnabled = function(self) return self._mouse end
    o.GetChecked = function(self) return self._checked end
    o.SetChecked = function(self, v) self._checked = v end
    o.GetStringHeight = function(self) return 12 * (1 + select(2, tostring(self._text):gsub("\n", ""))) end
    o.GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end
    o.GetID = function(self) return self._id or 1 end
    o.CreateFontString = function(self) return newObject("FontString") end
    o.CreateTexture = function(self) return newObject("Texture") end
    if name then _G[name] = o end
    table.insert(allFrames, o)
    return o
end

function CreateFrame(kind, name, parent, template) local f = newObject(kind, name); f._shown = false; return f end
function CreateFont(name) local f = newObject("Font", name); return f end
UIParent = newObject("Frame", "UIParent")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("  [chat] " .. m) end }
GameTooltip = newObject("GameTooltip", "GameTooltip")
GameTooltip.AddLine = function(self, l) self._lines = self._lines or {}; table.insert(self._lines, l) end
GameTooltip.SetOwner = function(self) self._lines = {} end
UISpecialFrames = {}
StaticPopupDialogs = {}
StaticPopup_Show = function() end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
YES, NO = "Yes", "No"
SlashCmdList = {}
C_Timer = { After = function(_, fn) fn() end }
function hooksecurefunc(name, fn)
    local old = _G[name]
    _G[name] = function(...) local r = old(...) fn(...) return r end
end
function tinsert(t, v) table.insert(t, v) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function time() return 1762000000 end
function GetBuildInfo() return "1.15.9", "65000", "Oct 1 2026", 11509 end
function UnitName() return "Lucy" end
function UnitSex() return 3 end -- female
function UnitClass() return "Warrior", "WARRIOR" end
function UnitRace() return "Dwarf", "Dwarf" end
function UnitExists() return true end
function GetRealZoneText() return "Coldridge Valley" end

-- current quest dialog state
local Q = { id = 0, title = "", text = "", obj = "", progress = "", reward = "" }
function GetQuestID() return Q.id end
function GetTitleText() return Q.title end
function GetQuestText() return Q.text end
function GetObjectiveText() return Q.obj end
function GetProgressText() return Q.progress end
function GetRewardText() return Q.reward end

-- quest log
local LOG = { { "Coldridge Valley", 0, nil, true }, { "A New Threat", 2, nil, false, false, false, nil, 170 },
              { "Unknown Forever Quest", 5, nil, false, false, false, nil, 99999 } }
local logSel = 2
function GetQuestLogSelection() return logSel end
function GetQuestLogTitle(i) local r = LOG[i]; if r then return unpack(r) end end
function GetQuestLogQuestText()
    if logSel == 2 then return "I hope you're here to lend us a hand, Warrior...", "Balir Frosthammer wants you to kill..." end
    return "A brand new quest in Forever.", "Do the new thing."
end
function QuestLog_UpdateQuestDetails() end
function QuestLog_Update() end
QUESTS_DISPLAYED = 6

-- Blizzard frames and font strings
QuestFrame = newObject("Frame", "QuestFrame"); QuestFrame._shown = false
QuestFrameDetailPanel = newObject("Frame", "QuestFrameDetailPanel")
QuestFrameProgressPanel = newObject("Frame", "QuestFrameProgressPanel")
QuestFrameRewardPanel = newObject("Frame", "QuestFrameRewardPanel")
QuestLogFrame = newObject("Frame", "QuestLogFrame"); QuestLogFrame._shown = false
for _, n in ipairs({ "QuestInfoTitleHeader", "QuestInfoDescriptionText", "QuestInfoObjectivesText",
    "QuestInfoRewardText", "QuestProgressTitleText", "QuestProgressText",
    "QuestLogQuestTitle", "QuestLogQuestDescription", "QuestLogObjectivesText" }) do
    newObject("FontString", n)
end
for i = 1, 6 do local b = newObject("Button", "QuestLogTitle" .. i); b._id = i; b._shown = i <= 3 end

local function fire(event, ...)
    for _, f in ipairs(events[event] or {}) do f._scripts.OnEvent(f, event, ...) end
end

------------------------------------------------------------------------
-- Load the addon in TOC order
------------------------------------------------------------------------
local NS = {}
local toc = io.open("SpeurtochtNL.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        local path = line:gsub("\\", "/")
        local chunk = assert(loadfile(path))
        chunk("SpeurtochtNL", NS)
    end
end
-- words saved by an older version: names should be cleaned out on login
SpeurtochtNLVocab = {
    durnan = { word = "durnan", meaning = "", added = 1 },
    lucy = { word = "lucy", meaning = "", added = 2 },
    troggs = { word = "troggs", meaning = "", added = 3 },
    minuten = { word = "minuten", meaning = "", added = 4 },
    vest = { word = "vest", meaning = "", added = 5 },
}
fire("ADDON_LOADED", "SpeurtochtNL")
fire("PLAYER_LOGIN")
local NQ = NS

check(NQ:CountQuests() >= 49, "expected at least 49 quests, got " .. NQ:CountQuests())
check(not NQ.vocab.durnan and not NQ.vocab.lucy and not NQ.vocab.troggs, "names / own name / Blizzard words removed on login")
check(NQ.vocab.minuten and NQ.vocab.minuten.meaning == "minutes", "empty meaning filled from dictionary")
check(NQ.vocab.vest ~= nil, "ordinary Dutch word that is also an item name is kept")
check(NQ.db.flagged.durnan, "removed names are remembered as red")
NQ:RemoveWord("minuten"); NQ:RemoveWord("vest")
check(NQ:WordKind("Durnan") == "name", "Durnan is a name")
check(NQ:WordKind("Magni's") == "name", "possessive name")
check(NQ:WordKind("troggs") == "term", "troggs is a Blizzard term")
check(NQ:WordKind("Lucy") == "player", "own character name")
check(NQ:WordKind("hulp") == nil, "ordinary word")
check(NQ:WordKind("Hand") == nil, "Hand at sentence start is not a name")

------------------------------------------------------------------------
-- Data integrity
------------------------------------------------------------------------
for id, q in pairs(NQ.Q) do
    check(type(q.en) == "string" and q.en ~= "", "quest " .. id .. " missing en title")
    check(type(q.t) == "string" and q.t ~= "", "quest " .. id .. " missing Dutch title")
    check(q.tier and q.tier >= 1 and q.tier <= 4, "quest " .. id .. " bad tier")
    for _, f in ipairs({ "t", "d", "o", "p", "c" }) do
        local s = q[f]
        if s then
            check(not s:find("%$[Gg][^;]*$"), ("quest %d field %s has unterminated $g"):format(id, f))
            check(not s:find("[^%$]%f[%w]lad%f[%W]") and not s:find("lass;"), ("quest %d field %s left English gender words"):format(id, f))
            local exp = NQ:Expand(s)
            check(not exp:find("%$"), ("quest %d field %s has unexpanded placeholder: %s"):format(id, f, exp:match("%$..") or ""))
        end
    end
    for _, pair in ipairs(q.g or {}) do
        check(type(pair[1]) == "string" and type(pair[2]) == "string", "quest " .. id .. " bad glossary pair")
    end
end

-- (Field-by-field checks against the English source happen in tools/import_batch.py.)

------------------------------------------------------------------------
-- Placeholder expansion
------------------------------------------------------------------------
check(NQ:Expand("Hallo $n, $gjongen:meid;! Een $c en $r.$bKlaar.") == "Hallo Lucy, meid! Een krijgster en dwerg.\nKlaar.",
    "Expand gave: " .. NQ:Expand("Hallo $n, $gjongen:meid;! Een $c en $r.$bKlaar."))
check(NQ:Expand("$g jongen : meid;") == "meid", "spaced $g form")

------------------------------------------------------------------------
-- Quest dialog: detail panel
------------------------------------------------------------------------
Q.id, Q.title = 170, "A New Threat"
Q.text, Q.obj = "I hope you're here to lend us a hand, Warrior.", "Balir Frosthammer wants you to kill 6 Rockjaw Troggs."
QuestFrame:Show()
QuestFrameDetailPanel:Show()
check(QuestInfoTitleHeader:GetText() == "Een nieuw gevaar", "detail title: " .. QuestInfoTitleHeader:GetText())
check(QuestInfoDescriptionText:GetText():find("krijgster", 1, true), "detail desc expands $c")
check(QuestInfoDescriptionText:GetText():find("meid", 1, true), "detail desc expands $g")
check(QuestInfoObjectivesText:GetText():find("Rockjaw Troggs", 1, true), "objectives keep English mob names")
check(NQ.current and NQ.current.en.desc == Q.text, "English kept for reader/tooltip")
check(NQ.reader.frame and NQ.reader.frame:IsShown(), "reader auto-opened")
check(NQ.reader.nl:GetText():find("|Hnqw:1:", 1, true), "reader Dutch column has word links")
check(NQ.reader.en:GetText():find("lend us a hand", 1, true), "reader English column")
check(NQ.reader.nl._mouse == true, "reader text accepts mouse input (needed for clicking words)")
-- clicks arrive through the real script handler, not only the direct call
local sec0 = NQ.reader.sections[1]
local p0 = sec0:find("hulp", 1, true)
NQ.reader.nl._scripts.OnHyperlinkClick(NQ.reader.nl, "nqw:1:" .. p0, "hulp", "LeftButton")
check(NQ:IsSaved("hulp"), "click through OnHyperlinkClick saves word")
NQ:RemoveWord("hulp")
-- names and Blizzard words: red, never saved
local pt = sec0:find("troggs", 1, true)
NQ.reader.nl._scripts.OnHyperlinkClick(NQ.reader.nl, "nqw:1:" .. pt, "troggs", "LeftButton")
check(not NQ:IsSaved("troggs"), "Blizzard word not saved")
check(NQ.reader.nl:GetText():find("|cffff5a4a|Hnqw:1:" .. pt .. "|h", 1, true), "Blizzard word shown red after click")
local pc = sec0:find("Coldridge", 1, true)
NQ.reader.nl._scripts.OnHyperlinkClick(NQ.reader.nl, "nqw:1:" .. pc, "Coldridge", "LeftButton")
check(not NQ:IsSaved("coldridge") and NQ.db.flagged.coldridge, "name not saved, flagged")
NQ:OnWordEnter(UIParent, "nqw:1:" .. pc)
check(GameTooltip._lines[2] and GameTooltip._lines[2]:find("Naam", 1, true), "tooltip says it's a name")
SlashCmdList.SPEURTOCHTNL("save durnan")
check(not NQ:IsSaved("durnan"), "typed name refused")
-- typed fallback
SlashCmdList.SPEURTOCHTNL("save opduiken")
check(NQ:IsSaved("opduiken") and NQ.vocab["opduiken"].meaning == "to pop up, appear", "typed save uses glossary meaning")
check(NQ.vocab["opduiken"].sentence:find("overal in het land opduiken", 1, true), "typed save finds sentence")
SlashCmdList.SPEURTOCHTNL("save Gnomenkrijger = gnome warrior")
check(NQ.vocab["gnomenkrijger"] and NQ.vocab["gnomenkrijger"].meaning == "gnome warrior", "typed save with own meaning")
NQ:RemoveWord("opduiken"); NQ:RemoveWord("gnomenkrijger")
SlashCmdList.SPEURTOCHTNL("check")

-- Alt peek
fire("MODIFIER_STATE_CHANGED", "LALT", 1)
check(QuestInfoDescriptionText:GetText() == Q.text, "Alt shows English")
fire("MODIFIER_STATE_CHANGED", "LALT", 0)
check(QuestInfoDescriptionText:GetText():find("troggs", 1, true) and QuestInfoDescriptionText:GetText():find("Ik hoop", 1, true), "Alt release restores Dutch")

-- Word click -> vocab
local sec = NQ.reader.sections[1]
local pos = sec:find("aanval", 1, true)
NQ:OnWordClick("nqw:1:" .. pos, "LeftButton")
check(NQ:IsSaved("aanval"), "word saved from reader")
local e = NQ.vocab["aanval"]
check(e and e.meaning == "attack", "meaning from quest glossary: " .. tostring(e and e.meaning))
check(e and e.sentence:find("Na de laatste aanval", 1, true), "sentence captured: " .. tostring(e and e.sentence))
check(e and e.quest == "Een nieuw gevaar", "quest title stored")
-- shared dictionary fallback
local pos2 = sec:find("hoop", 1, true)
NQ:OnWordClick("nqw:1:" .. pos2, "LeftButton")
check(NQ.vocab["hoop"] ~= nil, "unknown word still saved")
-- glossary click
NQ:OnWordClick("nqg:3", "LeftButton")
check(NQ:IsSaved("opduiken"), "glossary entry saved")
-- saved words are coloured on refresh
check(NQ.reader.nl:GetText():find("|cff7fe07f|Hnqw:1:" .. pos .. "|h", 1, true), "saved word highlighted")
-- remove
NQ:OnWordClick("nqw:1:" .. pos2, "RightButton")
check(not NQ:IsSaved("hoop"), "right click removes")

-- Anki export
local text, n = NQ:BuildAnkiText(false)
check(n == 2, "export count " .. n)
check(text:find("#separator:tab", 1, true) and text:find("aanval\tattack\t", 1, true), "anki line format")
check(not text:find("\n[^#][^\n]*\t[^\n]*\t[^\n]*\t[^\n]*\t", 1), "exactly 4 columns")
NQ:ShowExport(true)

------------------------------------------------------------------------
-- Progress and reward panels
------------------------------------------------------------------------
Q.progress = "Tenacious little buggers, aren't they?"
QuestFrameProgressPanel:Show()
check(QuestProgressText:GetText() == "Taaie kleine rotbeesten, hè?", "progress text: " .. QuestProgressText:GetText())
Q.reward = "If the problems we've had here..."
QuestFrameRewardPanel:Show()
check(QuestInfoRewardText:GetText():find("Magni's baard", 1, true), "reward text")

-- Close dialog: auto-opened reader closes
QuestFrame:Hide()
check(not NQ.reader.frame:IsShown(), "reader closes with quest frame")

------------------------------------------------------------------------
-- Untranslated quest -> capture
------------------------------------------------------------------------
Q.id, Q.title, Q.text, Q.obj = 88888, "The Cozy Sleeping Bag", "Find a warm place to rest.", "Rest at the campfire."
QuestFrame:Show(); QuestFrameDetailPanel:Show()
check(QuestInfoDescriptionText:GetText() ~= "", "untranslated quest leaves English alone")
check(NQ.capture.quests[88888] and NQ.capture.quests[88888].desc == "Find a warm place to rest.", "untranslated quest captured")
check(NQ.capture.quests[88888].npc ~= nil and NQ.capture.quests[88888].toc == 11509, "capture metadata")
check(NQ.reader.nl:GetText():find("nog niet vertaald", 1, true), "reader explains missing translation")
QuestFrame:Hide()

-- Changed English text (Forever) -> flagged
Q.id, Q.title = 179, "Dwarven Outfitters (Forever)"
QuestFrame:Show(); QuestFrameDetailPanel:Show()
check(NQ.current.mismatch, "title mismatch detected")
check(NQ.capture.changed[179] ~= nil, "changed quest captured")
check(QuestInfoTitleHeader:GetText() == "Kleding voor dwergen", "still translated by ID")
QuestFrame:Hide()

-- ID unknown, title known -> fallback by title
Q.id, Q.title = 123456, "The Boar Hunter"
QuestFrame:Show(); QuestFrameDetailPanel:Show()
check(NQ.current.q and NQ.current.matchedBy == "title", "title fallback")
check(QuestInfoTitleHeader:GetText() == "De zwijnenjager", "title fallback applies Dutch")
QuestFrame:Hide()

------------------------------------------------------------------------
-- Quest log
------------------------------------------------------------------------
QuestLogFrame:Show()
check(QuestLogQuestTitle:GetText() == "Een nieuw gevaar", "log title: " .. tostring(QuestLogQuestTitle:GetText()))
check(QuestLogQuestDescription:GetText():find("Ik hoop", 1, true), "log description Dutch")
NQ.db.logTitles = true
QuestLogTitle2:SetText("  A New Threat")
QuestLog_Update()
check(QuestLogTitle2:GetText() == "  Een nieuw gevaar", "log list title: " .. QuestLogTitle2:GetText())
logSel = 3
QuestLog_UpdateQuestDetails()
check(NQ.capture.quests[99999] ~= nil, "log captures untranslated quest")

------------------------------------------------------------------------
-- Settings toggles
------------------------------------------------------------------------
logSel = 2
QuestLog_UpdateQuestDetails()
NQ.db.translateLog = false
NQ:Refresh()
check(QuestLogQuestDescription:GetText():find("lend us a hand", 1, true), "translateLog off shows English")
NQ.db.translateLog = true
NQ:Refresh()

-- Slash commands don't error
for _, c in ipairs({ "save", "", "reader", "vocab", "export", "capture", "status", "help", "debug", "debug" }) do
    local ok, err = pcall(SlashCmdList.SPEURTOCHTNL, c)
    check(ok, "slash /speur " .. c .. ": " .. tostring(err))
end

print(("%d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
