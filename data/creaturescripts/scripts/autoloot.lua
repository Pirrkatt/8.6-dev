local config = {
    sendEffect = true,
    sendMessage = true,
    distEffect = CONST_ANI_ENERGY,
}

local function sendNotifications(player, lootPos, items)
    if config.sendEffect then
        local summon = player:getSummons()
        if summon then
            local distance = getDistanceBetween(summon[1]:getPosition(), lootPos)
            if distance >= 1 then
                summon[1]:getPosition():sendDistanceEffect(lootPos, config.distEffect)
                addEvent(function(s)
                    local sum = Creature(s)
                    if sum then
                        lootPos:sendDistanceEffect(sum:getPosition(), config.distEffect)
                    end
                end, (distance-1) * 150, summon[1]:getId())
            end
        end
    end

    if config.sendMessage then
        local message = player:getCurrentAutoLootSkin().name .. " has automatically looted: "

        for i, item in ipairs(items) do
            message = message .. item
            if i < #items - 1 then
                message = message .. ", "
            end 
            if i == #items - 1 then
                message = message .. " and "
            end
        end
        message = message .. " for you."
        player:sendTextMessage(MESSAGE_INFO_DESCR, message)
    end
end

local function scanContainer(cid, position)
    local player = Player(cid)
    if not player then
        return
    end

    local corpse = Tile(position):getTopDownItem()
    if not corpse or not corpse:isContainer() then
        return
    end

    local itemsLooted = {}
    if corpse:getType():isCorpse() and corpse:getAttribute(ITEM_ATTRIBUTE_CORPSEOWNER) == cid then
        for a = corpse:getSize() - 1, 0, -1 do
            local containerItem = corpse:getItem(a)
            if containerItem then
                if table.contains(player:getAutoLootList(), containerItem:getId()) then
                    if not containerItem:moveTo(player) then
                        player:sendTextMessage(MESSAGE_INFO_DESCR,"You did not have enough space to pick up the AutoLooted items!")
                        return
                    end
                    table.insert(itemsLooted, containerItem:getCount() .. "x " .. containerItem:getName())
                end
            end
        end
    end

    if #itemsLooted > 0 then
        sendNotifications(player, position, itemsLooted)
    end
end

function onKill(player, target)
    if not target:isMonster() then
        return true
    end

    if not player:isAutoLootActivated() then
        return true
    end

    addEvent(scanContainer, 100, player:getId(), target:getPosition())
    return true
end