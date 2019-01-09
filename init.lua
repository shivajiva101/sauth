-- sauth mod for minetest voxel game
-- by shivajiva101@hotmail.com

-- Expose auth handler functions
sauth = {}
local auth_table = {}
local MN = minetest.get_current_modname()
local WP = minetest.get_worldpath()
local ie = minetest.request_insecure_environment()

-- conf file settings
local caching = minetest.setting_getbool(MN .. '.caching') or false
local max_cache_records = tonumber(minetest.setting_get(MN .. '.cache_max')) or 500
local ttl = tonumber(minetest.setting_get(MN..'.cache_ttl')) or 86400 -- defaults to 24 hours

if not ie then
	error("insecure environment inaccessible"..
		" - make sure this mod has been added to minetest.conf!")
end

-- Requires library for db access
local _sql = ie.require("lsqlite3")

-- Prevent other mods using this instance!
if sqlite3 then sqlite3 = nil end

local singleplayer = minetest.is_singleplayer()

-- Use conf setting to determine handler for singleplayer
if not minetest.setting_get(MN .. '.enable_singleplayer')
and singleplayer then
	  minetest.log("info", "singleplayer game using builtin auth handler")
	  return
end

local db = _sql.open(WP.."/sauth.sqlite") -- connection

-- Create db:exec wrapper for error reporting
local function db_exec(stmt)
	if db:exec(stmt) ~= _sql.OK then
		minetest.log("info", "Sqlite ERROR:  ", db:errmsg())
	end
end

-- Cache handling
local cap = 0
local function fetch_cache()
	local q = "SELECT max(last_login) AS result FROM auth;"
	local it, state = db:nrows(q)
	local last = it(state)
	if last then
		last = last.result - ttl
		local r = {}
		q = ([[SELECT *	FROM auth WHERE last_login > %s LIMIT %s;
		]]):format(last, max_cache_records)
		for row in db:nrows(q) do
			auth_table[row.name] = {
				password = row.password,
				privileges = minetest.string_to_privs(row.privileges),
				last_login = row.last_login
			}
			cap = cap + 1
		end
	end
end

local function trim_cache()
	if cap < max_cache_records then return end
	local entry = os.time()
	local name
	for k, v in pairs(auth_table) do
		if v.last_login < entry then
			entry = v.last_login
			name = k
		end
	end
	auth_table[name] = nil
	cap = cap - 1
end

