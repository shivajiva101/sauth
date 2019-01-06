# sauth v1.1

IMPORTANT: Existing users need to import sauth/tools/schema_update.sql

An alternative auth handler for minetest using SQLite. Capable of handling large player databases whilst reducing the associated lag of having thousands of auth entries sat in memory. Only the players logged in are held in memory to act as cache, resulting in an increased playability experience. 

Requires: 

* lsqlite3 lua library. (http://lua.sqlite.org/)
* SQLite3 (https://www.sqlite.org/) OR your favourite SQL management app (for importing sql files)

I suggest you use luarocks (https://luarocks.org/) to install lsqlite3.

	sudo apt install luarocks
	luarocks install lsqlite3

Your server should run mods in secure mode, you must add sauth to the list of trusted mods in minetest.conf:

	secure.trusted_mods = sauth

The first time you start the server after adding this mod it will process your existing auth.txt and import the records if there are less than 3600, otherwise it creates a file called auth.sql in the world folder for you to manually import, then shuts the server down so you can proceed to import the file. Here's the instructions to import auth.sql with sqlite3, navigate to the world folder in a terminal and use the commands:

    sqlite3 sauth.sqlite
    .read auth.sql
    .exit

Be aware that it is a requirement that you import the database BEFORE restarting minetest or the server will create another database and duplicate entries for any players logging in before the import. If this happens you can shutdown the server and delete sauth.sqlite and then perform the import steps. Either way the original auth.txt is renamed to auth.txt.bak as it's not required for multiplayer games.

Database schema updates are applied the same way except you use schema_update.sql copied from sauth/tools folder to the world folder instead of auth.sql file. Note that only existing Db's prior to this version will need to import schema_update.sql

    sqlite3 sauth.sqlite
    .read schema_update.sql
    .exit

To enable the mod for singleplayer add:

	sauth.enable_singleplayer = true

to minetest.conf before starting the server. 

Enhanced caching can be turned on at the expense of memory consumption. When enabled, during server start the mod loads up to 500 players with a login in the past 24 hours prior to the last player to login before the server was stopped. You can enable and manage it by adding these minetest.conf settings:

	sauth.caching = true -- default is false
	sauth.cache_max = 500 -- maximum number of memory cached entries on startup
	sauth.cache_ttl = 86400 -- seconds deducted from last login

If you use player database you can easily keep the auth database clean of orphan entries using the shell script posted
here https://forum.minetest.net/viewtopic.php?f=9&t=18604#p297350 by sofar.
