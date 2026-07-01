-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-- Copyright (c) 2022-2026 Thomas Floeren

local _, ns = ...

local C_PetJournal_GetPetInfoByPetID = C_PetJournal.GetPetInfoByPetID
local C_PetJournal_GetBattlePetLink = C_PetJournal.GetBattlePetLink
local C_PetJournal_GetSummonedPetGUID = C_PetJournal.GetSummonedPetGUID
local GetTimePreciseSec = _G.GetTimePreciseSec
local tostring = _G.tostring
local format = _G.format
local GetTimePreciseSec = _G.GetTimePreciseSec
local GetTime = _G.GetTime
local WTC = WrapTextInColorCode
 -- Don't use a hyphen (U+002D), it's very short in some fonts (e.g. ArialN)
 -- If the minus sign glyph "−" (U+2212, \226\136\146) is missing in a user custom chat font,
 -- go with an en–dash (U+2013, \226\128\147).
local TEXT_MINUS = '\226\136\146'
local MYSHORTNAME = 'PW'
ns.MYSHORTNAME = MYSHORTNAME

--[[===========================================================================
	Colors and print
===========================================================================]]--

local colors = {
	-- Old:
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
	-- New 3.0
	BAD = 'DC143C', -- crimson
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


local function ts_debug(precise)
	local func = precise and GetTimePreciseSec or GetTime
	local ts = func() % 100
	local num_sec, num_dec = 2, 4
	local width = num_sec + 1 + num_dec
	return format('%0' .. width .. '.' .. num_dec .. 'f', ts)
end

function ns.debug_display()
-- 	ns.status_display()
	local actpet = C_PetJournal_GetSummonedPetGUID()
local lines = {
	{ '%s Debug:', MYSHORTNAME },
	{
		'DB current pet|r: %s [%s]',
		ns.id_to_name(ns.db.recentPets[1]),
		tostring(ns.db.recentPets[1]),
	},
	{
		'DB previous pet|r: %s [%s]',
		ns.id_to_name(ns.db.recentPets[2]),
		tostring(ns.db.recentPets[2]),
	},
	{
		'Char DB current pet|r: %s [%s]',
		ns.id_to_name(ns.dbc.recentPets[1]),
		tostring(ns.dbc.recentPets[1]),
	},
	{
		'Char DB previous pet|r: %s [%s]',

		ns.id_to_name(ns.dbc.recentPets[2]),
		tostring(ns.dbc.recentPets[2]),
	},
	{ '‹pet_verified›|r: %s', tostring(ns.pet_verified) },
	{ 'Currently summoned pet|r: %s [%s]', ns.id_to_name(actpet), tostring(actpet) },
	'---',
	{ '‹IsPossessBarVisible()› [in use]: %s', tostring(IsPossessBarVisible()) },
	{ '‹UnitIsControlling "player"›: %s', tostring(UnitIsControlling "player") },
	{
		'‹UnitHasVehicleUI "player"› [in use]: %s',

		tostring(UnitHasVehicleUI "player"),
	},
	{ '‹HasVehicleActionBar()› [in use]: %s', tostring(HasVehicleActionBar()) },
	{ '‹HasOverrideActionBar()›: %s', tostring(HasOverrideActionBar()) },
	{ '‹HasExtraActionBar()›: %s', tostring(HasExtraActionBar()) },
	{ '‹HasBonusActionBar()›: %s', tostring(HasBonusActionBar()) },
	-- {'‹HasTempShapeshiftActionBar()›: %s', tostring(HasTempShapeshiftActionBar())},
	{ '‹UnitInVehicle "player"›: %s', tostring(UnitInVehicle "player") },
	{ '‹CanExitVehicle()›: %s', tostring(CanExitVehicle()) },
	{ '‹IsMounted()›: %s', tostring(IsMounted()) },
	{ '‹IsFlying()› [in use]: %s', tostring(IsFlying()) },
	{ '‹IsStealthed()› [in use]: %s', tostring(IsStealthed()) },
}
	multiprint(lines, CLR.DEBUG())
end

do
	local function dprint(...)
		print(format('%s[%s] %s>DEBUG>', CLR.DEBUG(), ts_debug(true), MYSHORTNAME), ...)
	end

	-- without pet info
	function ns.debugprint(...)
		if ns.db.debugMode then dprint(...) end
	end

	-- with pet info
	function ns.debugprint_pet(...)
		if not ns.db.debugMode then return end
		local perchar = ns.dbc.charFavsEnabled and ns.db.favsOnly
		local curr_db = perchar and ns.dbc or ns.db
		dprint(...)
		print(
			format(
				'%sCurrent DB (%s) pet: %s',
				CLR.DEBUG(),
				CLR.EM(perchar and 'char' or 'global'),
				CLR.EM(ns.id_to_name(curr_db.recentPets[1]))
			)
		)
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

-- Certain addons attempt to steal our "/pw" command
-- Hook into hash_SlashCmdList and fix it once it's populated
local reapplied
function ns.protect_slashcommand(cmdstr, addonstr, cmdfunc)
	local failedmsg
	if type(hash_SlashCmdList) ~= 'table' then
		failedmsg = 'does not exist (yet)'
	elseif getmetatable(hash_SlashCmdList) then
		failedmsg = 'has already a metatable'
	end
	if failedmsg then
		C_Timer.After(
			25,
			function()
				ns.debugprint(
					'‹hash_SlashCmdList› '
						.. failedmsg
						.. '! We could not check for offending slash commands.'
				)
			end
		)
		return
	end

	local function get_offending_addons()
		local results = {}
		local mt = getmetatable(SlashCmdList)
		local backing_table = mt and mt.__index
		if type(backing_table) == 'table' then
			for name, _ in pairs(backing_table) do
				local i = 1
				while true do
					local cmd = _G['SLASH_' .. name .. i]
					if not cmd then break end
					if cmd:lower() == cmdstr and name ~= addonstr then
						tinsert(results, name)
						break -- one hit per addon is enough
					end
					i = i + 1
				end
			end
		end
		-- NOTE (TODO?):
		-- There is also the global `hash_ChatTypeInfoList`; check out OPie:
		-- OPie/Libs/ActionBook/Rewire.lua L1245
		-- This returns the addon that is actually overwriting our slash cmd,
		-- i.e. we do *not* get all conflicting addons:
		-- print('PW TEST:', hash_ChatTypeInfoList[cmdstr:upper()]) -- test
		return table.concat(results, ', ')
	end

	-- `_G.hash_SlashCmdList` exists at load time (contains only Blizz baseline commands);
	-- On first slash cmd entry, all addon commands are added:
	-- The key is the cmd string from the global vars like SLASH_PetWalker1,
	-- The value is the corresponding function from `_G.SlashCmdList`;
	-- So we use `__newindex` to see when this happens;
	-- If identical strings, the last one added wins; if it's not our cmd, we'll fix that;
	-- `Note: _G.SlashCmdList` is backed via mt.__index
	-- Offending slash cmds registered later *will* overwrite our command
	local mt = {}
	mt.__newindex = function(t, key, value)
		-- We only need to know when this happens, and fix afterwards
		-- No need to keep the MT, as later overwrites will not trigger `__newindex`
		setmetatable(t, nil)
		-- TODO: *Maybe* check immediately if '/pw == ourFunc', and don't delete the MT; this would save us
		-- the timed check afterwards, but at the cost of a permanent MT on hash_SlashCmdList,
		-- and we'd do a check on each new index. But I think this would be negligible.
		rawset(t, key, value)
		ns.debugprint('‹hash_SlashCmdList› got a new index.')
		-- Debug/curiosity: see if the table gets a new entry somewhere midsession (e.g. an addon adds cmd late)
		-- This will not catch any overwrites
		if ns.user_is_author then
			if reapplied then
				ns.addonprint('[author-only] New index: "' .. key .. '"')
				PlaySoundFile(1384045)
			end
			ns.reapply_slashprot()
		end
		-- Make sure everything is written
		C_Timer.After(0.15, function()
			-- Everything in hash_SlashCmdList is uppercase
			local str = cmdstr:upper()
			if hash_SlashCmdList[str] ~= cmdfunc then
				hash_SlashCmdList[str] = cmdfunc
				if ns.db.verbosityLevel > 1 then
					ns.addonprint(
						format(
							"%sAnother addon tried to steal your %s slash command. %sThis should be fixed now; if your last command didn't work, please %s. Offending commands: %s.",
							CLR.WARN(),
							CLR.KEY(cmdstr),
							CLR.TXT(),
							CLR.EM('try again'),
							CLR.BAD(get_offending_addons())
						)
					)
				end
			end
		end)
	end

	setmetatable(hash_SlashCmdList, mt)
end

-- Debug
function ns.reapply_slashprot()
-- 	do return end
	reapplied = true
	C_Timer.After(3, function()
		ns.protect_slash_pw()
		local mt = getmetatable(hash_SlashCmdList)
		if mt and mt.__newindex then
			ns.addonprint('[author-only] Reapplied slash protection.')
		else
			ns.addonprint('[author-only] Could not reapply slash protection.')
			PlaySoundFile(1384045)
		end
	end)
end

