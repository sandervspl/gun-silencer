-- Integration exercise: load the shipped Lua file and drive WoW events end to end.
local function equal(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function session(retail)
    local state = {
        weapon = 1001,
        muted = {},
        unmuted = {},
        played = {},
        events = {},
        log = nil,
    }

    WOW_PROJECT_MAINLINE = 1
    WOW_PROJECT_ID = retail and 1 or 2
    GunSilencerDB = nil
    SlashCmdList = {}
    DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    C_Item = {
        GetItemInfoInstant = function(itemID)
            if itemID == 1001 then
                return itemID, "Weapon", "Guns", "INVTYPE_RANGED", 0, 2, 3
            elseif itemID == 1002 then
                return itemID, "Weapon", "Bows", "INVTYPE_RANGED", 0, 2, 2
            end
        end,
    }
    GetInventoryItemID = function(_, slot)
        if slot == (retail and 16 or 18) then
            return state.weapon
        end
        return nil
    end
    UnitGUID = function() return "Player-1" end
    MuteSoundFile = function(id) state.muted[#state.muted + 1] = id end
    UnmuteSoundFile = function(id) state.unmuted[#state.unmuted + 1] = id end
    PlaySoundFile = function(path, channel)
        equal(channel, "SFX", "sound channel")
        equal(path, "Interface\\AddOns\\GunSilencer\\Media\\GunFire01.ogg", "silenced shot path")
        state.played[#state.played + 1] = path
        return true
    end
    CombatLogGetCurrentEventInfo = function()
        local log = state.log
        return 0, log[1], false, log[2], "Hunter", 0, 0, "Target-1", "Target", 0, 0, log[3]
    end
    CreateFrame = function()
        local frame = {}
        state.frame = frame
        function frame:RegisterEvent(name) state.events[name] = true end
        function frame:RegisterUnitEvent(name) state.events[name] = true end
        function frame:SetScript(_, fn) state.handler = fn end
        return frame
    end

    assert(loadfile("GunSilencer.lua"))("GunSilencer")
    local function fire(event, ...)
        assert(state.events[event], "event was not registered: " .. event)
        state.handler(state.frame, event, ...)
    end
    fire("ADDON_LOADED", "GunSilencer")
    fire("PLAYER_ENTERING_WORLD")
    equal(#state.muted, 7, "initial gun mutes")
    equal(state.events.COMBAT_LOG_EVENT_UNFILTERED, not retail or nil, "combat log registration")

    if retail then
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 75)
        equal(#state.played, 1, "Retail shot")
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 187650)
        fire("UNIT_SPELLCAST_SUCCEEDED", "target", "cast-3", 75)
        equal(#state.played, 1, "non-shot and other unit ignored")
    else
        state.log = { "RANGE_DAMAGE", "Player-2", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 0, "other player's shot ignored")
        state.log = { "RANGE_DAMAGE", "Player-1", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 1, "own shot")
        state.log = { "RANGE_MISSED", "Player-1", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 2, "ranged miss")
        state.log = { "SPELL_CAST_SUCCESS", "Player-1", 3044 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 3, "Arcane Shot")
        state.log = { "SPELL_CAST_SUCCESS", "Player-1", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 3, "Auto Shot not doubled")
    end

    state.weapon = 1002
    fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
    equal(#state.unmuted, 7, "bow restores gun sounds")
    local oldCount = #state.played
    if retail then
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", 75)
    else
        state.log = { "RANGE_DAMAGE", "Player-1", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
    end
    equal(#state.played, oldCount, "bow shot ignored")

    SlashCmdList.GUNSILENCER("off")
    state.weapon = 1001
    fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
    equal(#state.muted, 7, "disabled addon does not mute")
    SlashCmdList.GUNSILENCER("on")
    equal(#state.muted, 14, "enabling remutes")
    if retail then
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-5", 75)
    else
        state.log = { "RANGE_DAMAGE", "Player-1", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
    end
    equal(#state.played, oldCount + 1, "shot after reenabling")
    return retail and "Retail" or "Classic"
end

local sound = assert(io.open("Media/GunFire01.ogg", "rb"))
assert(sound:read(4) == "OggS", "bundled sound is an Ogg file")
sound:close()
local toc = assert(io.open("GunSilencer.toc", "r")):read("*a")
assert(toc:find("GunSilencer.lua", 1, true), "TOC loads the addon")

print(session(false) .. ": PASS")
print(session(true) .. ": PASS")
print("Sound asset and TOC: PASS")
