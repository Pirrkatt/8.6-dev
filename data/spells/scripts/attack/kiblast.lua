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
    exhaustTime = 0, -- Seconds before players can use the spell again
    pushExhaust = 0, -- Seconds to cast spell again after using the push spell
}
local exhaustStorageKiBlast = {}

local highDmgArea = createCombatArea({
    {1, 1, 1},
    {1, 2, 1},
    {1, 1, 1},
})

-- local cooldownCondition = Condition(CONDITION_SPELLCOOLDOWN)
-- cooldownCondition:setParameter(CONDITION_PARAM_SUBID, 176)

local blockedCreatures = {"Punching Bag", "Magic Candelabrum", "Magic Glass", "Puar", "DPS Meter", "Training Bag", "Barrel", "Akuma", "God Trainer Whis", "Iwan Quest", "Arak Quest", "Jerez Quest", "Mule Quest", 
"Quitela Quest", "Champa Quest", "Beerus Quest", "Liqueur Quest", "Sidra Quest", "Rumush Quest", "Vermoud Quest", "Giin Quest", "Goku SSJ Quest", "Goku SSJ2 Quest", "Goku SSJ3 Quest", "Janemba MVP", "Lost Saiyan MVP", "Xicor MVP", 
"Saiyan Fighter SSJ3 Quest", "Saiyan Slayer SSJ4 Quest", "Gogeta SSJ4 MVP"}

local spellData = {
    [1] = {
        combatType = COMBAT_ENERGYDAMAGE,
        distEffect = 18,
        magicEffect = 5,
        damageFactor = config.damageFactors.moderate,
        offset = {x = 1, y = 1, z = 0}, -- Offset for effect position
    },
    [2] = {
        combatType = COMBAT_ENERGYDAMAGE,
        distEffect = 17,
        magicEffect = 6,
        damageFactor = config.damageFactors.small,
        offset = {x = 1, y = 1, z = 0}, -- Offset for effect position
    },
    [3] = {
        combatType = COMBAT_ENERGYDAMAGE,
        distEffect = 19,
        magicEffect = 7,
        damageFactor = config.damageFactors.normal,
        offset = {x = 1, y = 1, z = 0}, -- Offset for effect position
    },
    [4] = {
        combatType = COMBAT_ENERGYDAMAGE,
        distEffect = 20,
        magicEffect = 8,
        damageFactor = config.damageFactors.small,
        offset = {x = 1, y = 1, z = 0}, -- Offset for effect position
    },
}

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
    return tile and tile:isWalkable() and not Creature(tile:getTopCreature()) and not tile:hasFlag(TILESTATE_PROTECTIONZONE) and not tile:hasFlag(TILESTATE_TELEPORT) and not tile:hasFlag(TILESTATE_FLOORCHANGE) and not tile:hasFlag(TILESTATE_BLOCKSOLID) and not tile:hasFlag(TILESTATE_IMMOVABLEBLOCKSOLID)
end

local function pushTarget(playerId, targetId)
    local player = Player(playerId)
    local target = Creature(targetId)

    if not player or not target or player == target then
        return false
    end

    --  if target:isMovementBlocked() then
    --      return false
    --  end

    local playerPosition = player:getPosition()
    local targetPosition = target:getPosition()

    if playerPosition.z ~= targetPosition.z then
        return false
    end

    local nextPosition = getPushPosition(playerPosition, targetPosition)

    if tryTeleport(nextPosition) then
        target:teleportTo(nextPosition)
        --targetPosition:sendMagicEffect(CONST_ME_POFF)
        return true
    else
        --targetPosition:sendMagicEffect(CONST_ME_STUN)
        -- addEvent(function()
        --      local t = Creature(targetId)
        --      if t then
        --          t:setMovementBlocked(false)
        --      end
        --      end, config.stunTime * 1000)
        --  target:setMovementBlocked(true)
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

local function castSpell(playerId, spellId)
    local player = Player(playerId)
    if not player then return end
    local target = player:getTarget()
    if not target then return end

    local spell = spellData[spellId]
    if not spell then
        error("Spell variable does not exist for playerId: " .. playerId)
    end

    local playerPos = player:getPosition()
    local targetPos = target:getPosition()
    local distance = playerPos:getDistance(targetPos)
    local milliseconds = distance * config.delayFactor

    playerPos:sendDistanceEffect(targetPos, spell.distEffect)

    addEvent(function()
        local player = Player(playerId)
        if not player then return end

        local target = player:getTarget()
        if not target then return end

        local playerLevel = player:getLevel()
        local playerMagicLevel = player:getMagicLevel()

        local minDmg = ((playerLevel * 5) + (playerMagicLevel * 12.5) + 25) * spell.damageFactor
        local maxDmg = ((playerLevel * 5) + (playerMagicLevel * 14) + 50) * spell.damageFactor

        -- Manually adjust the position using offset values
        local effectPosition = Position(
            targetPos.x + spell.offset.x,
            targetPos.y + spell.offset.y,
            targetPos.z + spell.offset.z
        )
        effectPosition:sendMagicEffect(spell.magicEffect)

        -- Damage application
        doTargetCombatHealth(player, target, spell.combatType, -minDmg, -maxDmg, CONST_ME_NONE)
        spell.func(player, target, minDmg, maxDmg)
    end, milliseconds)
end

function onCastSpell(player, variant)
    local playerId = player:getId()
    if exhaustStorageKiBlast[playerId] then
        if exhaustStorageKiBlast[playerId] - os.time() > 0 then
            player:sendCancelMessage("You are exhausted.")
            player:getPosition():sendMagicEffect(CONST_ME_POFF)
            return false
        end
    end

    if KIBLAST_DATA[playerId] and KIBLAST_DATA[playerId].lastUse and os.time() >= (KIBLAST_DATA[playerId].lastUse + config.totalTime) then
        KIBLAST_DATA[playerId] = nil
    end

    if not KIBLAST_DATA[playerId] then
		KIBLAST_DATA[playerId] = {}
        KIBLAST_DATA[playerId].state = "start"
    end

    if KIBLAST_DATA[playerId].state == "start" then
        KIBLAST_DATA[playerId].state = "cycling"
        KIBLAST_DATA[playerId].lastUse = os.time()
        player:sendExtendedOpcode(config.opCode, 'start')
        return true
    end

	if KIBLAST_DATA[playerId].state == "cycling" then
        exhaustStorageKiBlast[playerId] = (os.time() + 1)
		player:sendExtendedOpcode(config.opCode, 'stop')

		addEvent(function()
            local player = Player(playerId)
            if not player then
                return
            end

            local spellId = KIBLAST_DATA[playerId] and KIBLAST_DATA[playerId].spellId
            if not spellId then
                error("spellId could not be received in KIBLAST_DATA for playerId: " .. playerId)
            end

            KIBLAST_DATA[playerId] = nil

            -- If we're using pushSpell, add the cooldown gap between pushExhaust and exhaustTime
            if spellId == 3 then
                exhaustStorageKiBlast[playerId] = (os.time() + (config.pushExhaust - 1)) -- We already add 1 second as a fail-safe before the addEvent
                -- cooldownCondition:setParameter(CONDITION_PARAM_TICKS, config.pushExhaust * 1000)
            else
                exhaustStorageKiBlast[playerId] = (os.time() + (config.exhaustTime - 1))
                -- cooldownCondition:setParameter(CONDITION_PARAM_TICKS, config.exhaustTime * 1000)
            end
            -- player:addCondition(cooldownCondition)

            local target = player:getTarget()
            if not target then
                return
            end

			castSpell(playerId, spellId)
		end, 100)
        return false
	end
	return true
end
