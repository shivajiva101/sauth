-- sqlite3 auth handler mod with memory caching for minetest voxel game
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

--- Create cache when mod loads
local function create_cache()
	local q = "SELECT max(last_login) AS result FROM auth;"
	local it, state = db:nrows(q)
	local last = it(state)
	if last and last.result then
		last = last.result - ttl
		q = ([[SELECT * FROM auth WHERE last_login > %s LIMIT %s;
		]]):format(last, max_cache_records)
		for row in db:nrows(q) do
			cache[row.name] = {
				id = row.id,
				password = row.password,
				privileges = {},
				last_login = row.last_login
			}
			cap = cap + 1
		end
		local r = {}
		for k,v in pairs(cache) do
			q = ("SELECT * FROM user_privileges WHERE id = %i;"):format(v.id)
			for row in db:nrows(q) do
				r[row.privilege] = true
			end
			cache[k].privileges = r
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
CREATE TABLE IF NOT EXISTS auth (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	name VARCHAR(32) UNIQUE,
	password VARCHAR(512),
	last_login INTEGER);
CREATE TABLE IF NOT EXISTS user_privileges (
	id INTEGER,
	privilege VARCHAR(32),
	PRIMARY KEY (id, privilege) CONSTRAINT fk_id FOREIGN KEY (id)
	REFERENCES auth (id) ON DELETE CASCADE);
]]
db_exec(create_db)

create_cache()

--[[
###########################
###  Database: Queries  ###
###########################
]]

--- Get auth table record for name
---@param name string
---@return keypair table
local function get_auth_record(name)
	local query = ([[
	    SELECT * FROM auth WHERE name = '%s' LIMIT 1;
	]]):format(name)
	local it, state = db:nrows(query)
	local row = it(state)
	return row
end

--- Get privileges from user_privileges table for id
---@param id integer
---@return keypairs table or nil
local function get_privs(id)
	local q = ([[
	    SELECT * FROM user_privileges WHERE id = %i;
	]]):format(id)
	local r = {}
	for row in db:nrows(q) do
		r[row.privilege] = true
	end
	return r
end

--- Get id from player name
---@param name string
---@return id integer or nil
local function get_id(name)
	local q = ("SELECT * FROM auth WHERE name = '%s';"):format(name)
	local it, state = db:nrows(q)
	local row = it(state)
	return row.id
end

--- Check db for matching name
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
---@param privs pairs table
---@param last_login integer
---@return boolean
---@return string error message
local function add_player_record(name, password, privs, last_login)
	local stmt = ([[
		INSERT INTO auth (
		name,
		password,
		last_login
		) VALUES ('%s','%s', %i)
	]]):format(name, password, last_login)
	local r, e = db_exec(stmt)
	if r then
		-- add privileges
		local str = {}
		local id = db:last_insert_rowid()
		for k,v in pairs(privs) do
			str[#str + 1] = ([[
				INSERT INTO user_privileges (
				id,
				privilege
				) VALUES (%i, '%s');
			]]):format(id, k)
		end
		return db_exec(table.concat(str, "\n"))
	else
		return r, e
	end
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
---@param privs pair table
---@return boolean
---@return string error message
local function update_privileges(name, privs)
	local id = get_id(name)
	local stmt = ([[
		DELETE FROM user_privileges WHERE id = %i;
	]]):format(id)
	local r, e = db_exec(stmt)
	if r == true then
		local str = {}
		for k,v in pairs(privs) do
			str[#str + 1] = ([[
				INSERT INTO user_privileges (
				id,
				privilege
				) VALUES (%i, '%s');
			]]):format(id, k)
		end
		return db_exec(table.concat(str, "\n"))
	else
		return r, e
	end
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
		DELETE FROM auth WHERE name = '%s';
	]]):format(name)
	return db_exec(stmt)
end


--[[
###################
###  Functions  ###
###################
]]

--- Returns a complete player record
---@param name string
---@return keypair table or nil
local function get_player_record(name)
	local r = get_auth_record(name)
	if r then r.privileges = get_privs(r.id) end
	return r
end

--- Get Player db record
---@param name string
---@return keypair table
local function get_record(name)
	-- Prioritise cache
	if cache[name] then return cache[name] end
	return get_player_record(name)
end

--- Update last login for a player
---@param name string
---@param timestamp integer
---@return boolean
---@return string error message
local function update_login(name)
	local ts = os.time()
	if cache[name] then
		cache[name].last_login = ts
	else
		sauth.auth_handler.get_auth(name)
	end
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
	---@return keypairs table
	get_auth = function(name, add_to_cache)

		-- Check param
		assert(type(name) == 'string')

		-- if an auth record is cached ensure
		-- the owner is granted admin privs
		if cache[name] then
			if not owner_privs_cached and name == owner then
				-- grant admin privs
				for priv, def in pairs(minetest.registered_privileges) do
					if def.give_to_admin then
						cache[name].privileges[priv] = true
					end
				end
				owner_privs_cached = true
			end
			return cache[name]
		end

		-- catch ' passed in name string to prevent crash
		if name:find("%'") then return nil end

		-- Assert caching on missing param
		add_to_cache = add_to_cache or true

		-- Check db for matching record
		local auth_entry = get_player_record(name)

		-- Unknown name check
		if not auth_entry then return nil end

		-- Make a copy of the players privilege table.
		local privileges ={}
		for priv, _ in pairs(auth_entry.privileges) do
			privileges[priv] = true
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
				if def.give_to_admin then
					privileges[priv] = true
				end
			end
		end

		-- Construct record
		local record = {
			password = auth_entry.password,
			privileges = privileges,
			last_login = tonumber(auth_entry.last_login)}

		-- Conditionally retrieves records without caching
		-- by passing false as the second param
		if add_to_cache then
			cache[name] = record
			cap = cap + 1
		end

		return record
	end,

	--- Create a new auth entry
	---@param name string
	---@param password string
	---@return boolean
	create_auth = function(name, password)
		assert(type(name) == 'string')
		assert(type(password) == 'string')
		minetest.log('info', "[sauth] authentification handler adding player '"..name.."'")
		local privs = minetest.string_to_privs(minetest.settings:get("default_privs"))
		local res, err = add_player_record(name,password,privs,-1)
		if res then
			cache[name] = {
				password = password,
				privileges = privs,
				last_login = -1 -- defer
			}
		end
		return res, err
	end,

	--- Delete an auth entry
	---@param name string
	---@return boolean
	delete_auth = function(name)
		assert(type(name) == 'string')
		local record = get_record(name)
		local res = false
		if record then
			minetest.log('info', "[sauth] authentification handler deleting player '"..name.."'")
			res = del_record(name)
			if res then
				cache[name] = nil
			end
		end
		return res
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
	---@param privileges keypairs table
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
		update_privileges(name, privileges)
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
minetest.log('action', "[sauth] registered as the authentication handler!")

minetest.register_on_prejoinplayer(function(name, ip)
	local r = get_record(name)
	if r ~= nil then return	end
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
	local name = player:get_player_name()
	local r = get_record(name)
	if r ~= nil then sauth.auth_handler.record_login(name) end
	trim_cache()
end)

minetest.register_on_shutdown(function()
	db:close()
end)
