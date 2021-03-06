
local L = setmetatable({}, {
        __call = function (self, key)
            local lang = rawget(self, GetLocale())
            return (lang and lang[key] ~= true and lang[key]) or key
        end,
})

local AddonName = "Project60"

local VERSION_PREFIX = AddonName
local VERSION_SCOPE = "GUILD" -- "CHANNEL"
local VERSION_CHANNEL = AddonName
local VERSION_PATTERN = "^[0-9.-]+$"

local SLASHCMD = string.gsub(AddonName, "%s+", "")

local config = {
    enabled = true,
    enforce = true,
    version = "2018-11-26",
    ignored_version_senders = {},
    -- XXX make end-user configurable
    sister_guilds = {"Classic Alpha", "Classic Chads", "No Changes", "Project Cold Flame"},
    sister_characters = {},
}

-- CONSTANTS

local LEVEL_RIDING = 40

local RACES_ALLOWED = {
    Human = true,
    NightElf = true,
    Dwarf = true,
    Gnome = true,
    Orc = true,
    Troll = true,
    Scourge = true,
    Tauren = true,
}

local CLASSES_ALLOWED = {
    DRUID = true,
    HUNTER = true,
    MAGE = true,
    PALADIN = true,
    PRIEST = true,
    ROGUE = true,
    ROGUE = true,
    SHAMAN = true,
    WARLOCK = true,
}

local MAPAREA_DISALLOWED = {
    [101] = true, -- Outland
    [113] = true, -- Northrend
    [198] = true, -- Mount Hyjal
    [241] = true, -- Twilight Highlands
    [249] = true, -- Uldum
    [276] = true, -- The Maelstrom
    [424] = true, -- Pandaria
    [572] = true, -- Draenor
    [619] = true, -- Broken Isles
    [876] = true, -- Kul Tiras
    [875] = true, -- Zandalar

    [94] = true, -- Eversong Woods
    [95] = true, -- "Ghostlands
    [97] = true, -- Azuremist Isle
    [106] = true, -- Bloodmist Isle
    [179] = true, -- Gilneas
    [194] = true, -- Kezan
    [174] = true, -- The Lost Isles
    [378] = true, -- The Wandering Isle
}

local AURAS_DISALLOWED = {
    [136583] = true, -- Darkmoon Top Hat
    [127250] = true, -- Ancient Knowledge
    [146939] = true, -- Enduring Elixir of Wisdom
    [189375] = true, -- Rapid Mind
    [178119] = true, -- Accelerated Learning
    [258645] = true, -- Insightful Rubellite
    [24705] = true, -- Grim Visage
    [71354] = true, -- Heirloom Experience Bonus +5%
    [57353] = true, -- Heirloom Experience Bonus +10%
    [91991] = true, -- Juju Instinct
    [46668] = true, -- WHEE!
    [42138] = true, -- Brewfest Enthusiast
    [29175] = true, -- Ribbon Dance
    [95988] = true, -- Reverence for the Flame
    [100951] = true, -- WoW's 8th Anniversary
    [132700] = true, -- WoW's 9th Anniversary
    [150986] = true, -- WoW's 10th Anniversary
    [188454] = true, -- WoW's 11th Anniversary
    [219159] = true, -- WoW's 12th Anniversary
    [243305] = true, -- WoW's 13th Anniversary
    [277952] = true, -- WoW's 14th Anniversary
}

-- expose for debugging
--DEBUG Project60 = config

-- debounces repeated messages
local recentMessages = {}

local function Debounce(message)
    local fresh = not recentMessages[message]
    recentMessages[message] = true
    return fresh
end

local muted_version_senders = {}

-- prefaces messages with addon name
local function ChatMessage(fmt, ...)
    fmt = string.format("|cffc0c0c0%s:|r %s", AddonName, fmt)
    local message = string.format(fmt, ...)
    if Debounce(message) then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local eventFrame = CreateFrame("Frame", AddonName)

-- other uncontested versions have a better chance at announcing first
local versionAnnouncementCountdown = 120

local function ResetVersionAnnouncementInterval()
    -- include some randomness to prevent thundering herd
    versionAnnouncementCountdown = 60 + math.random(60)