-- Db tables - because we need them!
local create_db = [[
CREATE TABLE IF NOT EXISTS auth (name VARCHAR(32) PRIMARY KEY ON CONFLICT IGNORE,
password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS _s (import BOOLEAN, db_version VARCHAR(6));
]]
db_exec(create_db)

if caching then
	fetch_cache()
end

--[[
###########################
###  Database: Queries  ###
###########################
]]

local function get_record(name)
	-- cached?
	if auth_table[name] then return auth_table[name] end
	-- fetch record
	local query = ([[
	    SELECT * FROM auth WHERE name = '%s' LIMIT 1;
	]]):format(name)
	local it, state = db:nrows(query)
	local row = it(state)
	return row
end

local function check_name(name)
	local query = ([[
		SELECT DISTINCT name
		FROM auth
		WHERE LOWER(name) = LOWER('%s') LIMIT 1;
	]]):format(name)
	local it, state = db:nrows(query)
	local row = it(state)
	return row
end

local function get_setting(column)
	local query = ([[
		SELECT %s FROM _s
	]]):format(column)
	local it, state = db:nrows(query)
	local row = it(state)
	return row
end

local function search(name)
	local r,q = {}
	q = "SELECT name FROM auth WHERE name LIKE '%"..name.."%';"
	for row in db:nrows(q) do
		r[#r+1] = row.name
	end
	return r
end

local function get_names()
	local r,q = {}
	q = "SELECT name FROM auth;"
	for row in db:nrows(q) do
		r[row.name] = true
	end
	return r
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

if not get_setting('db_version') then
	add_setting('db_version', '1.1')
end

--[[
######################
###  Auth Handler  ###
######################
]]

sauth.auth_handler = {
	get_auth = function(name, add_to_cache)
		-- Return password,privileges,last_login
		assert(type(name) == 'string')
		-- catch empty names for mods that do privilege checks
		if name == nil or name == '' or name == ' ' then
			minetest.log("info", "[sauth] Name missing in call to get_auth. Rejected.")
			return nil
		end
		-- catch ' passed in name string to prevent crash
		if name:find("%'") then return nil end
		add_to_cache = add_to_cache or true -- Assert caching on missing param
		local r = auth_table[name]
		-- Check and load db record if reqd
		if r == nil then
			r = get_record(name)
	  	end
		-- Return nil on missing entry
		if not r then return nil end
		-- Figure out what privileges the player should have.
		-- Take a copy of the players privilege table
		local privileges, admin = {}
		if type(r.privileges) == "string" then
			-- db record
			for priv, _ in pairs(minetest.string_to_privs(r.privileges)) do
				privileges[priv] = true
			end
		else
			-- cache
			privileges = r.privileges
		end
		if core.settings then
			admin = core.settings:get("name")
		else
			-- use old api
			admin = core.setting_get("name")
		end
		-- If singleplayer, grant privileges marked give_to_singleplayer = true
		if core.is_singleplayer() then
			for priv, def in pairs(core.registered_privileges) do
				if def.give_to_singleplayer then
					privileges[priv] = true
				end
			end
		-- If admin, grant all privileges
		elseif name == admin then
			for priv, def in pairs(core.registered_privileges) do
				privileges[priv] = true
			end
		end
		-- Construct record
		local record = {
			password = r.password,
			privileges = privileges,
			last_login = tonumber(r.last_login)
			}
		-- Cache if reqd
		if not auth_table[name] and add_to_cache then
			auth_table[name] = record
			cap = cap + 1
		end
		return record
	end,
	create_auth = function(name, password)
		assert(type(name) == 'string')
		assert(type(password) == 'string')
		local ts, privs = os.time()
		if core.settings then
			privs = core.settings:get("default_privs")
		else
			-- use old api
			privs = core.setting_get("default_privs")
		end
		-- Params: name, password, privs, last_login
		add_record(name,password,privs,ts)
		return true
	end,
	delete_auth = function(name)
		assert(type(name) == 'string')
		local record = get_record(name)
		if record then
			del_record(name)
			auth_table[name] = nil
			minetest.log("info", "[sauth] Db record for " .. name .. " was deleted!")
 			return true
		end
	end,
	set_password = function(name, password)
		assert(type(name) == 'string')
		assert(type(password) == 'string')
		-- get player record
		if get_record(name) == nil then
			sauth.auth_handler.create_auth(name, password)
		else
			update_password(name, password)
			if auth_table[name] then auth_table[name].password = password end
		end
		return true
	end,
	set_privileges = function(name, privs)
		assert(type(name) == 'string')
		assert(type(privs) == 'table')
		if not sauth.auth_handler.get_auth(name) then
	    		-- create the record
			if core.settings then
				sauth.auth_handler.create_auth(name,
					core.get_password_hash(name,
						core.settings:get("default_password")))
			else
				sauth.auth_handler.create_auth(name,
					core.get_password_hash(name,
						core.setting_get("default_password")))
			end
		end
		local admin
		if core.settings then
			admin = core.settings:get("name")
		else
			-- use old api method
			admin = core.setting_get("name")
		end
		if name == admin then privs.privs = true end
		update_privileges(name, minetest.privs_to_string(privs))
		if auth_table[name] then auth_table[name].privileges = privs end
		minetest.notify_authentication_modified(name)
		return true
	end,
	reload = function()
		return true
	end,
	record_login = function(name)
		assert(type(name) == 'string')
		update_login(name)
		
		local auth = auth_table[name]
		if auth then
			auth.last_login = os.time()
		end
		return true
	end,
	name_search = function(name)
		assert(type(name) == 'string')
		return search(name)
	end,
	iterate = function()
		return get_names()
	end,
}

--[[
########################
###  import records  ###
########################
]]

-- Manage import/export dependant on size
if get_setting("import") == nil then
	local importauth = {}
	
	local function tablelength(T)
  		local count = 0
  		for _ in pairs(T) do count = count + 1 end
  		return count
	end
	
	local function save_sql(stmt)
		-- save file
		local file = ie.io.open(WP.."/auth.sql", "a")
		if file then
			file:write(stmt)
			file:close()
		end
	end

	local function remove_sql()
		ie.os.remove(WP.."/auth.sql")
	end

	local function read_auth_file()
		local file, errmsg = ie.io.open(WP.."/auth.txt", 'rb')
		if not file then
			minetest.log("info", " auth.txt missing! ("..errmsg..")")
			return
		end
		for line in file:lines() do
			if line ~= "" then
				local fields = line:split(":", true)
				local name, password, privilege_string, last_login = unpack(fields)
				last_login = tonumber(last_login)
				if not (name and password and privilege_string) then
					minetest.log("info", "Invalid record in auth.txt: "..dump(line))
					break
				end
				importauth[name] = {
					password = password, 
					privileges = privilege_string, 
					last_login = last_login
				}
			end
		end
		ie.io.close(file)
	end
	
	local function export_auth()
		local file, errmsg = ie.io.open(WP.."/auth.txt", 'rb')
		if not file then
			minetest.log("info", WP.."/auth.txt".." could not be opened for reading ("..errmsg..")")
			return
		end
		remove_sql()
		-- Create export file by appending lines
		local stmt = create_db.."BEGIN TRANSACTION;\n"
		for line in file:lines() do
			if line ~= "" then
				local fields = line:split(":", true)
				local name, password, privs, last_login = unpack(fields)
				last_login = tonumber(last_login)
				if not (name and password and privs) then
					break -- can't use bad data
				end
				stmt = stmt..("INSERT INTO auth VALUES ('%s','%s','%s','%s');\n"
				):format(name, password, privs, last_login)
				save_sql(stmt)
				stmt = ""
			end
		end
		stmt = "INSERT INTO _s (import, db_version) VALUES ('true', '1.1');\n"
		ie.io.close(file) -- close auth.txt
		save_sql(stmt.."COMMIT;\n") -- finalise
		ie.os.remove(WP.."/sauth.sqlite") -- remove existing db
		minetest.request_shutdown("Server Shutdown requested...", false, 5)
	end

	local function db_import()
		-- local instance creates player, update or duplication occurs!
		local player_name = core.get_connected_players() or ""
		if type(player_name) == 'table' and #player_name > 0 then
			player_name = player_name[1].name
		end
		for name, stuff in pairs(importauth) do
			if name ~= player_name then
				add_record(name,stuff.password,stuff.privileges,stuff.last_login)
			else
				update_privileges(name, stuff.privileges)
				update_password(name, stuff.password)
			end
		end
		importauth = nil
		if not get_setting("import") then
			add_setting("import", 'true') -- set db flag
		end
	end
	
	local function task()
		-- load auth.txt
		read_auth_file()
		if tablelength(importauth) < 1 then
			minetest.log("info", "[sauth] nothing to import!")
			return
		end			
		-- limit direct transfer to a sensible ~1 minute
		if tablelength(importauth) < 3600 then db_import() end
		-- are we there yet?
		if get_setting("import") == nil then export_auth() end -- dump to sql
		-- rename auth.txt otherwise it will still load!
		ie.os.rename(WP.."/auth.txt", WP.."/auth.txt.bak")
		-- removed from later versions of minetest
		if core.auth_table then
			core.auth_table = {} -- unload redundant data
		end
		core.notify_authentication_modified()
	end
	minetest.after(5, task)
end

--[[
########################
###  Register hooks  ###
########################
]]
-- Register auth handler
minetest.register_authentication_handler(sauth.auth_handler)
minetest.log('action', MN .. ": Registered auth handler")

minetest.register_on_prejoinplayer(function(name, ip)
	local r = get_record(name)	
	if r ~= nil then
		return
	end
	-- Check name isn't registered
	local chk = check_name(name)
	if chk then
		return ("\nCannot create new player called '%s'. "..
			"Another account called '%s' is already registered.\n"..
			"Please check the spelling if it's your account "..
			"or use a different name."):format(name, chk.name)
	end
end)

minetest.register_on_joinplayer(function(player)
	trim_cache()
end)

minetest.register_on_shutdown(function()
	db:close()
end)
