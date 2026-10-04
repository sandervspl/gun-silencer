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
local originalGunSounds = { 567617, 567721, 567718, 567722, 567719, 567720, 567723 }

local function session(kind, transmogScenario, aimedScenario, loginScenario, projectID)
    local retail = kind ~= "Classic"
    local forever = kind == "Forever"
    local state = {
        weapon = transmogScenario and 1002 or 1001,
        appearance = transmogScenario and 2001 or nil,
        mutedFiles = {},
        played = {},
        timers = {},
        events = {},
        log = nil,
        soundFails = {},
        soundEffectsEnabled = true,
        messages = {},
        randomVariants = {},
        time = 0,
        eventStep = 1,
    }

    WOW_PROJECT_MAINLINE = 1
    WOW_PROJECT_ID = projectID or (kind == "Retail" and 1 or 2)
    GetBuildInfo = function()
        return forever and "1.60.1" or retail and "12.0.1" or "1.15.9",
            "70170", "Oct 1 2026", forever and 16001 or retail and 120001 or 11509
    end
    Enum = {
        TransmogType = { Appearance = 0 },
        TransmogModification = { Main = 0, None = 0 },
        PlayerSwingType = forever and { MainHand = 0, OffHand = 1, Ranged = 2 } or nil,
    }
    GunSilencerDB = loginScenario == "saved-off" and { enabled = false } or
        loginScenario == "saved-on" and { enabled = true } or nil
    if loginScenario then
        state.weapon = nil
        if loginScenario == "saved-off" then
            -- The client can retain file mutes across UI reloads.
            for _, id in ipairs(originalGunSounds) do state.mutedFiles[id] = true end
        end
    end
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
    C_Transmog = {
        GetSlotVisualInfo = function(location)
            equal(location.slotID, retail and 16 or 18, "transmog location")
            equal(location.type, Enum.TransmogType.Appearance, "appearance transmog type")
            equal(location.modification, Enum.TransmogModification.Main, "main appearance")
            if kind == "Retail" then
                return { appliedSourceID = state.appearance or 0 }
            end
            return 0, 0, state.appearance or 0, 0, 0, 0, false
        end,
    }
    C_TransmogOutfitInfo = kind == "Retail" and {} or nil
    C_TransmogCollection = {
        GetSourceInfo = function(sourceID)
            if sourceID == 2001 then return { itemID = 1001 } end
            if sourceID == 2002 then return { itemID = 1002 } end
        end,
    }
    GetInventoryItemID = function(_, slot)
        if slot == (retail and 16 or 18) then
            return state.weapon
        end
        return nil
    end
    UnitGUID = function() return "Player-1" end
    GetTime = function() return state.time end
    MuteSoundFile = function(id)
        state.mutedFiles[id] = true
    end
    UnmuteSoundFile = function(id)
        state.mutedFiles[id] = nil
    end
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
        function frame:RegisterEvent(name)
            assert(not (retail and name == "COMBAT_LOG_EVENT_UNFILTERED"),
                "ADDON_ACTION_FORBIDDEN: Frame:RegisterEvent(COMBAT_LOG_EVENT_UNFILTERED)")
            state.events[name] = true
        end
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
        state.time = state.time + state.eventStep
        assert(state.events[event], "event was not registered: " .. event)
        state.handler(state.frame, event, ...)
    end
    local function runTimers()
        state.time = state.time + 0.45
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
    local function gunSoundsMuted(expected, label)
        -- Native sound playback uses the same file mute regardless of its source.
        for _, id in ipairs(originalGunSounds) do
            equal(state.mutedFiles[id] == true, expected, label .. " (file " .. id .. ")")
        end
    end
    fire("ADDON_LOADED", "AnotherAddon")
    fire("ADDON_LOADED", "GunSilencer")
    gunSoundsMuted(loginScenario ~= "saved-off", "gun sounds restored from settings before entering the world")
    fire("PLAYER_ENTERING_WORLD")
    gunSoundsMuted(loginScenario ~= "saved-off", "initial gun mutes")
    equal(state.events.COMBAT_LOG_EVENT_UNFILTERED, not retail or nil, "combat log registration")
    equal(state.events.PLAYER_SWING, forever or nil, "Forever ranged swing registration")

    if loginScenario then
        equal(GunSilencerDB.enabled, loginScenario ~= "saved-off", "saved setting survives login")
        autoShot("inventory-not-ready")
        equal(#state.played, 0, "missing equipment does not invent a player gunshot")
        state.weapon = 1001
        if loginScenario == "saved-off" then
            autoShot("still-disabled")
            equal(#state.played, 0, "saved off suppresses replacement sounds")
            SlashCmdList.GUNSILENCER("on")
        end
        -- No equipment event or slash command is needed when inventory becomes ready.
        ownShot(2)
        expectVariant(1)
        autoShot("pending-before-appearance-change")
        state.appearance = 2002
        fire("TRANSMOGRIFY_SUCCESS")
        gunSoundsMuted(true, "nearby guns stay muted while player uses a bow appearance")
        autoShot("bow-appearance")
        state.appearance = 2001
        fire("TRANSMOGRIFY_SUCCESS")
        local beforeTimers = #state.played
        runTimers()
        equal(#state.played, beforeTimers, "switching appearance away and back cancels the old reload")
        ownShot(3)

        SlashCmdList.GUNSILENCER("off")
        gunSoundsMuted(false, "off restores nearby guns")
        fire("PLAYER_ENTERING_WORLD")
        equal(GunSilencerDB.enabled, false, "off survives loading screens")
        gunSoundsMuted(false, "loading screens retain off")
        state.weapon = 1002
        state.appearance = nil
        fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
        SlashCmdList.GUNSILENCER("on")
        gunSoundsMuted(true, "enabling with a bow silences nearby guns")
        autoShot("bow-after-enabling")
        equal(#state.played, beforeTimers + 2, "bow attacks have no player gun replacements")
        -- Simulate a sound-engine reset during the next loading screen.
        state.mutedFiles = {}
        state.weapon = nil
        fire("PLAYER_ENTERING_WORLD")
        gunSoundsMuted(true, "loading screens reapply global gun mutes without inventory")
        state.weapon = 1002
        state.appearance = 2001
        ownShot(1)
        equal(#state.randomVariants, 0, "all login scenario variants consumed")
        math.random = originalRandom
        return kind .. " login " .. loginScenario
    end

    if transmogScenario then
        equal(state.events.TRANSMOGRIFY_SUCCESS, true, "appearance change event registration")
        if kind == "Retail" then
            equal(state.events.TRANSMOG_DISPLAYED_OUTFIT_CHANGED, true, "outfit change event registration")
        else
            equal(state.events.TRANSMOG_DISPLAYED_OUTFIT_CHANGED, nil, "outfit event absent on older clients")
        end
        ownShot(2)
        local beforeChange = #state.played
        expectVariant(1)
        autoShot("before-appearance-change")
        state.appearance = 2002
        fire(kind == "Retail" and "TRANSMOG_DISPLAYED_OUTFIT_CHANGED" or "TRANSMOGRIFY_SUCCESS")
        gunSoundsMuted(true, "bow appearance keeps nearby guns muted")
        runTimers()
        equal(#state.played, beforeChange + 1, "appearance change cancels delayed reload")
        autoShot("bow-appearance-shot")
        equal(#state.played, beforeChange + 1, "bow appearance shot ignored")
        fire("UNIT_SPELLCAST_START", "player", "bow-aimed", 19434)
        equal(#state.played, beforeChange + 1, "bow appearance Aimed Shot has no loading cue")
        if retail then
            fire("UNIT_SPELLCAST_STOP", "player", "bow-aimed", 19434)
        end

        state.appearance = 2001
        fire("TRANSMOGRIFY_SUCCESS")
        gunSoundsMuted(true, "gun appearance retains global mutes")
        ownShot(3)

        state.weapon = 1001
        state.appearance = 2002
        fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
        gunSoundsMuted(true, "gun with bow appearance keeps nearby guns muted")
        autoShot("gun-with-bow-appearance")
        equal(#state.played, beforeChange + 3, "gun with bow appearance shot ignored")
        state.appearance = nil
        fire("TRANSMOGRIFY_SUCCESS")
        gunSoundsMuted(true, "plain gun is silenced again")
        ownShot(1)
        equal(#state.randomVariants, 0, "all transmog shot variants consumed")
        math.random = originalRandom
        return kind .. " transmog"
    end

    if aimedScenario then
        -- A real shot can still be reloading when Aimed Shot blocks the next swing.
        local beforeAimed = #state.played
        expectVariant(2)
        autoShot("before-aimed")
        fire("UNIT_SPELLCAST_START", "player", "aimed-1", 20900)
        equal(state.played[beforeAimed + 2], soundPath("GunLoad", 1), "Aimed Shot loading cue starts with the cast")
        autoShot("blocked-auto-1")
        autoShot("blocked-auto-2")
        equal(#state.played, beforeAimed + 2, "Aimed Shot suppresses phantom Auto Shots")
        equal(#state.timers, 1, "blocked Auto Shots schedule no reloads")
        runTimers()
        equal(state.played[beforeAimed + 3], soundPath("GunLoad", 2), "real shot still reloads during Aimed Shot")

        fire("UNIT_SPELLCAST_START", "target", "other-aimed", 19434)
        fire("UNIT_SPELLCAST_STOP", "target", "aimed-1", 20900)
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "unrelated", 187650)
        autoShot("still-blocked")
        equal(#state.played, beforeAimed + 3, "other casts do not end Aimed Shot suppression")

        expectVariant(1)
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "aimed-1", 20900)
        equal(state.played[beforeAimed + 4], soundPath("GunFire", 1), "completed Aimed Shot plays its own sound")
        runTimers()
        fire("UNIT_SPELLCAST_STOP", "player", "aimed-1", 20900)
        ownShot(3)

        for _, ending in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
            fire("UNIT_SPELLCAST_START", "player", "aimed-old", 19434)
            fire("UNIT_SPELLCAST_START", "player", "aimed-new", 19434)
            fire(ending, "player", "aimed-old", 19434)
            local beforeBlocked = #state.played
            autoShot("late-stop-blocked")
            equal(#state.played, beforeBlocked, "late cast end does not clear a newer Aimed Shot")
            fire(ending, "player", "aimed-new", 19434)
            ownShot(2)
        end

        -- Completion may deliver STOP before SUCCEEDED, and instant Aimed Shots have no START.
        fire("UNIT_SPELLCAST_START", "player", "aimed-stop-first", 19434)
        fire("UNIT_SPELLCAST_STOP", "player", "aimed-stop-first", 19434)
        ownShot(1, nil, 19434)
        ownShot(3, nil, 19434)
        ownShot(2)
        fire("UNIT_SPELLCAST_START", "target", "other-aimed", 19434)
        ownShot(1)
        fire("UNIT_SPELLCAST_START", "player", "other-spell", 187650)
        ownShot(2)

        -- A loading screen must not retain an abandoned cast.
        fire("UNIT_SPELLCAST_START", "player", "aimed-before-world", 19434)
        fire("PLAYER_ENTERING_WORLD")
        ownShot(3)
        equal(#state.randomVariants, 0, "all Aimed Shot scenario variants consumed")
        math.random = originalRandom
        return kind .. " Aimed Shot"
    end

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
        local beforeAimedCue = #state.played
        fire("UNIT_SPELLCAST_START", "player", "classic-aimed", 20900)
        equal(state.played[beforeAimedCue + 1], soundPath("GunLoad", 1), "Classic Aimed Shot loading cue")
        ownShot(1, "SPELL_CAST_SUCCESS", 20900) -- Aimed Shot rank 2
        ownShot(2, "SPELL_CAST_SUCCESS", 34120) -- Steady Shot in Burning Crusade Classic
        ownShot(3, "SPELL_CAST_SUCCESS", 1978) -- Serpent Sting
        ownShot(1, "SPELL_CAST_SUCCESS", 3043) -- Scorpid Sting
    end

    local beforeOverlap = #state.played
    expectVariant(2)
    if retail then
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "overlap-ability", 3044)
    else
        state.log = { "SPELL_CAST_SUCCESS", "Player-1", 3044 }
        fire("COMBAT_LOG_EVENT_UNFILTERED")
    end
    state.eventStep = 0.05
    autoShot("overlap-2")
    autoShot("overlap-3")
    autoShot("overlap-4")
    equal(state.played[beforeOverlap + 1], soundPath("GunFire", 2), "first overlapping shot")
    equal(#state.played, beforeOverlap + 1, "close ability and Auto Shots share one gunshot")
    equal(#state.timers, 1, "suppressed shots schedule no extra reloads")
    state.eventStep = 0.06
    expectVariant(1)
    autoShot("after-overlap-window")
    equal(state.played[beforeOverlap + 2], soundPath("GunFire", 1), "later shot plays without extending suppression")
    equal(#state.timers, 2, "separated shots each schedule a reload")
    state.eventStep = 1
    runTimers()
    equal(state.played[beforeOverlap + 3], soundPath("GunLoad", 2), "first overlapping reload stays paired")
    equal(state.played[beforeOverlap + 4], soundPath("GunLoad", 1), "second overlapping reload stays paired")

    local beforeHearthSounds = #state.played
    expectVariant(2)
    autoShot("cast-before-hearth")
    equal(#state.timers, 1, "reload pending before hearth")
    -- Equipment can be briefly unavailable when the loading-screen event fires.
    state.weapon = nil
    fire("PLAYER_ENTERING_WORLD")
    gunSoundsMuted(true, "hearth reapplies all gun mutes")
    state.weapon = 1001
    runTimers()
    equal(#state.played, beforeHearthSounds + 1, "hearth cancels the old reload")
    ownShot(1)

    local beforePending = #state.played
    expectVariant(2)
    autoShot("cast-pending")
    equal(state.played[beforePending + 1], soundPath("GunFire", 2), "pending shot variant")
    state.weapon = 1002
    fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
    gunSoundsMuted(true, "bow keeps nearby guns muted")
    runTimers()
    equal(#state.played, beforePending + 1, "bow cancels delayed reload")
    local oldCount = #state.played
    autoShot("cast-4")
    equal(#state.played, oldCount, "bow shot ignored")

    SlashCmdList.GUNSILENCER("off")
    state.weapon = 1001
    fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
    gunSoundsMuted(false, "disabled addon does not mute")
    SlashCmdList.GUNSILENCER("on")
    gunSoundsMuted(true, "enabling remutes")
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
    local beforeDisabledSFX = #state.played
    expectVariant(1)
    autoShot("cast-muted-sfx")
    gunSoundsMuted(true, "disabled Sound Effects do not turn off replacements")
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
    gunSoundsMuted(false, "failed sound restores original gun sounds")
    equal(#state.played, beforeFailure, "failed sound is not counted as playback")
    equal(#state.messages, 5, "failed sound reports the fallback once")
    fire("PLAYER_EQUIPMENT_CHANGED", retail and 16 or 18)
    gunSoundsMuted(false, "failed sound does not remute on equipment updates")
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
print(session("Classic", true) .. ": PASS")
print(session("Retail", true) .. ": PASS")
print(session("Forever", true) .. ": PASS")
print(session("Retail", false, true) .. ": PASS")
print(session("Forever", false, true) .. ": PASS")
for _, kind in ipairs({ "Classic", "Retail", "Forever" }) do
    for _, setting in ipairs({ "default-on", "saved-on", "saved-off" }) do
        print(session(kind, false, false, setting) .. ": PASS")
    end
end
print("Six sound assets and TOC: PASS")
for _, projectID in ipairs({ 1, 11 }) do
    local label = "Forever project " .. projectID
    print(session("Forever", false, false, nil, projectID) .. " (" .. label .. "): PASS")
    print(session("Forever", true, false, nil, projectID) .. " (" .. label .. "): PASS")
    print(session("Forever", false, true, nil, projectID) .. " (" .. label .. "): PASS")
    for _, setting in ipairs({ "default-on", "saved-on", "saved-off" }) do
        print(session("Forever", false, false, setting, projectID) .. " (" .. label .. "): PASS")
    end
end