end

local function NeverAnnounceVersion()
    -- announce shortly after the universe's heat death
    versionAnnouncementCountdown = math.huge
end

local function AnnounceVersion()
    if VERSION_SCOPE == "GUILD" and not IsInGuild() then return end
    if VERSION_SCOPE == "PARTY" and not IsInGroup() then return end
    if VERSION_SCOPE == "RAID" and not IsInGroup() then return end

    C_ChatInfo.SendAddonMessage(VERSION_PREFIX, config.version, VERSION_SCOPE, VERSION_CHANNEL)
end

-- AUDIT

-- AUDIT/AREA

local function AllowedArea(areaID)
    while true do
        local mapInfo = C_Map.GetMapInfo(areaID)
        if mapInfo.mapType == 0 then break end

        if MAPAREA_DISALLOWED[mapInfo.mapID] then return false end
        if MAPAREA_DISALLOWED[mapInfo.name] then return false end

        areaID = mapInfo.parentMapID
    end

    return true
end

StaticPopupDialogs["PROJECT60_DISALLOWED_AREA"] = {
    button1 = OKAY,
    text = L("Disallowed area %s"),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
    sound = SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST,
}

local function AuditArea()
    local areaID = C_Map.GetBestMapForUnit("player")
    if not AllowedArea(areaID) then
        local mapDetails = C_Map.GetMapInfo(areaID)
        StaticPopup_Show("PROJECT60_DISALLOWED_AREA", mapDetails.name)
    end
end

-- AUDIT/AURA

local function AllowedAura(spellID)
    return not AURAS_DISALLOWED[spellID]
end

function AuditAuras()
    for auraIndex = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitAura("player", auraIndex)
        if not AllowedAura(spellID) then
            if config.enforce then
                CancelUnitBuff("player", auraIndex)
                ChatMessage(L("Cancelled aura %s"), name)
            else
                ChatMessage(L("No aura %s"), name)
            end
        end
    end
end

-- AUDIT/MOUNT

local function AllowedMount(mountID)
    if UnitLevel("player") < LEVEL_RIDING then return false end

    -- Traveler's Tundra Mammoth
    if mountID == 284 then return false end
    -- Grand Expedition Yak
    if mountID == 460 then return false end
    -- Mechano-Hog
    if mountID == 240 then return false end
    -- Mekgineer's Chopper
    if mountID == 275 then return false end

    local _, _, _, _, mountType = C_MountJournal.GetMountInfoExtraByID(mountID)

    -- ground and Qiraji
    -- XXX overly strict by disallowing skill- or area-grounded mounts
    return mountType == 230 or mountType == 241
end

StaticPopupDialogs["PROJECT60_DISMOUNT"] = {
    button1 = OKAY,
    button2 = CANCEL,
    text = L("Dismount %s?"),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
    OnAccept = function()
        Dismount()
    end,
}

local function AuditMount()
    if not IsMounted() then return end
    if UnitOnTaxi("player") then return end
    
    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local mountName, _, _, active = C_MountJournal.GetMountInfoByID(mountID)
        if active and not AllowedMount(mountID) then
            StaticPopup_Show("PROJECT60_DISMOUNT", mountName)
            return
        end
    end
end

-- AUDIT/TRAINING

local function AllowedTrainer(serviceName)
    if string.find(serviceName, L("Jewelcrafting"), 1, true) then
        return false
    end

    if string.find(serviceName, L("Inscription"), 1, true) then
        return false
    end

    if string.find(serviceName, L("Archaeology"), 1, true) then
        return false
    end

    return true
end

local function AllowedTrainerService(serviceName, skillLevel)
    if skillLevel > 300 then return false end

    if serviceName == L("Portal: Silvermoon") then return false end
    if serviceName == L("Portal: Dalaran - Northrend") then return false end
    
    return true
end

-- AUDIT/CLASS
-- AUDIT/RACE

StaticPopupDialogs["PROJECT60_DISALLOWED_RACE"] = {
    button1 = OKAY,
    text = L("Disallowed race %s"),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
}

