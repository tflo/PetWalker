-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-- Copyright (c) 2022-2026 Thomas Floeren

local MYNAME, ns = ...
local MYVERSION = C_AddOns.GetAddOnMetadata(MYNAME, 'Version')
-- API
local C_PetJournal_GetSummonedPetGUID = _G.C_PetJournal.GetSummonedPetGUID
local C_PetJournal_GetBattlePetLink = _G.C_PetJournal.GetBattlePetLink
local tostring = _G.tostring
local format = _G.format
local print = _G.print

local CLR = ns.CLR

local CHAR_NAME = UnitName 'player'
local MAX_NUM_RECENTS = 20
local MAX_VERBOSITY = 3
local MAX_TIMER = 4320

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
	Helpers
===========================================================================]]--

local BLOCK_SEP = CLR.ADDON() .. strrep('+', 42)

local function chat_user_notification(msg) -- OLD
	print(CLR.ADDON() .. MYNAME .. ":", msg)
end

local function addonprint(msg)
-- 	print(format('%s%s: %s', CLR.ADDON(), MYNAME, CLR.TXT(msg)))
	-- We dont't need a "|r" at the end of the string, right?
	print(format('%s%s: %s%s', CLR.ADDON(), MYNAME, CLR.TXT(), msg))
end
ns.addonprint = addonprint

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

function ns.msg_login()
	if ns.db.verbosityLevel < 2 then return end
	local async = false
	local ap, sp = get_link_actpet(), get_link_savedpet()
	if not ap or not sp or ap ~= sp then async = true end
	ap, sp = ap or '<None>', sp or '<None>'
	local petinfo = CLR.KEY(async and 'Current Pet: ' or 'Pet: ')
		.. CLR.STATE(ap)
		.. (async and ' | ' .. CLR.KEY('Saved pet: ') .. CLR.STATE(sp) or '')

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
			CLR.STATE(ns.db.newPetTimer ~= 0 and ns.sec_to_format(ns.db.newPetTimer, 1, true, true) or 'Off'),
			petinfo
		)
	)
end

function ns.msg_db_updated()
	if ns.db.verbosityLevel < 1 then return end
	if ns.db_global_updated then
		addonprint(format('Global database updated to version %s.', CLR.STATE(ns.db.dbVersion)))
	end
	if ns.db_char_updated then
		addonprint(format('Char database updated to version %s.', CLR.STATE(ns.dbc.dbVersion)))
	end
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

-- Having only one fav and being in favsOnly mode is 100% legit:
-- It allows the user to manually check out different pets,
-- while always being reset to his fav when the timer is due.
-- TODO: Ideally then we should reset the timer on any manual non-PW summoning, but how can
-- we reliably distinguish?
-- We could *additionally* reset the timer in save_pet(),as this is not triggered when
-- restoring. Or we could inverse the 'resettimer' parameter to 'do not reset timer', so we
-- would reset on every summoning except restore.
function ns.msg_onlyfavisactive(ap)
	if ns.db.verbosityLevel < 2 then return end
	addonprint(format('Your only eligible random pet %s is already active.', ns.id_to_link(ap)))
end

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
	addonprint(format('%sYou are in combat lockdown or flying; pet summoning aborted.', CLR.WARN()))
end

-- function ns.msg_recents_dupe_removed(idx)
-- 	if ns.db.verbosityLevel < 3 then return end
-- 	chat_user_notification(CLR.TXT() .. 'Removed a duplicate from recent pets at idx ' .. idx .. '.')
-- end

--[[---------------------------------------------------------------------------
	Summon Target Pet messages
---------------------------------------------------------------------------]]--

function ns.msg_target_summoned(link)
	if ns.db.verbosityLevel < 1 then return end
	addonprint(format('Target pet %s summoned.', link))
end

function ns.msg_target_is_same(link) -- Without web link
	if ns.db.verbosityLevel < 1 then return end
	addonprint(format('Target pet %s is the same as your currently summened pet.', link))
end

