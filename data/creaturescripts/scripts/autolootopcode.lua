local config = {
	opCode = 65,
	maxSlots = 99,
	pricePerSlot = 100,
}

local function sendExtendedJson(player, action, data)
	if data == nil then
		data = {}
	end
	player:sendExtendedOpcode(config.opCode, json.encode({action = action, data = data}))
end

local function getPlayerData(player)
	local serverData = {}
	serverData.slots = player:getAutoLootSlots()
	serverData.skins = player:getUnlockedAutoLootSkins()
	serverData.currentSkin = player:getCurrentAutoLootSkin()
	serverData.activated = player:isAutoLootActivated()
	serverData.lootData = player:getAutoLootList()
	return serverData
end

function onExtendedOpcode(player, opcode, json_data)
	if opcode == config.opCode then
		json_data = json.decode(json_data)

		local action = json_data["action"]
		local data = json_data["data"]

		local serverData = {}

		if action == 'init' then
			if not player:hasAutoLootSystem() then
				player:sendCancelMessage("You have not unlocked the AutoLoot system!")
				sendExtendedJson(player, 'cancel')
				return
			end

			serverData = getPlayerData(player)
			serverData.maxSlots = config.maxSlots
			serverData.pricePerSlot = config.pricePerSlot

			sendExtendedJson(player, action, serverData)
		elseif action == 'addItem' then
			if not player:hasAutoLootSystem() then
				player:sendCancelMessage("You have not unlocked the AutoLoot system!")
				sendExtendedJson(player, 'cancel')
				return
			end

			local itemType = ItemType(data)
			if itemType:getId() == 0 then
				local id = tonumber(data)
				if not id then
					player:sendCancelMessage("There is no item with that Name or ID.")
					return
				end

				itemType = Game.getItemTypeByClientId(tonumber(data))
				if not itemType or itemType:getId() == 0 then
					player:sendCancelMessage("There is no item with that Name or ID.")
					return
				end
			end

			if table.contains(player:getAutoLootList(), itemType:getId()) then
				player:sendCancelMessage("This item is already added to your list.")
				return
			end

			serverData.clientId = itemType:getClientId()
			serverData.itemName = itemType:getName()
			serverData.itemWeight = itemType:getWeight()
			serverData.itemId = itemType:getId()
			serverData.activated = false

			sendExtendedJson(player, action, serverData)
		elseif action == 'save' then
			player:updateAutoLootList(data.lootData)
			player:activateAutoLoot(data.activated)
			player:setCurrentAutoLootSkin(data.currentSkin.storage)
		elseif action == 'buySlots' then
			local slots = data.slotsAmount
			local cost = slots * config.pricePerSlot

			if player:getAutoLootSlots() + slots > config.maxSlots then
				-- This should not happen because it's handled first hand on client-side, so most likely something bugged out if we get here
				player:sendCancelMessage("Error occured when trying to buy slots, please try again.")
				return
			end

			local points = getPoints(player)
			if cost > points or points < 1 then
				player:sendCancelMessage("You don't have enough points to buy this amount of slots.")
			  	return
			end

			db.query("UPDATE `accounts` set `premium_points` = `premium_points` - " .. cost .. " WHERE `id` = " .. player:getAccountId())
			-- db.asyncQuery("INSERT INTO `shop_history` (`account`, `player`, `date`, `title`, `cost`, `details`) VALUES ('" .. player:getAccountId() .. "', '" .. player:getGuid() .. "', '2021-11-04 09:38:49', " .. db.escapeString(offer['title']) .. ", " .. db.escapeString(getCost) .. ", " .. db.escapeString(offer['description']) .. ")")
			player:addAutoLootSlots(slots)

			serverData = getPlayerData(player)
			serverData.maxSlots = config.maxSlots
			serverData.pricePerSlot = config.pricePerSlot
			sendExtendedJson(player, action, serverData)
			return
		elseif action == 'listFull' then
			player:sendCancelMessage("You have used all your available slots, please purchase more!")
			return
		elseif action == 'alreadyExists' then
			player:sendCancelMessage("This item already exists in the list.")
			return
		elseif action == 'maxSlots' then
			player:sendCancelMessage("You can't purchase more slots, you already have the maximum amount.")
			return
		end
	end
end