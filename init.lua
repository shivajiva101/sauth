-- sqlite3 auth handler mod for minetest voxel game
-- by shivajiva101@hotmail.com

-- Expose handler functions
sauth = {}
local cache = {}
local MN = minetest.get_current_modname()
local WP = minetest.get_worldpath()
local ie = minetest.request_insecure_environment()
local owner_privs_cached = false

if not ie then
	error("insecure environment inaccessible"..
		" - make sure this mod has been added to minetest.conf!")
end

-- read mt conf file settings
local caching = minetest.settings:get_bool(MN .. '.caching') or true
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

--- Apply statements against the current database
--- wrapping db:exec for error reporting
---@param stmt string
---@return boolean
---@return string error message
local function db_exec(stmt)
	if db:exec(stmt) ~= _sql.OK then
		minetest.log("info", "Sqlite ERROR:  ", db:errmsg())
		return false, db:errmsg()
	end
	return true
end

-- Cache handling
local cap = 0

--- Create cache on load
local function create_cache()
	local q = "SELECT max(last_login) AS result FROM auth;"
	local it, state = db:nrows(q)
	local last = it(state)
	if last and last.result ~= nil then
		last = last.result - ttl
		q = ([[SELECT *	FROM auth WHERE last_login > %s LIMIT %s;
		]]):format(last, max_cache_records)
		for row in db:nrows(q) do
			cache[row.name] = {
				password = row.password,
				privileges = minetest.string_to_privs(row.privileges),
				last_login = row.last_login
			}
			cap = cap + 1
		end
	end
	minetest.log("action", "[sauth] caching " .. cap .. " records.")
end

--- Remove oldest entry in the cache
local function trim_cache()
	if cap < max_cache_records then return end
	local entry = os.time()
	local name
	for k, v in pairs(cache) do
		if v.last_login < entry then
			entry = v.last_login
			name = k
		end
	end
	cache[name] = nil
	cap = cap - 1
end

-- Define db tables
local create_db = [[
CREATE TABLE IF NOT EXISTS auth (name VARCHAR(32) PRIMARY KEY,
password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);

CREATE INDEX IF NOT EXISTS idx_auth_name ON auth(name);
CREATE INDEX IF NOT EXISTS idx_auth_lastlogin ON auth(last_login);

CREATE TABLE IF NOT EXISTS _s (import BOOLEAN, db_version VARCHAR (6));
]]
db_exec(create_db)

if caching then
	create_cache()
end

--[[
###########################
###  Database: Queries  ###
###########################
]]

--- Get Player db record
---@param name string
---@return table pairs
local function get_player_record(name)
	local query = ([[
	    SELECT * FROM auth WHERE name = '%s' LIMIT 1;
	]]):format(name)
	local it, state = db:nrows(query)
	local row = it(state)
	return row
end

--- Check db for match
---@param name string
---@return table or nil
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

--- Fetch setting
---@param column_name string
---@return table pairs
local function get_setting(column_name)
	local query = ([[
		SELECT %s FROM _s
	]]):format(column_name)
	local it, state = db:nrows(query)
	local row = it(state)
	if row then return row[column_name] end
end

