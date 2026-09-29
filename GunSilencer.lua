local addonName = ...
local frame = CreateFrame("Frame")

-- IDs from the Wago "Mute Guns" aura (WotLK) and "Cow Mute Sounds".
local gunSounds = { 567617, 567721, 567718, 567722, 567719, 567720, 567723 }
local soundDirectory = "Interface\\AddOns\\GunSilencer\\Sound\\Item\\Weapons\\Gun\\"
local reloadDelay = 0.45
local retail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local rangedSwingType = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.Ranged
local useRangedSwing = retail and rangedSwingType ~= nil

-- Gun-based shot abilities that generate a cast event instead of RANGE_DAMAGE.
-- Auto Shot is handled by RANGE_DAMAGE/RANGE_MISSED in Classic.
local shotSpells = {
    [3044] = true,   -- Arcane Shot (Classic)
    [2643] = true,   -- Multi-Shot (Classic)
    [19434] = true,  -- Aimed Shot
    [34490] = true,  -- Silencing Shot
    [53209] = true,  -- Chimera Shot
    [53301] = true,  -- Explosive Shot
    [34120] = true,  -- Steady Shot (Burning Crusade Classic)
    [56641] = true,  -- Steady Shot (later clients)
    [185358] = true, -- Arcane Shot (Retail)
    [257620] = true, -- Multi-Shot (Retail)
    [5116] = true,   -- Concussive Shot
    [19801] = true,  -- Tranquilizing Shot (Classic)
    [343246] = true, -- Tranquilizing Shot (Retail)
    [20736] = true,  -- Distracting Shot
    [19503] = true,  -- Scatter Shot
    [53351] = true,  -- Kill Shot (Classic)
    [320976] = true, -- Kill Shot (Retail)
    [77767] = true,  -- Cobra Shot (Classic)
    [193455] = true, -- Cobra Shot (Retail)
    [217200] = true, -- Barbed Shot
    [342049] = true, -- Chimaera Shot (Retail)
    [212431] = true, -- Explosive Shot (Retail)
    [257044] = true, -- Rapid Fire (Retail)
    [120360] = true, -- Barrage
    [203155] = true, -- Sniper Shot
    [1978] = true,   -- Serpent Sting (Classic)
    [3043] = true,   -- Scorpid Sting (Classic)
    [3034] = true,   -- Viper Sting (Classic)
    [19386] = true,  -- Wyvern Sting
}
local shotSpellNames

local function isShotSpell(spellID)
    if shotSpells[spellID] then
        return true
    end
    if not spellID or not C_Spell or not C_Spell.GetSpellName then
        return false
    end

    local name = C_Spell.GetSpellName(spellID)
    if not name then
        return false
    end
    if not shotSpellNames then
        shotSpellNames = {}
        for knownID in pairs(shotSpells) do
            local knownName = C_Spell.GetSpellName(knownID)
            if knownName then
                shotSpellNames[knownName] = true
            end
        end
    end
    return shotSpellNames[name] or false
end

local muted = false
local soundAvailable = true
local muteGeneration = 0

local function isGunEquipped()
    local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not getInfo then
        return false
    end

    -- Classic has a ranged slot; MoP and Retail equip ranged weapons in main hand.
    for _, slot in ipairs({ 18, 16 }) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            local _, _, _, _, _, classID, subclassID = getInfo(itemID)
            if classID == 2 and subclassID == 3 then
                return true
            end
        end
    end
    return false
end

local function updateMutes()
    local shouldMute = GunSilencerDB.enabled and soundAvailable and isGunEquipped()
    if shouldMute == muted then
        return
    end

    for _, soundID in ipairs(gunSounds) do
        if shouldMute then
            MuteSoundFile(soundID)
        else
            UnmuteSoundFile(soundID)
        end
    end
    muted = shouldMute
    muteGeneration = muteGeneration + 1
end

local function playSound(path)
    if PlaySoundFile(path, "SFX") then
        return true
    end

    local getCVar = C_CVar and C_CVar.GetCVar or GetCVar
    if getCVar and (getCVar("Sound_EnableAllSound") == "0" or getCVar("Sound_EnableSFX") == "0") then
        return false
    end

    soundAvailable = false
    updateMutes()
    DEFAULT_CHAT_FRAME:AddMessage("GunSilencer: custom sound could not play; original gun sounds restored. Check the Sound folder and Sound Effects setting, then reload.")
    return false
end

local function playReplacement()
    local variant = math.random(1, 3)
    local suffix = "0" .. variant .. ".ogg"
    if not playSound(soundDirectory .. "GunFire" .. suffix) then
        return
    end

    local generation = muteGeneration
    local function playReload()
        if muted and muteGeneration == generation then
            playSound(soundDirectory .. "GunLoad" .. suffix)
        end
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(reloadDelay, playReload)
    else
        playReload()
    end
end

local function printStatus()
    local status = GunSilencerDB.enabled and "on" or "off"
    DEFAULT_CHAT_FRAME:AddMessage("GunSilencer: " .. status)
end

SLASH_GUNSILENCER1 = "/gunsilencer"
SLASH_GUNSILENCER2 = "/gsilencer"
SlashCmdList.GUNSILENCER = function(message)
    local command = string.lower((message or ""):match("^%s*(.-)%s*$"))
    if command == "on" or command == "off" then
        GunSilencerDB.enabled = command == "on"
        updateMutes()
    else
        DEFAULT_CHAT_FRAME:AddMessage("GunSilencer: /gunsilencer on|off")
    end
    printStatus()
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then
            return
        end
        if type(GunSilencerDB) ~= "table" then
            GunSilencerDB = {}
        end
        if GunSilencerDB.enabled == nil then
            GunSilencerDB.enabled = true
        end
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        if retail then
            -- Midnight disallows addons from registering the combat log.
            frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            if useRangedSwing then
                frame:RegisterEvent("PLAYER_SWING")
            end
        else
            frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED" then
        updateMutes()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if muted and unit == "player" and ((spellID == 75 and not useRangedSwing) or isShotSpell(spellID)) then
            playReplacement()
        end
    elseif event == "PLAYER_SWING" then
        local _, swingType = ...
        if muted and swingType == rangedSwingType then
            playReplacement()
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and muted then
        local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID = CombatLogGetCurrentEventInfo()
        if sourceGUID == UnitGUID("player") then
            if subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED" then
                playReplacement()
            elseif subevent == "SPELL_CAST_SUCCESS" and isShotSpell(spellID) then
                playReplacement()
            end
        end
    end
end)
