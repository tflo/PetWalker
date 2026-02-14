-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-- Copyright (c) 2022-2026 Thomas Floeren

local _, ns = ...

local C_PetJournal_GetPetInfoByPetID = C_PetJournal.GetPetInfoByPetID
local C_PetJournal_GetBattlePetLink = C_PetJournal.GetBattlePetLink
local C_PetJournal_GetSummonedPetGUID = C_PetJournal.GetSummonedPetGUID
local GetTimePreciseSec = _G.GetTimePreciseSec
local tostring = _G.tostring
local format = _G.format
local WTC = WrapTextInColorCode
 -- Don't use a hyphen (U+002D), it's very short in some fonts (e.g. ArialN)
 -- If the minus sign glyph "−" (U+2212, \226\136\146) is missing in a user custom chat font,
 -- go with an en–dash (U+2013, \226\128\147).
local TEXT_MINUS = '\226\136\146'
local MYSHORTNAME = 'PW'
ns.MYSHORTNAME = MYSHORTNAME

--[[===========================================================================
	Colors
===========================================================================]]--

local colors = {
-- 	ADDON = '0bff9a',
-- 	TXT = 'b6f2d0',
-- 	HEAD = '39d1bd', -- TODO: find a color for this
-- 	WARN = 'ec6950',
-- 	QUOTE = '88e2ac',
-- 	EM = '88e2ac',
-- 	KEY = '54d689',
-- 	STATE = '2ebc69',
-- 	CMD = 'e24eef',

-- 	old:
	ADDON = '7CFC00',
	TXT = '8FBC8F',
	HEAD = '7CFC00', -- TODO: find a color for this
	WARN = 'FA8072',
	QUOTE = '808000',
	EM = 'ADFF2F',
	KEY = '00FA9A',
	STATE = '32CD32',
	CMD = 'FF00FF',
	DEBUG = 'EE82EE',



-- 	HEAD = 'FFE4B5', -- moccasin
-- 	BAD = 'DC143C', -- crimson
-- 	ON = '32CD32', -- limegreen
-- 	OFF = 'C0C0C0', -- silver
-- 	GOOD = '00FA9A', -- mediumspringgreen
-- 	YYY = '90EE90', -- lightgreen
}

local CLR = setmetatable({}, {
	__index = function(_, k)
		local color = colors[k]
		assert(color, format('Color %q not defined.', k))
		color = 'FF' .. color
		return function(text) return text and WTC(text, color) or '\124c' .. color end
	end,
})
ns.CLR = CLR
-- Usage: print('text ' .. CLR.WARN('warning') .. ' text' .. CLR.HEAD() .. ' text')

local function multiprint(linestable, linecolor)
	linecolor = linecolor or CLR.TXT()
	for _, v in ipairs(linestable) do
		if type(v) == 'table' then
			v[1] = linecolor .. v[1]
			print(format(unpack(v)))
		elseif v then
			print(v)
		end
	end
end
ns.multiprint = multiprint

--[[===========================================================================
	Helpers
===========================================================================]]--

function ns.id_to_name(id)
	if not id then return "<¡id_to_name() didn't receive a pet GUID!>" end
	local name = select(8, C_PetJournal_GetPetInfoByPetID(id))
	return tostring(name) or '¿petname?'
end

function ns.id_to_species(id)
	if not id then return "<¡id_to_species() didn't receive a pet GUID!>" end
	local spec = C_PetJournal_GetPetInfoByPetID(id)
	return tostring(spec) or '¿petspecies?'
end

function ns.id_to_link(id)
	if not id then return "<¡id_to_link() didn't receive a pet GUID!>" end
	local link = C_PetJournal_GetBattlePetLink(id)
	return tostring(link) or '¿petlink?'
end

--[[===========================================================================
	Debug
===========================================================================]]--

