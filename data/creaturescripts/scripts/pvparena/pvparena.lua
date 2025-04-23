dofile("data/creaturescripts/scripts/pvparena/arena_game.lua")

Arena = {
    queues = {
        ["2x2"] = {},
        ["3x3"] = {},
        ["4x4"] = {},
        ["5x5"] = {}
    },
    queuedPlayers = {}, -- [playerId] = {mode = x, queueId = y}
    matches = {}, -- [matchId] = Match Instance
    matchIdCounter = 0,
    queueIdCounter = 0,
    playersInGame = {},
    hasWindowOpen = {},
}

local config = {
    opCode = 69,
    lpStorageKey = PlayerStorageKeys.pvpArenaLP,
    lpWin = 25, -- How many points to receive for a win
    lpLoss = 25, -- How many points to lose for a loss
    debugMode = false,
}

local rankThresholds = {
    [PVPRANK_Z] =    500,
    [PVPRANK_S] =    400,
    [PVPRANK_A] =    300,
    [PVPRANK_C] =    200,
    [PVPRANK_B] =    100,
    [PVPRANK_NONE] = 0,
}

local reasonMessages = {
    ["party"]               = "Party size changed, you have been removed from all PvP Arena queues.",
    ["logout"]              = "%s has logged out, you have been removed from all PvP Arena queues.",
    ["buttonJoin"]          = "You have joined the PvP Arena queue for %s.",
    ["buttonLeaveLeader"]   = "You have left the PvP Arena queue for %s.",
    ["buttonLeaveMember"]   = "Your party leader has left the PvP Arena queue for %s, you are no longer queued.",
}

function onExtendedOpcode(player, opcode, buffer)
    if opcode == config.opCode then
        local status, json_data = pcall(function()
            return json.decode(buffer)
        end)

        if not status then
            return false
        end

        local action = json_data.action
        local data = json_data.data

        if action == "showWindow" then
            table.insert(Arena.hasWindowOpen, player:getId())
            player:sendShowPvpWindow()
        elseif action == "closeWindow" then
            table.removeValue(Arena.hasWindowOpen, player:getId())
        elseif action == "joinQueue" then
            Arena:joinQueue(player, data.mode)
        elseif action == "leaveQueue" then
            Arena:leaveQueue(player)
        elseif action == "arenaStatus" then
            player:sendArenaStatus(data.mode)
        end
    end
    return true
end

function Arena:onPartySizeChange(party)
    self:leaveQueue(party:getLeader())
    for _, playerId in pairs(party:getMembers()) do
        self:leaveQueue(playerId)
    end
end

function Arena:onLogout(playerId)
    self:leaveQueue(playerId)
end

local function isInPz(player)
    local tile = Tile(player:getPosition())
    return tile:hasFlag(TILESTATE_PROTECTIONZONE)
end

function Arena:joinQueue(player, mode)
    if not mode then
        return false
    end

    if self.playersInGame[player:getId()] then
        player:sendCancelMessage("You can not join a queue while inside the arena.")
        return false
    end

    if self.queuedPlayers[player:getId()] then
        player:sendCancelMessage("You are already queued for a game.")
        return false
    end

    if not isInPz(player) then
        player:sendCancelMessage("You need to be in a protection zone to queue up for a game.")
        return false
    end

    local queue = self.queues[mode]
    local modeNum = tonumber(mode:sub(1, 1))

    local players = {}

    local party = player:getParty()
    if party then
        if party:getLeader() ~= player then
            player:sendCancelMessage("Only the party leader can join PvP Arena.")
            return false
        end

        if party:getMemberCount() + 1 > modeNum then -- Add 1 because leader is not counted in getMemberCount
            player:sendCancelMessage("There is too many players in your party to queue for this mode.")
            return false
        end

        for _, p in pairs(party:getMembers()) do
            if not isInPz(p) then
                player:sendCancelMessage(p:getName() .. " needs to move to a protection zone to queue up for a game.")
                return false
            end

            if self.queuedPlayers[p:getId()] then
                error("[PvP Arena] - Something went wrong.")
            end

            table.insert(players, p:getId())
        end
    end

    table.insert(players, player:getId())

    self.queueIdCounter = self.queueIdCounter + 1
    local queueId = self.queueIdCounter

    queue[queueId] = {
        players = players,
        isParty = #players > 1
    }

    local queuedAmount = self:getQueuedPlayersAmount(mode)

    for _, playerId in pairs(players) do
        local p = Player(playerId)
        if not p then
            error(string.format("[PvP Arena] - Can't find Player with ID %s, something went wrong.", playerId))
        end

        self.queuedPlayers[playerId] = {mode = mode, queueId = queueId}
        p:sendTextMessage(MESSAGE_STATUS_SMALL, string.format(reasonMessages["buttonJoin"], mode))
        -- p:setMovementBlocked(true)

        local data = {
            mode = mode,
            queuedAmount = queuedAmount,
        }
        p:sendExtendedOpcode(config.opCode, json.encode({action = "joinQueue", data = data}))
    end

    self:sendUpdateLFM(mode, queuedAmount) -- Update queue amount in "Looking for Match" window
    self:sendUpdateQueues() -- Update queue amounts in main window

    if queuedAmount >= modeNum * 2 then
        self:tryStartMatch(mode)
    end
    return true
