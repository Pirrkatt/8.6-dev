local opCode = 66

function onExtendedOpcode(player, opcode, json_data)
	if opcode == opCode then
		json_data = json.decode(json_data)

		local action = json_data["action"]
		local data = json_data["data"]

		if action == 'result' then
			KIBLAST_DATA[player:getId()] = data
			return
		end
	end
end