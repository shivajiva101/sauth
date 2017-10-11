-- sauth mod for minetest voxel game
-- by shivajiva101@hotmail.com

-- expose handler functions
sauth = {}
local auth_table = {}
local MN = minetest.get_current_modname()
local WP = minetest.get_worldpath()
local ie = minetest.request_insecure_environment()

if not ie then
	error("insecure environment inaccessible"..
		" - make sure this mod has been added to minetest.conf!")
end

-- requires library for db access
local _sql = ie.require("lsqlite3")
-- don't allow other mods to use the global library!
if sqlite3 then sqlite3 = nil end

local singleplayer = minetest.is_singleplayer()

-- multiplayer unless you restart it.
if not minetest.setting_get(MN .. '.enable_singleplayer')
and singleplayer then
	  minetest.log("info", "singleplayer game using builtin auth handler")
	  return
end

local db = _sql.open(WP.."/sauth.sqlite") -- connection

-- db:exec wrapper for error reporting
local function db_exec(stmt)
	if db:exec(stmt) ~= _sql.OK then
		minetest.log("info", "Sqlite ERROR:  ", db:errmsg())
	end
end

-- db tables - because we need them!
local create_db = [[
CREATE TABLE IF NOT EXISTS auth (id INTEGER PRIMARY KEY AUTOINCREMENT,
name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512),
last_login INTEGER);
CREATE TABLE IF NOT EXISTS _s (import BOOLEAN);
]]
db_exec(create_db)

--[[
###########################
###  Database: Queries  ###
###########################
]]

local function get_record(name)
	local query = ([[
	    SELECT * FROM auth WHERE name = '%s'
	]]):format(name)
	for row in db:nrows(query) do
		return row
	end
end

local function get_setting(column)
	local query = ([[
		SELECT %s FROM _s
	]]):format(column)
	for row in db:nrows(query) do
		return row
	end
end

--[[
##############################
###  Database: Statements  ###
##############################
]]

local function add_record(name, password, privs, last_login)
	local stmt = ([[
		INSERT INTO auth (
		name,
		password,
		privileges,
		last_login
    		) VALUES ('%s','%s','%s','%s')
	]]):format(name, password, privs, last_login)
	db_exec(stmt)
end

local function add_setting(column, val)
	local stmt = ([[
		INSERT INTO _s (%s) VALUES ('%s')
	]]):format(column, val)
	db_exec(stmt)
end

local function update_login(name)
	local ts = os.time()
	local stmt = ([[
		UPDATE auth SET last_login = %i WHERE name = '%s'
	]]):format(ts, name)
	db_exec(stmt)
end

local function update_password(name, password)
	local stmt = ([[
		UPDATE auth SET password = '%s' WHERE name = '%s'
	]]):format(password,name)
	db_exec(stmt)
end

local function update_privileges(name, privs)
	local stmt = ([[
		UPDATE auth SET privileges = '%s' WHERE name = '%s'
	]]):format(privs,name)
	db_exec(stmt)
end

local function del_record(name)
	local stmt = ([[
		DELETE FROM auth WHERE name = '%s'
	]]):format(name)
	db_exec(stmt)
end

--[[
######################
###  Auth Handler  ###
######################
]]

