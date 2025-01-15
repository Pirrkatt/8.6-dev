local config = {
    opCode = 67,
    exhaustDuration = 30, -- Seconds before players can use stopwatch again
    immunityDuration = 4, -- Immunity duration in seconds
}

local exhaust = {}
STOPWATCH_IMMUNITY = {} -- Tracks immunity timers for players

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    local playerId = player:getId()
    local currentTime = os.time()

    if exhaust[playerId] and exhaust[playerId] > currentTime then
        player:sendCancelMessage("Wait a bit before using this again.")
        player:getPosition():sendMagicEffect(CONST_ME_POFF)
        return true
    end

    exhaust[playerId] = currentTime + config.exhaustDuration
    STOPWATCH_IMMUNITY[playerId] = os.mtime() + config.immunityDuration * 1000

    -- player:setMovementBlocked(true)
    local pos = player:getPosition()
    local posString = pos.x .. "," .. pos.y .. "," .. pos.z
	local spectators = Game.getSpectators(pos, false, true, 7, 7, 5, 5)
	for _, spectator in ipairs(spectators) do
        spectator:sendExtendedOpcode(config.opCode, posString)
    end

    addEvent(function()
        local p = Player(player:getId())
        -- if p then
        -- p:setMovementBlocked(false)
        -- end
    end, config.immunityDuration * 1000)
    return true
end