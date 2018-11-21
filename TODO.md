## Todo

- [x] re-enable vehicles
- [x] XP auras
- [ ] revise sister guild logic:
  ```Lua
  local guildies = {}
  local unitID = "party" .. partyIndex
  local name = UnitName(unitID)

  OnEvent GROUP_JOINED, GROUP_ROSTER_UPDATE do
      if UnitIsInMyGuild(unitID) then return true

      local guild = GetGuildInfo(unitID or name)

      GuildRoster()
  end

  OnEvent GUILD_ROSTER_UPDATE do
      for i = 1, GetNumGuildMembers() do
          local guildieName = GetGuildRosterInfo(i)
          guildies[guildieName] = true
      end
  end
  
  -- player may be in a sister guild or no guild
  table.insert(whoQueue, name)

  OnUpdate (elapsed) do
      throttle = throttle - elapsed
      if throttle < 0 then
          throttle = 5
          if #whoQueue then
              -- check if "/who" is idle
              SetWhoToUI(false)
              SendWho("n-" .. name)
  
  OnEvent WHO_LIST_UPDATE
      -- restore results
      SetWhoToUI(true)
      for i = 1, GetNumWhoResults() do
          local name, guild = GetWhoInfo(i)
          SavedVariables.GuildieOrSisterGuildy[name] = true
      end
  end
  ```
- [ ] block vehicle passenger
- [ ] detect mass rez cast
- [ ] audit infractions done before addon install (e.g., riding skill)
- [ ] block Battlegrounds leveling
- [ ] block "PvP items"; block "spent with honor"
- [ ] add sister guild mail
- [ ] hunter: block pets
- [ ] druid: block flight-form until 70: GetShapeshiftForm() == 5 or 6 (balance)
- [ ] block city tabards
- [ ] Project70: allow flying at 70
- [ ] enforce raid progression
- [ ] guild configuration
- [ ] persist config
- [ ] block DMF profession leveling
- [ ] no talents until Molten Core set bonus

## Test

- [x] multidisciplinary trainers
- [x] vehicles: Pilgrim's Bounty tables ok
- [ ] version detection
- [x] insider/outsider group
- [ ] insider/outsider trade
- [ ] insider/outsider mail with money and attachments
- [ ] summoning stones
- [ ] insider/outsider summoning warlock
- [ ] pet battles
- [ ] vehicles: party member with Mammoth/Chopper
- [ ] sister guilds
- [ ] equipping armor reducing weapons
- [ ] message debouncing: clear on every tick or reload?
