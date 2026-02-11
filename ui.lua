-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-- Copyright (c) 2022-2026 Thomas Floeren

local MYNAME, ns = ...
local ADDON_NAME = MYNAME -- tmp

-- API
local C_PetJournal_GetSummonedPetGUID = _G.C_PetJournal.GetSummonedPetGUID
local C_PetJournal_GetBattlePetLink = _G.C_PetJournal.GetBattlePetLink
local tostring = _G.tostring
local format = _G.format
local print = _G.print
local WTC = WrapTextInColorCode

local CHAR_NAME = UnitName 'player'
local MAX_NUM_RECENTS = 20

local function get_link_actpet()
	local p = C_PetJournal_GetSummonedPetGUID()
	p = p and C_PetJournal_GetBattlePetLink(p)
	return p
end

local function get_link_savedpet()
	local p = ns.dbc.charFavsEnabled and ns.dbc.recentPets[1] or ns.db.recentPets[1]
	p = p and C_PetJournal_GetBattlePetLink(p)
	return p
end

--[[===========================================================================
	Colors - OLD - replace this crap!
===========================================================================]]--

local colscheme_green = {
	basetext = {
		notification = '8FBC8F',
		warning = 'FA8072',
	},
	element = {
		addonname = '7CFC00',
		quote = '808000',
		emphasis = 'ADFF2F',
		keyword = '00FA9A',
		state = '32CD32',
		command = 'FF00FF',
	}
}

local function set_colors(scheme)
	local prefix = '|cff'
	local colorstrings = {
		bn = prefix .. scheme.basetext.notification,
		bw = prefix .. scheme.basetext.warning,
		an = prefix .. scheme.element.addonname,
		q = prefix .. scheme.element.quote,
		e = prefix .. scheme.element.emphasis,
		k = prefix .. (scheme.element.keyword or scheme.element.emphasis),
		s = prefix .. (scheme.element.state or scheme.element.emphasis),
		c = prefix .. (scheme.element.command or scheme.element.emphasis),
	}
	return colorstrings
end

local CO = set_colors(colscheme_green)

--[[===========================================================================
	Colors
===========================================================================]]--