StaticPopupDialogs["PROJECT60_DISALLOWED_CLASS"] = {
    button1 = OKAY,
    text = L("Disallowed class %s"),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
}

local function AuditRaceAndClass()
    local race, raceEN = UnitRace("player")
    local class, classEN = UnitClass("player")

    if not RACES_ALLOWED[raceEN] then
        StaticPopup_Show("PROJECT60_DISALLOWED_RACE", race)
    end

    if not CLASSES_ALLOWED[classEN] then
        StaticPopup_Show("PROJECT60_DISALLOWED_CLASS", class)
    end
end

-- AUDIT/EQUIP

local function AllowedItem(itemID)
    if itemID == nil then return false end

    -- Annihilator (armor reducing)
    if itemID == 12798 then return false end

    local _, _, rarity = GetItemInfo(itemID)
    if rarity == LE_ITEM_QUALITY_HEIRLOOM then
        return false
    end

    -- XXX PvP item

    return true
end

local function CursorUnequip()
    local free = GetContainerNumFreeSlots(BACKPACK_CONTAINER)
    if free > 0 then
        PutItemInBackpack()
    else
        for bagID = 1, NUM_BAG_SLOTS do
            local free, bagType = GetContainerNumFreeSlots(bagID)
            if free > 0 and bagType == 0 then
                PutItemInBag(CONTAINER_BAG_OFFSET + bagID)
            end
        end
    end
end
    
local function AuditSlot(slotID)
    local itemID = GetInventoryItemID("player", slotID)
    
    if itemID and not AllowedItem(itemID) then
        if config.enforce then
            PickupInventoryItem(slotID)
            CursorUnequip()
            if CursorHasItem() then
                -- ironically, heirlooms are disposable
                local _, _, rarity = GetItemInfo(itemID)
                if rarity == LE_ITEM_QUALITY_HEIRLOOM then
                    DeleteCursorItem()
                    ChatMessage(L("Deleted heirloom"))
                end
            else
                ChatMessage(L("Unequipped heirloom or disallowed gear"))
            end
        else
            ChatMessage(L("No heirloom or disallowed gear"))
        end
    end
end

local function AuditAllSlots()
    for slotID = INVSLOT_AMMO, INVSLOT_LAST_EQUIPPED do
        AuditSlot(slotID)
    end
end

-- AUDIT/SPELLS

local function AuditSpells()
    -- XXX check for premature riding training
    -- XXX check for level >300 tradeskills
end

-- AUDIT/GROUP

local function AllowedGuild(guildName)
    -- XXX if sister_guilds is a map
    if config.sister_guilds[guildName] then return true end

    -- XXX if sister_guilds is an array
    for _, sister in ipairs(config.sister_guilds) do
        if sister == guildName then return true end
    end

    return false
end

local ALLOWED_NPCS = {
    ["The WoW Dev Team"] = true,
    ["Usuri Brightcoin"] = true, -- Currency Conversion
    ["Jepetto Joybuzz"] = true, -- Upgraded Toy
    ["Enchanter Nalthanis"] = true, -- Updated Materials
    ["Brew of the Month Club"] = true,
    ["The Postmaster"] = true,
}

local function AllowedCharacter(name)
    return ALLOWED_NPCS[name] or UnitIsInMyGuild(name) or name and config.sister_characters[name]
end

local function AllowedUnit(unitID)
    if UnitIsInMyGuild(unitID) then return true end

    local name = UnitName(unitID)
    if AllowedCharacter(name) then return true end

    -- Alas, GetGuildInfo() is ranged
    local guild = GetGuildInfo(unitID)
    if AllowedGuild(guild) then
        config.sister_characters[name] = true
        return true
    end

    return false
end

local function AllowedParty()
    if not IsInGuild() then return false end

    for partyIndex = 1, GetNumGroupMembers() - 1 do
        local unitID = "party" .. partyIndex
        if not AllowedUnit(unitID) then
            return false, unitID
        end
    end
    return true
end

local function AllowedRaid()
    if not IsInGuild() then return false end

    for raiderIndex = 1, GetNumGroupMembers() do
        local unitID = "raid" .. raidIndex
        if not AllowedUnit(unitID) then
            return false, unitID
        end
    end
    return true