end

---@description Leaves the queue for the Player and all players in their party
function Arena:leaveQueue(player)
    local queueData = self.queuedPlayers[type(player) == "number" and player or player:getId()]
    if not queueData then
        return false
    end

    local queue = self.queues[queueData.mode]
    local queueEntry = queue[queueData.queueId]

    if not queueEntry then
        return false
    end

    for _, playerId in ipairs(queueEntry.players) do
        self.queuedPlayers[playerId] = nil

        local player = Player(playerId)
        if player then
            player:sendExtendedOpcode(config.opCode, json.encode({action = "leaveQueue"}))
            -- p:setMovementBlocked(false)
        end
    end

    queue[queueData.queueId] = nil

    local queuedAmount = self:getQueuedPlayersAmount(queueData.mode)
    self:sendUpdateLFM(queueData.mode, queuedAmount) -- Update queue amount in "Looking for Match" window
    self:sendUpdateQueues()
    return true
end

function Arena:validateEntry(entry)
    local group = {}

    for _, playerId in ipairs(entry.players) do
        local player = Player(playerId)
        if not player then
            return false
        end
        table.insert(group, playerId)
    end

    return group
end

local function findBalancedTeams(queue, maxTeamSize)
    local results = {}

    local function clone(tbl)
        local copy = {}
        for i = 1, #tbl do
            copy[i] = tbl[i]
        end
        return copy
    end

    local function backtrack(index, team1, team2, used)
        if #team1 == maxTeamSize and #team2 == maxTeamSize then
            results.team1 = team1
            results.team2 = team2
            results.usedIndexes = clone(used)
            return true
        end

        if index > #queue then
            return false
        end

        local group = queue[index]
        local groupSize = #group

        -- Randomize order of team assignment
        local tryTeam1First = math.random() < 0.5

        local firstTryTeam = tryTeam1First and team1 or team2
        local secondTryTeam = tryTeam1First and team2 or team1

        -- Try placing group in first random team
        if #firstTryTeam + groupSize <= maxTeamSize then
            local newTeam = clone(firstTryTeam)
            for _, p in ipairs(group) do table.insert(newTeam, p) end
            local newUsed = clone(used)
            table.insert(newUsed, index)
            if tryTeam1First then
                if backtrack(index + 1, newTeam, team2, newUsed) then return true end
            else
                if backtrack(index + 1, team1, newTeam, newUsed) then return true end
            end
        end

        -- Try placing group in second random team
        if #secondTryTeam + groupSize <= maxTeamSize then
            local newTeam = clone(secondTryTeam)
            for _, p in ipairs(group) do table.insert(newTeam, p) end
            local newUsed = clone(used)
            table.insert(newUsed, index)
            if not tryTeam1First then
                if backtrack(index + 1, newTeam, team2, newUsed) then return true end
            else
                if backtrack(index + 1, team1, newTeam, newUsed) then return true end
            end
        end

        -- Try skipping this group
        if backtrack(index + 1, team1, team2, used) then return true end

        return false
    end

    backtrack(1, {}, {}, {})

    return results