function ns.msg_target_not_in_collection(link, name)
	if ns.db.verbosityLevel < 1 then return end
	addonprint(
		format( -- Trailing space is for URL parsers (Chattynator), in case we have a "|r" at the end.
			'Unfortunately, the target pet %s is not in your collection: \nhttps://www.warcraftpets.com/search?q=%s ',
			link,
			name:gsub("[ ']", { [' '] = '%20', ["'"] = '%27' })
		)
	)
end

function ns.msg_target_is_not_battlepet()
	if ns.db.verbosityLevel < 1 then return end
	addonprint('The target is not a battle pet!')
end

function ns.msg_target_is_not_companion_battlepet(name)
	if ns.db.verbosityLevel < 1 then return end
	addonprint(
		format( -- Trailing space is for URL parsers (Chattynator), in case we have a "|r" at the end.
			'Target pet %q is a battle pet, but not a companion battle pet. (Not in your collection and unlikely to be collectible at all.): \nhttps://www.wowhead.com/search?q=%s ',
			name,
			name:gsub("[ ']", { [' '] = '%20', ["'"] = '%27' })
		)
	)
end

--[[---------------------------------------------------------------------------
	The main, success, message when a pet was summoned. Either by restore_pet or
	new_pet, or previous_pet or the transitioncheck.
---------------------------------------------------------------------------]]--

function ns.set_sum_msg_to_newpet(newpet, pool, npool)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 2
			and format(
				'Summoned %s pet from %s%s: %s.',
				npool > 1 and 'a new' or 'your only',
				curr_pool_str(true),
				pool == ns.pet_pool_favs and ' (F)' or '',
				ns.id_to_link(newpet)
			)
		or nil
end

-- Called by the restore_pet func
function ns.set_sum_msg_to_restore_pet(pet)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 3
			and format('Restored your last pet %s.', ns.id_to_link(pet))
		or nil
end

-- Called by the previous_pet func
function ns.set_sum_msg_to_previouspet(pet)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 2
			and format('Summoned your previous pet %s.', ns.id_to_link(pet))
		or nil
end

-- Called by the transitioncheck func
function ns.set_sum_msg_to_transcheck(pet)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 3
			and format('Summoned your last saved pet %s.', ns.id_to_link(pet))
		or nil
end

-- Called by the summon func
function ns.msg_pet_summon_success()
	if ns.msg_pet_summoned_content then addonprint(ns.msg_pet_summoned_content) end
end

-- Called by the summon func
function ns.msg_pet_summon_failed()
	if ns.db.verbosityLevel < 1 then return end
	addonprint(CLR.WARN() .. "You don't meet the conditions for summoning a pet right now.")
end

--[[---------------------------------------------------------------------------
Three big messages: Status, Low Pet Pool, and Help
---------------------------------------------------------------------------]]--

