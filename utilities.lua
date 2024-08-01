local addon_name, ns = ...

local C_PetJournalGetPetInfoByPetID = C_PetJournal.GetPetInfoByPetID
local C_PetJournalGetBattlePetLink = C_PetJournal.GetBattlePetLink

function ns.id_to_name(id)
	if not id then return '"no ID!" from id_to_name' end
	local name = select(8, C_PetJournalGetPetInfoByPetID(id))
	return name
end

function ns.id_to_species(id)
	if not id then return '"no ID!" from id_to_species' end
	local spec = C_PetJournalGetPetInfoByPetID(id)
	return spec
end

function ns.id_to_link(id)
	if not id then return '"no ID!" from id_to_link' end
	local link = C_PetJournalGetBattlePetLink(id)
	return link
end


function ns.debug_display()
	ns.status_display()
	print(
		'|cffEE82EEDebug:\n  DB current pet: ', (ns.id_to_name(ns.db.currentPet) or '<nil>'),
		'\n  DB previous pet: ', (ns.id_to_name(ns.db.previousPet) or '<nil>'),
		'\n  Char DB current pet: ', (ns.id_to_name(ns.dbc.currentPet) or '<nil>'),
		'\n  Char DB previous pet: ', (ns.id_to_name(ns.dbc.previousPet) or '<nil>'),
		'\n  pet_verified: ', ns.pet_verified, '\n'
	)
end

-- without pet info
function ns.debugprint(...)
	if ns.db.debugMode then
		local a, b = strsplit('.', GetTimePreciseSec())
		print(format('[%s.%s] %s:', a:sub(-3), b:sub(1, 3), '|cffEE82EEPetWalker Debug|r'), ...)
	end
end

-- with pet info
function ns.debugprint_pet(msg)
	if ns.db.debugMode then
		print(
			'|cffEE82EEPetWalker Debug: '
				.. msg
				.. ' # Current DB ' .. (ns.dbc.charFavsEnabled and ns.db.favsOnly and '(char)' or '(global)') .. ' pet: '
				.. ns.id_to_name(ns.dbc.charFavsEnabled and ns.db.favsOnly and ns.dbc.currentPet or ns.db.currentPet)
		)
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
