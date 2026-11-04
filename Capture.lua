--[[
    SpeurtochtNL - Capture
    Records the English text of every quest you see that has no Dutch
    translation yet (and translated quests whose English text has changed,
    which matters for WoW Forever). Stored in SpeurtochtNLCapture, saved to
    WTF\Account\<ACCOUNT>\SavedVariables\SpeurtochtNL.lua when you log out or /reload.

    tools/capture_to_json.py turns that file into a JSON batch for translation.
]]
local _, NQ = ...

local FIELDS = { "title", "desc", "obj", "progress", "reward" }

local function Merge(store, id, cur)
    local e = store[id] or {}
    for _, k in ipairs(FIELDS) do
        local v = cur.en[k]
        if v and v ~= "" then e[k] = v end
    end
    e.zone = e.zone or (GetRealZoneText and GetRealZoneText())
    if cur.source ~= "log" and UnitExists("npc") then e.npc = e.npc or UnitName("npc") end
    e.build = NQ.build
    e.toc = NQ.toc
    -- Who saw it: the client has already put the player's name, class and race
    -- into the English text, so tools/import_capture.py needs these to turn them
    -- back into $n $c $r. Level and faction place the quest in the plan.
    e.pname = UnitName and UnitName("player") or nil
    e.pclass = UnitClass and UnitClass("player") or nil
    e.prace = UnitRace and UnitRace("player") or nil
    e.psex = UnitSex and UnitSex("player") or nil
    e.plevel = UnitLevel and UnitLevel("player") or nil
    e.faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    if cur.level and cur.level > 0 then e.level = cur.level end
    e.seen = time()
    store[id] = e
    return e
end

NQ:On("QuestShown", function(cur)
    if not cur or not NQ.db.capture then return end
    local id = cur.id
    if not id or id == 0 then
        -- No ID (shouldn't happen on modern clients): key by title instead
        id = "t:" .. (cur.en.title or "?")
    end
    if not cur.q then
        local isNew = NQ.capture.quests[id] == nil
        Merge(NQ.capture.quests, id, cur)
        if isNew and NQ.db.debug then NQ:Print("nieuwe quest bewaard: %s", cur.en.title or id) end
    elseif cur.mismatch then
        Merge(NQ.capture.changed, id, cur)
    end
end)

function NQ:CaptureStats()
    local n, c = 0, 0
    for _ in pairs(self.capture.quests) do n = n + 1 end
    for _ in pairs(self.capture.changed) do c = c + 1 end
    return n, c
end
