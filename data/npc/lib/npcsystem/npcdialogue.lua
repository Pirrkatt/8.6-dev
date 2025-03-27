
local opCode = 68
local nameColor = "#FF768E"

if NpcDialogue == nil then
	NpcDialogue = {}

	function NpcDialogue.sendStartDialogue(player)
		player:sendExtendedOpcode(opCode, json.encode({action = 'greet'}))
	end

	function NpcDialogue.sendDialogue(player, npcMessage, npcName, npcOutfit)
		if npcOutfit.lookTypeEx ~= 0 then
			local itemType = ItemType(npcOutfit.lookTypeEx)
			local clientId = itemType:getClientId()
			npcOutfit.lookTypeEx = clientId
		end

		local data = {
			name = npcName,
			color = nameColor,
			outfit = npcOutfit,
			message = npcMessage,
		}
		player:sendExtendedOpcode(opCode, json.encode({action = 'talk', data = data}))
	end

	function NpcDialogue.sendCancelDialogue(player)
		player:sendExtendedOpcode(opCode, json.encode({action = 'cancel'}))
	end
end

-- Store original C++ selfSay function
local _selfSay = selfSay

function selfSay(words, target, publicize, replyOptions)
	_selfSay(words, target)

	if not target then
		return
	end

	if type(target) == 'number' then
		target = Player(target)

		if not target then
			return
		end
	end

	local npc = Npc()
	if npc == nil then
		return
	end

	if replyOptions then
		words = words .. "\n{Yes}\n{No}"
	end

	NpcDialogue.sendDialogue(target, words, npc:getName(), npc:getOutfit())
end