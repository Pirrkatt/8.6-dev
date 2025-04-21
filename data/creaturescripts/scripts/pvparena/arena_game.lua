ArenaGame = {}
ArenaGame.__index = ArenaGame

local config = {
    opCode = 69,
    matchDuration = 1, -- Game ends after x minutes
    maxKills = 1, -- Game ends after x kills
    teleportBack = Position(1000, 1000, 7), -- Where to get teleported to when game ends
    debugMode = false,
}

local mapSettings = {
    ["2x2"] = {
        ["startRed"] = Position(1039, 980, 7),
        ["startBlue"] = Position(1039, 1022, 7),
        ["respawnPoints"] = {
            Position(1031, 985, 7),
            Position(1042, 988, 7),
            Position(1028, 993, 7),
            Position(1049, 996, 7),
            Position(1031, 1006, 7),
            Position(1035, 998, 7),
            Position(1045, 1012, 7),
            Position(1028, 1015, 7)
        },
    }
}

function ArenaGame:new(id, team1, team2, mode)
    local settings = mapSettings[mode]
    if not settings then
        error("[PvP Arena] - Invalid mode: " .. tostring(mode))
    end

    local arenagame = {
        id = id,
        teamRed = team1,
        teamBlue = team2,
        mode = mode,
        score = {["teamBlue"] = 0, ["teamRed"] = 0},
        maxKills = config.maxKills,
        matchDuration = config.matchDuration,
        startTime = nil,
        endEventId = nil,
        settings = settings,
    }
    setmetatable(arenagame, ArenaGame)
    return arenagame
end

function ArenaGame:resetPlayersHealth()
    for _, playerId in pairs(self:getPlayers()) do
        local player = Player(playerId)
        if player then
            player:addHealth(player:getMaxHealth())
            player:addMana(player:getMaxMana())
        end
    end
end

function ArenaGame:teleportPlayers(start)
    if start then
        for _, playerId in pairs(self.teamRed) do
            local player = Player(playerId)
            if not player then
                error("Player does not exist or is not online.") -- Cancel match?
                return false
            end
            player:teleportTo(self.settings["startRed"])
        end

        for _, playerId in pairs(self.teamBlue) do
            local player = Player(playerId)
            if not player then
                error("Player does not exist or is not online.")
                return false
            end
            player:teleportTo(self.settings["startBlue"])
        end
    else
        for _, playerId in pairs(self:getPlayers()) do
            local player = Player(playerId)
            if player then
                player:teleportTo(config.teleportBack)
            end
        end
    end
    return true
end

function ArenaGame:startMatch()
    if not self:teleportPlayers(true) then
        print("[PvP Arena] - Could not teleport all players, something went wrong.")  -- Cancel Match?
    end
    self:resetPlayersHealth()

    self.startTime = os.time()

    local endEventDelay = self.matchDuration * 60 * 1000
    self.endEventId = addEvent(function()
        if not self then
            return
        end

        local winner
        if self.score["teamBlue"] > self.score["teamRed"] then
            winner = "teamBlue"
        elseif self.score["teamRed"] > self.score["teamBlue"] then
            winner = "teamRed"
        else
            winner = "draw"
        end

        self:endMatch(winner)
    end, endEventDelay)
end

function ArenaGame:endMatch(winningTeam)
    if self.endEventId then
        stopEvent(self.endEventId)
        self.endEventId = nil
    end

    self:teleportPlayers(false)
    self:resetPlayersHealth()

    if config.debugMode then
        print("Match #" .. self.id .. " has ended!")
        print("Winner: " .. winningTeam .. ".")
    end

    Arena:endMatch(self.id, self.mode, winningTeam)
end

function ArenaGame:respawn(playerId)
    local randomRespawn = self.settings.respawnPoints[math.random(#self.settings.respawnPoints)]
    local player = Player(playerId)
    if player then
        player:addHealth(player:getMaxHealth())
        player:addMana(player:getMaxMana())
        player:teleportTo(randomRespawn)

        if config.debugMode then
            print(player:getName() .. " has respawned successfully.")
        end
        return true
    end
    return false
end

function ArenaGame:kill(killerId, victimId)
    local team = self:getTeam(killerId)
    self.score[team] = (self.score[team] or 0) + 1

    for _, playerId in pairs(self:getPlayers()) do
        local player = Player(playerId)
        player:sendExtendedOpcode(config.opCode, json.encode({action = "updateScore", data = {blueScore = self.score["teamBlue"], redScore = self.score["teamRed"]}}))
    end

    if config.debugMode then
        print(killerId .. " has killed " .. victimId)
        local oppositeTeam = self:getTeam(victimId)
        print("Score is now: " .. team .. ": ".. self.score[team] .. " " .. oppositeTeam .. ": ".. self.score[oppositeTeam])
        print("Time Left: " .. self:getTimeLeft() .. " seconds.")
    end

    if self.score[team] >= self.maxKills then
        self:endMatch(team)
        return
    end

    self:respawn(victimId)
end

function ArenaGame:getTeam(playerId)
    if table.contains(self.teamRed, playerId) then
        return "teamRed"
    elseif table.contains(self.teamBlue, playerId) then
        return "teamBlue"
    end
end

function ArenaGame:getPlayers()
    local t = {}
    for _, playerId in pairs(self.teamRed) do
        table.insert(t, playerId)
    end
    for _, playerId in pairs(self.teamBlue) do
        table.insert(t, playerId)
    end
    return t
end

---@return integer timeLeft in seconds (>=0)
function ArenaGame:getTimeLeft()
    if not self.startTime then
        error("[PvP Arena] - Could not get time left for arena " .. self.id .. ".")
    end

    local endTime = self.startTime + (self.matchDuration * 60)
    return math.max(endTime - os.time(), 0)
end

-- CreatureScript Event
function onPrepareDeath(creature, killer)
    local creatureMatchId = creature:isInPvpArena()
    local killerMatchId = killer:isInPvpArena()

    if creatureMatchId and killerMatchId and (creatureMatchId == killerMatchId) then
        local match = Arena.matches[creatureMatchId]
        match:kill(killer:getId(), creature:getId())
        return false
    end
    return true
end