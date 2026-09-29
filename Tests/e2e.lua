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

local originalRandom = math.random

local function session(kind)
    local retail = kind ~= "Classic"
    local forever = kind == "Forever"
    local state = {
        weapon = 1001,
        muted = {},
        unmuted = {},
        played = {},
        timers = {},
        events = {},
        log = nil,
        soundFails = {},
        soundEffectsEnabled = true,
        messages = {},
        randomVariants = {},
    }

    WOW_PROJECT_MAINLINE = 1
    WOW_PROJECT_ID = retail and 1 or 2
    Enum = forever and { PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } } or nil
    GunSilencerDB = nil
    SlashCmdList = {}
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) state.messages[#state.messages + 1] = message end }
    local spellNames = {
        [3044] = "Arkaner Schuss", [14281] = "Arkaner Schuss",
        [2643] = "Mehrfachschuss", [14288] = "Mehrfachschuss",
        [19434] = "Gezielter Schuss", [20900] = "Gezielter Schuss",
    }
    C_Spell = { GetSpellName = function(spellID) return spellNames[spellID] end }
    C_CVar = { GetCVar = function(name)
        if name == "Sound_EnableSFX" then
            return state.soundEffectsEnabled and "1" or "0"
        end
        return "1"
    end }
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
        if not state.soundEffectsEnabled or state.soundFails[path] then
            return nil
        end
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

    local function expectVariant(variant)
        state.randomVariants[#state.randomVariants + 1] = variant
    end
    math.random = function(first, last)
        equal(first, 1, "first random variant")
        equal(last, 3, "last random variant")
        assert(#state.randomVariants > 0, "unexpected random variant selection")
        return table.remove(state.randomVariants, 1)
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
        expectVariant(variant)
        if forever and not spellID then
            fire("PLAYER_SWING", 2.8, Enum.PlayerSwingType.Ranged)
        elseif retail then
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
    local function autoShot(tag)
        if forever then
            fire("PLAYER_SWING", 2.8, Enum.PlayerSwingType.Ranged)
        elseif retail then
            fire("UNIT_SPELLCAST_SUCCEEDED", "player", tag, 75)
        else
            state.log = { "RANGE_DAMAGE", "Player-1", 75 }
            fire("COMBAT_LOG_EVENT_UNFILTERED")
        end
    end
    fire("ADDON_LOADED", "GunSilencer")
    fire("PLAYER_ENTERING_WORLD")
    equal(#state.muted, 7, "initial gun mutes")
    equal(state.events.COMBAT_LOG_EVENT_UNFILTERED, not retail or nil, "combat log registration")
    equal(state.events.PLAYER_SWING, forever or nil, "Forever ranged swing registration")

    if retail then
        ownShot(3)
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 187650)
        fire("UNIT_SPELLCAST_SUCCEEDED", "target", "cast-3", 75)
        if forever then
            fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-auto", 75)
            fire("PLAYER_SWING", 2.8, Enum.PlayerSwingType.MainHand)
        end
        equal(#state.played, 2, "non-shot and other unit ignored")
        ownShot(3, nil, 185358)
        ownShot(1)
        ownShot(2)
        ownShot(2, nil, 193455) -- Cobra Shot
        ownShot(3, nil, 217200) -- Barbed Shot
        ownShot(1, nil, 320976) -- Kill Shot
        ownShot(2, nil, 257044) -- Rapid Fire
        ownShot(3, nil, 5116) -- Concussive Shot
        ownShot(1, nil, 343246) -- Tranquilizing Shot
    else
        state.log = { "RANGE_DAMAGE", "Player-2", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 0, "other player's shot ignored")
        state.log = { "SPELL_CAST_SUCCESS", "Player-1", 187650 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 0, "non-shot cast ignored")
        ownShot(3)
        ownShot(3, "RANGE_MISSED")
        ownShot(1, "SPELL_CAST_SUCCESS", 3044)
        state.log = { "SPELL_CAST_SUCCESS", "Player-1", 75 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        equal(#state.played, 6, "Auto Shot not doubled")
        ownShot(1)
        ownShot(2, "SPELL_CAST_SUCCESS", 53351) -- Kill Shot
        ownShot(3, "SPELL_CAST_SUCCESS", 77767) -- Cobra Shot
        ownShot(1, "SPELL_CAST_SUCCESS", 5116) -- Concussive Shot
        ownShot(2, "SPELL_CAST_SUCCESS", 19801) -- Tranquilizing Shot
        ownShot(3, "SPELL_CAST_SUCCESS", 19503) -- Scatter Shot
        ownShot(1, "SPELL_CAST_SUCCESS", 20736) -- Distracting Shot
        ownShot(2, "SPELL_CAST_SUCCESS", 14281) -- Arcane Shot rank 2
        ownShot(3, "SPELL_CAST_SUCCESS", 14288) -- Multi-Shot rank 2
        ownShot(1, "SPELL_CAST_SUCCESS", 20900) -- Aimed Shot rank 2
        ownShot(2, "SPELL_CAST_SUCCESS", 34120) -- Steady Shot in Burning Crusade Classic
        ownShot(3, "SPELL_CAST_SUCCESS", 1978) -- Serpent Sting
        ownShot(1, "SPELL_CAST_SUCCESS", 3043) -- Scorpid Sting
    end

    local beforeOverlap = #state.played
    expectVariant(2)
    autoShot("overlap-1")
    expectVariant(1)
    autoShot("overlap-2")
    equal(state.played[beforeOverlap + 1], soundPath("GunFire", 2), "first overlapping shot")
    equal(state.played[beforeOverlap + 2], soundPath("GunFire", 1), "second overlapping shot")
    equal(#state.timers, 2, "both overlapping reloads scheduled")
    runTimers()
    equal(state.played[beforeOverlap + 3], soundPath("GunLoad", 2), "first overlapping reload stays paired")
    equal(state.played[beforeOverlap + 4], soundPath("GunLoad", 1), "second overlapping reload stays paired")

    local beforePending = #state.played
    expectVariant(2)
    autoShot("cast-pending")
    equal(state.played[beforePending + 1], soundPath("GunFire", 2), "pending shot variant")
    state.weapon = 1002
    fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
    equal(#state.unmuted, 7, "bow restores gun sounds")
    runTimers()
    equal(#state.played, beforePending + 1, "bow cancels delayed reload")
    local oldCount = #state.played
    autoShot("cast-4")
    equal(#state.played, oldCount, "bow shot ignored")

    SlashCmdList.GUNSILENCER("off")
    state.weapon = 1001
    fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
    equal(#state.muted, 7, "disabled addon does not mute")
    SlashCmdList.GUNSILENCER("on")
    equal(#state.muted, 14, "enabling remutes")
    expectVariant(3)
    autoShot("cast-5")
    equal(state.played[oldCount + 1], soundPath("GunFire", 3), "shot after reenabling")
    SlashCmdList.GUNSILENCER("off")
    SlashCmdList.GUNSILENCER("on")
    runTimers()
    equal(#state.played, oldCount + 1, "disabled and re-enabled addon cancels old reload")
    ownShot(1)

    C_Timer = nil
    local beforeFallback = #state.played
    expectVariant(2)
    autoShot("cast-fallback")
    equal(state.played[beforeFallback + 1], soundPath("GunFire", 2), "fallback shot")
    equal(state.played[beforeFallback + 2], soundPath("GunLoad", 2), "fallback reload")

    state.soundEffectsEnabled = false
    local beforeMutedSFX = #state.unmuted
    local beforeDisabledSFX = #state.played
    expectVariant(1)
    autoShot("cast-muted-sfx")
    equal(#state.unmuted, beforeMutedSFX, "disabled Sound Effects do not turn off replacements")
    equal(#state.played, beforeDisabledSFX, "disabled Sound Effects make no sound")
    state.soundEffectsEnabled = true
    expectVariant(1)
    autoShot("cast-restored-sfx")
    equal(state.played[beforeDisabledSFX + 1], soundPath("GunFire", 1), "shot returns when Sound Effects are enabled")
    equal(state.played[beforeDisabledSFX + 2], soundPath("GunLoad", 1), "reload returns when Sound Effects are enabled")

    state.soundFails[soundPath("GunFire", 2)] = true
    local beforeFailure = #state.played
    expectVariant(2)
    autoShot("cast-failed-audio")
    equal(#state.unmuted, 21, "failed sound restores original gun sounds")
    equal(#state.played, beforeFailure, "failed sound is not counted as playback")
    equal(#state.messages, 5, "failed sound reports the fallback once")
    fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
    equal(#state.muted, 21, "failed sound does not remute on equipment updates")
    autoShot("cast-after-failure")
    equal(#state.played, beforeFailure, "shots after audio failure use restored game sounds")
    equal(#state.messages, 5, "audio failure warning is shown only once")
    equal(#state.randomVariants, 0, "all queued random variants consumed")
    math.random = originalRandom
    return kind
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

print(session("Classic") .. ": PASS")
print(session("Retail") .. ": PASS")
print(session("Forever") .. ": PASS")
print("Six sound assets and TOC: PASS")