end

StaticPopupDialogs["PROJECT60_LEAVE_PARTY"] = {
    button1 = YES,
    button2 = NO,
    text = L("Leave party with outsider %s?"),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
    OnAccept = function()
        LeaveParty()
    end,
}

local function AuditGroup()
    if not IsInGroup() then return end

    local allowed, outsiderUnitID = (IsInRaid() and AllowedRaid or AllowedParty)()
    if not allowed then
        local outsiderName = GetUnitName(outsiderUnitID)
        StaticPopup_Show("PROJECT60_LEAVE_PARTY", outsiderName)
    end
end

-- AREA

function eventFrame:ZONE_CHANGED()
    if not config.enabled then return end

    AuditArea()
end

-- AUCTION HOUSE

StaticPopupDialogs["PROJECT60_CLOSE_AUCITON_HOUSE"] = {
    button1 = YES,
    button2 = NO,
    text = L("Close Auction House?"),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
    OnAccept = function()
        CloseAuctionHouse()
    end,
}

function eventFrame:AUCTION_HOUSE_SHOW()
    -- XXX make the dialog take up AH frame
    StaticPopup_Show("PROJECT60_CLOSE_AUCITON_HOUSE")
end

-- AURA

function eventFrame:UNIT_AURA(unit)
    if not config.enabled then return end
    if unit ~= "player" then return end

    AuditAuras()
end

-- EQUIP

function eventFrame:PLAYER_EQUIPMENT_CHANGED(slotID, eqipped)
    AuditSlot(slotID)
end

-- GROUP

StaticPopupDialogs["PROJECT60_DECLINE_GROUP"] = {
    button1 = YES,
    button2 = NO,
    text = L("Decline group with with outsider %s?"),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
    OnAccept = function()
        DeclineGroup()
    end,
}

function eventFrame:PARTY_INVITE_REQUEST(leader)
    if not AllowedCharacter(leader) then
        StaticPopup_Show("PROJECT60_DECLINE_GROUP", leader)
    end
end

function eventFrame:GROUP_JOINED()
    AuditGroup()
end

function eventFrame:GROUP_ROSTER_UPDATE()
    AuditGroup()
end

-- HEIRLOOMS

local original_HeirloomsJournal_OnShow = nil

-- hide contents of Heirlooms tab
local function patched_HeirloomsJournal_OnShow(...)
    if config.enabled then
        -- XXX replace with dismissable opaque overlay frame
        if config.enforce then
            HeirloomsJournal:Hide()
            ChatMessage(L("Disabled Heirlooms"))
        else
            ChatMessage(L("No heirlooms"))
        end
    end

    return original_HeirloomsJournal_OnShow(...)
end

-- LFG

local original_LFD_IsEmpowered = LFD_IsEmpowered

-- disables Join button
local function patched_LFD_IsEmpowered(...)
    if config.enabled and config.enforce then
        return false
    end
    
    return original_LFD_IsEmpowered(...)
end

local original_GroupFinderFrame_OnShow = GroupFinderFrame:GetScript("OnShow")

-- timely display of message
local function patched_GroupFinderFrame_OnShow(...)
    if config.enabled then
        -- XXX replace with dismissable opaque overlay frame
        if config.enforce then
            ChatMessage(L("Disabled Dungeon Finder and Raid Finder"))
        else
            ChatMessage(L("No Dungeon Finder nor Raid Finder"))
        end
    end
    
    return original_GroupFinderFrame_OnShow(...)
end

-- LFR

local original_RaidBrowser_IsEmpowered = RaidBrowser_IsEmpowered

-- UNTESTED
local function patched_RaidBrowser_IsEmpowered(...)
    if config.enabled and config.enforce then
        return false
    end

    return original_RaidBrowser_IsEmpowered(...)
end

local original_RaidFinderFrame_OnShow = RaidFinderFrame:GetScript("OnShow")

-- timely display of message
local function patched_RaidFinderFrame_OnShow(...)
    if config.enabled then
        -- XXX replace with dismissable opaque overlay frame
        if config.enforce then
            ChatMessage(L("Disabled Dungeon Finder and Raid Finder"))
        else
            ChatMessage(L("No Dungeon Finder nor Raid Finder"))
        end
    end

    return original_RaidFinderFrame_OnShow(...)