function ns.help_display()
	local text = {
		BLOCK_SEP,
		format( -- Header
			'%s%s Help: %s or %s supports these commands:',
			CLR.HEAD(),
			CLR.ADDON(ns.MYSHORTNAME),
			CLR.CMD('/petwalker'),
			CLR.CMD('/pw')
		),
		{ -- Toggle auto
			'%s : Toggle %s (new pet or restore); this is the %q.',
			CLR.CMD('a'),
			CLR.KEY('auto-summoning'),
			CLR.QUOTE('Main Switch'),
		},
		{ -- Dismiss & disable
			'%s : Immediately %s current pet and %s; %q.',
			CLR.CMD('d'),
			CLR.KEY('dismiss'),
			CLR.KEY('disable auto-summoning'),
			CLR.QUOTE('Emergency Off'),
		},
		{ -- Skyride-mounted
			'%s : Toggle %s also %s: %s',
			CLR.CMD('sr'),
			CLR.KEY('auto-summoning'),
			CLR.KEY('while mounted for Skyriding'),
			CLR.STATE('allowed / not allowed'),
		},
		{ -- New pet
			'%s : Summon %s from pool.',
			CLR.CMD('n'),
			CLR.KEY('new random pet'),
		},
		{ -- Pool
			'%s : Toggle %s: %s or %s.',
			CLR.CMD('f'),
			CLR.KEY('pet pool'),
			CLR.STATE('Favorites Only'),
			CLR.STATE('All Pets'),
		},
		{ -- Favorites Probability
			'%s : %s in All Pets mode: e.g., %s or %s. Zero (%s) excludes favorites, %s means ‘no special treatment for favs’ (combined pool).',
			CLR.CMD('f <0...1>'),
			CLR.KEY('Favorites Probability '),
			CLR.CMD('0.5 '),
			CLR.CMD('.5'),
			CLR.CMD('0'),
			CLR.CMD('1'),
		},
		{ -- Per-char / global favs
			'%s : Toggle %s: %s or %s.',
			CLR.CMD('c'),
			CLR.KEY('favorites'),
			CLR.STATE('Per-character'),
			CLR.STATE('Global Favorites'),
		},
		{ -- Timer
			'%s : Set %s in minutes: %s to %s (%sd), %s to %s.',
			CLR.CMD('<number>'),
			CLR.KEY('Summon Timer'),
			CLR.CMD('1'),
			CLR.CMD(MAX_TIMER),
			MAX_TIMER / 60 / 24,
			CLR.CMD('0'),
			CLR.KEY('disable'),
		},
		{ -- Previous pets
			'%s : Cycle through %s (recently summoned) %s.',
			CLR.CMD('p'),
			CLR.KEY('Previous'),
			CLR.KEY('Pets'),
		},
		{ -- Max previous
			'%s : Set %s (%s to %s).',
			CLR.CMD('p <number>'),
			CLR.KEY('number of remembered Previous Pets'),
			CLR.CMD('1'),
			CLR.CMD(MAX_NUM_RECENTS),
		},
		{ -- Verbosity
			'%s : %s: %s (only failures and warnings are printed to chat); %s for %s verbosity (new summons); %s for %s verbosity (also restored pets).',
			CLR.CMD('v'),
			CLR.KEY('Verbosity'),
			CLR.STATE('silent'),
			CLR.CMD('vv'),
			CLR.STATE('medium'),
			CLR.CMD('vvv'),
			CLR.STATE('full'),
		},
		{ -- Status
			'%s : Display current %s.',
			CLR.CMD('s'),
			CLR.KEY('status/settings'),
		},
		{ -- Help
			'%s : Show this %s text.',
			CLR.CMD('h'),
			CLR.KEY('help'),
		},
		{ -- Examples
			'%s %s enables/disables any auto-summoning, %s sets the new-pet summon timer to 20 minutes, %s sets the favorites probability in All Pets mode to 0.33 (33%%). — In Game Options > Keybindigs you can directly bind some commands.',
			CLR.ADDON('Examples:'),
			CLR.CMD('/pw a'),
			CLR.CMD('/pw 20'),
			CLR.CMD('/pw f .33'),
		},
		BLOCK_SEP,
	}
	ns.multiprint(text)
end

local function get_charfavs_for_status()
	local tab_links, count = {}, 0
	for id, _ in pairs(ns.dbc.charFavs) do
		count = count + 1
		tinsert(tab_links, C_PetJournal_GetBattlePetLink(id))
	end
	local str_links = table.concat(tab_links, ' ')
	return count, str_links
end

