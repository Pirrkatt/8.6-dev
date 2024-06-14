function onUpdateDatabase()
	print("> Updating database to version 20 (adding premium_points to accounts)")

	db.query("ALTER TABLE `accounts` ADD `premium_points` int(11) NOT NULL DEFAULT '0'")
	return true
end