end

-- MAIL

local original_OpenMailAttachment_OnClick = OpenMailAttachment_OnClick

StaticPopupDialogs["PROJECT60_TAKE_MAIL_ITEM"] = {
    button1 = YES,
    button2 = NO,
    text = L("Take mail item from outsider %s?"),
    hideOnEscape = true,
    showAlert = true,
    OnAccept = function(self, data)
        original_OpenMailAttachment_OnClick(data.frame, data.index)
    end,
}

-- XXX block money

local function patched_OpenMailAttachment_OnClick(frame, index)
    _, _, sender, _, money, _, _, _, _, _, _, _, isGM = GetInboxHeaderInfo(InboxFrame.openMailID)
    if not (isGM or AllowedCharacter(sender)) then
        StaticPopup_Show("PROJECT60_TAKE_MAIL_ITEM", sender, nil, {frame = frame, index = index})
        return
    end

    return original_OpenMailAttachment_OnClick(frame, index)
end

-- MOUNT

-- recent COMPANION_UPDATE("MOUNT")
local mountUpdate = false

function eventFrame:COMPANION_UPDATE(critterType)
    if critterType == "MOUNT" then
        -- defer until update as IsMounted() is not yet true
        mountUpdate = true
    end
end

--[[
-- UNTESTED
function eventFrame:UNIT_ENTERED_VEHICLE(hasVehicleUI)
    if CanExitVehicle() then
        if config.enforce then
            VehicleExit()
            ChatMessage(L("Exitted vehicle"))
        else
            ChatMessage(L("No vehicles"))
        end
    end
end
]]

-- TOYS

function eventFrame:TOYS_UPDATED()
    if not config.enabled then return end
    
    if ToyBox and ToyBox:IsVisible() then
        -- XXX replace with dismissable opaque overlay frame
        if config.enforce then
            ToyBox:Hide()
            ChatMessage(L("Disabled Toy Box"))
        else
            ChatMessage(L("No toys"))
        end
    end
end

-- TRADE

StaticPopupDialogs["PROJECT60_CANCEL_TRADE"] = {
    button1 = YES,
    button2 = NO,
    text = L("Cancel trade with outsider %s?"),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
    OnAccept = function()
        CancelTrade()
    end,
}

-- UNTESTED
function eventFrame:TRADE_SHOW(trader)
    if not AllowedUnit("npc") then
        local outsiderName = UnitName("npc")
        StaticPopup_Show("PROJECT60_CANCEL_TRADE", outsiderName)
    end
end

-- RECRUIT-A-FRIEND

StaticPopupDialogs["PROJECT60_DECLINE_LEVEL_GRANT"] = {
    button1 = YES,
    button2 = NO,
    text = L("Decline Recruit-a-Friend boost?"),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
    OnAccept = function()
        DeclineLevelGrant()
    end,
}

-- UNTESTED
function eventFrame:LEVEL_GRANT_PROPOSED()
    StaticPopup_Show("PROJECT60_DECLINE_LEVEL_GRANT")
end

-- SUMMON

function eventFrame:CONFIRM_SUMMON()
    -- XXX differentiate between warlock and meeting stone?
end

-- TALENTS

local original_AreTalentsLocked = AreTalentsLocked

-- conveniently disables the MainMenuBarMicroButton alert
local function patched_AreTalentsLocked(...)
    if config.enabled then
        if config.enforce then
            return true
        end
    end
    
    return original_AreTalentsLocked(...)
end

local original_PlayerTalentFrameTalents_OnShow = nil

-- hide contents of Talents tab
local function patched_PlayerTalentFrameTalents_OnShow(...)
    original_PlayerTalentFrameTalents_OnShow(...)

    if config.enabled then
        -- XXX replace with dismissable opaque overlay frame
        if config.enforce then
            PlayerTalentFrameTalents:Hide()
            ChatMessage(L("Disabled Talents"))
        else
            ChatMessage(L("No talents"))
        end
    end
end