function ns.status_display()
	if not ns.pool_initialized then ns.initialize_pool() end
	local num_cfavs, list_cfavs = get_charfavs_for_status()
	local text = {
		BLOCK_SEP,
		format( -- Header
			'%s%s [v%s]: Status & Settings:',
			CLR.HEAD(),
			CLR.ADDON(MYNAME),
			CLR.STATE(MYVERSION)
		),
		{ -- Enabled
			'%s is %s.',
			CLR.KEY('Automatic Random-summoning / Restore'),
			ns.db.autoEnabled and CLR.STATE('enabled') or CLR.WARN('disabled'),
		},
		{ -- Timer
			'%s is %s. Next random pet in %s.',
			CLR.KEY('Summon Timer'),
			CLR.STATE(
				ns.db.newPetTimer ~= 0 and ns.sec_to_format(ns.db.newPetTimer, 2, false, false)
					or 'disabled'
			),
			CLR.EM(ns.remaining_timer_for_display()),
		},
		{ -- Skyride-mounted
			'%s is %s.',
			CLR.KEY('Automatic summoning while Skyride-mounted'),
			CLR.STATE(ns.db.drSummoning and 'allowed' or 'not allowed'),
		},
		{ -- descr
			'%s of Previous Pets: %s (1 to %s).',
			CLR.KEY('History'),
			CLR.STATE(ns.db.numRecents - 1),
			MAX_NUM_RECENTS,
		},
		{ -- Verbosity
			'%s level for messages: %s (of %s).',
			CLR.KEY('Verbosity'),
			CLR.STATE(ns.db.verbosityLevel),
			MAX_VERBOSITY,
		},
		{ -- Pool
			'%s is %s%s. Eligible pets: %s.',
			CLR.KEY('Pet Pool'),
			CLR.STATE(curr_pool_str(true)),
			not ns.db.favsOnly and ns.db.favsProbability < 1 and ' (favs prob: ' .. CLR.STATE(
				ns.db.favsProbability
			) .. ')' or '',
			CLR.EM(curr_num_pool_str()),
		},
		{ -- Per-char favs
			'%s are %s for %s.',
			CLR.KEY('Per-character Favorites'),
			CLR.STATE(ns.dbc.charFavsEnabled and 'enabled' or 'disabled'),
			CLR.EM(CHAR_NAME),
		},
		ns.db.eventAlt and format(
			'%s%s are %s for all chars.',
			CLR.WARN(),
			CLR.KEY('Alternative Events'),
			CLR.STATE('enabled')
		) or '',
		-- '\n',
		{ -- Header for char favs list
			'%s has %s char-specific favorite%s',
			CLR.EM(CHAR_NAME),
			CLR.KEY(num_cfavs),
			num_cfavs == 0 and 's.' or num_cfavs == 1 and ':' or 's:',
		},
		num_cfavs > 0 and list_cfavs,
		BLOCK_SEP,
	}

	ns.multiprint(text)
end

-- TODO: different msgs for the situations:
-- No favs
-- No non-favs bc all pets are favorites
-- One of the two pools is empty (not strictly a failure but favsProbability set to 1)
-- TODO: add db.flags when favsProbability or favsOnly has been force-changed, so we
-- can show this in the status text.
function ns.msg_force_changed_pool()
	if ns.db.verbosityLevel < 1 then return end
	addonprint(
		format(
			"%sYou don't have any summonable pets in your active pool, or in one of your active pools (Favorites/NonFavorites). I've set your pet pool to %s and will try to re-initialize the pool.",
			CLR.WARN(),
			CLR.KEY('All Pets (f 1)')
		)
	)
end

-- TODO: this needs a rework
function ns.msg_low_petpool(nPool)
	if ns.db.verbosityLevel < 0 then return end
	local R = CLR.WARN()
	local poolstr = ns.db.favsOnly and 'Favs' or ns.db.favsProbability == 1 and 'All Pets' or ns.db.favsProbability == 0 and 'NonFavs' or 'Favs+NonFavs'
	local content = {
		('Your current pet pool (' .. poolstr .. ') contains ' .. nPool < 1 and CLR.KEY() .. '0 (zero) ' ..R.. 'pets ' or R.. 'only ' ..CLR.KEY() .. '1 ' ..R.. 'pet '),
		'eligible as random summon!',
		'\nYou should either ' .. (ns.db.favsOnly and 'flag more pets as favorite, or set the random pool to ' .. CLR.STATE() ..'All Pets' or 'collect more pets'), ', or set the random-summon timer to ', CLR.STATE() .. '0', '.',
		'\nAlso check your ', CLR.KEY() .. 'Filter ', 'settings in the ', CLR.KEY() .. 'Blizz Pet Journal ', '(not in Rematch!), as they are affecting the pool of available pets!',
		'\nSome pets are ', CLR.KEY() .. 'faction-restricted ', 'and cannot be summoned on the other faction, so they may not be eligible on your current toon.',
		'\nPlease note that certain pets are intentionally ', CLR.KEY() .. 'excluded ', 'from random summoning, to not break their usability (for example ',
		CLR.QUOTE() .. 'Guild Herald', '). ',
		((ns.dbc.charFavsEnabled and ns.db.favsOnly) and '\nYou have set ' .. CLR.EM() .. CHAR_NAME ..R.. ' to use ' .. CLR.STATE() .. 'char-specific favorite ' ..R.. 'pets. Maybe switching to ' .. CLR.STATE() .. 'global favorites ' ..R.. '(' .. CLR.CMD() .. '/pw c' ..R.. ') will help.' or ''),
	}
	local content = table.concat(content, R)
	chat_user_notification(content)
