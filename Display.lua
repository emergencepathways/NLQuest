--[[
    SpeurtochtNL - Display
    Puts the Dutch text into the quest dialog and quest log, keeps the live
    English text from the client for the reader / hover tooltip, and handles
    the "EN" hover button and Alt-to-peek.

    Only quest text font strings are touched. Tooltips, chat, item names and
    the rest of the UI stay English.
]]
local _, NQ = ...

-- Font string names differ a little between client generations, so every
-- slot lists the names to try. Missing frames are skipped silently.
local SLOTS = {
    title    = { "QuestInfoTitleHeader", "QuestTitleText" },
    desc     = { "QuestInfoDescriptionText", "QuestDescription" },
    obj      = { "QuestInfoObjectivesText", "QuestObjectiveText" },
    reward   = { "QuestInfoRewardText", "QuestRewardText" },
    ptitle   = { "QuestProgressTitleText" },
    progress = { "QuestProgressText" },
    rtitle   = { "QuestRewardTitleText" },
    ltitle   = { "QuestLogQuestTitle" },
    ldesc    = { "QuestLogQuestDescription" },
    lobj     = { "QuestLogObjectivesText" },
}

local function SetSlot(slot, text)
    if not text or text == "" then return end
    for _, name in ipairs(SLOTS[slot]) do
        local fs = _G[name]
        if fs and fs.SetText then fs:SetText(text) end
    end
end

-- NQ.current describes the quest on screen:
--   source = "detail" | "progress" | "reward" | "log"
--   id, q (translation or nil), en = { title, desc, obj, progress, reward }
NQ.current = nil
NQ.showingEnglish = false

local function Track(source, id, en)
    local q, foundId, matchedBy, mismatch = NQ:Lookup(id, en.title)
    NQ.current = { source = source, id = foundId or id, q = q, en = en,
                   matchedBy = matchedBy, mismatch = mismatch,
                   npc = UnitExists("npc") and UnitName("npc") or nil }
    NQ:Fire("QuestShown", NQ.current)
    return q
end

------------------------------------------------------------------------
-- Apply Dutch (or English, for Alt-peek) to whatever is on screen
------------------------------------------------------------------------
function NQ:ApplyFrame(english)
    local cur = self.current
    if not cur or cur.source == "log" then return end
    local q, en = cur.q, cur.en
    if not q then return end
    local useEN = english or not self.db.enabled or not self.db.translateFrame
    local function pick(nl, eng) return useEN and eng or self:Expand(nl) or eng end

    if cur.source == "detail" then
        SetSlot("title", pick(q.t, en.title))
        SetSlot("desc", pick(q.d, en.desc))
        SetSlot("obj", pick(q.o, en.obj))
    elseif cur.source == "progress" then
        SetSlot("ptitle", pick(q.t, en.title))
        SetSlot("progress", pick(q.p, en.progress))
    elseif cur.source == "reward" then
        SetSlot("title", pick(q.t, en.title))
        SetSlot("rtitle", pick(q.t, en.title))
        SetSlot("reward", pick(q.c, en.reward))
    end
end

function NQ:ApplyLog(english)
    local cur = self.logCurrent
    if not cur or not cur.q then return end
    local q, en = cur.q, cur.en
    local useEN = english or not self.db.enabled or not self.db.translateLog
    local function pick(nl, eng) return useEN and eng or self:Expand(nl) or eng end
    SetSlot("ltitle", pick(q.t, en.title))
    SetSlot("ldesc", pick(q.d, en.desc))
    SetSlot("lobj", pick(q.o, en.obj))
end

------------------------------------------------------------------------
-- Quest dialog (talking to an NPC)
------------------------------------------------------------------------
local function OnDetail()
    local en = {
        title = GetTitleText and GetTitleText() or "",
        desc = GetQuestText and GetQuestText() or "",
        obj = GetObjectiveText and GetObjectiveText() or "",
    }
    Track("detail", GetQuestID and GetQuestID() or 0, en)
    NQ:ApplyFrame(NQ.showingEnglish)
end

local function OnProgress()
    local en = {
        title = GetTitleText and GetTitleText() or "",
        progress = GetProgressText and GetProgressText() or "",
    }
    Track("progress", GetQuestID and GetQuestID() or 0, en)
    NQ:ApplyFrame(NQ.showingEnglish)
end

local function OnReward()
    local en = {
        title = GetTitleText and GetTitleText() or "",
        reward = GetRewardText and GetRewardText() or "",
    }
    Track("reward", GetQuestID and GetQuestID() or 0, en)
    NQ:ApplyFrame(NQ.showingEnglish)
end

-- Run after Blizzard's own OnShow code has filled in the English text.
local function Deferred(fn)
    return function() C_Timer.After(0, fn) end
end

------------------------------------------------------------------------
-- Quest log
------------------------------------------------------------------------
local function LogQuestID(index)
    if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
        local id = C_QuestLog.GetQuestIDForLogIndex(index)
        if id and id > 0 then return id end
    end
    return select(8, GetQuestLogTitle(index))
end

