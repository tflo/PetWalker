local addon_name, ns = ...

local C_PetJournalGetPetInfoByPetID = C_PetJournal.GetPetInfoByPetID
local C_PetJournalGetBattlePetLink = C_PetJournal.GetBattlePetLink
local GetTimePreciseSec = _G.GetTimePreciseSec

local COLOR_DEBUG = '|cffEE82EE'

function ns.id_to_name(id)
	if not id then return '"no ID!" from `id_to_name`' end
	local name = select(8, C_PetJournalGetPetInfoByPetID(id))
	return name or '?petname?'
end

function ns.id_to_species(id)
	if not id then return '"no ID!" from `id_to_species`' end
	local spec = C_PetJournalGetPetInfoByPetID(id)
	return spec or '?petspecies?'
end

function ns.id_to_link(id)
	if not id then return '"no ID!" from `id_to_link`' end
	local link = C_PetJournalGetBattlePetLink(id)
	return link or '?petlink?'
end


function ns.debug_display()
	ns.status_display()
	local lines = {
		format('%sPW Debug:', COLOR_DEBUG),
		format('%sDB current pet|r: %s', COLOR_DEBUG, ns.id_to_name(ns.db.currentPet)),
		format('%sDB previous pet|r: %s', COLOR_DEBUG, ns.id_to_name(ns.db.previousPet)),
		format('%sChar DB current pet|r: %s', COLOR_DEBUG, ns.id_to_name(ns.dbc.currentPet)),
		format('%sChar DB previous pet|r: %s', COLOR_DEBUG, ns.id_to_name(ns.dbc.previousPet)),
		format('%spet_verified|r: %s', COLOR_DEBUG, tostring(ns.pet_verified)),
	}
	for _, l in ipairs(lines) do print(l) end
end

-- without pet info
function ns.debugprint(...)
	if ns.db.debugMode then
		local a, b = strsplit('.', GetTimePreciseSec())
		print(format('[%s.%s] %s%s:', a:sub(-3), b:sub(1, 3), COLOR_DEBUG, 'PetWalker Debug|r'), ...)
	end
end

-- with pet info
function ns.debugprint_pet(msg)
	if ns.db.debugMode then
	local a, b = strsplit('.', GetTimePreciseSec())
	local lines = {
		format('[%s.%s] %sPW Debug|r: %s', a:sub(-3), b:sub(1, 3), COLOR_DEBUG, msg),
		format('%sCurrent DB (%s) pet|r: %s', COLOR_DEBUG, ns.dbc.charFavsEnabled and ns.db.favsOnly and 'char' or 'global', ns.id_to_name(ns.dbc.charFavsEnabled and ns.db.favsOnly and ns.dbc.currentPet or ns.db.currentPet)),
	}
	for _, l in ipairs(lines) do print(l) end
	end
end

function ns.remaining_timer(time)
	local rem = ns.time_newpet_success + ns.db.newPetTimer - time
	return rem > 0 and rem or 0
end

-- Seconds to minutes
local function sec_to_min(seconds)
	local min, sec = tostring(math.floor(seconds / 60)), tostring(seconds % 60)
	return format('%.0f:%02.0f', min, sec)
end

function ns.remaining_timer_for_display()
	local rem = ns.time_newpet_success + ns.db.newPetTimer - time()
	rem = rem > 0 and rem or 0
	return sec_to_min(rem)
end


--[[ License ===================================================================

	Copyright © 2022–2024 Thomas Floeren

	This file is part of PetWalker.

	PetWalker is free software: you can redistribute it and/or modify it under
	the terms of the GNU General Public License as published by the Free
	Software Foundation, either version 3 of the License, or (at your option)
	any later version.

	PetWalker is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
	FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
	details.

	You should have received a copy of the GNU General Public License along with
	PetWalker. If not, see <https://www.gnu.org/licenses/>.

============================================================================]]--