end

function Arena:makeTeams(mode)
    local queue = self.queues[mode]
    local modeNum = tonumber(mode:sub(1, 1))

    local validEntries = {}
    local invalidEntries = {}

    for queueId, entry in pairs(queue) do
        local group = self:validateEntry(entry)
        if group then
            table.insert(validEntries, { group = group, originalIndex = queueId })
        else
            table.insert(invalidEntries, queueId) -- If the entry is invalid, mark it for removal
        end
    end

    -- Remove invalid entries after the loop
    for _, invalidIndex in ipairs(invalidEntries) do
        queue[invalidIndex] = nil
    end

    local groupedOnly = {}
    for _, v in ipairs(validEntries) do
        table.insert(groupedOnly, v.group)
    end

    local results = findBalancedTeams(groupedOnly, modeNum)
    if results.team1 and results.team2 then
        return results
    end

    return false
end

function Arena:tryStartMatch(mode)
    -- Check if arena is busy
    for _, game in pairs(self.matches) do
        if game.mode == mode then
            if config.debugMode then
                print("Can not start match, " .. mode .. " arena is busy.")
            end
            return false
        end
    end

    local teams = self:makeTeams(mode)
    if not teams then
        return false
    end

    self:startMatch(mode, teams)
    return true
end

function Arena:startMatch(mode, teams)
    self.matchIdCounter = self.matchIdCounter + 1
    local matchId = self.matchIdCounter

    local match = ArenaGame:new(matchId, teams.team1, teams.team2, mode)
    self.matches[matchId] = match

    for _, playerId in pairs(match:getPlayers()) do
        self.playersInGame[playerId] = matchId

        local player = Player(playerId)
        self:leaveQueue(player)

        local data = {
            matchDuration = match.matchDuration,
            teamBlue = match.teamBlue,
            teamRed = match.teamRed,
            mode = mode,
        }
        player:sendExtendedOpcode(config.opCode, json.encode({action = "joinMatch", data = data}))
    end

    match:startMatch()

    if config.debugMode then
        print("[PvP Arena] Started match #" .. matchId .. " (" .. mode .. ")")
        print("-- TEAM 1 -- ")
        pdump(teams.team1)
        print("-- TEAM 2 -- ")
        pdump(teams.team2)
        print("----------------------------------")
    end
end

function Arena:endMatch(matchId, mode, winner)
    local match = self.matches[matchId]
    if not match then
        error("[PvP Arena] - Could not find match with ID " .. matchId .. ".")
    end

    for _, playerId in pairs(match:getPlayers()) do
        self.playersInGame[playerId] = nil

        local player = Player(playerId)
        if player then
            local endData = {
                result = "draw",
                lpDiff = 0,
            }
            if winner == "draw" then
                player:sendTextMessage(MESSAGE_STATUS_SMALL, "The match ended in a draw. Your LP and Rank remains the same.")
                endData.result = "draw"
                endData.lpDiff = 0
            else
                local team = match:getTeam(playerId)
                if team then
                    if winner == team then
                        self:addLP(player, config.lpWin)
                        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Your team has won. You gained " .. config.lpWin .. " LP.")
                        endData.result = "win"
                        endData.lpDiff = config.lpWin
                    else
                        local oldLp = self:getLP(player)
                        self:removeLP(player, config.lpLoss)
                        local newLp = self:getLP(player)

                        local lostLp = oldLp - newLp
                        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Your team has lost. You lost " .. lostLp .. " LP.")
                        endData.result = "loss"
                        endData.lpDiff = lostLp
                    end
                end
            end
            player:updatePvpRank()
            player:sendExtendedOpcode(config.opCode, json.encode({action = "endMatch", data = endData}))
        end
    end

    self.matches[matchId] = nil

    addEvent(function() self:tryStartMatch(mode) end, 5 * 1000) -- Try to start a new match after 5 seconds
end