local colors = {
	ADDON = '7CFC00',
	TXT = '8FBC8F',
	WARN = 'FA8072',
	QUOTE = '808000',
	EM = 'ADFF2F',
	KEY = '00FA9A',
	STATE = '32CD32',
	CMD = 'FF00FF',
-- 	DEBUG = 'FF00FF', -- magenta
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

--[[===========================================================================
	Helpers
===========================================================================]]--

local BLOCK_SEP = strrep('+', 42)

local function chat_user_notification(msg) -- OLD
	print(CO.an .. ADDON_NAME .. ":", msg)
end

local function addonprint(msg)
	print(format('%s%s: %s', CLR.ADDON(), MYNAME, CLR.TXT(msg)))
end

local function curr_pool_str(short)
	local str = '¿POOL_STR?'
	if ns.db.favsOnly then
		str = short and 'Favs' or 'Favorites'
	elseif ns.db.favsProbability == 1 then
		str = short and 'All Pets' or 'All Pets'
	elseif ns.db.favsProbability == 0 then
-- 		str = short and 'Non-favs' or 'Non-favorites'
		str = short and 'NonFavs' or 'NonFavorites'
	else
-- 		str = short and 'Favs+Non-favs' or 'Favorites+Non-favorites'
		str = short and 'Favs+NonFavs' or 'Favorites+NonFavorites'
	end
	return str
end

local function curr_num_pool_str()
	local str = '¿#POOL?'
	-- The checks are highly redundant, but it shows me
	-- when I have a mismatch of setting and existing pools.
	if
		ns.pet_pool and not (ns.pet_pool_other or ns.pet_pool_favs) and (ns.db.favsOnly or ns.db.favsProbability == 0 or ns.db.favsProbability == 1)
	then
		str = #ns.pet_pool
	elseif
		(ns.pet_pool_other and ns.pet_pool_favs) and not ns.pet_pool
		and not ns.db.favsOnly
		and ns.db.favsProbability > 0
		and ns.db.favsProbability < 1
	then
		str = #ns.pet_pool_favs .. '+' .. #ns.pet_pool_other
	end
	-- str = ns.pet_pool and #ns.pet_pool
	-- or ns.pet_pool_other and #ns.pet_pool_other .. '+' .. #ns.pet_pool_favs or str
	return str
end

--[[===========================================================================
	Messages
===========================================================================]]--

-- Login msg
function ns.msg_login()
	if ns.db.verbosityLevel < 2 then return end
	local petinfo
	if ns.db.verbosityLevel > 2 then
		local async = false
		local ap, sp = get_link_actpet(), get_link_savedpet()
		if not ap or not sp or ap ~= sp then async = true end
		ap, sp = ap or 'None', sp or 'None'
		petinfo = CLR.KEY(async and 'Current Pet: ' or 'Pet: ')
			.. CLR.STATE()
			.. ap
			.. (async and ' | ' .. CLR.KEY('Saved pet: ') .. sp or '')
	end
	addonprint(
		format(
			'%s %s | %s %s | %s %s | %s',
			CLR.KEY('Auto:'),
			ns.db.autoEnabled and CLR.STATE('On') or CLR.WARN('Off'),
			CLR.KEY('Pet pool:'),
			CLR.STATE(
				ns.db.favsOnly and ns.dbc.charFavsEnabled and 'Char favs'
					or ns.db.favsOnly and 'Global favs'
					or 'All pets'
			),
			CLR.KEY('Timer:'),
			CLR.STATE(ns.db.newPetTimer > 0 and ns.db.newPetTimer / 60 .. ' min' or 'Off'),
			petinfo
		)
	)
end

function ns.msg_no_saved_pet()
	if ns.db.verbosityLevel < 1 then return end
	addonprint(
		format(
			'%sCannot restore pet; no pet has been saved yet%s.|r This should only happen when switching to char-specific favorites for the first time on a char. – Summoned a random pet instead.',
			CLR.WARN(),
			ns.dbc.charFavsEnabled and ' for ' .. CLR.EM(CHAR_NAME) or ''
		)
	)
end

function ns.msg_no_previous_pet()
	if ns.db.verbosityLevel < 1 then return end
	addonprint(
		format(
			'%sNo Previous Pet has been saved yet%s.',
			CLR.WARN(),
			ns.dbc.charFavsEnabled and ' for ' .. CLR.EM(CHAR_NAME) or ''
		)
	)
end

function ns.msg_onlyfavisactive(ap)
	if ns.db.verbosityLevel < 1 then return end
	addonprint(format('Your only eligible random pet %s is already active.', ns.id_to_link(ap)))
end

-- addonprint(format('%s', X))
function ns.msg_removed_invalid_id(counter)
	if ns.db.verbosityLevel < 2 then return end
	addonprint(
		format(
			'%s orphaned pet ID%s %s been removed from the char favorites.',
			counter,
			counter > 1 and 's' or '',
			counter > 1 and 'have' or 'has'
		)
	)
end

function ns.msg_saved_pet_unsummonable(reason, number)
	if ns.db.verbosityLevel < 2 then return end
	addonprint(
		format(
			'%sThe saved pet is not summonable. Reason: %s(%s) %s.|r Trying other saved pets (char/global/previous pet, etc.) now…',
			CLR.WARN(),
			CLR.EM(),
			number or '<??>',
			reason or '<unknown>'
		)
	)
end

function ns.msg_previous_pet_unsummonable()
	if ns.db.verbosityLevel < 1 then return end
addonprint(
	format(
		'%sThe saved Previous Pet or other saved pets are not summonable either. Saving the currently active pet or summoning a new one…',
		CLR.WARN()
	)
)
end

function ns.msg_manual_summon_stopped()
	if ns.db.verbosityLevel < 1 then return end
	format('%sYou are in combat lockdown or flying; pet summoning aborted.', CLR.WARN())
end

-- function ns.msg_recents_dupe_removed(idx)
-- 	if ns.db.verbosityLevel < 3 then return end
-- 	chat_user_notification(CO.bn .. 'Removed a duplicate from recent pets at idx ' .. idx .. '.')
-- end


-- Summon Target Pet messages

function ns.msg_target_summoned(link)
	if ns.db.verbosityLevel < 1 then return end
	addonprint(format('Target pet %s summoned.', link))
end

-- addonprint(format('%s', X)) -- XXX
function ns.msg_target_is_same(link) -- Without web link
	if ns.db.verbosityLevel < 1 then return end
	addonprint(format('Target pet %s is the same as your currently summened pet.', link))
end

-- function ns.msg_target_is_same(link, name) -- With web link
-- 	if ns.db.verbosityLevel < 1 then return end
-- 	chat_user_notification(format('%sTarget pet %s is the same pet as you currently have summened: \nhttps://www.warcraftpets.com/search?q=%s', CO.bn, link, name:gsub("[ ']", {[" "] = "%20", ["'"] = "%27"})))
-- end

function ns.msg_target_not_in_collection(link, name)
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(format('%sUnfortunately, the target pet %s is not in your collection: \nhttps://www.warcraftpets.com/search?q=%s', CO.bn, link, name:gsub("[ ']", {[" "] = "%20", ["'"] = "%27"})))
end

function ns.msg_target_is_not_battlepet()
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(format('%sThe target is not a battle pet!', CO.bn))
end

function ns.msg_target_is_not_companion_battlepet(name)
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(format('%sTarget pet "%s" is a battle pet, but not a companion battle pet. (Not in your collection and unlikely to be collectible at all.): \nhttps://www.wowhead.com/search?q=%s', CO.bn, name, name:gsub("[ ']", {[" "] = "%20", ["'"] = "%27"})))
end


--[[---------------------------------------------------------------------------
The main, success, message when a pet was summoned. Either by restore_pet or
new_pet, or previous_pet or the transitioncheck.
---------------------------------------------------------------------------]]--

-- Called by the new_pet func
-- function ns.set_sum_msg_to_newpet(newpet, pool)
-- 	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 2 and format('%sSummoned %s pet %s.', CO.bn, #pool > 1 and 'a new random' or 'your only pool', ns.id_to_link(np)) or nil
-- end
function ns.set_sum_msg_to_newpet(newpet, pool)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 2 and format('%sSummoned %s pet from %s%s: %s.', CO.bn, #pool > 1 and 'a new' or 'your only', curr_pool_str(true), pool == ns.pet_pool_favs and ' (F)' or '', ns.id_to_link(newpet)) or nil
end

-- Called by the restore_pet func
function ns.set_sum_msg_to_restore_pet(pet)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 3 and format('%sRestored your last pet %s.', CO.bn, ns.id_to_link(pet)) or nil
end

-- Called by the previous_pet func
function ns.set_sum_msg_to_previouspet(pet)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 2 and format('%sSummoned your previous pet %s.', CO.bn, ns.id_to_link(pet)) or nil
end

-- Called by the transitioncheck func
function ns.set_sum_msg_to_transcheck(pet)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 3 and format('%sSummoned your last saved pet %s.', CO.bn, ns.id_to_link(pet)) or nil
end

-- Called by the summon func
function ns.msg_pet_summon_success()
	if ns.msg_pet_summoned_content then
		chat_user_notification(ns.msg_pet_summoned_content)
	end
end

-- Called by the summon func
function ns.msg_pet_summon_failed()
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(CO.bw .. "You don't meet the conditions for summoning a pet right now.")
end


--[[---------------------------------------------------------------------------
Three big messages: Status, Low Pet Pool, and Help
---------------------------------------------------------------------------]]--

function ns.help_display(print_bottomspace)
	local header = {
		CO.bn .. ' Help: ',
		CO.c .. '\n/pw ', 'or ', CO.c .. '/petwalker ', 'supports these commands: ',
	}

	local body = {
		{CO.c .. 'd', ' : ', CO.k .. 'Dismiss ', 'current pet and ', CO.k .. 'disable auto-summoning ', '(new pet / restore).'},

		{CO.c .. 'a', ' : ', 'Toggle ', CO.k .. 'auto-summoning ', '(new pet / restore).'},

		{CO.c .. 'sr', ' : ', 'Toggle ', CO.k .. 'auto-summoning ', 'also ', CO.k .. 'while mounted for Skyriding: ', CO.s .. 'allowed / not allowed', '.'},

		{CO.c .. 'n', ' : ', 'Summon ', CO.k .. 'new pet ', 'from pool.'},

		{CO.c .. 'f', ' : ', 'Toggle ', CO.k .. 'pet pool: ', CO.s .. 'Favorites Only', ', or ', CO.s .. 'All Pets', '.'},

		{CO.c .. 'f <0...1>', ' : ', CO.k .. 'Favorites Probability ', 'in All Pets mode: e.g., ', CO.c .. '0.5 ', 'or ', CO.c .. '.5', '. Zero (', CO.c .. '0', ') excludes favorites, ', CO.c .. '1 ', 'means \'no special treatment for favs\'.'},

		{CO.c .. 'c', ' : ', 'Toggle ', CO.k .. 'favorites: ', CO.s .. 'Per-character', ', or ', CO.s .. 'Global Favorites', '.'},

		{CO.c .. '<number>', ' : ', 'Set ', CO.k .. 'Summon Timer ', 'in minutes (', CO.c .. '1 ', 'to ', CO.c .. '1440', '; ', CO.c .. '0 ', 'to ', CO.k .. 'disable', ').'},

		{CO.c .. 'p', ' : ', 'Cycle through ', CO.k .. 'Previous (recently summoned) Pets', '.'},

		{CO.c .. 'p <number>', ' : ', 'Set ', CO.k .. 'number of recorded Previous Pets ', '(', CO.c .. '1 ', 'to ', CO.c .. MAX_NUM_RECENTS, ').'},

		{CO.c .. 'v', ' : ', CO.k .. 'Verbosity: ', CO.s .. 'silent ', '(only failures and warnings are printed to chat); ', CO.c .. 'vv ', 'for ', CO.s .. 'medium ', CO.k .. 'verbosity ', '(new summons); ', CO.c .. 'vvv ', 'for ', CO.s .. 'full ', CO.k .. 'verbosity ', '(also restored pets).'},

		{CO.c .. 's', ' : ', 'Display current ', CO.k .. 'status/settings.'},

		{CO.c .. 'h', ' : ', 'This help text.'},
	}

	local footer = {
		CO.bn .. '\nExamples: ', CO.c .. '/pw a', ' disables auto-summon/restore, or enables it if disabled. ', CO.c .. '/pw 20', ' sets the new-pet summon timer to 20 minutes.',
		'\nIn Options > Keybindigs you can directly bind some commands.',
	}

	local header_text = table.concat(header, CO.bn)
	local footer_text = table.concat(footer, CO.bn)

	print('\n' .. CO.an .. BLOCK_SEP .. '\n' .. ADDON_NAME .. header_text .. '\n')
	local sep = '\124r' .. CO.bn
	for _, v in ipairs(body) do
		print(table.concat(v, sep))
	end
	print(footer_text .. '\n' .. CO.an .. BLOCK_SEP .. (print_bottomspace and '\n ' or ''))
end

function ns.status_display(print_topsep, print_bottomsep)
	if not ns.pool_initialized then ns.initialize_pool() end
	local header = {
		CO.bn .. ' [v', C_AddOns.GetAddOnMetadata(ADDON_NAME, 'Version'), '] Status & Settings:',
	}
	local body = {
		{CO.k ..'Automatic Random-summoning / Restore ', 'is ', CO.s .. (ns.db.autoEnabled and 'enabled' or CO.bw .. 'disabled'), '.'},

		{CO.k .. 'Summon Timer ', 'is ', CO.s .. (ns.db.newPetTimer > 0 and (ns.db.newPetTimer/60) .. CO.bn .. ' minutes' or 'disabled'), '. Next random pet in ', CO.e .. ns.remaining_timer_for_display(), '.'},

		{CO.k ..'Automatic summoning while mounted for Skyriding ', 'is ', CO.s .. (ns.db.drSummoning and 'allowed' or 'not allowed'), '.'},

		{CO.k .. 'History ', 'of Previous Pets: ', CO.s .. ns.db.numRecents - 1, ' (1 to ' .. MAX_NUM_RECENTS .. ').'},

		{CO.k .. 'Verbosity ', 'level of messages: ', CO.s .. ns.db.verbosityLevel, ' (of 3).'},

		{CO.k .. 'Pet Pool ', 'is ', CO.s .. (curr_pool_str(true)), (not ns.db.favsOnly and ns.db.favsProbability < 1 and ' (favs prob: ' .. CO.s .. ns.db.favsProbability .. CO.bn .. ')' or ''), '. Eligible pets: ', CO.e .. (curr_num_pool_str()), '.'},

		{CO.k .. 'Per-character Favorites ', 'are ', CO.s .. (ns.dbc.charFavsEnabled and 'enabled' or 'disabled'), ' for ', CO.e .. CHAR_NAME, '.'},
	}
	-- Separating this bc it might be a longish list
	local charfavlist = {
		'\n', ns:list_charfavs(),
	}

	local header_text = table.concat(header, CO.bn)
	local charfavlist_text = table.concat(charfavlist, CO.bn)
	local extra_settings = (ns.db.eventAlt and table.concat({CO.k ..'\nAlternative Events ', 'are ', CO.s .. 'enabled ', 'for all chars.'}, CO.bn) or nil)

	print((print_topsep and '\n' .. CO.an .. BLOCK_SEP .. '\n' or CO.an) .. ADDON_NAME .. header_text .. '\n')
	local sep = '\124r' .. CO.bn
	for _, v in ipairs(body) do
		print(table.concat(v, sep))
	end
	if extra_settings then print(extra_settings) end
	print(charfavlist_text)
	if print_bottomsep then print(CO.an .. BLOCK_SEP .. '\n ') end
end

-- TODO: different msgs for the situations:
-- No favs
-- No non-favs bc all pets are favorites
-- One of the two pools is empty (not strictly a failure but favsProbability set to 1)
-- TODO: add db.flags when favsProbability or favsOnly has been force-changed, so we
-- can show this in the status text.
function ns.msg_force_changed_pool()
	chat_user_notification(format('%sYou don\'t have any summonable pets in your active pool, or in one of your active pools (Favorites/Non-favorites). I\'ve set your pet pool to %sAll Pets|r and will try to re-initialize the pool.', CO.bw, CO.k))
end

function ns.msg_low_petpool(nPool)
	if ns.db.verbosityLevel < 0 then return end
	local R = CO.bw
	local poolstr = ns.db.favsProbability == -1 and 'All Pets' or ns.db.favsProbability == 0 and 'Non-fav Pets' or ns.db.favsProbability == 1 and 'Fav Pets' or 'Favs + Non-fav Pets'
	local content = {
		('Your current pool (' .. poolstr .. ') contains ' .. nPool < 1 and CO.k .. '0 (zero) ' ..R.. 'pets ' or R.. 'only ' ..CO.k .. '1 ' ..R.. 'pet '),
		'eligible as random summon!',
		'\nYou should either ' .. (ns.db.favsOnly and 'flag more pets as favorite, or set the random pool to ' .. CO.s ..'All Pets' or 'collect more pets'), ', or set the random-summon timer to ', CO.s .. '0', '.',
		'\nAlso check your ', CO.k .. 'Filter ', 'settings in the ', CO.k .. 'Blizz Pet Journal ', '(not in Rematch!), as they are affecting the pool of available pets!',
		'\nSome pets are ', CO.k .. 'faction-restricted ', 'and cannot be summoned on the other faction, so they may not be eligible on your current toon.',
		'\nPlease note that certain pets are intentionally ', CO.k .. 'excluded ', 'from random summoning, to not break their usability (for example ',
		CO.q .. 'Guild Herald', '). ',
		((ns.dbc.charFavsEnabled and ns.db.favsOnly) and '\nYou have set ' .. CO.e .. CHAR_NAME ..R.. ' to use ' .. CO.s .. 'char-specific favorite ' ..R.. 'pets. Maybe switching to ' .. CO.s .. 'global favorites ' ..R.. '(' .. CO.c .. '/pw c' ..R.. ') will help.' or ''),
	}
	local content = table.concat(content, R)
	chat_user_notification(content)
end


--[[===========================================================================
	Slash UI
===========================================================================]]--

SLASH_PetWalker1, SLASH_PetWalker2 = '/pw', '/petwalker'
function SlashCmdList.PetWalker(msg)
	local args = {}
	for arg in msg:gmatch('[^ ]+') do
		tinsert(args, arg)
	end
	if args[1] == 'd' or args[1] == 'dis' then
		ns:dismiss_and_disable()
	elseif args[1] == 'dd' or args[1] == 'debd' then
		ns:debug_display()
	elseif args[1] == 'dm' or args[1] == 'debug' then
		ns.debugmode_toggle()
	elseif args[1] == 'vvv' then
		ns.verbosity_full()
	elseif args[1] == 'vv' then
		ns.verbosity_medium()
	elseif args[1] == 'v' then
		ns.verbosity_silent()
	elseif args[1] == 'v0' then
		ns.verbosity_mute()
	elseif args[1] == 'a' or args[1] == 'auto' then
		ns:auto_toggle()
	elseif args[1] == 'n' or args[1] == 'new' then
		ns:new_pet(nil, true)
	elseif args[1] == 'f' or args[1] == 'fav' then
		ns:favs_toggle(args[2])
	elseif args[1] == 'aev' or args[1] == 'altevents' then -- Probably better to leave this undocumented
		ns:event_toggle()
	elseif args[1] == 'c' or args[1] == 'char' then
		ns.charfavs_slash_toggle()
	elseif (args[1] == 'p' or args[1] == 'prev') and tonumber(args[2]) then
		ns.set_num_recents(args[2])
	elseif args[1] == 'p' or args[1] == 'prev' then
		ns.previous_pet()
	elseif args[1] == 's' or args[1] == 'status' then
		ns.status_display(true, true)
	elseif tonumber(args[1]) then
		ns:timer_slash_cmd(args[1])
	elseif args[1] == 'sr' then
		ns.dr_summoning_toggle()
	elseif args[1] == 't' or args[1] == 'target' then
		ns.summon_targetpet()
	elseif args[1] == 'h' or args[1] == 'help' then
		ns.help_display(true)
	elseif args[1] == nil then
		ns.help_display(false)
		ns.status_display(false, true)
	else
		chat_user_notification(format('%sInvalid command or arguments. Enter %s/pw help %sfor a list of commands.', CO.bw, CO.c, CO.bw))
	end
end

--[[---------------------------------------------------------------------------
Toggles, Commands
---------------------------------------------------------------------------]]--

function ns:dismiss_and_disable()
	local actpet = C_PetJournal_GetSummonedPetGUID()
	if actpet then
		C_PetJournal.SummonPetByGUID(actpet)
	end
	ns.db.autoEnabled = false
	ns.events:unregister_pw_events()
	chat_user_notification(format('%sPet dismissed and auto-summoning %s.', CO.bn, ns.db.autoEnabled and 'enabled' or 'disabled'))
end

function ns.verbosity_full()
	ns.db.verbosityLevel = 3
	chat_user_notification(CO.bn .. 'Verbosity: full (3).')
end

function ns.verbosity_medium()
	ns.db.verbosityLevel = 2
	chat_user_notification(CO.bn .. 'Verbosity: medium (2).')
end

function ns.verbosity_silent()
	ns.db.verbosityLevel = 1
	chat_user_notification(CO.bn .. 'Verbosity: silent (1).')
end

function ns.verbosity_mute()
	ns.db.verbosityLevel = 0
	chat_user_notification(CO.bn .. 'Verbosity: mute (0).')
end

function ns:auto_toggle()
	if ns.db.autoEnabled then
		ns.db.autoEnabled = false
		ns.events:unregister_pw_events()
	else
		ns.db.autoEnabled = true
		ns.events:register_pw_events()
		ns.autoaction()
	end
	chat_user_notification(format('%sPet auto-summoning %s.', CO.bn, ns.db.autoEnabled and 'enabled' or 'disabled'))
end

function ns:event_toggle()
	ns.db.eventAlt = not ns.db.eventAlt
	if ns.db.autoEnabled then
		ns.events:unregister_summon_events()
		ns.events:register_summon_events()
	end
	chat_user_notification(format('%s%s %s.', CO.bn, ns.db.eventAlt and 'Alternative event(s)' or 'Default event (PLAYER_STARTED_MOVING)', ns.db.autoEnabled and 'registered' or 'selected. Note that auto-summoning is currently disabled; event(s) will be registered when you enable auto-summoning (' .. CO.c .. '/pw a' .. CO.bn .. ')'))
end

-- function ns:favs_toggle_OLD()
-- 	ns.db.favsOnly = not ns.db.favsOnly
-- 	ns.pool_initialized, ns.pet_verified = false, false
-- 	if ns.db.autoEnabled then ns:new_pet() end
-- 	chat_user_notification(format('%sPet pool: %s%s.', CO.bn, ns.db.favsOnly and 'favorites' or 'all pets', ns.db.favsOnly and ns.dbc.charFavsEnabled and ' (char-specific)' or ns.db.favsOnly and ' (global)' or ''))
-- end

function ns:favs_toggle(arg2)
	if arg2 then
		arg2 = tonumber(arg2)
		if not arg2 or arg2 < 0 or arg2 > 1 then
			chat_user_notification(format('%sThe optional second argument must be a number from %s0|r to %s1|r. For example: %s0|r, %s0.2|r, %s0.45|r, %s0.618|r, %s1|r.', CO.bn, CO.c, CO.c, CO.c, CO.c, CO.c, CO.c, CO.c))
			return
		end
		ns.db.favsProbability = arg2
		ns.db.favsProbability_reset_by_pw = false
		if arg2 < 1 then
			chat_user_notification(format('%sFavorites probability in All Pets mode set to %s%s|r. Switched to All Pets mode.', CO.bn, CO.k, arg2))
		else
			chat_user_notification(format('%sFavorites probability in All Pets mode set to %sNo Special Treatment|r. Switched to All Pets mode.', CO.bn, CO.k))
		end
		ns.db.favsOnly = false
	else
		ns.db.favsOnly = not ns.db.favsOnly
		ns.db.favsOnly_reset_by_pw = false
		chat_user_notification(format('%sPet pool: %s%s.', CO.bn, ns.db.favsOnly and 'Favorites' or 'All Pets', ns.db.favsOnly and ns.dbc.charFavsEnabled and ' (char-specific)' or ns.db.favsOnly and ' (global)' or ''))
	end
	ns.pool_initialized, ns.pet_verified = false, false
	if ns.db.autoEnabled then ns:new_pet() end
end

function ns.charfavs_slash_toggle() -- for slash command only
	ns.dbc.charFavsEnabled = not ns.dbc.charFavsEnabled
	ns.pool_initialized, ns.pet_verified = false, false
	--[[ Since we are changing from one saved-pet table to another, we prefer to
	restore the pet from the new list, rather than doing new_pet like in the favs_toggle. ]]
	if ns.db.autoEnabled then
		ns.transitioncheck()
	else -- Needed for a correct display of char/normal favs in the PJ
		ns:cfavs_update()
	end
	if PetWalkerCharFavsCheckbox then PetWalkerCharFavsCheckbox:SetChecked(ns.dbc.charFavsEnabled) end
	chat_user_notification(format('%sCharacter-specific favorites %s for %s%s.', CO.bn, ns.dbc.charFavsEnabled and 'enabled' or 'disabled', CO.e, CHAR_NAME))
end

function ns.dr_summoning_toggle()
	ns.db.drSummoning = not ns.db.drSummoning
	chat_user_notification(format('%sSummoning while mounted for Skyriding %s.', CO.bn, ns.db.drSummoning and 'enabled' or 'disabled'))
end

function ns.debugmode_toggle() -- for slash command only
	ns.db.debugMode = not ns.db.debugMode
	chat_user_notification(format('%sDebug mode %s.', CO.bn, ns.db.debugMode and 'enabled' or 'disabled'))
end

local function is_acceptable_timervalue(v)
	return (v >= 1 and v <= 1440 or v == 0)
end

function ns:timer_slash_cmd(value)
	value = tonumber(value)
	if is_acceptable_timervalue(value) or ns.db.debugMode then
		ns.db.newPetTimer = value * 60
		ns.db.newPetTimer_reset_by_pw = false
		chat_user_notification(format('%s%s.',CO.bn, ns.db.newPetTimer == 0 and 'Summon timer disabled' or 'Summoning a new pet every ' .. ns.db.newPetTimer/60 .. ' minutes'))
	else
		chat_user_notification(format('%sNot a valid timer value. Enter a number from %s1%1$s to %2$s1440%1$s for a timer in minutes, or %2$s0%1$s (zero) to %3$sdisable%1$s the timer. \nExamples: %2$s/pw 20%1$s will summon a new pet every 20 minutes, %2$s/pw 0%1$s disables the timer. Note that there is a space between "/pw" and the number.', CO.bw, CO.c, CO.k))
	end
end

function ns.set_num_recents(num)
	num = max(min(floor(num), MAX_NUM_RECENTS), 1)
	ns.db.numRecents = num + 1 -- "current" is idx 1
	for _, v in ipairs({ ns.db.recentPets, ns.dbc.recentPets }) do
		while #v > ns.db.numRecents do
			table.remove(v)
		end
	end
	chat_user_notification(
		format('%sPrevious Pets history set to %s.', CO.bn, ns.db.numRecents - 1)
	)
end

-- Used for info print
function ns:list_charfavs()
	local favlinks, count, name = {}, 0, nil
	for id, _ in pairs(ns.dbc.charFavs) do
		count = count + 1
		name = C_PetJournal_GetBattlePetLink(id)
		table.insert(favlinks, name)
	end
	local favlinks_text = table.concat(favlinks, ' ')
	return CO.e .. CHAR_NAME .. CO.bn .. ' has ' .. CO.e .. count .. CO.bn ..
	' character-specific favorite pet' .. (count > 1 and 's:\n' or count > 0 and ':\n' or 's.') .. favlinks_text
end


--[[---------------------------------------------------------------------------
	For the bindings.xml
---------------------------------------------------------------------------]]--

-- BINDING_HEADER_PETWALKER = "PetWalker  "
BINDING_NAME_PETWALKER_TOGGLE_AUTO = 'Toggle Auto-Summoning'
BINDING_NAME_PETWALKER_NEW_PET = 'Summon New Pet'
BINDING_NAME_PETWALKER_PREVIOUS_PET = 'Summon Previous Pet(s)'
BINDING_NAME_PETWALKER_TARGET_PET = 'Summon Same Pet as Target'
BINDING_NAME_PETWALKER_DISMISS_PET = 'Dismiss Pet & Disable Auto-Summoning'

function PetWalker_binding_toggle_autosummon() ns:auto_toggle() end
function PetWalker_binding_new_pet() ns:new_pet(nil, true) end
function PetWalker_binding_previous_pet() ns.previous_pet() end
function PetWalker_binding_target_pet() ns:summon_targetpet() end
function PetWalker_binding_dismiss_and_disable() ns:dismiss_and_disable() end
