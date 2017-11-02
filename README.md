# sauth

An alternative auth handler for minetest using SQLite. Capable of handling large player databases whilst reducing the associated lag of having thousands of auth entries sat in memory. Only the players logged in are held in memory to act as cache, resulting in an increased playability experience. 

Requires: 

* lsqlite3 lua library. (http://lua.sqlite.org/)
* SQLite3 (only needed for importing large auth.txt files)

I suggest you use luarocks(https://luarocks.org/) to install lsqlite3.

If the target server runs mods in secure mode[recommended], you must add sauth
to the list of trusted mods in minetest.conf:

	secure.trusted_mods = sauth

This mod will import your existing auth.txt on first run if there are less than 3600 records, otherwise it exports SQL block
insert statements to a file called auth.sql in the world folder and shuts the server down. Server owners be aware that it is a requirement that you import the database BEFORE restarting minetest or the server will create another database and duplicate entries for any players logging in before the import. You can shutdown the server and delete sauth.sqlite if you forgot and then do the import steps. I recommend you import auth.sql with sqlite3 (https://www.sqlite.org/), navigate to the world folder in a terminal and use the commands:

    sqlite3
    .open sauth.sqlite
    .read auth.sql
    .exit

Either way it will rename the original auth.txt to auth.txt.bak as it is not required for multiplayer games.

To enable the mod for singleplayer add:

```sauth.enable_singleplayer = true```

to minetest.conf before starting the server.

If you use player database you can easily keep the auth database clean of orphan entries using the shell script posted
here https://forum.minetest.net/viewtopic.php?f=9&t=18604#p297350 by sofar.
