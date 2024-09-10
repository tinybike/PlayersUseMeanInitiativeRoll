local partyEntities = {}
local enemyEntities = {}
local meanInitiativeRoll = {}
local numPartyMembersInCombat = {}
local numPartyMembersAccountedFor = {}
local firstCombatParticipantUuid = {}
local refresherBoneTemplateId = "876c66a6-018c-48fe-8406-d90561d3db23"
local DEBUG_LOGGING = true

local function debugPrint(...)
    if DEBUG_LOGGING then
        print(...)
    end
end

local function debugDump(...)
    if DEBUG_LOGGING then
        _D(...)
    end
end

local function calculateMeanInitiativeRoll(combatGuid)
    debugPrint("Calculating mean")
    local totalInitiativeRoll = 0
    local numInitiativeRolls = 0
    for _, partyEntity in pairs(partyEntities[combatGuid]) do
        debugDump(partyEntity)
        if partyEntity.originalInitiativeRoll ~= nil and partyEntity.hasLeftCombat == false then
            totalInitiativeRoll = totalInitiativeRoll + partyEntity.originalInitiativeRoll
            numInitiativeRolls = numInitiativeRolls + 1
        end
    end
    local meanInitiativeRoll = math.floor(totalInitiativeRoll / numInitiativeRolls + 0.5)
    debugPrint("Mean initiative roll:", meanInitiativeRoll)
    return meanInitiativeRoll
end

local function setPartyInitiativeRollToMean(combatGuid)
    for _, partyEntity in pairs(partyEntities[combatGuid]) do
        if partyEntity.entity ~= nil and partyEntity.hasLeftCombat == false then
            debugPrint("Setting initiative roll for party entity", partyEntity.displayName)
            local entity = partyEntity.entity
            debugDump(partyEntity)
            debugDump(entity.CombatParticipant)
            entity.CombatParticipant.InitiativeRoll = meanInitiativeRoll[combatGuid]
            if entity.CombatParticipant.CombatHandle.CombatState ~= nil then
                debugDump(entity.CombatParticipant.CombatHandle.CombatState.Initiatives)
                entity.CombatParticipant.CombatHandle.CombatState.Initiatives[entity] = meanInitiativeRoll[combatGuid]
            end
            entity:Replicate("CombatParticipant")
            partyEntity.initiativeRoll = meanInitiativeRoll[combatGuid]
            debugPrint("Initiative roll", partyEntity.displayName, ":", partyEntity.originalInitiativeRoll, "->", entity.CombatParticipant.InitiativeRoll)
            debugDump(partyEntity)
        end
    end
end

local function forceRefreshTopbar(combatGuid)
    if firstCombatParticipantUuid[combatGuid] ~= nil then
        local x, y, z = Osi.GetPosition(firstCombatParticipantUuid[combatGuid])
        local forceRefresherUuid = Osi.CreateAt(refresherBoneTemplateId, x, y, z, 0, 0, "")
        debugPrint("Force refresher uuid", forceRefresherUuid)
        local forceRefresherEntity = Ext.Entity.Get(forceRefresherUuid)
        -- debugDump(forceRefresherEntity:GetAllComponents())
        forceRefresherEntity.GameObjectVisual.Scale = 0.0
        forceRefresherEntity:Replicate("GameObjectVisual")
        Ext.Timer.WaitFor(1000, function ()
            Osi.EnterCombat(forceRefresherUuid, firstCombatParticipantUuid[combatGuid])
            Ext.Timer.WaitFor(1000, function ()
                Osi.RequestDelete(forceRefresherUuid)
            end)
        end)
    end
end

local function replicatePartyCombatParticipants(combatGuid)
    for _, partyEntity in pairs(partyEntities[combatGuid]) do
        if partyEntity.entity ~= nil then
            debugPrint("Replicate")
            debugDump(partyEntity)
            partyEntity.entity:Replicate("CombatParticipant")
        end
    end
    forceRefreshTopbar(combatGuid)
end

local function bumpEnemyInitiativeRoll(enemyEntity)
    local entity = enemyEntity.entity
    local bumpedInitiativeRoll = math.random() > 0.5 and enemyEntity.originalInitiativeRoll + 1 or enemyEntity.originalInitiativeRoll - 1
    debugPrint("Enemy", enemyEntity.displayName, "might split group, bumping roll from", enemyEntity.originalInitiativeRoll, "to", bumpedInitiativeRoll)
    debugDump(enemyEntity)
    debugDump(entity.CombatParticipant)
    entity.CombatParticipant.InitiativeRoll = bumpedInitiativeRoll
    if entity.CombatParticipant.CombatHandle.CombatState ~= nil then
        debugDump(entity.CombatParticipant.CombatHandle.CombatState.Initiatives)
        entity.CombatParticipant.CombatHandle.CombatState.Initiatives[entity] = bumpedInitiativeRoll
    end
    entity:Replicate("CombatParticipant")
    enemyEntity.initiativeRoll = bumpedInitiativeRoll
    debugDump(enemyEntity)
end

local function bumpEnemyInitiativeRolls(combatGuid)
    debugPrint("Updating enemy entities initiative rolls if needed...")
    for _, enemyEntity in pairs(enemyEntities[combatGuid]) do
        if enemyEntity.originalInitiativeRoll == meanInitiativeRoll[combatGuid] then
            bumpEnemyInitiativeRoll(enemyEntity)
        end
    end
end

