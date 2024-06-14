local skins = {
    -- itemId    skinName or Index
       [2153] = {skin = 1, unlockSystem = true},
       [19524] = {skin = 2, unlockSystem = true},
       [19525] = {skin = 3, unlockSystem = true},
       [19526] = {skin = 4},
       [19527] = {skin = 5},
       [19529] = {skin = 6},
       [19530] = {skin = 7},
       [19531] = {skin = 8},
       [19532] = {skin = 9},
       [19533] = {skin = 10}
   }

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    local skinItem = skins[item:getId()]
    if not skinItem then
        return true
    end

    if player:hasAutoLootSkin(skinItem.skin) then
        player:sendCancelMessage("You have already unlocked this skin!")
        return true
    end

    if not player:hasAutoLootSystem() then
        if skinItem.unlockSystem then
            player:sendTextMessage(MESSAGE_INFO_DESCR, "You have unlocked the AutoLoot system!")
            player:addAutoLootSkin(skinItem.skin)
            player:unlockAutoLootSystem()
        else
            player:sendCancelMessage("Go complete quest and collect stone 19523, 19524 or 19525")
        end
        return true
    end

    player:addAutoLootSkin(skinItem.skin)
    item:remove(1)
    player:getPosition():sendMagicEffect(CONST_ME_FIREWORK_YELLOW)
    player:sendTextMessage(MESSAGE_INFO_DESCR, "You have unlocked a new AutoLoot skin!")
    return true
end