--- Search for records where the name is like param string
---@param name any
---@return table ipairs
--- Uses sql LIKE %name% to pattern match any
--- string that contains name
local function search(name)
	local r,q = {}
	q = "SELECT name FROM auth WHERE name LIKE '%"..name.."%';"
	for row in db:nrows(q) do
		r[#r+1] = row.name
	end
	return r
end

--- Get pairs table of names in the database
---@return table
local function get_names()
	local r,q = {}
	q = "SELECT name FROM auth;"
	for row in db:nrows(q) do
		r[row.name] = true
	end
	return r
end


--[[
###########################
###  Database: Inserts  ###
###########################
]]

--- Add auth record to database
---@param name string
---@param password string
---@param privs string
---@param last_login integer
---@return boolean
---@return string error message
local function add_player_record(name, password, privs, last_login)
	local stmt = ([[
		INSERT INTO auth (
		name,
		password,
		privileges,
		last_login
		) VALUES ('%s','%s','%s',%i)
	]]):format(name, password, privs, last_login)
	return db_exec(stmt)
end

--- Add setting to the database
---@param name string
---@param val any
---@return boolean
---@return string error message
local function add_setting(name, val)
	local stmt = ([[
		INSERT INTO _s (%s) VALUES ('%s')
	]]):format(name, val)
	return db_exec(stmt)
end

-- Add db version to settings
if not get_setting('db_version') then
	add_setting('db_version', '1.1')
end


--[[
###########################
###  Database: Updates  ###
###########################
]]

--- Update last login for a player
---@param name string
---@param timestamp integer
---@return boolean
---@return string error message
local function update_auth_login(name, timestamp)
	local stmt = ([[
		UPDATE auth SET last_login = %i WHERE name = '%s'
	]]):format(timestamp, name)
	return db_exec(stmt)
end

--- Update password for a player
---@param name string
---@param password string
---@return boolean
---@return string error message
local function update_password(name, password)
	local stmt = ([[
		UPDATE auth SET password = '%s' WHERE name = '%s'
	]]):format(password,name)
	return db_exec(stmt)
end

--- Update privileges for a player
---@param name string
---@param privs string
---@return boolean
---@return string error message
local function update_privileges(name, privs)
	local stmt = ([[
		UPDATE auth SET privileges = '%s' WHERE name = '%s'
	]]):format(privs,name)
	return db_exec(stmt)
end


--[[
#############################
###  Database: Deletions  ###
#############################
]]

--- Delete a players auth record from the database
---@param name string
---@return boolean
---@return string error message
local function del_record(name)
	local stmt = ([[
		DELETE FROM auth WHERE name = '%s'
	]]):format(name)
	return db_exec(stmt)
end


--[[
###################
###  Functions  ###
###################
]]

--- Get Player db record
---@param name string
---@return table pairs
local function get_record(name)
	-- Prioritise cache if enabled
	if caching and cache[name] then return cache[name] end
	return get_player_record(name)
end

--- Update last login for a player
---@param name string
---@param timestamp integer
---@return boolean
---@return string error message
local function update_login(name)
	local ts = os.time()
	if caching then cache[name].last_login = ts end
	return update_auth_login(name, ts)
end


--[[
######################
###  Auth Handler  ###
######################
]]

sauth.auth_handler = {

	--- Return auth record entry with privileges as a pair table
	--- Prioritises cached data over repeated db searches
	---@param name string
	---@param add_to_cache boolean optional - default is true
	---@return table of pairs
	get_auth = function(name, add_to_cache)

		-- Check param
		assert(type(name) == 'string')

		-- if an auth record exists in the cache the only
		-- other check reqd is that the owner has all privs
		if caching and cache[name] then
			if not owner_privs_cached and name == owner then
				-- grant all privs
				for priv, def in pairs(minetest.registered_privileges) do
					cache[name].privileges[priv] = true
				end
				owner_privs_cached = true
			end
			return cache[name]
		end

		-- catch ' passed in name string to prevent crash
		if name:find("%'") then return nil end

		-- Assert caching on missing param
		add_to_cache = add_to_cache or caching

		-- Check db for matching record
		local auth_entry = get_player_record(name)

		-- Unknown name check
		if not auth_entry then return nil end

		-- Make a copy of the players privilege table.
		-- Data originating from the db is a string
		-- so it must be cast to a table
		local privileges
		if type(auth_entry.privileges) == "string" then
			-- Reconstruct table using minetest function
			privileges = minetest.string_to_privs(auth_entry.privileges)
		else
			privileges = auth_entry.privileges -- cached
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
			last_login = tonumber(auth_entry.last_login)}

		-- Cache if reqd, mt core calls this function constantly
		-- so minimise the codes path to speed things up
		if add_to_cache then
			cache[name] = record
			cap = cap + 1
			return record
		end
	end,

	--- Create a new auth entry
	---@param name string
	---@param password string
	---@return boolean
	create_auth = function(name, password)
		assert(type(name) == 'string')
		assert(type(password) == 'string')
		local ts = os.time()
		local privs = minetest.settings:get("default_privs")
		add_player_record(name,password,privs,ts)
		if caching then
			cache[name] = {
				password = password,
				privileges = minetest.string_to_privs(privs),
				last_login = -1 -- defer
			}
		end
		return true
	end,


	--- Delete an auth entry
	---@param name string
	---@return boolean
	delete_auth = function(name)
		assert(type(name) == 'string')
		local record = get_record(name)
		if record then
			del_record(name)
			if caching then cache[name] = nil end
			minetest.log("info", "[sauth] Db record for " .. name .. " was deleted!")
			return true
		end
		return false
	end,

	--- Set password for an auth record
	---@param name string
	---@param password string
	---@return boolean
	set_password = function(name, password)
		assert(type(name) == 'string')
		assert(type(password) == 'string')
		-- get player record
		if get_record(name) == nil then
			sauth.auth_handler.create_auth(name, password)
		else
			update_password(name, password)
			if cache[name] then cache[name].password = password end
		end
		return true
	end,

	--- Set privileges for an auth record
	---@param name string
	---@param privileges string
	---@return boolean
	set_privileges = function(name, privileges)
		assert(type(name) == 'string')
		assert(type(privileges) == 'table')
		local auth_entry = sauth.auth_handler.get_auth(name)
		if not auth_entry then
			auth_entry = sauth.auth_handler.create_auth(name,
					minetest.get_password_hash(name,
						minetest.settings:get("default_password")))

		end
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
		if name == owner then privileges.privs = true end
		-- Update record
		update_privileges(name, minetest.privs_to_string(privileges))
		if cache[name] then cache[name].privileges = privileges end
		minetest.notify_authentication_modified(name)
		return true
	end,

	--- Reload database
	---@param return boolean
	reload = function()
		-- deprecated due to the change in storage mechanism but maybe useful
		-- for cache regeneration
		return true
	end,

	--- Records the last login timestamp
	---@param name string
	---@return boolean
	---@return string error message
	record_login = function(name)
		assert(type(name) == 'string')
		return update_login(name)
	end,

	--- Searches for names like param
	---@param name string
	---@return table ipairs
	name_search = function(name)
		assert(type(name) == 'string')
		return search(name)
	end,

	--- Return an iterator function for the auth table names
	---@return function iterator
	iterate = function()
		local names = get_names()
		return pairs(names)
	end,
}


--[[
########################
###  Register hooks  ###
########################
]]

-- Register auth handler
minetest.register_authentication_handler(sauth.auth_handler)

-- Log event as minetest registers silently
minetest.log('action', "[sauth] now registered as the authentication handler")

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
	if caching then trim_cache() end
end)

minetest.register_on_shutdown(function()
	db:close()
end)
