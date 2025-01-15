function onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    if not creature or not attacker or not creature:isPlayer() then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    local playerId = creature:getId()
    local currentTime = os.mtime()

    if STOPWATCH_IMMUNITY[playerId] and STOPWATCH_IMMUNITY[playerId] > currentTime then
        return 0, primaryType, 0, secondaryType
    end

    return primaryDamage, primaryType, secondaryDamage, secondaryType
end

function onManaChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    if not creature or not attacker or not creature:isPlayer() then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    local playerId = creature:getId()
    local currentTime = os.mtime()

    if STOPWATCH_IMMUNITY[playerId] and STOPWATCH_IMMUNITY[playerId] > currentTime then
        return 0, primaryType, 0, secondaryType
    end

    return primaryDamage, primaryType, secondaryDamage, secondaryType
end