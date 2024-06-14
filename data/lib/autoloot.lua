local defaultSlots = 4

local skinsTable = {
    [1] = {storage = 0, name = "Rat",      lookType = 21}, -- Default skin, always unlocked
    [2] = {storage = 0, name = "Demon",    lookType = 35},
    [3] = {storage = 0, name = "Dragon",   lookType = 34},
}

local function setupTablesStorages(t)
    for k, v in pairs(t) do
        local storageKey = PlayerStorageKeys.autoLoot.skinListBase + k - 1
        v.storage = storageKey
    end
end

setupTablesStorages(skinsTable)

function Player.spawnAutoLooter(self)
    if not self:hasAutoLootSystem() then
        return
    end

    for _, sum in pairs(self:getSummons()) do
        if sum:isAutoLooter() then
            return
        end
    end

    local summon = Game.createMonster("AutoLooter", self:getPosition(), false, true)
    if summon then
        summon:setMaster(self)
        summon:rename(self:getCurrentAutoLootSkin().name)
        summon:setOutfit({lookType = self:getCurrentAutoLootSkin().lookType})
        summon:changeSpeed(self:getBaseSpeed())
    end
end

function Player.despawnAutoLooter(self)
    if #self:getSummons() == 0 then
        return
    end

    for _, summon in ipairs(self:getSummons()) do
        if summon and summon:isAutoLooter() then
            summon:setMaster(nil)
            summon:getPosition():sendMagicEffect(CONST_ME_POFF)
            summon:remove()
        end
    end
end

---@return boolean
function Player.hasAutoLootSystem(self)
    return self:getStorageValue(PlayerStorageKeys.autoLoot.unlockedSystem) == 1
end

function Player.unlockAutoLootSystem(self)
    if self:hasAutoLootSystem() then
        return
    end

    self:setStorageValue(PlayerStorageKeys.autoLoot.unlockedSystem, 1)
	self:addAutoLootSlots(defaultSlots)

    -- Unlock default skin
	if not self:hasAutoLootSkin(1) then
		self:addAutoLootSkin(1)
	end

    -- Set current skin to default skin
    if not self:getCurrentAutoLootSkin().storage then
        self:setCurrentAutoLootSkin(skinsTable[1].storage)
    end

    self:activateAutoLoot(true)
    self:spawnAutoLooter()
end

---@param amount number
function Player.addAutoLootSlots(self, amount)
    local currentSlots = math.max(0, self:getAutoLootSlots())
    self:setStorageValue(PlayerStorageKeys.autoLoot.slotsAmount, currentSlots + amount)
end

---@return number
function Player.getAutoLootSlots(self)
    return self:getStorageValue(PlayerStorageKeys.autoLoot.slotsAmount)
end

---@param skin string|number name|index
---@return boolean
function Player.hasAutoLootSkin(self, skin)
    if type(skin) == "string" then
        for _, v in pairs(skinsTable) do
            if skin == v.name then
                return self:getStorageValue(v.storage) == 1
            end
        end
    elseif type(skin) == "number" then
        return self:getStorageValue(skinsTable[skin].storage) == 1
    end
    return false
end

---@param skin string|number name|index
function Player.addAutoLootSkin(self, skin)
    if self:hasAutoLootSkin(skin) then
        return
    end

    if type(skin) == "string" then
        for _, v in pairs(skinsTable) do
            if skin == v.name then
                self:setStorageValue(v.storage, 1)
                return
            end
        end
    elseif type(skin) == "number" then
        self:setStorageValue(skinsTable[skin].storage, 1)
    end
end

---@return table SelectedSkin 
function Player.getCurrentAutoLootSkin(self)
    for _, v in pairs(skinsTable) do
        if v.storage == self:getStorageValue(PlayerStorageKeys.autoLoot.currentSkin) then
            return v
        end
    end
    return {}
end

---@param storage number
function Player.setCurrentAutoLootSkin(self, storage)
    if storage == self:getCurrentAutoLootSkin().storage then
        return
    end

    self:setStorageValue(PlayerStorageKeys.autoLoot.currentSkin, storage)

    if #self:getSummons() == 0 then
        return
    end

    for _, sum in pairs(self:getSummons()) do
        if sum:isAutoLooter() then
            sum:getPosition():sendMagicEffect(CONST_ME_CRAPS)
            sum:rename(self:getCurrentAutoLootSkin().name)
            sum:setOutfit({lookType = self:getCurrentAutoLootSkin().lookType})
        end
    end
end

---@return table UnlockedSkins
function Player.getUnlockedAutoLootSkins(self)
    local t = {}
    for _, v in ipairs(skinsTable) do
        if self:getStorageValue(v.storage) == 1 then
            table.insert(t, v)
        end
    end
    return t
end

---@return boolean
function Player.isAutoLootActivated(self)
    return self:getStorageValue(PlayerStorageKeys.autoLoot.isActivated) == 1
end

---@param activate boolean
function Player.activateAutoLoot(self, activate)
    if activate then
        self:setStorageValue(PlayerStorageKeys.autoLoot.isActivated, 1)
        self:spawnAutoLooter()
    else
        self:setStorageValue(PlayerStorageKeys.autoLoot.isActivated, 0)
        self:despawnAutoLooter()
    end
end

---@param lootData table
function Player.updateAutoLootList(self, lootData)
    local lootItems = {}
    for _, itemInfo in ipairs(lootData) do
        if itemInfo.activated then
            table.insert(lootItems, itemInfo.itemId)
        end
    end

    local lootIndex = 1
    for i = PlayerStorageKeys.autoLoot.itemListBase, PlayerStorageKeys.autoLoot.itemListBase + self:getAutoLootSlots() - 1 do
        if not lootItems[lootIndex] then
            self:setStorageValue(i, -1)
        end

        self:setStorageValue(i, lootItems[lootIndex])
        lootIndex = lootIndex + 1
    end
end

---@return table ItemIDs
function Player.getAutoLootList(self)
    local t = {}
    for i = PlayerStorageKeys.autoLoot.itemListBase, PlayerStorageKeys.autoLoot.itemListBase + self:getAutoLootSlots() - 1 do
        local itemId = self:getStorageValue(i)
        if itemId > 0 then
            table.insert(t, itemId)
        end
    end
    return t
end