function ns.debug_display()
	ns.status_display()
	local actpet = C_PetJournal_GetSummonedPetGUID()
	local lines = {
		format('%s%s Debug:', CLR.DEBUG(), MYSHORTNAME),
		format('%sDB current pet|r: %s [%s]', CLR.DEBUG(), ns.id_to_name(ns.db.recentPets[1]), tostring(ns.db.recentPets[1])),
		format('%sDB previous pet|r: %s [%s]', CLR.DEBUG(), ns.id_to_name(ns.db.recentPets[2]), tostring(ns.db.recentPets[2])),
		format('%sChar DB current pet|r: %s [%s]', CLR.DEBUG(), ns.id_to_name(ns.dbc.recentPets[1]), tostring(ns.dbc.recentPets[1])),
		format('%sChar DB previous pet|r: %s [%s]', CLR.DEBUG(), ns.id_to_name(ns.dbc.recentPets[2]), tostring(ns.dbc.recentPets[2])),
		format('%s`pet_verified`|r: %s', CLR.DEBUG(), tostring(ns.pet_verified)),
		format('%sCurrently summoned pet|r: %s [%s]', CLR.DEBUG(), ns.id_to_name(actpet), tostring(actpet)),
		'---',
		format('%s`IsPossessBarVisible()` [in use]: %s', CLR.DEBUG(), tostring(IsPossessBarVisible())),
		format("%s`UnitIsControlling 'player'`: %s", CLR.DEBUG(), tostring(UnitIsControlling 'player')),
		format("%s`UnitHasVehicleUI 'player'` [in use]: %s", CLR.DEBUG(), tostring(UnitHasVehicleUI 'player')),
		format('%s`HasVehicleActionBar()` [in use]: %s', CLR.DEBUG(), tostring(HasVehicleActionBar())),
		format('%s`HasOverrideActionBar()`: %s', CLR.DEBUG(), tostring(HasOverrideActionBar())),
		format('%s`HasExtraActionBar()`: %s', CLR.DEBUG(), tostring(HasExtraActionBar())),
		format('%s`HasBonusActionBar()`: %s', CLR.DEBUG(), tostring(HasBonusActionBar())),
-- 		format('%s`HasTempShapeshiftActionBar()`: %s', CLR.DEBUG(), tostring(HasTempShapeshiftActionBar())),
		format("%s`UnitInVehicle 'player'`: %s", CLR.DEBUG(), tostring(UnitInVehicle 'player')),
		format('%s`CanExitVehicle()`: %s', CLR.DEBUG(), tostring(CanExitVehicle())),
		format('%s`IsMounted()`: %s', CLR.DEBUG(), tostring(IsMounted())),
		format('%s`IsFlying()` [in use]: %s', CLR.DEBUG(), tostring(IsFlying())),
		format('%s`IsStealthed()` [in use]: %s', CLR.DEBUG(), tostring(IsStealthed())),
	}
	for _, l in ipairs(lines) do print(l) end
end

-- without pet info
function ns.debugprint(...)
	if ns.db.debugMode then
		local a, b = strsplit('.', GetTimePreciseSec())
		print(format('[%s.%s] %s%s>DEBUG>', a:sub(-3), b:sub(1, 3), CLR.DEBUG(), MYSHORTNAME), ...)
	end
end

-- with pet info
function ns.debugprint_pet(msg)
	if ns.db.debugMode then
	local a, b = strsplit('.', GetTimePreciseSec())
	local lines = {
		format('[%s.%s] %s%s: %s', a:sub(-3), b:sub(1, 3), CLR.DEBUG(), MYSHORTNAME, msg),
		format('%sCurrent DB (%s) pet|r: %s', CLR.DEBUG(), ns.dbc.charFavsEnabled and ns.db.favsOnly and 'char' or 'global', ns.id_to_name(ns.dbc.charFavsEnabled and ns.db.favsOnly and ns.dbc.recentPets[1] or ns.db.recentPets[1])),
	}
	for _, l in ipairs(lines) do print(l) end
	end
end

--[[===========================================================================
	For UI
===========================================================================]]--

function ns.remaining_timer(time)
	local rem = ns.time_newpet_success + ns.db.newPetTimer - time
	return max(rem, 0)
end

-- Used in: status (×2), timer-change confirmation, login msg,
function ns.sec_to_format(seconds, symbol, compact, joined)
	symbol = tonumber(symbol)
	if tonumber(symbol) == nil then symbol = 1 end
	symbol = min(max(floor(symbol), 1), 3)
	if type(compact) ~= 'boolean' then compact = true end
	if type(joined) ~= 'boolean' then joined = false end
	-- Sanitize combos
	if symbol == 1 or joined then compact = true end
	if symbol == 3 then compact, joined = false, false end

	local space, joiner = compact and '' or ' ', joined and '' or ' '
	local sd = symbol == 1 and 'd' or 'days'
	local sh = symbol == 1 and 'h' or symbol == 2 and  'hrs' or 'hours'
	local sm = symbol == 1 and 'm' or symbol == 2 and 'min' or 'minutes'
	local ss = symbol == 1 and 's' or symbol == 2 and 'sec' or 'seconds'

	-- Let's output an overdue remaining timer as negative value
	local sign = seconds < 0 and TEXT_MINUS or ''

	local rem = abs(seconds)
	local d = floor(rem / 86400); rem = rem % 86400
	local h = floor(rem / 3600); rem = rem % 3600
	local m = floor(rem / 60); rem = rem % 60
	local s = floor(rem)

	local days = d ~= 0 and format('%s%s%s%s', d, space, sd, joiner) or ''
	local hrs = h ~= 0 and format('%s%s%s%s', h, space, sh, joiner) or ''
	local min = m ~= 0 and format('%s%s%s%s', m, space, sm, joiner) or ''
	local sec = s ~= 0 and format('%s%s%s', s, space, ss) or ''
	return format('%s%s%s%s%s', sign, days, hrs, min, sec):trim()
end

function ns.remaining_timer_for_display()
	local remaining = ns.time_newpet_success + ns.db.newPetTimer - time()
-- 	remaining = max(remaining, 0) -- should never be negative
	return ns.sec_to_format(remaining, 1, true, false)
end

function ns.table_is_empty(t)
	return next(t) == nil
end
