# sauth v2.0
[![Build status](https://github.com/shivajiva101/sauth/workflows/Check%20&%20Release/badge.svg)](https://github.com/shivajiva101/sauth/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<b>IMPORTANT: Version 2 changes the DB schema inline with the core auth schema. Existing users need to convert sauth.sqlite using the python script in sauth/tools(see instructions.txt). ONLY USE with minetest version 0.5 or greater.</b>

Sauth is an alternative sqlite3 auth handler for minetest. Capable of handling large player databases and provides mitigation of auth entry request load by use of memory caching. Fine tune your servers auth memory load by caching clients who play regularly to reduce join event load on the server, resulting in a better playability experience on servers with many player accounts.

Requires:

* lsqlite3 lua library. (http://lua.sqlite.org/)
* SQLite3 (https://www.sqlite.org/) <b>OR</b> your favourite SQL management app (for importing sql files)

I suggest you use luarocks (https://luarocks.org/) to install lsqlite3.

	sudo apt install luarocks
	luarocks install lsqlite3

Your server should always run mods in secure mode, you must add sauth to the list of trusted mods in minetest.conf for example:

	secure.trusted_mods = irc,sauth

You can and should use your existing auth db, make a copy of auth.sqlite renaming it to sauth.sqlite <b>BEFORE</b> starting the server.

To enable the mod for singleplayer add:

	sauth.enable_singleplayer = true

to minetest.conf before starting the server.

Caching comes at the expense of memory consumption. During server startup sauth initialises the cache with up to 500 players who logged in to the server in the last 24 hours before the last player to login prior to shutdown. You can manage the cache by adding these settings to minetest.conf and modifying the values otherwise the mod will use the hard coded defaults.

	sauth.cache_max = 500 -- default maximum number of memory cached entries on startup
	sauth.cache_ttl = 86400 -- default seconds deducted from last login

If you use player database you can keep the auth database clean of orphan entries using the shell script posted
here https://forum.minetest.net/viewtopic.php?f=9&t=18604#p297350 by sofar.

<b>Uninstalling</b>

If/when you want to remove sauth and retain its auth data, simply rename your existing auth.sqlite, which becomes a stale backup from the moment a new record is created by sauth, then rename sauth.sqlite to auth.sqlite, it's as simple as that!