local original_TalentMicroButton_HasPvpTalentAlertToShow = TalentMicroButton.HasPvpTalentAlertToShow

-- hide "You have unspent PvP points" alerts
local function patched_TalentMicroButton_HasPvpTalentAlertToShow(...)
    if config.enabled then
        if config.enforce then
            return false
        end
    end

    return original_TalentMicroButton_HasPvpTalentAlertToShow(...)
end

-- TRAINING

-- tweak minimum levels for riding skill training
local original_GetTrainerServiceInfo = GetTrainerServiceInfo

local function patched_GetTrainerServiceInfo(skillIndex)
    local serviceName, serviceType, texture, reqLevel = original_GetTrainerServiceInfo(skillIndex)
    local _, skillLevel = GetTrainerServiceSkillReq(skillIndex)

    if config.enabled then
        if not AllowedTrainerService(serviceName, skillLevel) then
            if config.enforce then
                serviceType = "unavailable"
                if Debounce("Blocked training") then
                    ChatMessage(L("Blocked training %s"), serviceName)
                end
            else
                if Debounce("No training") then
                    ChatMessage(L("No training %s"), serviceName)
                end
            end
        end

        local TRAINING_SERVICE_RELEVEL = {
            [L("Apprentice Riding")] = 40,
            [L("Journeyman Riding")] = 60,
        }

        -- cosmetically adjust level requirements for riding
        local level = TRAINING_SERVICE_RELEVEL[serviceName]
        if level then
            if config.enforce then
                reqLevel = level
                if reqLevel > UnitLevel("player") then
                    serviceType = "unavailable"
                end
                if Debounce("Adjusted level requirement") then
                    ChatMessage(L("Adjusted %s level requirement"), serviceName)
                end
            else
                if Debounce("Level requirement") then
                    ChatMessage(L("No %s until level %d"), serviceName, level)
                end
            end
        end
    end

    return serviceName, serviceType, texture, reqLevel
end

function eventFrame:TRAINER_SHOW()
    -- block a trainer if any blocked skills
    for skillIndex = 1, GetNumTrainerServices() do
        local serviceName, serviceType, texture, reqLevel = GetTrainerServiceInfo(skillIndex)
        if not AllowedTrainer(serviceName) then
            -- XXX replace with dismissable opaque overlay frame
            local trainerName = UnitName("npc")
            if config.enforce then
                CloseTrainer()
                ChatMessage(L("Closed trainer %s"), trainerName)
                break
            else
                ChatMessage(L("No training from %s"), trainerName)
            end
        end
    end
end

-- TRANSMOG

function eventFrame:TRANSMOGRIFY_OPEN()
    if not config.enabled then return end
    
    -- XXX replace with dismissable opaque overlay frame
    if config.enforce then
        C_Transmog.Close()
        ChatMessage(L("Closed transmogrification"))
    else
        ChatMessage(L("No transmogrification"))
    end
end

-- XXX triggers with TRANSMOGRIFY_OPEN
function eventFrame:TRANSMOG_COLLECTION_UPDATED()
    if not config.enabled then return end

    -- XXX replace with dismissable opaque overlay frame
    if config.enforce then
        WardrobeCollectionFrame:Hide()
        ChatMessage(L("Disabled Appearances"))
    else
        ChatMessage(L("No appearances"))
    end
end

-- XP

StaticPopupDialogs["PROJECT60_STOP_XP_GAIN"] = {
    button1 = OKAY,
    text = "Stop XP Gain",
    subText = (UnitFactionGroup("player") == "Alliance"
                   and L("Visit Behsten in Stormwind")
                   or L("Visit Slahtz in Orgrimmar")),
    enterClicksFirstButton = true,
    hideOnEscape = true,
    showAlert = true,
}

local function AllowedXP(unitID)
    return UnitLevel(unitID) < MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_CLASSIC]
end

-- UNTESTED
function eventFrame:CHAT_MSG_COMBAT_XP_GAIN()
    if not config.enabled then return end
    
    if not AllowedXP("player") and not IsXPUserDisabled() then
        StaticPopup_Show("PROJECT60_STOP_XP_GAIN")
    end
end

-- MAIN

