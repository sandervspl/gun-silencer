-- Integration exercise: load the shipped Lua file and drive WoW events end to end.
local function equal(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local addonSoundDirectory = "Interface\\AddOns\\GunSilencer\\Sound\\Item\\Weapons\\Gun\\"

local function soundPath(kind, variant)
    return addonSoundDirectory .. kind .. "0" .. variant .. ".ogg"
end

local function session(retail)
    local state = {
        weapon = 1001,
        muted = {},
        unmuted = {},
        played = {},
        timers = {},
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
        assert(path:sub(1, #addonSoundDirectory) == addonSoundDirectory, "sound must use the addon directory")
        state.played[#state.played + 1] = path
        return true
    end
    C_Timer = {
        After = function(delay, callback)
            assert(type(delay) == "number" and delay > 0 and delay < 1, "reload delay is a short interval")
            state.timers[#state.timers + 1] = callback
        end,
    }
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
    local function runTimers()
        local pending = state.timers
        state.timers = {}
        for _, callback in ipairs(pending) do
            callback()
        end
    end
    local function ownShot(variant, subevent, spellID)
        local oldCount = #state.played
        if retail then
            fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", spellID or 75)
        else
            state.log = { subevent or "RANGE_DAMAGE", "Player-1", spellID or 75 }
            fire("COMBAT_LOG_EVENT_UNFILTERED")
        end
        equal(state.played[oldCount + 1], soundPath("GunFire", variant), "gunshot variant")
        equal(#state.timers, 1, "reload scheduled once")
        runTimers()
        equal(state.played[oldCount + 2], soundPath("GunLoad", variant), "matching reload variant")
    end
    fire("ADDON_LOADED", "GunSilencer")
    fire("PLAYER_ENTERING_WORLD")
    equal(#state.muted, 7, "initial gun mutes")
    equal(state.events.COMBAT_LOG_EVENT_UNFILTERED, not retail or nil, "combat log registration")

    if retail then
        ownShot(1)
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 187650)
        fire("UNIT_SPELLCAST_SUCCEEDED", "target", "cast-3", 75)
        equal(#state.played, 2, "non-shot and other unit ignored")
        ownShot(2, nil, 185358)
        ownShot(3)
        ownShot(1)
    else
        state.log = { "RANGE_DAMAGE", "Player-2", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 0, "other player's shot ignored")
        ownShot(1)
        ownShot(2, "RANGE_MISSED")
        ownShot(3, "SPELL_CAST_SUCCESS", 3044)
        state.log = { "SPELL_CAST_SUCCESS", "Player-1", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 6, "Auto Shot not doubled")
        ownShot(1)
    end

    local beforePending = #state.played
    if retail then
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-pending", 75)
    else
        state.log = { "RANGE_DAMAGE", "Player-1", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
    end
    equal(state.played[beforePending + 1], soundPath("GunFire", 2), "pending shot variant")
    state.weapon = 1002
    fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
    equal(#state.unmuted, 7, "bow restores gun sounds")
    runTimers()
    equal(#state.played, beforePending + 1, "bow cancels delayed reload")
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
    equal(state.played[oldCount + 1], soundPath("GunFire", 3), "shot after reenabling")
    SlashCmdList.GUNSILENCER("off")
    SlashCmdList.GUNSILENCER("on")
    runTimers()
    equal(#state.played, oldCount + 1, "disabled and re-enabled addon cancels old reload")
    ownShot(1)

    C_Timer = nil
    local beforeFallback = #state.played
    if retail then
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fallback", 75)
    else
        state.log = { "RANGE_DAMAGE", "Player-1", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
    end
    equal(state.played[beforeFallback + 1], soundPath("GunFire", 2), "fallback shot")
    equal(state.played[beforeFallback + 2], soundPath("GunLoad", 2), "fallback reload")
    return retail and "Retail" or "Classic"
end

for _, kind in ipairs({ "GunFire", "GunLoad" }) do
    for variant = 1, 3 do
        local file = "Sound/Item/Weapons/Gun/" .. kind .. "0" .. variant .. ".ogg"
        local sound = assert(io.open(file, "rb"))
        assert(sound:read(4) == "OggS", file .. " is not an Ogg file")
        sound:close()
    end
end
local toc = assert(io.open("GunSilencer.toc", "r")):read("*a")
assert(toc:find("GunSilencer.lua", 1, true), "TOC loads the addon")

print(session(false) .. ": PASS")
print(session(true) .. ": PASS")
print("Six sound assets and TOC: PASS")
