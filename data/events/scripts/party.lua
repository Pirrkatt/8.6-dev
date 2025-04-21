function Party:onJoin(player)
	addEvent(function() Arena:onPartySizeChange(self) end, 1) -- Fix since we want to know what the new party looks like (after joining)
	return true
end

function Party:onLeave(player)
	Arena:onPartySizeChange(self)
	return true
end

function Party:onDisband()
	return true
end
