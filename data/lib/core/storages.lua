--[[
Reserved storage ranges:
- 300000 to 301000+ reserved for achievements
- 20000 to 21000+ reserved for achievement progress
- 10000000 to 20000000 reserved for outfits and mounts on source
]]--
PlayerStorageKeys = {
	autoLoot = {
		unlockedSystem = 2000,
		isActivated = 2001,
		slotsAmount = 2002,
		currentSkin = 2003,
		skinListBase = 2100,
		skinListLast = 2199, -- Not used, just for indication
		itemListBase = 2200,
		itemListLast = 2299, -- Not used, just for indication
	},
	pvpArenaLP = 2400,
}

GlobalStorageKeys = {
}