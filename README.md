# sauth

An alternative auth handler for minetest using SQLite. Capable of handling large player databases whilst reducing the associated lag of having thousands of auth entries sat in memory. Only the players logged in are held in memory to act as cache, resulting in an increased playability experience. 

Requires: 

* lsqlite3 lua library. (http://lua.sqlite.org/)
* SQLite3 (only needed for importing large auth.txt files)

I suggest you use luarocks(https://luarocks.org/) to install lsqlite3.

If the target server runs mods in secure mode[recommended], you must add sauth
to the list of trusted mods in minetest.conf:

	secure.trusted_mods = sauth

This mod will import your existing auth.txt if there are less than 360 records, otherwise it exports SQL block
insert statememnts to auth.sql file in the world folder. I recommend you import auth.sql with sqlite3 (https://www.sqlite.org/),
using the commands:

    .open sauth.sqlite
    .read auth.sql
    .exit

Either way it will rename the original auth.txt to auth.txt.bak as it is not required for multiplayer games.

To enable the mod for singleplayer add:

```sauth.enable_singleplayer = true```

to minetest.conf before starting the server.
