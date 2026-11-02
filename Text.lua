--[[
    SpeurtochtNL - Text helpers
    Placeholder substitution ($n, $c, $r, $b, $g), Dutch class/race names,
    and turning Dutch text into clickable words for the reader.
]]
local _, NQ = ...

local CLASS_NL = {
    WARRIOR = { "krijger", "krijgster" },
    PALADIN = { "paladijn", "paladijn" },
    HUNTER  = { "jager", "jageres" },
    ROGUE   = { "schurk", "schurk" },
    PRIEST  = { "priester", "priesteres" },
    SHAMAN  = { "sjamaan", "sjamaan" },
    MAGE    = { "magiër", "magiër" },
    WARLOCK = { "heksenmeester", "heksenmeester" },
    DRUID   = { "druïde", "druïde" },
}
local RACE_NL = {
    Human = "mens", Dwarf = "dwerg", NightElf = "nachtelf", Gnome = "gnoom",
    Orc = "ork", Scourge = "ondode", Undead = "ondode", Tauren = "tauren", Troll = "trol",
}

local function IsFemale()
    return UnitSex("player") == 3
end

function NQ:PlayerClassNL()
    local loc, file = UnitClass("player")
    local t = CLASS_NL[file]
    if not t then return (loc or ""):lower() end
    return IsFemale() and t[2] or t[1]
end

function NQ:PlayerRaceNL()
    local loc, file = UnitRace("player")
    return RACE_NL[file] or (loc or ""):lower()
end

-- Expand quest placeholders for display. English text from the client is
-- already expanded; this is only used for our Dutch strings.
function NQ:Expand(s)
    if not s or s == "" then return s end
    local female = IsFemale()
    s = s:gsub("%$[Gg]%s*([^:;]-)%s*:%s*([^;]-)%s*;", function(m, f)
        return female and f or m
    end)
    s = s:gsub("%$[Bb]", "\n")
    local name = UnitName("player") or ""
    s = s:gsub("%$[Nn]", function() return name end)
    local class = self:PlayerClassNL()
    s = s:gsub("%$[Cc]", function() return class end)
    local race = self:PlayerRaceNL()
    s = s:gsub("%$[Rr]", function() return race end)
    return s
end

------------------------------------------------------------------------
-- Word handling for the reader and vocabulary saver
------------------------------------------------------------------------
-- A "word" is a run of letters (including UTF-8 accented letters),
-- apostrophes and inner hyphens. Bytes >= 128 are treated as letters.
local WORD = "[%a\128-\255][%a\128-\255'%-]*"

function NQ:NormalizeWord(w)
    w = w:gsub("^['%-]+", ""):gsub("['%-]+$", "")
    -- lowercase ASCII; accented capitals are rare at word start in Dutch
    return w:lower()
end

-- Is this a name or a Warcraft word rather than Dutch?
-- Returns kind ("player" | "term" | "name") and an explanation, or nil.
function NQ:WordKind(word)
    local clean = word:gsub("^['%-]+", ""):gsub("['%-]+$", "")
    local key = self:NormalizeWord(clean)
    local me = UnitName("player")
    if me and key == me:lower() then return "player", "Dat ben jij! (your character's name)" end
    if self.terms[key] then return "term", self.terms[key] end
    local first = clean:sub(1, 1)
    if self.names[key] and first:upper() == first and first:lower() ~= first then
        return "name", "Naam uit de Warcraft-wereld (blijft Engels)"
    end
    -- possessive of a name: Magni's, Felix's
    local base = key:match("^(.-)'s$")
    if base and self.names[base] and first:upper() == first then
        return "name", "Naam uit de Warcraft-wereld (blijft Engels)"
    end
end

-- Look a word up in the current quest glossary, then the shared dictionary.
function NQ:Meaning(word, quest)
    local key = self:NormalizeWord(word)
    if quest and quest.g then
        for _, pair in ipairs(quest.g) do
            if pair[1]:lower() == key then return pair[2] end
        end
    end
    return self.dict[key]
end

-- Return the sentence of `text` that contains character position `pos`.
function NQ:SentenceAt(text, pos)
    local s = pos
    while s > 1 do
        local c = text:sub(s - 1, s - 1)
        if c == "." or c == "!" or c == "?" or c == "\n" then break end
        s = s - 1
    end
    local e = pos
    while e <= #text do
        local c = text:sub(e, e)
        if c == "." or c == "!" or c == "?" or c == "\n" then break end
        e = e + 1
    end
    return strtrim(text:sub(s, e))
end

-- Escape characters SimpleHTML / hyperlink parsing would choke on.
local function Esc(s)
    return (s:gsub("|", "||"))
end

-- Turn plain Dutch text into text where every word is a hyperlink:
--   |Hnqw:<sectionIndex>:<position>|h<word>|h
-- The reader keeps each section's plain text, so a click can recover the
-- word and its sentence from (section, position).
-- Saved words are coloured so progress is visible while reading; names and
-- Warcraft words you've clicked are shown red.
local FLAG_COLOR = "ffff5a4a"
function NQ:Linkify(text, sectionIndex, savedColor)
    local out, pos = {}, 1
    while true do
        local s, e = text:find(WORD, pos)
        if not s then
            table.insert(out, Esc(text:sub(pos)))
            break
        end
        table.insert(out, Esc(text:sub(pos, s - 1)))
        local w = text:sub(s, e)
        local link = ("|Hnqw:%d:%d|h%s|h"):format(sectionIndex, s, w)
        local flagged = self.db and self.db.flagged and self.db.flagged[self:NormalizeWord(w)] and self:WordKind(w)
        if flagged then
            link = "|c" .. FLAG_COLOR .. link .. "|r"
        elseif savedColor and self:IsSaved(w) then
            link = "|c" .. savedColor .. link .. "|r"
        end
        table.insert(out, link)
        pos = e + 1
    end
    return table.concat(out)
end

-- Word starting at byte position `pos` in `text`.
function NQ:WordAt(text, pos)
    local s, e = text:find(WORD, pos)
    if s == pos then return text:sub(s, e) end
end
