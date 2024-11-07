KIBLAST_DATA = {}

local config = {
    opCode = 66,
    totalTime = 10, -- Total time player have to select a spell
    cycleDelay = 500, -- Time between each icon cycle in milliseconds

    damageFactors = {
        small = 0.6,
        normal = 1.0,
        moderate = 1.2,
    },
    pushTiles = 2, -- Tiles to push the creature
    stunTime = 2, -- Stun duration in seconds
    delayFactor = 80, -- Milliseconds per tile of distance
    exhaustTime = 2, -- Seconds before players can use the spell again
}
local exhaustStorage = {}

local highDmgArea = createCombatArea({
    {1, 1, 1},
    {1, 2, 1},
    {1, 1, 1},
})

local blockedCreatures = {"Demon", "Rotworm"}

local spellData = {
    [1] = {
        combatType = COMBAT_ENERGYDAMAGE,
        distEffect = CONST_ANI_ENERGY,
        magicEffect = CONST_ME_ENERGYAREA,
        damageFactor = config.damageFactors.normal,
    },
    [2] = {
        combatType = COMBAT_FIREDAMAGE,
        distEffect = CONST_ANI_FIRE,
        magicEffect = CONST_ME_FIREATTACK,
        damageFactor = config.damageFactors.small,
    },
    [3] = {
        combatType = COMBAT_POISONDAMAGE,
        distEffect = CONST_ANI_POISON,
        magicEffect = CONST_ME_SMALLPLANTS,
        damageFactor = config.damageFactors.moderate,
    },
    [4] = {
        combatType = COMBAT_ICEDAMAGE,
        distEffect = CONST_ANI_SMALLICE,
        magicEffect = CONST_ME_ICEAREA,
        damageFactor = config.damageFactors.small,
    },
}

local function sendExtendedJson(player, action, data)
	if data == nil then
		data = {}
	end
	player:sendExtendedOpcode(config.opCode, json.encode({action = action, data = data}))
end

local function getPushPosition(playerPos, targetPos)
    local xOffset = targetPos.x - playerPos.x
    local yOffset = targetPos.y - playerPos.y

    if math.abs(xOffset) > math.abs(yOffset) + 2 then
        xOffset = (xOffset > 0) and 1 or -1
        yOffset = 0
    elseif math.abs(yOffset) > math.abs(xOffset) + 2 then
        xOffset = 0
        yOffset = (yOffset > 0) and 1 or -1
    else
        xOffset = (xOffset ~= 0) and (xOffset / math.abs(xOffset)) or 0
        yOffset = (yOffset ~= 0) and (yOffset / math.abs(yOffset)) or 0
    end

    return Position(targetPos.x + xOffset, targetPos.y + yOffset, targetPos.z)
end

local function tryTeleport(position)
    local tile = Tile(position)
    return tile and tile:isWalkable() and not Creature(tile:getTopCreature()) and not tile:hasFlag(TILESTATE_PROTECTIONZONE)
end

local function pushTarget(playerId, targetId)
    local player = Player(playerId)
    local target = Creature(targetId)

    if not player or not target or player == target then
        return false
    end

    -- if target:isMovementBlocked() then
    --     return false
    -- end

    local playerPosition = player:getPosition()
    local targetPosition = target:getPosition()

    if playerPosition.z ~= targetPosition.z then
        return false
    end

    local nextPosition = getPushPosition(playerPosition, targetPosition)

    if tryTeleport(nextPosition) then
        target:teleportTo(nextPosition)
        targetPosition:sendMagicEffect(CONST_ME_POFF)
        return true
    else
        targetPosition:sendMagicEffect(CONST_ME_STUN)
        -- addEvent(function()
        --     local t = Creature(targetId)
        --     if t then
        --         t:setMovementBlocked(false)
        --     end
        --     end, config.stunTime * 1000)
        -- target:setMovementBlocked(true)
        return false
    end
end

local function applyHighDamage(player, target, minDmg, maxDmg)
    if player and target then
        doAreaCombatHealth(player, spellData[1].combatType, target:getPosition(), highDmgArea, -(minDmg/2), -(maxDmg/2), CONST_ME_NONE)
    end
end

local function applyManaRestore(player)
    if player then
        local missingMana = player:getMaxMana() - player:getMana()
        player:addMana(missingMana * 0.05)
    end
end

local function applyPushStun(player, target)
    for i = 1, config.pushTiles do
        addEvent(function(pid, tid)
            local player = Player(pid)
            local target = Creature(tid)

            if player and target then
                if table.contains(blockedCreatures, target:getName()) then
                    return
                end

                pushTarget(player, target)
            end
        end, 200 * (i-1), player:getId(), target:getId())
    end
end

local function applyHealthRestore(player)
    if player then
        local missingHealth = player:getMaxHealth() - player:getHealth()
        player:addHealth(missingHealth * 0.1)
    end
end

spellData[1].func = applyHighDamage
spellData[2].func = applyManaRestore
spellData[3].func = applyPushStun
spellData[4].func = applyHealthRestore

--------------------------------------------------------------------------------------------

local function castSpell(player, variant, spellId)
	if not player then return end
    local target = player:getTarget()
    if not target then return end

    local spell = spellData[spellId]

    local playerPos = player:getPosition()
    local targetPos = target:getPosition()
    local distance = playerPos:getDistance(targetPos)
    local milliseconds = distance * config.delayFactor

    playerPos:sendDistanceEffect(targetPos, spell.distEffect)

    addEvent(function(playerId)
        local player = Player(playerId)
        if not player then return end

        local target = player:getTarget()
        if not target then return end

        local playerLevel = player:getLevel()
        local playerMagicLevel = player:getMagicLevel()

        local minDmg = ((playerLevel * 5) + (playerMagicLevel * 12.5) + 25) * spell.damageFactor
        local maxDmg = ((playerLevel * 5) + (playerMagicLevel * 14) + 50) * spell.damageFactor

        -- local effectPosition = targetPos + Position(1, 1, 0)
        -- effectPosition:sendMagicEffect(985)
        doTargetCombatHealth(player, target, spell.combatType, -minDmg, -maxDmg, spell.magicEffect)
        spell.func(player, target, minDmg, maxDmg)
    end, milliseconds, player:getId())
end

function onCastSpell(player, variant)
    if exhaustStorage[player:getId()] then
        if exhaustStorage[player:getId()] - os.time() > 0 then
            player:sendCancelMessage("You are exhausted.")
            player:getPosition():sendMagicEffect(CONST_ME_POFF)
            return false
        end
    end

    if KIBLAST_DATA[player:getId()] == nil then
		KIBLAST_DATA[player:getId()] = "cycling"
		sendExtendedJson(player, 'start', config)
		return true
	elseif KIBLAST_DATA[player:getId()] == "cycling" then
        exhaustStorage[player:getId()] = (os.time() + config.exhaustTime)

		sendExtendedJson(player, 'stop')

		addEvent(function(playerId)
            local player = Player(playerId)
            if not player then return end
            local target = player:getTarget()
            if not target then
                KIBLAST_DATA[player:getId()] = nil
                return false
            end
			castSpell(player, variant, KIBLAST_DATA[player:getId()])
			KIBLAST_DATA[player:getId()] = nil
		end, 50, player:getId())
        return false
	end
	return true
end