local function onFirstCombatParticipant(combatGuid)
    partyEntities[combatGuid] = {}
    enemyEntities[combatGuid] = {}
    meanInitiativeRoll[combatGuid] = nil
    numPartyMembersInCombat[combatGuid] = Osi.CombatGetInvolvedPartyMembersCount(combatGuid)
    debugPrint("Num party members in combat:", numPartyMembersInCombat[combatGuid], combatGuid)
    for _, player in pairs(Osi.DB_Players:Get(nil)) do
        combatParticipantUuid = Osi.GetUUID(player[1])
        if firstCombatParticipantUuid[combatGuid] == nil then
            firstCombatParticipantUuid[combatGuid] = combatParticipantUuid
        end
        partyEntities[combatGuid][combatParticipantUuid] = {}
    end
    debugPrint("Party entities for combat", combatGuid)
    debugDump(partyEntities)
    numPartyMembersAccountedFor[combatGuid] = 0
end

Ext.Events.SessionLoaded:Subscribe(function ()
    Ext.Entity.Subscribe("CombatParticipant", function (entity, _, _)
        local entityUuid = entity.Uuid.EntityUuid
        local combatGuid = Osi.CombatGetGuidFor(entityUuid)
        if combatGuid ~= nil then
            if not partyEntities[combatGuid] then
                onFirstCombatParticipant(combatGuid)
            end
            local initiativeRoll = entity.CombatParticipant.InitiativeRoll
            if initiativeRoll ~= -100 then
                debugPrint("Initiative roll:", initiativeRoll, entityUuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
                if partyEntities[combatGuid][entityUuid] then
                    if partyEntities[combatGuid][entityUuid].entity == nil then
                        partyEntities[combatGuid][entityUuid] = {
                            uuid=entityUuid,
                            displayName=Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)),
                            entity=entity,
                            initiativeRoll=initiativeRoll,
                            originalInitiativeRoll=initiativeRoll,
                            hasLeftCombat=false
                        }
                        numPartyMembersAccountedFor[combatGuid] = numPartyMembersAccountedFor[combatGuid] + 1
                        debugPrint("Accounted for", numPartyMembersAccountedFor[combatGuid], "party members")
                        debugDump(partyEntities)
                        if numPartyMembersAccountedFor[combatGuid] > 1 then
                            debugPrint("Got more than 1 party members, calculating mean...")
                            meanInitiativeRoll[combatGuid] = calculateMeanInitiativeRoll(combatGuid)
                            setPartyInitiativeRollToMean(combatGuid)
                            debugDump(meanInitiativeRoll)
                            bumpEnemyInitiativeRolls(combatGuid)
                            replicatePartyCombatParticipants(combatGuid)
                        end
                    end
                else
                    local isEnemyOrNeutral = Osi.IsEnemy(entityUuid, GetHostCharacter()) == 1 or Osi.IsNeutral(entityUuid, GetHostCharacter()) == 1
                    debugPrint(Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
                    debugPrint("isEnemyOrNeutral:", entityUuid, isEnemyOrNeutral)
                    if isEnemyOrNeutral then
                        if initiativeRoll ~= -20 and enemyEntities[combatGuid][entityUuid] == nil then
                            enemyEntities[combatGuid][entityUuid] = {
                                uuid=entityUuid,
                                displayName=Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)),
                                entity=entity,
                                initiativeRoll=initiativeRoll,
                                originalInitiativeRoll=initiativeRoll
                            }
                            debugPrint("Enemy/neutral entities:")
                            debugDump(enemyEntities)
                        end
                        if meanInitiativeRoll[combatGuid] ~= nil and initiativeRoll == meanInitiativeRoll[combatGuid] then
                            debugPrint("Bumpable enemy initiative roll:", initiativeRoll, entityUuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
                            bumpEnemyInitiativeRoll(enemyEntities[combatGuid][entityUuid])
                            replicatePartyCombatParticipants(combatGuid)
                        end
                    end
                end
            end
        end
    end)
    Ext.Osiris.RegisterListener("EnteredCombat", 2, "before", function (entityGuid, combatGuid)
        debugPrint("Entered combat", combatGuid, entityGuid)
        local entityUuid = Osi.GetUUID(entityGuid)
        if entityUuid ~= nil and partyEntities[combatGuid][entityUuid] ~= nil then
            debugDump(partyEntities)
            if partyEntities[combatGuid][entityUuid].hasLeftCombat == true then
                partyEntities[combatGuid][entityUuid].hasLeftCombat = false
                partyEntities[combatGuid][entityUuid].initiativeRoll = partyEntities[combatGuid][entityUuid].originalInitiativeRoll
                if partyEntities[combatGuid][entityUuid].initiativeRoll ~= meanInitiativeRoll[combatGuid] then
                    debugPrint("Adjusted re-entered combat participant, setting initiative roll to mean again...")
                    setPartyInitiativeRollToMean(combatGuid)
                end
                debugPrint("Restored initiative roll for", entityUuid)
                debugDump(partyEntities)
            end
        end
    end)
    Ext.Osiris.RegisterListener("LeftCombat", 2, "after", function (entityGuid, combatGuid)
        debugPrint("Left combat", combatGuid, entityGuid)
        local entityUuid = Osi.GetUUID(entityGuid)
        if entityUuid ~= nil and partyEntities[combatGuid][entityUuid] ~= nil then
            debugPrint(entityUuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
            partyEntities[combatGuid][entityUuid].hasLeftCombat = true
        end
    end)
    Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function (combatGuid)
        debugPrint("Combat ended", combatGuid)
        partyEntities[combatGuid] = nil
        enemyEntities[combatGuid] = nil
        meanInitiativeRoll[combatGuid] = nil
        numPartyMembersInCombat[combatGuid] = nil
        numPartyMembersAccountedFor[combatGuid] = nil
        firstCombatParticipantUuid[combatGuid] = nil
    end)
end)
