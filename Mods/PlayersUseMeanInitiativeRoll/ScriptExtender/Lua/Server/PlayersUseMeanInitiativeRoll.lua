local party_initiative_rolls = {}
local party_entities = {}
local left_combat_entity_uuids = {}
local mean_initiative_roll = {}

Ext.Events.SessionLoaded:Subscribe(function ()
    Ext.Entity.Subscribe("CombatParticipant", function (entity, _, _)
        local entity_uuid = entity.Uuid.EntityUuid
        local combat_guid = Osi.CombatGetGuidFor(entity_uuid)
        local initiative_roll = entity.CombatParticipant.InitiativeRoll
        print("Initiative roll:", initiative_roll, entity_uuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entity_uuid)))
        if combat_guid ~= nil then
            if not party_initiative_rolls[combat_guid] then
                print("combat guid not found in tables, making new", combat_guid)
                party_initiative_rolls[combat_guid] = {}
                party_entities[combat_guid] = {}
                left_combat_entity_uuids[combat_guid] = {}
                mean_initiative_roll[combat_guid] = 0
            end
            if initiative_roll ~= -100 then
                local is_player_or_ally = Osi.IsPlayer(entity_uuid) == 1 or Osi.IsAlly(entity_uuid, GetHostCharacter()) == 1
                if not is_player_or_ally and initiative_roll == mean_initiative_roll[combat_guid] then
                    adjusted_initiative_roll = math.random() > 0.5 and initiative_roll + 1 or initiative_roll - 1
                    print("enemy might split group, bumping roll by 1", initiative_roll, adjusted_initiative_roll)
                    entity.CombatParticipant.InitiativeRoll = adjusted_initiative_roll
                    entity.CombatParticipant.CombatHandle.CombatState.Initiatives[entity] = adjusted_initiative_roll
                    entity:Replicate("CombatParticipant")
                elseif is_player_or_ally and left_combat_entity_uuids[combat_guid][entity_uuid] ~= true then
                    table.insert(party_initiative_rolls[combat_guid], initiative_roll)
                    table.insert(party_entities[combat_guid], entity)
                    local sum = 0
                    for _, roll in ipairs(party_initiative_rolls[combat_guid]) do
                        sum = sum + roll
                    end
                    mean_initiative_roll[combat_guid] = math.floor(sum / #party_initiative_rolls[combat_guid] + 0.5)
                    for _, entity in ipairs(party_entities[combat_guid]) do
                        entity.CombatParticipant.InitiativeRoll = mean_initiative_roll[combat_guid]
                        entity.CombatParticipant.CombatHandle.CombatState.Initiatives[entity] = mean_initiative_roll[combat_guid]
                        entity:Replicate("CombatParticipant")
                    end
                    print("mean initiative roll:", mean_initiative_roll[combat_guid], sum)
                    _D(party_initiative_rolls)
                    _D(mean_initiative_roll)
                end
            end
        end
    end)

    Ext.Osiris.RegisterListener("LeftCombat", 2, "after", function (entity_guid, combat_guid)
		local entity_uuid = Osi.GetUUID(entity_guid)
        print("left combat", combat_guid, entity_uuid, Osi.ResolveTranslatedString(Osi.GetDisplayName(entity_uuid)))
        if not left_combat_entity_uuids[combat_guid] then
            left_combat_entity_uuids[combat_guid] = {}
        end
        left_combat_entity_uuids[combat_guid][entity_uuid] = true
    end)
    
    Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function (combat_guid)
        print("******************************************************")
        print("******************************************************")
        print("******************************************************")
        print("******************************************************")
        print("*****************combat ended*************************")
        print("******************************************************")
        print("******************************************************")
        print("******************************************************")
        print("******************************************************")
        _D(party_initiative_rolls[combat_guid])
        _D(mean_initiative_roll)
        _D(left_combat_entity_uuids)
        party_initiative_rolls[combat_guid] = nil
        party_entities[combat_guid] = nil
        left_combat_entity_uuids[combat_guid] = nil
		mean_initiative_roll[combat_guid] = nil
	end)
end)
