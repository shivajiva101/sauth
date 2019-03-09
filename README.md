# sauth v1.1

IMPORTANT: Existing users need to import sauth/tools/schema_update.sql prior to starting the server!

An alternative auth handler for minetest using SQLite. Capable of handling large player databases whilst reducing the associated lag of having thousands of auth entries sat in memory. Only the players logged in are held in memory to act as cache, resulting in an increased playability experience. 

Requires: 

* lsqlite3 lua library. (http://lua.sqlite.org/)
* SQLite3 (https://www.sqlite.org/) OR your favourite SQL management app (for importing sql files)

I suggest you use luarocks (https://luarocks.org/) to install lsqlite3.

	sudo apt install luarocks
	luarocks install lsqlite3

Your server should run mods in secure mode, you must add sauth to the list of trusted mods in minetest.conf:

	secure.trusted_mods = sauth

If you want to import the auth.sqlite data from an existing database you need to use sauth/tools/import_db.sql BEFORE starting the server. Here's the instructions to import import_db.sql with sqlite3, first copy import_db.sql to your world folder then navigate to the world folder in a terminal and use the commands:

    sqlite3 sauth.sqlite
    .read import_db.sql
    .exit

Database schema updates are applied the same way except you use schema_update.sql copied from sauth/tools folder to the world folder instead of auth.sql file. Note that only existing Db's prior to this version will need to import schema_update.sql

    sqlite3 sauth.sqlite
    .read schema_update.sql
    .exit

To enable the mod for singleplayer add:

	sauth.enable_singleplayer = true

to minetest.conf before starting the server. 

Enhanced caching can be turned on at the expense of memory consumption. When enabled, using the defaults, during server start the mod caches up to 500 players with a login in the past 24 hours prior to the last player to login before the server was stopped. You can enable and manage it by adding these minetest.conf settings:

	sauth.caching = true -- default is false
	sauth.cache_max = 500 -- default maximum number of memory cached entries on startup
	sauth.cache_ttl = 86400 -- default seconds deducted from last login


If you use player database you can easily keep the auth database clean of orphan entries using the shell script posted
here https://forum.minetest.net/viewtopic.php?f=9&t=18604#p297350 by sofar.