function Arena:getLP(player)
    local lp = player:getStorageValue(config.lpStorageKey)
    return lp >= 0 and lp or 0
end

function Arena:addLP(player, amount)
    local currentLp = self:getLP(player)
    local newLp = math.max(0, currentLp + amount)
    player:setStorageValue(config.lpStorageKey, newLp)

    if config.debugMode then
        print("- ADDED LP FOR PLAYER: " .. player:getName() .. " -")
        print("OLD LP: " .. currentLp)
        print("NEW LP: " .. newLp)
        print("-----------------------------------")
    end
end

function Arena:removeLP(player, amount)
    local currentLp = self:getLP(player)
    local newLp = math.max(0, currentLp - amount)
    player:setStorageValue(config.lpStorageKey, newLp)

    if config.debugMode then
        print("- REMOVED LP FOR PLAYER: " .. player:getName() .. " -")
        print("OLD LP: " .. currentLp)
        print("NEW LP: " .. newLp)
        print("-----------------------------------")
    end
end

---@param mode string mode to check queue for
---@return boolean
function Arena:isInQueue(player, mode)
    if not mode then
        return false
    end

    for _, entry in ipairs(self.queues[mode]) do
        for _, playerId in ipairs(entry.players) do
            if playerId == player:getId() then
                return true
            end
        end
    end
    return false
end

---@param mode? string If mode is not defined, we return a table with all modes
---@return table number Amount of players who are queued in the mode(s)
function Arena:getQueuedPlayersAmount(mode)
    local t = {}

    if mode then
        t[mode] = 0
        local queue = self.queues[mode]
        for _, entry in pairs(queue) do
            t[mode] = t[mode] + #entry.players
        end
        return t[mode]
    end

    for k, queue in pairs(self.queues) do
        t[k] = 0
        for _, entry in pairs(queue) do
            t[k] = t[k] + #entry.players
        end
    end
    return t
end

function Player:sendShowPvpWindow()
    local data = {
        lp = Arena:getLP(self),
        rank = self:getPvpRank(),
        nextRankLp = rankThresholds[self:getPvpRank() + 1],
        playersQueued = Arena:getQueuedPlayersAmount(),
    }

    self:sendExtendedOpcode(config.opCode, json.encode({action = "showWindow", data = data}))
end

---@return integer|nil matchId Returns the matchId if the player is in a PvP Arena, or nil otherwise.
function Player:isInPvpArena()
    local playerId = self:getId()
    return Arena.playersInGame[playerId]
end

---@description Updates queued players amount for all players with the window opened
function Arena:sendUpdateQueues()
    if config.debugMode then
        print("-- UPDATED QUEUES -- ")
        pdump(self.queues)
        print("--------------------------------------------")
    end

    for k, playerId in pairs(self.hasWindowOpen) do
        local player = Player(playerId)
        if player then
            player:sendExtendedOpcode(config.opCode, json.encode({action = "updateQueues", data = self:getQueuedPlayersAmount()}))
        else
            self.hasWindowOpen[k] = nil
        end
    end
end

function Arena:sendUpdateLFM(mode, queuedAmount)
    for playerId, data in pairs(self.queuedPlayers) do
        if data.mode == mode then
            local player = Player(playerId)
            player:sendExtendedOpcode(config.opCode, json.encode({action = "updateLFM", data = {mode = mode, queuedAmount = queuedAmount}}))
        end
    end
end

function Player:sendArenaStatus(mode)
    local data = {
        mode = mode,
        timeLeft = 0,
    }

    for _, game in pairs(Arena.matches) do
        if game.mode == mode then
            data.timeLeft = game:getTimeLeft()
            break
        end
    end

    self:sendExtendedOpcode(config.opCode, json.encode({action = "arenaStatus", data = data}))
end

function Player:updatePvpRank()
    local playerLp = Arena:getLP(self)

    local newRank = PVPRANK_NONE
    for rank, threshold in pairs(rankThresholds) do
        if playerLp >= threshold and rank > newRank then
            newRank = rank
        end
    end

    if self:getPvpRank() ~= newRank then
        self:setPvpRank(newRank)
    end
end