end

--[[===========================================================================
	Slash UI
===========================================================================]]--

local CMD1, CMD2 = '/petwalker', '/pw'

local function slashfunc(msg)
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
		ns.status_display()
	elseif tonumber(args[1]) then
		ns:timer_slash_cmd(args[1])
	elseif args[1] == 'sr' then
		ns.dr_summoning_toggle()
	elseif args[1] == 't' or args[1] == 'target' then
		ns.summon_targetpet()
	elseif args[1] == 'h' or args[1] == 'help' then
		ns.help_display()
	elseif args[1] == nil then
		ns.help_display()
		ns.status_display()
	else
		addonprint(
			format(
				'%sInvalid command or arguments. Enter %s for a list of commands.',
				CLR.WARN(),
				CLR.CMD('/pw help')
			)
		)
	end
end


SLASH_PetWalker1, SLASH_PetWalker2 = CMD1, CMD2
SlashCmdList.PetWalker = slashfunc

function ns.protect_slash_pw()
	ns.protect_slashcommand(CMD2, 'PetWalker', slashfunc)
end

ns.protect_slash_pw()

--[[---------------------------------------------------------------------------
	Commands
---------------------------------------------------------------------------]]--

function ns:dismiss_and_disable()
	local actpet = C_PetJournal_GetSummonedPetGUID()
	if actpet then C_PetJournal.SummonPetByGUID(actpet) end
	ns.db.autoEnabled = false
	ns.events:unregister_pw_events()
	addonprint(
		format(
			'Pet dismissed and auto-summoning %s.',
			ns.db.autoEnabled and 'enabled' or 'disabled'
		)
	)
end

function ns.verbosity_full()
	ns.db.verbosityLevel = 3
	addonprint('Verbosity: full (3).')
end

function ns.verbosity_medium()
	ns.db.verbosityLevel = 2
	addonprint('Verbosity: medium (2).')
end

function ns.verbosity_silent()
	ns.db.verbosityLevel = 1
	addonprint('Verbosity: silent (1).')
end

function ns.verbosity_mute()
	ns.db.verbosityLevel = 0
	addonprint('Verbosity: mute (0).')
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
	addonprint(format('Pet auto-summoning %s.', ns.db.autoEnabled and 'enabled' or 'disabled'))
end

function ns:event_toggle()
	ns.db.eventAlt = not ns.db.eventAlt
	if ns.db.autoEnabled then
		ns.events:unregister_summon_events()
		ns.events:register_summon_events()
	end
	addonprint(
		format(
			'%s %s.',
			ns.db.eventAlt and 'Alternative event(s)' or 'Default event (PLAYER_STARTED_MOVING)',
			ns.db.autoEnabled and 'registered'
				or 'selected. Note that auto-summoning is currently disabled; event(s) will be registered when you enable auto-summoning ('
					.. CLR.CMD('/pw a')
					.. ')'
		)
	)
end

