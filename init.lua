-- sauth mod for minetest voxel game
-- by shivajiva101@hotmail.com

-- Expose handler functions
sauth = {}
local auth_table = {}
local MN = minetest.get_current_modname()
local WP = minetest.get_worldpath()
local ie = minetest.request_insecure_environment()

if not ie then
	error("insecure environment inaccessible"..
		" - make sure this mod has been added to minetest.conf!")
end

-- read mt conf file settings
local caching = minetest.settings:get_bool(MN .. '.caching', false)
local max_cache_records = tonumber(minetest.settings:get(MN .. '.cache_max')) or 500
local ttl = tonumber(minetest.settings:get(MN..'.cache_ttl')) or 86400 -- defaults to 24 hours
local owner = minetest.settings:get("name")

-- localise library for db access
local _sql = ie.require("lsqlite3")

-- Prevent use of this db instance. If you want to run mods that
-- don't secure this global make sure they load AFTER this mod!
if sqlite3 then sqlite3 = nil end

local singleplayer = minetest.is_singleplayer()

-- Use conf setting to determine handler for singleplayer
if not minetest.settings:get_bool(MN .. '.enable_singleplayer')
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
	minetest.log("action", "[sauth] cached " .. cap .. " records.")
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

-- Db tables
local create_db = [[
CREATE TABLE IF NOT EXISTS auth (name VARCHAR(32) PRIMARY KEY,
password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS _s (import BOOLEAN, db_version VARCHAR (6));
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

		-- catch ' passed in name string to prevent crash
		if name:find("%'") then return nil end
		add_to_cache = add_to_cache or true -- Assert caching on missing param
		local auth_entry =  auth_table[name] or get_record(name)
		if not auth_entry then return nil end
		-- Figure out what privileges the player should have.
		-- Take a copy of the players privilege table
		local privileges
		if type(auth_entry.privileges) == "string" then
			privileges = minetest.string_to_privs(auth_entry.privileges)
		else
			privileges = auth_entry.privileges
		end
		-- If singleplayer, grant privileges marked give_to_singleplayer
		if minetest.is_singleplayer() then
			for priv, def in pairs(minetest.registered_privileges) do
				if def.give_to_singleplayer then
					privileges[priv] = true
				end
			end
		-- Grant owner all privileges
		elseif name == owner then
			for priv, def in pairs(minetest.registered_privileges) do
				privileges[priv] = true
			end
		end
		-- Construct record
		local record = {
			password = auth_entry.password,
			privileges = privileges,
			last_login = tonumber(auth_entry.last_login)
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
		local ts = os.time()
		local privs = minetest.settings:get("default_privs")
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
	set_privileges = function(name, privileges)
		assert(type(name) == 'string')
		assert(type(privileges) == 'table')
		local auth_entry = sauth.auth_handler.get_auth(name)
		if not auth_entry then
	    		-- create the record
			auth_entry = sauth.auth_handler.create_auth(name,
					minetest.get_password_hash(name,
						minetest.settings:get("default_password")))

		end
		local admin = minetest.settings:get("name")
		-- Run grant callbacks
		for priv, _ in pairs(privileges) do
			if not auth_entry.privileges[priv] then
				minetest.run_priv_callbacks(name, priv, nil, "grant")
			end
		end
		-- Run revoke callbacks
		for priv, _ in pairs(auth_entry.privileges) do
			if not privileges[priv] then
				minetest.run_priv_callbacks(name, priv, nil, "revoke")
			end
		end
		-- Ensure owner has ability to grant
		if name == admin then privileges.privs = true end
		-- Update sources
		update_privileges(name, minetest.privs_to_string(privileges))
		if auth_table[name] then auth_table[name].privileges = privileges end
		minetest.notify_authentication_modified(name)
		return true
	end,
	reload = function()
		-- deprecated due to the change in storage mechanism but maybe useful
		-- for cache regeneration
		return true
	end,
	record_login = function(name)
		assert(type(name) == 'string')
		update_login(name)
		-- maintain cache
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
