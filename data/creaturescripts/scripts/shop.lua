-- BETA VERSION, net tested yet
-- Instruction: 
-- creaturescripts.xml      <event type="extendedopcode" name="Shop" script="shop.lua" />
-- and in login.lua         player:registerEvent("Shop")
-- create sql table shop_history
-- set variables
-- set up function init(), add there items and categories, follow examples
-- set up callbacks at the bottom to add player item/outfit/whatever you want

local SHOP_EXTENDED_OPCODE = 201
local SHOP_OFFERS = {}
local SHOP_CALLBACKS = {}
local SHOP_CATEGORIES = nil
local SHOP_BUY_URL = "https://dbuniverse.net/?subtopic=points&system=paypal" -- can be empty
local SHOP_CHANGE_NAME_COST = 2000 -- can not be empty
local SHOP_AD = nil
local MAX_PACKET_SIZE = 50000

--[[ SQL TABLE

CREATE TABLE `shop_history` (
  `id` int(11) NOT NULL,
  `account` int(11) NOT NULL,
  `player` int(11) NOT NULL,
  `date` datetime NOT NULL,
  `title` varchar(100) NOT NULL,
  `cost` int(11) NOT NULL,
  `details` varchar(500) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `shop_history`
  ADD PRIMARY KEY (`id`);
ALTER TABLE `shop_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

]]--

function init()
  --  print(json.encode(g_game.getLocalPlayer():getOutfit())) -- in console in otclient, will print current outfit and mount

  SHOP_CATEGORIES = {}

  -- Category order matters here, don't change
  local CATEGORY_ITEMS = addCategory({
    name="Items",
    type="item",
  })

  local CATEGORY_OUTFITS = addCategory({
    name="Outfits",
    type="outfit",
  })

  local CATEGORY_SPECIAL = addCategory({
    name="Special",
    type="special",
  })

  local CATEGORY_COSMETICS = addCategory({
    name="Cosmetics",
    type="cosmetics",
  })

  local CATEGORY_LABELS = addCategory({
    name="Labels",
    type="labels",
  })

  local CATEGORY_AURAS = addCategory({
    name="Auras",
    type="auras",
  })

  local CATEGORY_SHADERS = addCategory({
    name="Shaders",
    type="shaders",
  })

  local CATEGORY_FURNITURE = addCategory({
    name="Furniture",
    type="furniture",
  })

  CATEGORY_ITEMS.addItem(1, 2463, 1, "Saiyan Armor Blessed")
  CATEGORY_ITEMS.addItem(2500, 2475, 1, "Mechanoid Helmet", "Desciption text...")
  CATEGORY_ITEMS.addItem(1, 2160, 100, "Crystal Coins")
  CATEGORY_FURNITURE.addFurnitureItem(1, 2160, 2222, 100, "ASd")

  CATEGORY_OUTFITS.addOutfit(500, {
        mount=0,
        feet=114,
        legs=114,
        body=116,
        type=143,
        auxType=0,
        addons=3,
        head=2,
        rotating=true
    }, "Random Outfit")
  CATEGORY_OUTFITS.addOutfit(100, {
      mount=0,
      feet=0,
      legs=0,
      body=0,
      type=35,
      auxType=0,
      addons=0,
      head=0,
      rotating=false
  }, "Demon Outfit", "This one is not rotating")


  local labelNamesSorted = {}
  for i,child in pairs(labelNames) do
  labelNamesSorted[child.id-activeLabelStorage] = i
  end

  for i,child in pairs(labelNamesSorted) do
  if child ~= "-" then
  local getChild = labelNames[child]
  local getId = getChild.itemId or baseLabelId
  local getDesc = getChild.desc or ""
  CATEGORY_LABELS.addItem(getChild.premiumPrice, getId, 1, child, getDesc,2250+(getChild.id -activeLabelStorage), getChild.imageFile) 
  end
  end

  -- local auraNamesSorted = {}
  -- for i,child in pairs(auraNames) do
  -- auraNamesSorted[child.id-activeAuraStorage] = i
  -- end
  -- for i,child in pairs(auraNamesSorted) do
  -- if child ~= "-" then
  -- local getChild = auraNames[child]
  -- local getId = getChild.itemId or baseAuraId
  -- local getDesc = getChild.desc or ""
  -- CATEGORY_AURAS.addItem(getChild.premiumPrice, getId, 1, child, getDesc,2750+(getChild.id - activeAuraStorage), getChild.imageFile) 
  -- end
  -- end

  local shaderNamesSorted = {}
  for i,child in pairs(shaderNames) do
  shaderNamesSorted[child.id-activeShaderStorage] = i
  end
  for i,child in pairs(shaderNamesSorted) do
  if child ~= "-" then
  local getChild = shaderNames[child]
  local getId = getChild.itemId or baseShaderId
  local getDesc = getChild.desc or ""
  CATEGORY_SHADERS.addItem(getChild.premiumPrice, getId, 1, child, getDesc,3250+(getChild.id - activeShaderStorage), getChild.imageFile) 
  end
  end

  -- local effectNamesSorted = {}
  -- for i,child in pairs(effectNames) do
  -- effectNamesSorted[child.id-activeEffectStorage] = i
  -- end
  -- for i,child in pairs(effectNamesSorted) do
  -- if child ~= "-" then
  -- local getChild = effectNames[child]
  -- local getId = getChild.itemId or baseEffectId
  -- local getDesc = getChild.desc or ""
  -- CATEGORY_COSMETICS.addItem(getChild.premiumPrice, getId, 1, child, getDesc,3750+(getChild.id - activeEffectStorage), getChild.imageFile) 
  -- end
  -- end
end

function addCategory(data)
  data['offers'] = {}
  table.insert(SHOP_CATEGORIES, data)
  table.insert(SHOP_CALLBACKS, {})
  local index = #SHOP_CATEGORIES
  return {
    addItem = function(cost, itemId, count, title, description, actionId, imageFile, callback)
      local action = 0
      if actionId then
        action = actionId
      end
      if not callback then
        callback = defaultItemBuyAction
      end
      table.insert(SHOP_CATEGORIES[index]['offers'], {
        cost=cost,
        type="item",
        item=ItemType(itemId):getClientId(), -- displayed
        itemId=itemId,
        imageFile=imageFile,
        count=count,
        title=title,
        actionId=action,
        description=description
      })
      table.insert(SHOP_CALLBACKS[index], callback)
    end,
    addFurnitureItem = function(cost, itemId, ItemlookId,count, title, description, actionId, imageFile, callback)
      local action = 0
      if actionId then
        action = actionId
      end
          if not callback then
            callback = defaultItemBuyAction
          end
          table.insert(SHOP_CATEGORIES[index]['offers'], {
            cost=cost,
            type="item",
            item=ItemType(ItemlookId):getClientId(), -- displayed
            itemId=itemId,
            imageFile=imageFile,
            count=count,
            title=title,
            actionId=action,
            description=description
          })
          table.insert(SHOP_CALLBACKS[index], callback)
        end,
    addOutfit = function(cost, outfit, title, description, callback)
      if not callback then
        callback = defaultOutfitBuyAction
      end
      table.insert(SHOP_CATEGORIES[index]['offers'], {
        cost=cost,
        type="outfit",
        outfit=outfit,
        title=title,
        actionId=action,
        description=description
      })    
      table.insert(SHOP_CALLBACKS[index], callback)
    end,
    addImage = function(cost, image, title, description, callback)
      if not callback then
        callback = defaultImageBuyAction
      end
      table.insert(SHOP_CATEGORIES[index]['offers'], {
        cost=cost,
        type="image",
        image=image,
        title=title,
        actionId=action,
        description=description
      })
      table.insert(SHOP_CALLBACKS[index], callback)
    end
  }
end

function getPoints(player)
  local points = 0
  local resultId = db.storeQuery("SELECT `premium_points` FROM `accounts` WHERE `id` = " .. player:getAccountId())
  if resultId ~= false then
    points = result.getDataInt(resultId, "premium_points")
    result.free(resultId)
  end
  return points
end

function getStatus(player)
  local status = {
    ad = SHOP_AD,
    points = getPoints(player),
    buyUrl = SHOP_BUY_URL,
    nickCost = SHOP_CHANGE_NAME_COST,
  }
  return status
end

function sendJSON(player, action, data, forceStatus)
  if player:isUsingOtClient() then
    local status = nil
    if not player:getStorageValue(1150001) or player:getStorageValue(1150001) + 10 < os.time() or forceStatus then
        status = getStatus(player)
    end
    player:setStorageValue(1150001, os.time())


    local buffer = json.encode({action = action, data = data, status = status})  
    local s = {}
    for i=1, #buffer, MAX_PACKET_SIZE do
      s[#s+1] = buffer:sub(i,i+MAX_PACKET_SIZE - 1)
    end
    local msg = NetworkMessage()
    if #s == 1 then
      msg:addByte(50)
      msg:addByte(SHOP_EXTENDED_OPCODE)
      msg:addString(s[1])
      msg:sendToPlayer(player)
      return  
    end
    -- split message if too big
    msg:addByte(50)
    msg:addByte(SHOP_EXTENDED_OPCODE)
    msg:addString("S" .. s[1])
    msg:sendToPlayer(player)
    for i=2,#s - 1 do
      msg = NetworkMessage()
      msg:addByte(50)
      msg:addByte(SHOP_EXTENDED_OPCODE)
      msg:addString("P" .. s[i])
      msg:sendToPlayer(player)
    end
    msg = NetworkMessage()
    msg:addByte(50)
    msg:addByte(SHOP_EXTENDED_OPCODE)
    msg:addString("E" .. s[#s])
    msg:sendToPlayer(player)
  end
end

function sendMessage(player, title, msg, forceStatus)
  sendJSON(player, "message", {title=title, msg=msg}, forceStatus)
end

function onExtendedOpcode(player, opcode, buffer)
  if opcode ~= SHOP_EXTENDED_OPCODE then
    return false
  end
  local status, json_data = pcall(function() return json.decode(buffer) end)
  if not status then
    return false
  end

  local action = json_data['action']
  local data = json_data['data']
  if not action or not data then
    return false
  end

  if SHOP_CATEGORIES == nil then
    init()    
  end

  if action == 'init' then
    sendJSON(player, "categories", SHOP_CATEGORIES)
  elseif action == 'buy' then
    processBuy(player, data)
  elseif action == 'changeName' then
    processChangeName(player, data)
  elseif action == "history" then
    sendHistory(player)
  end
  return true
end

canChangeToName = function(name)
  local result = {
    ability = false
  }
  
  if name:len() < 3 or name:len() > 14 then
    result.reason = "The length of your new name must be between 3 and 14 characters."
    return result
  end

  local match = name:gmatch("%s+")
  local count = 0
  for v in match do
    count = count + 1
  end

  local matchtwo = name:match("^%s+")
  if (matchtwo) then
    result.reason = "Your new name can't have whitespace at begin."
    return result
  end

  if (count > 1) then
    result.reason = "Your new name have more than 1 whitespace."
    return result
  end

  -- just copied from znote aac.
  local words = { "owner", "gamemaster", "hoster", "admin", "staff", "tibia", "account", "god", "anal", "ass", "fuck", "sex", "hitler", "pussy", "dick", "rape", "adm", "cm", "gm", "tutor", "counsellor" }
  local split = name:split(" ")
  for k, word in ipairs(words) do
    for k, nameWord in ipairs(split) do
      if nameWord:lower() == word then
        result.reason = "You can't use word \"" .. word .. "\" in your new name."
        return result
      end
    end
  end

  local tmpName = name:gsub("%s+", "")
  for i = 1, #words do
    if (tmpName:lower():find(words[i])) then
      result.reason = "You can't use word \"" .. words[i] .. "\" with whitespace in your new name."
      return result
    end
  end

  if MonsterType(name) then
    result.reason = "Your new name \"" .. name .. "\" can't be a monster's name."
    return result
  elseif Npc(name) then
    result.reason = "Your new name \"" .. name .. "\" can't be a npc's name."
    return result
  end

  local letters = "{}|_*+-=<>0123456789@#%^&()/*'\\.,:;~!\"$"
  for i = 1, letters:len() do
    local c = letters:sub(i, i)
    for i = 1, name:len() do
      local m = name:sub(i, i)
      if m == c then
        result.reason = "You can't use this letter \"" .. c .. "\" in your new name."
        return result
      end
    end
  end
  result.ability = true
  return result
end

function processChangeName(player, data)
  local newName = data["newName"]
  if not newName then return end
  local getCost = SHOP_CHANGE_NAME_COST
  local points = getPoints(player)
  if not getCost or getCost > points or points < 1 then
    return sendMessage(player, "Error!", "You don't have enough points to buy Nickname Change!", true)    
  end
  local tile = Tile(player:getPosition())
  local playerId = player:getId()
  
  if (tile) then
    if (not tile:hasFlag(TILESTATE_PROTECTIONZONE)) then
      return sendMessage(player, "Error!", "You can change name only in Protection Zone.", true)
    end
  end
  
  local resultId = db.storeQuery("SELECT * FROM `players` WHERE `name` = " .. db.escapeString(newName) .. "")
  if resultId ~= false then
    return sendMessage(player, "Error!", "This name is already used, please try another!", true)
  end
    
  local result = canChangeToName(newName)
  if not result.ability then
    return sendMessage(player, "Error!", result.reason, true)
  end
  
    db.query("UPDATE `accounts` set `premium_points` = `premium_points` - " .. getCost .. " WHERE `id` = " .. player:getAccountId())
    db.asyncQuery("INSERT INTO `shop_history` (`account`, `player`, `date`, `title`, `cost`, `details`) VALUES ('" .. player:getAccountId() .. "', '" .. player:getGuid() .. "', '2021-11-04 09:38:49', " .. db.escapeString("Nickname Change") .. ", " .. db.escapeString(getCost) .. ", " .. db.escapeString("You changed nickname to "..newName) .. ")")
  newName = newName:lower():gsub("(%l)(%w*)", function(a, b) return string.upper(a) .. b end)
  db.query("UPDATE `players` SET `name` = " .. db.escapeString(newName) .. " WHERE `id` = " .. player:getGuid())
  sendMessage(player, "Success!", "You have successfully changed your name to "..newName.."!", true)
  
  addEvent(function()
    local self = Player(playerId)
    if not self then
      return false
    end

    self:remove()
  end, 1000)
end

function processBuy(player, data)
  local categoryId = tonumber(data["category"])
  local offerId = tonumber(data["offer"])
  local offer = SHOP_CATEGORIES[categoryId]['offers'][offerId]
  local callback = SHOP_CALLBACKS[categoryId][offerId]
  if not offer or not callback or data["title"] ~= offer["title"] or data["cost"] ~= offer["cost"] then
    sendJSON(player, "categories", SHOP_CATEGORIES) -- refresh categories, maybe invalid
    return sendMessage(player, "Error!", "Invalid offer")      
  end
  local getCount = tonumber(data["buyCount"])
  local getCost = offer['cost'] and (tonumber(offer['cost']) * getCount) or 0

  local points = getPoints(player)
  if not getCost or getCost > points or points < 1 then
    return sendMessage(player, "Error!", "You don't have enough points to buy " .. offer['title'] .."!", true)    
  end

  local status = callback(player, offer, getCount)
  if status == true then    
    db.query("UPDATE `accounts` set `premium_points` = `premium_points` - " .. getCost .. " WHERE `id` = " .. player:getAccountId())
    db.asyncQuery("INSERT INTO `shop_history` (`account`, `player`, `date`, `title`, `cost`, `details`) VALUES ('" .. player:getAccountId() .. "', '" .. player:getGuid() .. "', '2021-11-04 09:38:49', " .. db.escapeString(offer['title']) .. ", " .. db.escapeString(getCost) .. ", " .. db.escapeString(offer['description']) .. ")")
    return sendMessage(player, "Success!", "You bought " .. offer['title'] .."!", true)
  end
  if status == nil or status == false then
    status = "Unknown error while buying " .. offer['title']
  end
  sendMessage(player, "Error!", status)
end

function sendHistory(player)
  if player:getStorageValue(1150002) and player:getStorageValue(1150002) + 10 > os.time() then
    return -- min 10s delay
  end
  player:setStorageValue(1150002, os.time())
  
  local history = {}
	local resultId = db.storeQuery("SELECT * FROM `shop_history` WHERE `account` = " .. player:getAccountId() .. " order by `id` DESC")

	if resultId ~= false then
    repeat
      local details = result.getDataString(resultId, "details")
      local status, json_data = pcall(function() return json.decode(details) end)
      if not status then    
        json_data = {
          type = "image",
          title = result.getDataString(resultId, "title"),
          cost = result.getDataInt(resultId, "cost")
        }
      end
      table.insert(history, json_data)
      history[#history]["description"] = "Bought on " .. result.getDataString(resultId, "date") .. " for " .. result.getDataInt(resultId, "cost") .. " points."
    until not result.next(resultId)
    result.free(resultId)
	end
  
  sendJSON(player, "history", history)
end

-- BUY CALLBACKS
-- May be useful: print(json.encode(offer))

function defaultItemBuyAction(player, offer, number)
  local getItemType = ItemType(offer["itemId"])
  if not getItemType then return end

  local getCount = number and number or offer["buyCount"]

  -- Check if the player has enough capacity for the items
  if player:getFreeCapacity() < getItemType:getWeight(getCount) then
    return "Please make sure you have free capacity to hold these items."
  end

  local backpack = player:getSlotItem(CONST_SLOT_BACKPACK)

  -- Check if the player has enough slots in the backpack
  if not backpack or backpack:getEmptySlots(true) < 1 then
    return "Please make sure you have a free slot in your backpack."
  end

  -- Add the items to the player's inventory
  local createdItem = player:addItem(offer["itemId"], getCount, false, getItemType:getCharges() or 1)

  if not createdItem then
    return "Can't add items! Do you have enough space?"
  end

  -- Set the actionId if specified
  if offer["actionId"] and offer["actionId"] > 0 then
    createdItem:setActionId(offer["actionId"])
  end

  return true
end

function defaultOutfitBuyAction(player, offer)
  return "default outfit buy action is not implemented"
end

function defaultImageBuyAction(player, offer)
  return "default image buy action is not implemented"
end

function customImageBuyAction(player, offer)
  return "custom image buy action is not implemented. Offer: " .. offer['title']
end