function ns:favs_toggle(arg2)
	if arg2 then
		arg2 = tonumber(arg2)
		if not arg2 or arg2 < 0 or arg2 > 1 then
			addonprint(
				format(
					'The optional second argument must be a number from %s to %s. For example: %s, %s, %s, %s, %s. The zero before the decimal point is optional (%s).',
					CLR.CMD('0'),
					CLR.CMD('1'),
					CLR.CMD('0'),
					CLR.CMD('0.2'),
					CLR.CMD('0.45'),
					CLR.CMD('0.618'),
					CLR.CMD('1'),
					CLR.CMD('.5')
				)
			)
			return
		end
		ns.db.favsProbability = arg2
		ns.db.favsProbability_reset_by_pw = false
		if arg2 < 1 then
			addonprint(
				format(
					'Favorites probability in All Pets mode set to %s. All Pets mode activated.',
					CLR.KEY(arg2)
				)
			)
		else
			addonprint(
				format(
					'Favorites in All Pets mode set to %s. All Pets mode activated.',
					CLR.QUOTE('No Special Treatment')
				)
			)
		end
		ns.db.favsOnly = false
	else
		ns.db.favsOnly = not ns.db.favsOnly
		ns.db.favsOnly_reset_by_pw = false
		addonprint(
			format(
				'Pet pool: %s%s.',
				CLR.KEY(ns.db.favsOnly and 'Favorites' or 'All Pets'),
				ns.db.favsOnly and ns.dbc.charFavsEnabled and ' (char-specific)'
					or ns.db.favsOnly and ' (global)'
					or ''
			)
		)
	end
	ns.pool_initialized, ns.pet_verified = false, false
	if ns.db.autoEnabled then ns:new_pet() end
end

function ns.charfavs_slash_toggle() -- for slash command only
	ns.dbc.charFavsEnabled = not ns.dbc.charFavsEnabled
	ns.pool_initialized, ns.pet_verified = false, false
	-- Pre-3.0
-- 	if ns.db.autoEnabled then
-- 		ns.transitioncheck()
-- 	else -- Needed for a correct display of char/normal favs in the PJ
-- 		ns:cfavs_update()
-- 	end
	if ns.db.autoEnabled then
		-- TODO: is this change benificial?
		-- I tend to think that we should auto-switch to favsOnly when char favs are activated
		ns:cfavs_update()
		ns.initialize_pool()
	else -- Needed for a correct display of char/normal favs in the PJ
		ns:cfavs_update()
	end
	if PetWalkerCharFavsCheckbox then
		PetWalkerCharFavsCheckbox:SetChecked(ns.dbc.charFavsEnabled)
	end
	addonprint(
		format(
			'Character-specific favorites %s for %s.',
			CLR.KEY(ns.dbc.charFavsEnabled and 'enabled' or 'disabled'),
			CLR.EM(CHAR_NAME)
		)
	)
end

function ns.dr_summoning_toggle()
	ns.db.drSummoning = not ns.db.drSummoning
	addonprint(
		format(
			'Summoning while mounted for Skyriding %s.',
			CLR.KEY(ns.db.drSummoning and 'enabled' or 'disabled')
		)
	)
end

function ns.debugmode_toggle() -- for slash command only
	ns.db.debugMode = not ns.db.debugMode
	addonprint(
		format('Debug mode %s.', CLR.KEY(ns.db.debugMode and 'enabled' or 'disabled'))
	)
end

local function is_acceptable_timervalue(v)
	return (v >= 1 and v <= 60*60*24*3 or v == 0)
end

function ns:timer_slash_cmd(value)
	value = tonumber(value)
	if is_acceptable_timervalue(value) or ns.db.debugMode then
		ns.db.newPetTimer = value * 60
		ns.db.newPetTimer_reset_by_pw = false
		addonprint(
			format(
				'%s.',
				ns.db.newPetTimer == 0 and 'Summon timer disabled'
					or 'A new pet for you every ' .. ns.sec_to_format(ns.db.newPetTimer, 3, false, false)
			)
		)
	else
		addonprint(
			format(
				'%sNot a valid timer value. Enter a number of minutes from %s to %s (3 days), or %s (zero) to %s the timer. \nExamples: %s will summon a new pet every 20 minutes, %s disables the timer. Note the space between "/pw" and the number.',
				CLR.WARN(),
				CLR.CMD('1'),
				CLR.CMD('4320'),
				CLR.CMD('0'),
				CLR.KEY('disable'),
				CLR.CMD('/pw 20'),
				CLR.CMD('/pw 0'),
				CLR.KEY()
			)
		)
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
	addonprint(
		format('Previous Pets history set to %s.', ns.db.numRecents - 1)
	)
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
