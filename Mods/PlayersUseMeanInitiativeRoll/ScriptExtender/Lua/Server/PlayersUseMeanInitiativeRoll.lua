local partyInitiativeRolls = {}
local partyEntities = {}
local meanInitiativeRoll = {}
local partyMemberEntityUuidsChangedInitiative = {}

Ext.Events.SessionLoaded:Subscribe(function ()
    Ext.Entity.Subscribe("CombatParticipant", function (entity, _, _)
        local entityUuid = entity.Uuid.EntityUuid
        local combatGuid = Osi.CombatGetGuidFor(entityUuid)
        if combatGuid ~= nil then
            if not partyInitiativeRolls[combatGuid] then
                partyInitiativeRolls[combatGuid] = {}
                partyEntities[combatGuid] = {}
                meanInitiativeRoll[combatGuid] = 0
                partyMemberEntityUuidsChangedInitiative[combatGuid] = {}
                local numPartyMembersInCombat = Osi.CombatGetInvolvedPartyMembersCount(combatGuid)
                for i = 1, numPartyMembersInCombat do
                    partyMemberEntityUuidsChangedInitiative[combatGuid][Osi.GetUUID(Osi.CombatGetInvolvedPartyMember(combatGuid, i))] = false
                end
            end
            local initiativeRoll = entity.CombatParticipant.InitiativeRoll
            if initiativeRoll ~= -100 then
                local isPlayerOrAlly = Osi.IsPlayer(entityUuid) == 1 or Osi.IsAlly(entityUuid, GetHostCharacter()) == 1
                -- print("Initiative roll:", initiativeRoll, entityUuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
                -- _D(partyMemberEntityUuidsChangedInitiative)
                if not isPlayerOrAlly and initiativeRoll == meanInitiativeRoll[combatGuid] then
                    local adjustedInitiativeRoll = math.random() > 0.5 and initiativeRoll + 1 or initiativeRoll - 1
                    print("enemy might split group, bumping roll by 1", initiativeRoll, adjustedInitiativeRoll)
                    entity.CombatParticipant.InitiativeRoll = adjustedInitiativeRoll
                    entity.CombatParticipant.CombatHandle.CombatState.Initiatives[entity] = adjustedInitiativeRoll
                    entity:Replicate("CombatParticipant")
                end
                if isPlayerOrAlly and partyMemberEntityUuidsChangedInitiative[combatGuid][entityUuid] == false then
                    table.insert(partyInitiativeRolls[combatGuid], initiativeRoll)
                    table.insert(partyEntities[combatGuid], entity)
                    local sum = 0
                    for _, roll in ipairs(partyInitiativeRolls[combatGuid]) do
                        sum = sum + roll
                    end
                    meanInitiativeRoll[combatGuid] = math.floor(sum / #partyInitiativeRolls[combatGuid] + 0.5)
                    for _, partyEntity in ipairs(partyEntities[combatGuid]) do
                        partyEntity.CombatParticipant.InitiativeRoll = meanInitiativeRoll[combatGuid]
                        partyEntity.CombatParticipant.CombatHandle.CombatState.Initiatives[partyEntity] = meanInitiativeRoll[combatGuid]
                        partyEntity:Replicate("CombatParticipant")
                    end
                    partyMemberEntityUuidsChangedInitiative[combatGuid][entityUuid] = true
                    -- _D(meanInitiativeRoll)
                end
            end
        end
    end)
    Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function (combatGuid)
        -- print("combat ended", combatGuid)
        partyInitiativeRolls[combatGuid] = nil
        partyEntities[combatGuid] = nil
        meanInitiativeRoll[combatGuid] = nil
        partyMemberEntityUuidsChangedInitiative[combatGuid] = nil
    end)
end)
