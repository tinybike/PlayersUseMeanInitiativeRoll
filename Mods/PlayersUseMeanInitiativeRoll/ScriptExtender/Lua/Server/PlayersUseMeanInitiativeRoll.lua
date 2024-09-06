local partyEntities = {}
local enemyEntities = {}
local meanInitiativeRoll = {}
local numPartyMembersInCombat = {}
local numPartyMembersAccountedFor = {}
local firstCombatParticipantUuid = {}
local refresherBoneTemplateId = "876c66a6-018c-48fe-8406-d90561d3db23"

local function calculateMeanInitiativeRoll(combatGuid)
    print("Calculating mean")
    local totalInitiativeRoll = 0
    local numInitiativeRolls = 0
    for _, partyEntity in pairs(partyEntities[combatGuid]) do
        _D(partyEntity)
        if partyEntity.originalInitiativeRoll ~= nil and partyEntity.hasLeftCombat == false then
            totalInitiativeRoll = totalInitiativeRoll + partyEntity.originalInitiativeRoll
            numInitiativeRolls = numInitiativeRolls + 1
        end
    end
    local meanInitiativeRoll = math.floor(totalInitiativeRoll / numInitiativeRolls + 0.5)
    print("Mean initiative roll:", meanInitiativeRoll)
    return meanInitiativeRoll
end

local function setPartyInitiativeRollToMean(combatGuid)
    for _, partyEntity in pairs(partyEntities[combatGuid]) do
        print("setting initiative roll for party entity")
        _D(partyEntity)
        if partyEntity.entity ~= nil and partyEntity.hasLeftCombat == false then
            local entity = partyEntity.entity
            entity.CombatParticipant.InitiativeRoll = meanInitiativeRoll[combatGuid]
            entity.CombatParticipant.CombatHandle.CombatState.Initiatives[entity] = meanInitiativeRoll[combatGuid]
            entity:Replicate("CombatParticipant")
            partyEntity.initiativeRoll = meanInitiativeRoll[combatGuid]
            print("Updated initiative roll for party entity to", entity.CombatParticipant.InitiativeRoll)
            _D(partyEntity)
        end
    end
end

local function forceRefresh(combatGuid)
    if firstCombatParticipantUuid[combatGuid] ~= nil then
        local x, y, z = Osi.GetPosition(firstCombatParticipantUuid[combatGuid])
        local forceRefresherUuid = Osi.CreateAt(refresherBoneTemplateId, x, y, z, 0, 0, "")
        print("Force refresher uuid", forceRefresherUuid)
        local forceRefresherEntity = Ext.Entity.Get(forceRefresherUuid)
        --_D(forceRefresherEntity:GetAllComponents())
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
            print("Replicate")
            _D(partyEntity)
            partyEntity.entity:Replicate("CombatParticipant")
        end
    end
end

local function bumpEnemyInitiativeRoll(enemyEntity)
    local entity = enemyEntity.entity
    local bumpedInitiativeRoll = math.random() > 0.5 and enemyEntity.originalInitiativeRoll + 1 or enemyEntity.originalInitiativeRoll - 1
    local enemyDisplayName = Osi.ResolveTranslatedString(Osi.GetDisplayName(entity.Uuid.EntityUuid))
    print("Enemy", enemyDisplayName, "might split group, bumping roll from", enemyEntity.originalInitiativeRoll, "to", bumpedInitiativeRoll)
    entity.CombatParticipant.InitiativeRoll = bumpedInitiativeRoll
    entity.CombatParticipant.CombatHandle.CombatState.Initiatives[entity] = bumpedInitiativeRoll
    entity:Replicate("CombatParticipant")
    enemyEntity.initiativeRoll = bumpedInitiativeRoll
    _D(enemyEntity)
end

local function bumpEnemyInitiativeRolls(combatGuid)
    print("Updating enemy entities initiative rolls if needed...")
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
    print("Num party members in combat:", numPartyMembersInCombat[combatGuid], combatGuid)
    for _, player in pairs(Osi.DB_Players:Get(nil)) do
        combatParticipantUuid = Osi.GetUUID(player[1])
        if firstCombatParticipantUuid[combatGuid] == nil then
            firstCombatParticipantUuid[combatGuid] = combatParticipantUuid
        end
        partyEntities[combatGuid][combatParticipantUuid] = {}
    end
    print("Party entities for combat", combatGuid)
    _D(partyEntities)
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
                print("Initiative roll:", initiativeRoll, entityUuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
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
                        print("Accounted for", numPartyMembersAccountedFor[combatGuid], "party members")
                        _D(partyEntities)
                        if numPartyMembersAccountedFor[combatGuid] > 1 then
                            print("Got more than 1 party members, calculating mean...")
                            meanInitiativeRoll[combatGuid] = calculateMeanInitiativeRoll(combatGuid)
                            setPartyInitiativeRollToMean(combatGuid)
                            _D(meanInitiativeRoll)
                            bumpEnemyInitiativeRolls(combatGuid)
                            replicatePartyCombatParticipants(combatGuid)
                        end
                    end
                else
                    local isEnemyOrNeutral = Osi.IsEnemy(entityUuid, GetHostCharacter()) == 1 or Osi.IsNeutral(entityUuid, GetHostCharacter()) == 1
                    print(Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
                    print("isEnemyOrNeutral:", entityUuid, isEnemyOrNeutral)
                    if isEnemyOrNeutral then
                        if initiativeRoll ~= -20 and enemyEntities[combatGuid][entityUuid] == nil then
                            enemyEntities[combatGuid][entityUuid] = {
                                uuid=entityUuid,
                                displayName=Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)),
                                entity=entity,
                                initiativeRoll=initiativeRoll,
                                originalInitiativeRoll=initiativeRoll
                            }
                            print("Enemy/neutral entities:")
                            _D(enemyEntities)
                        end
                        if meanInitiativeRoll[combatGuid] ~= nil and initiativeRoll == meanInitiativeRoll[combatGuid] then
                            print("Bumpable enemy initiative roll:", initiativeRoll, entityUuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
                            bumpEnemyInitiativeRoll(enemyEntities[combatGuid][entityUuid])
                            replicatePartyCombatParticipants(combatGuid)
                        end
                    end
                end
            end
        end
    end)
    Ext.Osiris.RegisterListener("CombatStarted", 1, "before", function (combatGuid)
        print("combat started", combatGuid)
        forceRefresh(combatGuid)
    end)
    Ext.Osiris.RegisterListener("LeftCombat", 2, "after", function (entityGuid, combatGuid)
        print("Left combat", combatGuid, entityGuid)
        local entityUuid = Osi.GetUUID(entityGuid)
        if entityUuid ~= nil and partyEntities[combatGuid][entityUuid] ~= nil then
            print(entityUuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entityUuid)))
            partyEntities[combatGuid][entityUuid].hasLeftCombat = true
        end
    end)
    Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function (combatGuid)
        print("Combat ended", combatGuid)
        partyEntities[combatGuid] = nil
        enemyEntities[combatGuid] = nil
        meanInitiativeRoll[combatGuid] = nil
        numPartyMembersInCombat[combatGuid] = nil
        numPartyMembersAccountedFor[combatGuid] = nil
        firstCombatParticipantUuid[combatGuid] = nil
    end)
end)
