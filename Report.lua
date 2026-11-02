--[[
    Speurtocht.NL - Reporting
    WoW addons can't reach the internet, so a report is a ready-made link to
    a GitHub issue form with the quest's details already filled in. The
    player copies it (Ctrl+C), pastes it in a browser and clicks Submit.

    Untranslated quest            -> "Missing quest" form (includes the English text)
    Translated quest              -> "Translation fix" form (includes the Dutch text)
]]
local _, NQ = ...

NQ.REPO = "emergencepathways/NLQuest"
local MAX_URL = 7000 -- browsers and GitHub accept longer, but this stays safe everywhere

local function enc(s)
    return (tostring(s or ""):gsub("\n", "\r\n"):gsub("[^%w%-%._~]", function(c)
        return ("%%%02X"):format(c:byte())
    end))
end

local function PlayerLine()
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    local race = UnitRace("player") or "?"
    local class = UnitClass("player") or "?"
    return ("%s, %s, %s, level %s"):format(faction, race, class, tostring(UnitLevel and UnitLevel("player") or "?"))
end

local function ClientLine()
    local version, build, _, toc = GetBuildInfo()
    return ("%s (build %s, interface %s) · Speurtocht.NL %s"):format(tostring(version), tostring(build), tostring(toc), NQ.version)
end

local function EnglishBlock(en)
    local parts = {}
    for _, k in ipairs({ { "desc", "Description" }, { "obj", "Objectives" }, { "progress", "Progress" }, { "reward", "Completion" } }) do
        local text = en[k[1]]
        if text and text ~= "" then table.insert(parts, "**" .. k[2] .. ":**\n" .. text) end
    end
    return table.concat(parts, "\n\n")
end

local function DutchBlock(q)
    local parts = {}
    for _, k in ipairs({ { "d", "Beschrijving" }, { "o", "Doelen" }, { "p", "Voortgang" }, { "c", "Voltooiing" } }) do
        if q[k[1]] then table.insert(parts, "**" .. k[2] .. ":**\n" .. NQ:Expand(q[k[1]])) end
    end
    return table.concat(parts, "\n\n")
end

-- Build the issue link for a quest (cur = NQ.current-style table).
function NQ:ReportURL(cur)
    if not cur then return nil end
    local en, q = cur.en or {}, cur.q
    local fields, long, longKey
    local base = "https://github.com/" .. self.REPO .. "/issues/new?"
    if not q or cur.mismatch then
        local title = ("[Missing] %s (%s)"):format(en.title or "?", tostring(cur.id))
        if q and cur.mismatch then title = ("[Changed] %s (%s)"):format(en.title or "?", tostring(cur.id)) end
        fields = {
            template = "missing-quest.yml", title = title,
            ["quest-id"] = cur.id, ["quest-title"] = en.title,
            where = table.concat({ GetRealZoneText and GetRealZoneText() or "", cur.npc or "" }, " / "),
            player = PlayerLine(), client = ClientLine(),
            notes = cur.mismatch and "The English text differs from the existing translation (tekst gewijzigd)." or nil,
        }
        long, longKey = EnglishBlock(en), "english"
    else
        fields = {
            template = "translation-fix.yml",
            title = ("[Fix] %s (%s)"):format(self:Expand(q.t or en.title or "?"), tostring(cur.id)),
            ["quest-id"] = cur.id, ["quest-title"] = ("%s / %s"):format(self:Expand(q.t or ""), en.title or ""),
            client = ClientLine(),
        }
        long, longKey = DutchBlock(q), "current"
    end

    local parts = {}
    for k, v in pairs(fields) do
        if v and v ~= "" then table.insert(parts, enc(k) .. "=" .. enc(v)) end
    end
    local url = base .. table.concat(parts, "&")
    -- add the long text, shortened if needed to keep the link a safe length
    local room = MAX_URL - #url - #longKey - 2
    local encoded = enc(long)
    if #encoded > room then
        local cut = #long
        repeat
            cut = math.floor(cut * 0.85)
            encoded = enc(long:sub(1, cut) .. " [...]")
        until #encoded <= room or cut < 50
    end
    if long ~= "" and #encoded <= room then url = url .. "&" .. longKey .. "=" .. encoded end
    return url
end

------------------------------------------------------------------------
-- Window with the link, ready to copy
------------------------------------------------------------------------
local W = {}
local function Build()
    local f = NQ.MakeWindow("SpeurtochtNLReport", 540, 250, "Melden · Report")
    W.frame = f
    local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    help:SetPoint("TOPLEFT", f.titleText, "BOTTOMLEFT", 0, -8)
    help:SetPoint("RIGHT", -20, 0)
    help:SetJustifyH("LEFT")
    W.help = help

    local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetHeight(24)
    box:SetPoint("BOTTOMLEFT", 24, 84)
    box:SetPoint("BOTTOMRIGHT", -20, 84)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    box:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(W.url or "") self:HighlightText() end -- read-only
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    W.box = box

    local steps = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    steps:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -4, -10)
    steps:SetPoint("RIGHT", -20, 0)
    steps:SetJustifyH("LEFT")
    steps:SetText("1. Ctrl+C   2. Plak in je browser (Ctrl+V, Enter)   3. Klik op Submit new issue\n1. Ctrl+C   2. Paste into your browser   3. Click Submit new issue  (a free GitHub account is needed)")
end

function NQ:ShowReport(cur)
    cur = cur or self.current
    if not cur then
        self:Print("Open eerst een quest (questvenster of questlogboek). / Open a quest first.")
        return
    end
    if not W.frame then Build() end
    W.url = self:ReportURL(cur)
    if not cur.q then
        W.help:SetText(("|cffffd100%s|r heeft nog geen vertaling. Met deze link meld je de quest op GitHub, met de Engelse tekst al ingevuld.\n|cff999999This quest has no translation yet. The link reports it on GitHub with the English text filled in.|r"):format(cur.en.title or "?"))
    else
        W.help:SetText(("Fout of onduidelijk Nederlands in |cffffd100%s|r? Met deze link meld je het op GitHub, met de huidige tekst al ingevuld.\n|cff999999Spotted a mistake? The link opens a translation-fix report with the current Dutch filled in.|r"):format(self:Expand(cur.q.t or cur.en.title or "?")))
    end
    W.box:SetText(W.url)
    W.box:SetCursorPosition(0)
    W.frame:Show()
    W.box:SetFocus()
    W.box:HighlightText()
end
