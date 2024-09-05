local partyInitiativeRolls = {}
local partyEntities = {}
local meanInitiativeRoll = {}
local numPartyMembersInCombat = {}
local numPartyMembersAccountedFor = {}

Ext.Events.SessionLoaded:Subscribe(function ()
    Ext.Entity.Subscribe("CombatParticipant", function (entity, _, _)
        local entityUuid = entity.Uuid.EntityUuid
        local combatGuid = Osi.CombatGetGuidFor(entityUuid)
        if combatGuid ~= nil then
            if not partyInitiativeRolls[combatGuid] then
                partyInitiativeRolls[combatGuid] = {}
                partyEntities[combatGuid] = {}
                meanInitiativeRoll[combatGuid] = nil
                numPartyMembersInCombat[combatGuid] = Osi.CombatGetInvolvedPartyMembersCount(combatGuid)
                -- print("Num party members in combat:", numPartyMembersInCombat[combatGuid], combatGuid)
                for i = 1, numPartyMembersInCombat[combatGuid] do
                    partyInitiativeRolls[combatGuid][Osi.GetUUID(Osi.CombatGetInvolvedPartyMember(combatGuid, i))] = nil
                end
                numPartyMembersAccountedFor[combatGuid] = 0
            end
            local initiativeRoll = entity.CombatParticipant.InitiativeRoll
            if initiativeRoll ~= -100 and numPartyMembersInCombat[combatGuid] > 0 then
                local isPlayerOrAlly = Osi.IsPlayer(entityUuid) == 1 or Osi.IsAlly(entityUuid, GetHostCharacter()) == 1
                -- print("Initiative roll:", initiativeRoll, entityUuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
                if isPlayerOrAlly then
                    if partyInitiativeRolls[combatGuid][entityUuid] == nil then
                        table.insert(partyEntities[combatGuid], entity)
                        partyInitiativeRolls[combatGuid][entityUuid] = initiativeRoll
                        numPartyMembersAccountedFor[combatGuid] = numPartyMembersAccountedFor[combatGuid] + 1
                        -- print("Accounted for", numPartyMembersAccountedFor[combatGuid], "out of", numPartyMembersInCombat[combatGuid], "total")
                        -- _D(partyInitiativeRolls)
                    end
                    if meanInitiativeRoll[combatGuid] == nil and numPartyMembersAccountedFor[combatGuid] == numPartyMembersInCombat[combatGuid] then
                        -- print("All party members accounted for, averaging initiative rolls...")
                        -- _D(partyInitiativeRolls)
                        local totalInitiativeRoll = 0
                        for _, partyMemberInitiativeRoll in pairs(partyInitiativeRolls[combatGuid]) do
                            totalInitiativeRoll = totalInitiativeRoll + partyMemberInitiativeRoll
                        end 
                        meanInitiativeRoll[combatGuid] = math.floor(totalInitiativeRoll / numPartyMembersInCombat[combatGuid] + 0.5)
                        for _, partyEntity in ipairs(partyEntities[combatGuid]) do
                            partyEntity.CombatParticipant.InitiativeRoll = meanInitiativeRoll[combatGuid]
                            partyEntity.CombatParticipant.CombatHandle.CombatState.Initiatives[partyEntity] = meanInitiativeRoll[combatGuid]
                            partyEntity:Replicate("CombatParticipant")
                        end
                        -- _D(meanInitiativeRoll)
                    end
                else
                    if meanInitiativeRoll[combatGuid] ~= nil and initiativeRoll == meanInitiativeRoll[combatGuid] then
                        -- print("Enemy initiative roll:", initiativeRoll, entityUuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
                        local adjustedInitiativeRoll = math.random() > 0.5 and initiativeRoll + 1 or initiativeRoll - 1
                        -- print("Enemy might split group, bumping roll to", adjustedInitiativeRoll)
                        entity.CombatParticipant.InitiativeRoll = adjustedInitiativeRoll
                        entity.CombatParticipant.CombatHandle.CombatState.Initiatives[entity] = adjustedInitiativeRoll
                        entity:Replicate("CombatParticipant")
                        for _, partyEntity in ipairs(partyEntities[combatGuid]) do
                            partyEntity:Replicate("CombatParticipant")
                        end
                    end
                end
            end
        end
    end)
    Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function (combatGuid)
        -- print("Combat ended", combatGuid)
        partyInitiativeRolls[combatGuid] = nil
        partyEntities[combatGuid] = nil
        meanInitiativeRoll[combatGuid] = nil
        numPartyMembersInCombat[combatGuid] = nil
        numPartyMembersAccountedFor[combatGuid] = nil
    end)
end)
