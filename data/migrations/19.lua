function onUpdateDatabase()
    print("> Updating database to version 21 (adding pvprank field to players)")

    db.query("ALTER TABLE `players` ADD `pvprank` TINYINT(1) NOT NULL DEFAULT '0'")
    return true
end