local function OnLogDetails()
    local index = GetQuestLogSelection and GetQuestLogSelection()
    if not index or index == 0 then return end
    local title, _, _, isHeader = GetQuestLogTitle(index)
    if isHeader or not title then return end
    local desc, obj = GetQuestLogQuestText()
    local en = { title = title, desc = desc or "", obj = obj or "" }
    local q, id, matchedBy, mismatch = NQ:Lookup(LogQuestID(index), title)
    NQ.logCurrent = { source = "log", id = id or LogQuestID(index), q = q, en = en,
                      matchedBy = matchedBy, mismatch = mismatch }
    NQ:ApplyLog(NQ.showingEnglish)
    -- Only drive the reader from the log when no quest dialog is open
    if not (QuestFrame and QuestFrame:IsShown()) then
        NQ.current = NQ.logCurrent
        NQ:Fire("QuestShown", NQ.current)
    end
end

-- Optional: Dutch titles in the quest log list
local function OnLogUpdate()
    if not NQ.db.enabled or not NQ.db.logTitles or NQ.showingEnglish then return end
    local shown = QUESTS_DISPLAYED or 6
    for i = 1, shown do
        local btn = _G["QuestLogTitle" .. i]
        if btn and btn:IsShown() then
            local index = btn:GetID()
            local title, _, _, isHeader = GetQuestLogTitle(index)
            if title and not isHeader then
                local q = NQ:Lookup(LogQuestID(index), title)
                if q and q.t then
                    local current = btn:GetText() or ""
                    local prefix = current:match("^(.-)" .. title:gsub("%p", "%%%0")) or "  "
                    btn:SetText(prefix .. NQ:Expand(q.t))
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- "EN" hover button
------------------------------------------------------------------------
local function EnglishTooltip(owner, cur)
    if not cur then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(cur.en.title or "", 1, 0.82, 0)
    local function add(label, text)
        if text and text ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(label, 0.6, 0.8, 1)
            GameTooltip:AddLine(text, 1, 1, 1, true)
        end
    end
    add("Description", cur.en.desc)
    add("Objectives", cur.en.obj)
    add("Progress", cur.en.progress)
    add("Completion", cur.en.reward)
    if not cur.q then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Nog geen vertaling voor deze quest.", 1, 0.5, 0.25, true)
    end
    GameTooltip:Show()
end

local function MakeENButton(parent, anchorTo, getCurrent, x, y)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(34, 20)
    b:SetText("EN")
    b:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", x, y)
    b:SetFrameStrata("HIGH")
    b:SetScript("OnEnter", function(self) EnglishTooltip(self, getCurrent()) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function() NQ:ToggleReader(true) end)
    b:Hide()
    return b
end

local frameButton, logButton
function NQ:UpdateButtons()
    local on = self.db.enabled and self.db.hoverEnglish
    if frameButton then frameButton:SetShown(on and QuestFrame:IsShown()) end
    if logButton then logButton:SetShown(on and QuestLogFrame and QuestLogFrame:IsShown()) end
end

------------------------------------------------------------------------
-- Alt to peek at English
------------------------------------------------------------------------
local function SetPeek(english)
    if NQ.showingEnglish == english then return end
    NQ.showingEnglish = english
    NQ:ApplyFrame(english)
    NQ:ApplyLog(english)
    if english then
        if NQ.db.logTitles and QuestLog_Update and QuestLogFrame and QuestLogFrame:IsShown() then QuestLog_Update() end
    else
        OnLogUpdate()
    end
end

------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------
NQ:On("Login", function()
    if QuestFrameDetailPanel then QuestFrameDetailPanel:HookScript("OnShow", Deferred(OnDetail)) end
    if QuestFrameProgressPanel then QuestFrameProgressPanel:HookScript("OnShow", Deferred(OnProgress)) end
    if QuestFrameRewardPanel then QuestFrameRewardPanel:HookScript("OnShow", Deferred(OnReward)) end

    if QuestFrame then
        frameButton = MakeENButton(QuestFrame, QuestFrame, function() return NQ.current end, -48, -48)
        QuestFrame:HookScript("OnShow", function() NQ:UpdateButtons() end)
        QuestFrame:HookScript("OnHide", function()
            NQ:UpdateButtons()
            NQ:Fire("QuestHidden", "frame")
        end)
    end

    if type(QuestLog_UpdateQuestDetails) == "function" then
        hooksecurefunc("QuestLog_UpdateQuestDetails", OnLogDetails)
    end
    if type(QuestLog_Update) == "function" then
        hooksecurefunc("QuestLog_Update", OnLogUpdate)
    end
    if QuestLogFrame then
        logButton = MakeENButton(QuestLogFrame, QuestLogFrame, function() return NQ.logCurrent end, -80, -48)
        QuestLogFrame:HookScript("OnShow", function() NQ:UpdateButtons(); C_Timer.After(0, OnLogDetails) end)
        QuestLogFrame:HookScript("OnHide", function()
            NQ:UpdateButtons()
            NQ:Fire("QuestHidden", "log")
        end)
    end

    local mod = CreateFrame("Frame")
    mod:RegisterEvent("MODIFIER_STATE_CHANGED")
    mod:SetScript("OnEvent", function(_, _, key, down)
        if not NQ.db.altPeek or not NQ.db.enabled then return end
        if key == "LALT" or key == "RALT" then SetPeek(down == 1) end
    end)
end)

-- Re-apply after settings change
function NQ:Refresh()
    self:ApplyFrame(self.showingEnglish)
    self:ApplyLog(self.showingEnglish)
    OnLogUpdate()
    if QuestLog_Update and QuestLogFrame and QuestLogFrame:IsShown() and not self.db.logTitles then
        QuestLog_Update()
    end
    self:UpdateButtons()
    self:Fire("QuestShown", self.current)
end
