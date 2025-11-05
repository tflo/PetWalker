-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2022-2025 Thomas Floeren

local addon_name, ns = ...

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

-- 1: v2.6, Nov 2025: currentPet/previousPet --> recentPets ==> reset specific
local DB_VERSION_CURRENT = 2

local defaults_global = {
	dbVersion = DB_VERSION_CURRENT,
	autoEnabled = true,
	newPetTimer = 720,
	remainingTimer = 360,
	favsOnly = true,
	verbosityLevel = 3,
	drSummoning = true,
	numRecents = 4,
	recentPets = {},
	eventAlt = nil,
	debugMode = false,
}

local defaults_perchar = {
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

-- Cleanup/migrate
if not _G.PetWalkerDB.dbVersion or _G.PetWalkerDB.dbVersion ~= DB_VERSION_CURRENT then
	-- Migrate currentPet and previousPet to recentPets; inserting nil is OK
	_G.PetWalkerDB.recentPets, _G.PetWalkerPerCharDB.recentPets = {}, {}
	table.insert(_G.PetWalkerDB.recentPets, _G.PetWalkerDB.currentPet)
	table.insert(_G.PetWalkerDB.recentPets, _G.PetWalkerDB.previousPet)
	table.insert(_G.PetWalkerPerCharDB.recentPets, _G.PetWalkerPerCharDB.currentPet)
	table.insert(_G.PetWalkerPerCharDB.recentPets, _G.PetWalkerPerCharDB.previousPet)
	-- Cleanup old stuff
	_G.PetWalkerDB.currentPet, _G.PetWalkerDB.previousPet, _G.PetWalkerPerCharDB.currentPet, _G.PetWalkerPerCharDB.previousPet, _G.PetWalkerPerCharDB.eventAlt =
		nil, nil, nil, nil, nil
end

merge_defaults(defaults_global, _G.PetWalkerDB)
merge_defaults(defaults_perchar, _G.PetWalkerPerCharDB)
ns.db, ns.dbc = _G.PetWalkerDB, _G.PetWalkerPerCharDB


--[[===========================================================================
	Some variables and early stuff
===========================================================================]]--

