# sauth

An alternative auth handler for minetest using SQLite.

Requires lsqlite3 lua library. (http://lua.sqlite.org/)

I suggest you use luarocks(https://luarocks.org/) to install it.

If you are running mod security(recommended) you will need to add this to the list of trusted mods.
This mod will import your existing auth.txt and rename the file to auth.old. It's not required for multiplayer games.
To enable the mod for singleplayer add:

```sauth.enable_singleplayer = true```

to minetest.conf before starting the server.