LFD_IsEmpowered = patched_LFD_IsEmpowered
GroupFinderFrame:SetScript("OnShow", patched_GroupFinderFrame_OnShow)
RaidBrowser_IsEmpowered = patched_RaidBrowser_IsEmpowered
RaidFinderFrame:SetScript("OnShow", patched_RaidFinderFrame_OnShow)
AreTalentsLocked = patched_AreTalentsLocked
GetTrainerServiceInfo = patched_GetTrainerServiceInfo
TalentMicroButton.HasPvpTalentAlertToShow = patched_TalentMicroButton_HasPvpTalentAlertToShow
OpenMailAttachment_OnClick = patched_OpenMailAttachment_OnClick

local function Enable()
    -- reset message debouncers
    wipe(recentMessages)

    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("GROUP_JOINED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("COMPANION_UPDATE")
    --eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    eventFrame:RegisterEvent("TOYS_UPDATED")
    eventFrame:RegisterEvent("LEVEL_GRANT_PROPOSED")
    eventFrame:RegisterEvent("TRADE_SHOW")
    eventFrame:RegisterEvent("TRAINER_SHOW")
    eventFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
    eventFrame:RegisterEvent("CONFIRM_SUMMON")
    eventFrame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    eventFrame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")

    if VERSION_SCOPE == "CHANNEL" then
        JoinTemporaryChannel(VERSION_CHANNEL, nil, eventFrame:GetID())
    end

    config.enabled = true

    AuditRaceAndClass()

    AuditAllSlots()

    AuditSpells()

    AuditGroup()

    AuditArea()

    AuditAuras()

    AuditMount()

    if config.enforce then
        CloseAuctionHouse()

        if UnitInVehicle("player") then
            VehicleExit()
        end
        CancelTrade()
        CloseTrainer()
        CancelSummon()
    end

    C_ChatInfo.RegisterAddonMessagePrefix(VERSION_PREFIX)
end

local function Disable()
    eventFrame:UnregisterAllEvents()

    if VERSION_SCOPE == "CHANNEL" then
        LeaveChannelByName(VERSION_CHANNEL)
    end

    config.enabled = false
end

function eventFrame:CHAT_MSG_ADDON(prefix, message, distribution, sender)
    if prefix == VERSION_PREFIX then
        -- ignored forever
        if config.ignored_version_senders[sender] then return end

        -- muted until player next login
        if muted_version_senders[sender] then return end
        
        if message == config.version then
            -- another version leader agrees; put more time on the clock
            ResetVersionAnnouncementIntervalInterval()
        elseif message > config.version then
            -- limit abuse
            muted_version_senders[sender] = true
            if string.match(message, VERSION_PATTERN) then
                ChatMessage(L("Obsolete add-on version %s; new version %s per %s"), config.version, message, sender)
                NeverAnnounceVersion()
            end
        end
    end
end

function eventFrame:ADDON_LOADED(addon)
    if addon == "Blizzard_Collections" then
        if not original_HeirloomsJournal_OnShow then
            original_HeirloomsJournal_OnShow = HeirloomsJournal:GetScript("OnShow")
            HeirloomsJournal:SetScript("OnShow", patched_HeirloomsJournal_OnShow)
        end
    elseif addon == "Blizzard_TalentUI" then
        if not original_PlayerTalentFrameTalents_OnShow then
            original_PlayerTalentFrameTalents_OnShow = PlayerTalentFrameTalents_OnShow
            PlayerTalentFrameTalents:SetScript("OnShow", patched_PlayerTalentFrameTalents_OnShow)
        end
    end
end

function eventFrame:PLAYER_ENTERING_WORLD()
    --DEBUG ChatMessage(L("Welcome"))
    Enable()
end

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

function eventFrame:OnEvent(event, ...)
    local fn = self[event]
    if fn then
        fn(self, ...)
    end
end

eventFrame:SetScript("OnEvent", eventFrame.OnEvent)

function eventFrame:OnUpdate(elapsed)
    -- reset message debouncers (every tick)
    wipe(recentMessages)

    if mountUpdate then
        mountUpdate = false
        AuditMount()
    end

    -- send my version on a quiet channel
    versionAnnouncementCountdown = versionAnnouncementCountdown - elapsed
    if versionAnnouncementCountdown < 0 then
        AnnounceVersion()
        ResetVersionAnnouncementInterval()
    end
end

eventFrame:SetScript("OnUpdate", eventFrame.OnUpdate)

local function SlashCommand(arg)
    if arg == L("enable") and not config.enabled then
        ChatMessage(L("Enabled"))
        Enable()
    elseif arg == L("disable") and config.enabled then
        Disable()
        ChatMessage(L("Disabled"))
    elseif arg == L("enforce") and not config.enforce then
        config.enforce = true
        ChatMessage(L("Enforcement on"))
    elseif arg == L("overlook") and config.enforce then
        config.enforce = false
        ChatMessage(L("Enforcement off"))
    end
end

SlashCmdList[SLASHCMD .. "_SLASHCMD"] = SlashCommand
_G["SLASH_" .. SLASHCMD .. "_SLASHCMD1"] = "/" .. SLASHCMD


-- LOCALIZATION

L["frFR"] = {
    -- game strings
    ["Archaeology"] = "archéologue",
    ["Jewelcrafting"] = "Joaillerie",
    ["Inscription"] = "Calligraphie",
    ["Apprentice Riding"] = "Apprenti cavalier",
    ["Journeyman Riding"] = "Compagnon cavalier",

    -- area
    ["Disallowed area %s"] = nil,

    -- mount
    ["Dismount %s?"] = nil,
    ["Exitted vehicle"] = nil,
    --["No vehicles"] = nil,

    -- training
    ["Portal: Silvermoon"] = nil,
    ["Portal: Dalaran - Northrend"] = nil,
    ["Blocked training %s"] = nil,
    ["No training %s"] = nil,
    ["Adjusted %s level requirement"] = nil,
    ["No %s until level %d"] = nil,
    ["Closed trainer %s"] = nil,
    ["No training from %s"] = nil,

    -- race/class
    ["Disallowed race %s"] = nil,
    ["Disallowed class %s"] = nil,

    -- equip
    ["Deleted heirloom"] = nil,
    ["Unequipped heirloom or disallowed gear"] = nil,
    ["No heirloom or disallowed gear"] = nil,

    -- auction house
    ["Close Auction House?"] = nil,

    -- aura
    ["Cancelled aura %s"] = nil,
    ["No aura %s"] = nil,

    -- group
    ["Leave party with outsider %s?"] = nil,
    ["Decline group with outsider %s?"] = nil,
    ["No groups with outsider"] = nil,
    ["Disabled Dungeon Finder and Raid Finder"] = nil,
    ["No Dungeon Finder nor Raid Finder"] = nil,
    ["Disabled Dungeon Finder and Raid Finder"] = nil,
    ["No Dungeon Finder nor Raid Finder"] = nil,

    -- journal
    ["Disabled Heirlooms"] = nil,
    ["No heirlooms"] = nil,
    ["Disabled Toy Box"] = nil,
    ["No toys"] = nil,

    -- trade
    ["Cancel trade with outsider %s?"] = nil,

    -- recruit-a-friend
    ["Decline Recruit-a-Friend boost?"] = nil,

    -- talents
    ["Disabled Talents"] = nil,
    ["No talents"] = nil,

    -- transmog
    ["Closed transmogrification"] = nil,
    ["No transmogrification"] = nil,

    -- appearances
    ["Disabled Appearances"] = nil,
    ["No appearances"] = nil,

    -- xp
    ["Stop XP Gain"] = nil,
    ["Visit Behsten in Stormwind"] = nil,
    ["Visit Slahtz in Orgrimmar"] = nil,

    -- version
    ["Obsolete add-on version %s; new version %s per %s"] = nil,

    -- /project60
    ["Enabled"] = nil,
    ["disable"] = nil,
    ["Disabled"] = nil,
    ["enforce"] = nil,
    ["Enforcement on"] = nil,
    ["overlook"] = nil,
    ["Enforcement off"] = nil,
    ["Welcome"] = "Bonjour",

    -- mail
    ["Take mail item from outsider %s?"] = nil,
}
