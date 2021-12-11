# sauth v1.1
[![Build status](https://github.com/shivajiva101/sauth/workflows/Check%20&%20Release/badge.svg)](https://github.com/shivajiva101/sauth/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

IMPORTANT: USE either 0.4 or 0.5 branch depending on your server version. Existing users need to import sauth/tools/schema_update.sql

An alternative auth handler for minetest using SQLite. Capable of handling a large player database and providing granular control of auth entries cached in memory. Fine tune your servers auth memory load by caching clients who play regularly to reduce load on the server during join events, resulting in a potential increased playability experience all round on servers with a large volume of accounts. 

Requires: 

* lsqlite3 lua library. (http://lua.sqlite.org/)
* SQLite3 (https://www.sqlite.org/) OR your favourite SQL management app (for importing sql files)

I suggest you use luarocks (https://luarocks.org/) to install lsqlite3.

	sudo apt install luarocks
	luarocks install lsqlite3

Your server should run mods in secure mode, you must add sauth to the list of trusted mods in minetest.conf for example:

	secure.trusted_mods = irc,sauth

If you want to import the auth.sqlite data from an existing database you need to use sauth/tools/import_db.sql BEFORE starting the server. Here's the instructions to import import_db.sql with sqlite3, first copy import_db.sql to your world folder then navigate to the world folder in a terminal and use the commands:

    sqlite3 sauth.sqlite
    .read import_db.sql
    .exit

Database schema updates are applied the same way except you use schema_update.sql copied from sauth/tools folder to the world folder instead of import_db.sql file. Note that only sauth databases prior to this version need to import schema_update.sql

    sqlite3 sauth.sqlite
    .read schema_update.sql
    .exit

To enable the mod for singleplayer add:

	sauth.enable_singleplayer = true

to minetest.conf before starting the server. 

Enhanced caching can be turned on at the expense of memory consumption. When enabled, using the defaults, during server startup sauth initialises the cache with up to 500 players who logged in to the server in the last 24 hours before the last player to login prior to shutdown. You can enable enhanced caching with:

	sauth.caching = true -- default is false
	
and manage the cache by adding these settings to minetest.conf and modifying the values

	sauth.cache_max = 500 -- default maximum number of memory cached entries on startup
	sauth.cache_ttl = 86400 -- default seconds deducted from last login

If you use player database you can keep the auth database clean of orphan entries using the shell script posted
here https://forum.minetest.net/viewtopic.php?f=9&t=18604#p297350 by sofar.
