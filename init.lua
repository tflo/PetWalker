-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-- Copyright (c) 2022-2026 Thomas Floeren

local _, ns = ...

--[[===========================================================================
	Defaults
===========================================================================]]--

local function merge_defaults(src, dst)
	for k, v in pairs(src) do
		local src_type = type(v)
		if src_type == 'table' then
			if type(dst[k]) ~= 'table' then dst[k] = {} end
			merge_defaults(v, dst[k])
		elseif type(dst[k]) ~= src_type then
			dst[k] = v
		end
	end
end

-- Do not sync the DB version to the addon version; update DB version only if needed!
-- Use minors (e.g. 2.1) for intermediate alpha/beta/dev versions.
-- HISTORY:
-- 1 or 2: v2.6, Nov 2025: currentPet/previousPet --> recentPets ==> reset specific
-- 2.1: v3.0 dev versions, before July: favs probability
-- 3: v3.0, July 2026: favs probability
local DB_VERSION_CURRENT = 3

local defaults_global = {
	dbVersion = DB_VERSION_CURRENT,
	autoEnabled = true,
	newPetTimer = 720,
	newPetTimer_reset_by_pw = false,
	remainingTimer = 360,
	favsOnly = false,
	favsOnly_reset_by_pw  = false,
	favsProbability = 0.33,
	favsProbability_reset_by_pw = false,
	verbosityLevel = 3,
	drSummoning = true,
	numRecents = 4,
	recentPets = {},
	eventAlt = nil,
	debugMode = false,
}

local defaults_perchar = {
	dbVersion = DB_VERSION_CURRENT,
	charFavsEnabled = false,
	charFavs = {},
	recentPets = {},
}

if type(_G.PetWalkerDB) ~= 'table' then
	_G.PetWalkerDB = {}
end
if type(_G.PetWalkerPerCharDB) ~= 'table' then
	_G.PetWalkerPerCharDB = {}
end


merge_defaults(defaults_global, _G.PetWalkerDB)
merge_defaults(defaults_perchar, _G.PetWalkerPerCharDB)
local db, dbc = _G.PetWalkerDB, _G.PetWalkerPerCharDB
ns.db, ns.dbc = db, dbc


--[[----------------------------------------------------------------------------
	DB Update
----------------------------------------------------------------------------]]--

local protected_tables = {
	recentPets = true,
	charFavs = true,
}

-- Reverse nil cleanup
local function clean_removed(trg, ref)
	for k, v in pairs(trg) do
		if ref[k] == nil then
			trg[k] = nil
		elseif not protected_tables[k] and type(v) == 'table' then
			clean_removed(v, ref[k])
		end
	end
end

local function update_db()
	local ver_glob = db.dbVersion or 0
	local ver_char = dbc.dbVersion or 0

	-- Do the migration in ascending order, in case we have historically overlapping changes!
	if ver_glob < 2.1 then
		-- User likes favs, so give them a higher fav ratio in All mode.
		db.favsProbability = db.favsOnly and 0.66 or defaults_global.favsProbability
	end

	if ver_glob ~= DB_VERSION_CURRENT then
		clean_removed(db, defaults_global)
		db.dbVersion = DB_VERSION_CURRENT
		-- TODO: print a message
		ns.db_global_updated = true
	end
	if ver_char ~= DB_VERSION_CURRENT then
		clean_removed(dbc, defaults_perchar)
		dbc.dbVersion = DB_VERSION_CURRENT
		-- TODO: print a message
		ns.db_char_updated = true
	end

end

update_db()

-- Tmp


--[[===========================================================================
	Some variables and early stuff
===========================================================================]]--

-- nothing here
