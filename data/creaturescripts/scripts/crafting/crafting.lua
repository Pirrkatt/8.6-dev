Crafting = {}

dofile("data/creaturescripts/scripts/crafting/weapons.lua")
dofile("data/creaturescripts/scripts/crafting/equipment.lua")
dofile("data/creaturescripts/scripts/crafting/potions.lua")
dofile("data/creaturescripts/scripts/crafting/legs.lua")
dofile("data/creaturescripts/scripts/crafting/upgradeables.lua")
dofile("data/creaturescripts/scripts/crafting/others.lua")


local fetchLimit = 10

function onExtendedOpcode(player, opcode, buffer)
  if opcode == ExtendedOPCodes.CODE_CRAFTING then
    local status, json_data =
      pcall(
      function()
        return json.decode(buffer)
      end
    )

    if not status then
      return false
    end

    local action = json_data.action
    local data = json_data.data

    if action == "fetch" then
      Crafting:sendCrafts(player, "weapons")
      Crafting:sendCrafts(player, "equipment")
      Crafting:sendCrafts(player, "potions")
      Crafting:sendCrafts(player, "legs")
      Crafting:sendCrafts(player, "upgradeables")
      Crafting:sendCrafts(player, "others")
    elseif action == "craft" then
      Crafting:craft(player, data.category, data.craftId)
    end
  end
  return true
end

function Crafting:sendCrafts(player, category)
  local data = {}

  for i = 1, #Crafting[category] do
    local craft = {}
    craft.materials = {}
    for key, value in pairs(Crafting[category][i]) do
      if key == "materials" then
        for x = 1, #value do
          local material = value[x]
          local itemType = ItemType(material.id)
          craft.materials[x] = {
            id = material.id,
            count = material.count,
            player = player:getItemCount(material.id)
          }
        end
      else
        craft[key] = value
      end
    end

    local itemType = ItemType(craft.id)
    craft.item = {
      id = itemType:getClientId(),
      count = craft.count
    }

    for x = 1, #craft.materials do
      craft.materials[x].id = ItemType(craft.materials[x].id):getClientId()
    end
    table.insert(data, craft)
  end

  if #data >= fetchLimit then
    local x = 1
    for i = 1, math.floor(#data / fetchLimit) do
      player:sendExtendedOpcode(
        ExtendedOPCodes.CODE_CRAFTING,
        json.encode({action = "fetch", data = {category = category, crafts = {unpack(data, x, math.min(x + fetchLimit - 1, #data))}}})
      )
      x = x + fetchLimit
    end

    if x < #data then
      player:sendExtendedOpcode(ExtendedOPCodes.CODE_CRAFTING, json.encode({action = "fetch", data = {category = category, crafts = {unpack(data, x, #data)}}}))
    end
  else
    player:sendExtendedOpcode(ExtendedOPCodes.CODE_CRAFTING, json.encode({action = "fetch", data = {category = category, crafts = data}}))
  end
end

function Crafting:craft(player, category, craftId)
  local craft = Crafting[category][craftId]

  local money = player:getMoney()

  if money < craft.cost then
    player:sendCancelMessage("You don't have required money.")
    return
  end

  for i = 1, #craft.materials do
    local material = craft.materials[i]
    if player:getItemCount(material.id) < material.count then
      player:sendCancelMessage("You don't have all the required materials.")
      return
    end
  end

  local item = Game.createItem(craft.id, craft.count)
  if item then
    local retValue = player:addItemEx(item)
    if retValue == RETURNVALUE_NOERROR then
      player:removeMoneyNpc(craft.cost)

      for i = 1, #craft.materials do
        local material = craft.materials[i]
        player:removeItem(material.id, material.count)
      end

      Crafting:sendMaterials(player, category)
      player:addAchievement("crafter")
      player:sendExtendedOpcode(ExtendedOPCodes.CODE_CRAFTING, json.encode({action = "crafted"}))
    end
  end
end

function Crafting:sendMaterials(player, category)
  local data = {}

  for i = 1, #Crafting[category] do
    local materials = {}
    local catMaterials = Crafting[category][i].materials
    for x = 1, #catMaterials do
      materials[x] = player:getItemCount(catMaterials[x].id)
    end
    table.insert(data, materials)
  end

  if #data >= fetchLimit then
    local x = 1
    for i = 1, math.floor(#data / fetchLimit) do
      player:sendExtendedOpcode(
        ExtendedOPCodes.CODE_CRAFTING,
        json.encode({action = "materials", data = {category = category, from = x, materials = {unpack(data, x, math.min(x + fetchLimit - 1, #data))}}})
      )
      x = x + fetchLimit
    end

    if x < #data then
      player:sendExtendedOpcode(
        ExtendedOPCodes.CODE_CRAFTING,
        json.encode({action = "materials", data = {category = category, from = x, materials = {unpack(data, x, #data)}}})
      )
    end
  else
    player:sendExtendedOpcode(ExtendedOPCodes.CODE_CRAFTING, json.encode({action = "materials", data = {category = category, from = 1, materials = data}}))
  end
end

function Player:showCrafting()
  Crafting:sendMaterials(self, "weapons")
  Crafting:sendMaterials(self, "equipment")
  Crafting:sendMaterials(self, "potions")
  Crafting:sendMaterials(self, "legs")
  Crafting:sendMaterials(self, "upgradeables")
  Crafting:sendMaterials(self, "others")
  self:sendExtendedOpcode(ExtendedOPCodes.CODE_CRAFTING, json.encode({action = "show"}))
end
