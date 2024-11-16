local opCode = 66

function onExtendedOpcode(player, opcode, result)
	if opcode == opCode then
		if not KIBLAST_DATA[player:getId()] then
			error("KIBLAST_DATA entry for playerId: " .. player:getId() .. " does not exist!")
		end
		KIBLAST_DATA[player:getId()].spellId = tonumber(result)
	end
end