sauth.auth_handler = {
	get_auth = function(name)
	-- return password,privileges,last_login
	assert(type(name) == 'string')
	local r = auth_table[name]
	-- check if db record needs to be loaded
	if r == nil then
		r = get_record(name)
	else
		return auth_table[name]				
	end
	-- If not in authentication table, return nil
	if not r then return nil end
	local admin = (name == minetest.setting_get("name"))
	local privs = {}
	if singleplayer or admin then
			-- If admin, grant all privs, if singleplayer
			-- grant all privs with give_to_singleplayer
			-- save privs to speed up caching
			for priv, def in pairs(core.registered_privileges) do
				if (singleplayer and def.give_to_singleplayer) or admin then
					privs[priv] = true
				end
			end			
	else
		privs = minetest.string_to_privs(r.privileges)
	end
	local record = {
		password = r.password,
		privileges = privs,
		last_login = tonumber(r.last_login)
		}
	if not auth_table[name] then auth_table[name] = record end
	return record
	end,
	create_auth = function(name, password)
		assert(type(name) == 'string')
		assert(type(password) == 'string')
		-- name, password, privs, last_login
		local ts = os.time()
		local privs = minetest.settings:get("default_privs")
		add_record(name,password,privs,ts)
		auth_table[name] = {
			password = password,
			privileges = minetest.string_to_privs(privs),
			last_login = ts}
		return true
	end,
	delete_auth = function(name)
		assert(type(name) == 'string')
		-- prevent removal if player is online
		if auth_table[name] == nil then del_record(name) end
		return true
	end,
	set_password = function(name, password)
		assert(type(name) == 'string')
		assert(type(password) == 'string')
		-- get player record
		if get_record(name) == nil then
			sauth.auth_handler.create_auth(name, password)
		else
			update_password(name,password)
			auth_table[name].password = password
		end
		return true
	end,
	set_privileges = function(name, privs)
		assert(type(name) == 'string')
		assert(type(privs) == 'table')
		if not sauth.auth_handler.get_auth(name) then
	    		-- create the record
	   		sauth.auth_handler.create_auth(name,
				minetest.get_password_hash(name,
					minetest.settings:get("default_password")))
		end
		update_privileges(name, minetest.privs_to_string(privs))
		auth_table[name].privileges = privs
		minetest.notify_authentication_modified(name)
		return true
	end,
	reload = function()
		return true
	end,
	record_login = function(name)
		assert(type(name) == 'string')
		update_login(name)
		auth_table[name].last_login = os.time()
		return true
	end
}

--[[
########################
###  import records  ###
########################
]]

-- manage import/export dependant on size
if get_setting("import") == nil then

	local function save_sql(stmt)
		-- save file
		local file = ie.io.open(WP.."/auth.sql", "a")
		if file then
			file:write(stmt)
			file:close()
		end
	end

	local function del_sql()
		ie.os.remove(WP.."/auth.sql")
	end

	local function export_auth()
		local file, errmsg = ie.io.open(WP.."/auth.txt", 'rb')
		if not file then
			minetest.log("info", WP.."/auth.txt".." could not be opened for reading ("..errmsg..")")
			return
		end
		del_sql()
		local index = 1
		local stmt = create_db.."BEGIN;\n"
		for line in file:lines() do
			if line ~= "" then
				local fields = line:split(":", true)
				local name, password, privs, last_login = unpack(fields)
				last_login = tonumber(last_login)
				if not (name and password and privs) then
					break -- can't use bad data
				end
				stmt = stmt..("INSERT INTO auth VALUES ('%s','%s','%s','%s','%s');\n"
				):format(index, name, password, privs, last_login)
				save_sql(stmt)
				stmt = ""
				index = index + 1
			end
		end
		stmt = "UPDATE _s (import) VALUES ('true');\n"
		ie.io.close(file)
		save_sql(stmt.."END;\n")
		add_setting("import", false)
	end

	local function db_import()
		for name, stuff in pairs(core.auth_table) do
			local privs = minetest.privs_to_string(stuff.privileges)
			add_record(name,stuff.password,privs,stuff.last_login)
			add_setting("import", true) -- set db flag
		end
	end
	-- limit direct transfer to a sensible ~1 minute
	if #core.auth_table < 360 then db_import() end
	-- are we there yet?
	if get_setting("import") == false then
		-- dump to sql
		export_auth()
	end
	-- rename auth.txt otherwise it will still load!
	ie.os.rename(WP.."/auth.txt", WP.."/auth.txt.bak")
	core.auth_table = {} -- clear
	core.notify_authentication_modified()
end

--[[
########################
###  Register hooks  ###
########################
]]
-- register auth handler
minetest.register_authentication_handler(sauth.auth_handler)
minetest.log('action', MN .. ": Registered auth handler")
-- housekeeping
minetest.register_on_leaveplayer(function(player)
	auth_table[player:get_player_name()] = nil
end)

minetest.register_on_shutdown(function()
	db:close()
end)
