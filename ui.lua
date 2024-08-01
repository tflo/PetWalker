local addon_name, ns = ...
local _

-- API references
local C_PetJournalGetSummonedPetGUID = _G.C_PetJournal.GetSummonedPetGUID
local C_PetJournalGetBattlePetLink = _G.C_PetJournal.GetBattlePetLink
local UnitName = _G.UnitName
local GetAddOnMetadata = _G.C_AddOns.GetAddOnMetadata




local this_char = UnitName 'player'


local function get_link_actpet()
	local p = C_PetJournalGetSummonedPetGUID()
	p = p and C_PetJournalGetBattlePetLink(p)
	return p
end

local function get_link_savedpet()
	local p = ns.dbc.charFavsEnabled and ns.dbc.currentPet or ns.db.currentPet
	p = p and C_PetJournalGetBattlePetLink(p)
	return p
end

--[[===========================================================================
Colors
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
	local prefix = '|r|cff'
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
Messages
===========================================================================]]--

local sep = '-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --'

local function chat_user_notification(msg)
	print(CO.an .. addon_name .. ":", msg)
end

local function chat_user_notification_block(msg)
	print('\n' .. CO.an .. sep .. '\n' .. addon_name .. ':', msg, '\n' .. CO.an .. sep , '\n ')
end

local function chat_user_notification_large(first, second, third, last)
	print('\n' .. CO.an .. sep .. '\n' .. addon_name .. ':', first)
	if second then print(second) end
	if third then print(third) end
	print(last, '\n' .. CO.an .. sep)
end

-- Login msg
function ns.msg_login()
	if ns.db.verbosityLevel < 2 then return end
	local sep = CO.bn .. ' | '
	local petinfo
	if ns.db.verbosityLevel > 2 then
		local async = false
		local ap, sp = get_link_actpet(), get_link_savedpet()
		if not ap or not sp or ap ~= sp then async = true end
		ap, sp = ap or 'None', sp or 'None'
		petinfo = CO.k .. (async and 'Current Pet: ' or 'Pet: ') .. CO.s .. ap .. (async and sep .. CO.k .. 'Saved pet: ' .. CO.s .. sp or '')
	end
	chat_user_notification(table.concat({CO.k .. 'Auto: ' .. CO.s .. (ns.db.autoEnabled and 'On' or CO.bw .. 'Off'), CO.k .. 'Pet pool: ' .. CO.s .. (ns.db.favsOnly and ns.dbc.charFavsEnabled and 'Char favs' or ns.db.favsOnly and 'Global favs' or 'All pets'), CO.k .. 'Timer: ' .. CO.s .. (ns.db.newPetTimer > 0 and ns.db.newPetTimer/60 .. ' min' or 'Off'), petinfo}, sep))
end

-- TODO: Do we need a warning at 1 selectable pet? Or should this be considered a valid use-case? (User manually summons a pet from Journal, but wants to get back his (only) fav pet when the timer is due.)
-- function ns.msg_low_petpool(nPool)
-- 	chat_user_notification(CO.bw .. ": " .. (nPool < 1 and "0 (zero) pets" or "Only 1 pet") .. " eligible as random summon! You should either " .. (ns.db.favsOnly and "flag more pets as favorite, or set the ramdom pool to 'All Pets'" or "collect more pets") .. ", or set the random-summon timer to '0'. Please note that certain pets are excluded from random summoning, to not break their usability (for example Guild Herald)." .. ((ns.dbc.charFavsEnabled and ns.db.favsOnly) and "\nNote that you have set this char to use char-specific favorite pets. Maybe switching to global favorites ('/pw c') will help." or ""))
-- end

function ns.msg_no_saved_pet()
	if ns.db.verbosityLevel < 0 then return end
	chat_user_notification(CO.bw .. 'No Current Pet has been saved yet' .. (ns.dbc.charFavsEnabled and ' for ' .. CO.e .. this_char or '') .. CO.bw .. ' --> Summoning a new pet.')
end

function ns.msg_no_previous_pet()
	if ns.db.verbosityLevel < 0 then return end
	chat_user_notification(CO.bw .. 'No Previous Pet has been saved yet' .. (ns.dbc.charFavsEnabled and ' for ' .. CO.e .. this_char or '') .. CO.bw .. '.')
end

function ns.msg_onlyfavisactive(ap)
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(CO.bn .. 'Your only eligible random pet ' .. (ns.id_to_link(ap) or '???') .. ' is already active.')
end

function ns.msg_removed_invalid_id(counter)
	if ns.db.verbosityLevel < 2 then return end
	chat_user_notification(format('%s%s orphaned pet ID%s %s been removed from the char favorites.', CO.bn, counter, counter > 1 and 's' or '', counter > 1 and 'have' or 'has'))
end

function ns.msg_saved_pet_unsummonable(reason, number)
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(format('%sThe saved Current Pet is not summonable. Reason: %s(%s) %s%s\n--> Checking other saved pets (char/global pet, previous pet, etc.) now.', CO.bw, CO.e, number or '?', reason or 'unknown', CO.bw))
end

function ns.msg_previous_pet_unsummonable()
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(CO.bw .. 'The saved Previous Pet or other saved pets are not summonable either.\n--> Saving the currently active pet or summoning a new one.')
end


-- Summon Target Pet messages

function ns.msg_target_summoned(link)
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(format('%sTarget pet %s summoned.', CO.bn, link))
end

function ns.msg_target_is_same(link) -- Without web link
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(format('%sTarget pet %s is the same pet as you currently have summened.', CO.bn, link))
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
function ns.set_sum_msg_to_newpet(ap, np, n)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 2 and format('%sSummoned %s pet %s.', CO.bn, n > 1 and 'a new random' or 'your only eligible random', ns.id_to_link(np)) or nil
end

-- Called by the restore_pet func
function ns.set_sum_msg_to_restore_pet(pet)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 3 and format('%sRestored your last pet %s.', CO.bn, ns.id_to_link(pet) or '???') or nil
end

-- Called by the previous_pet func
function ns.set_sum_msg_to_previouspet(pet)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 2 and format('%sSummoned your previous pet %s.', CO.bn, ns.id_to_link(pet) or '???') or nil
end

-- Called by the transitioncheck func
function ns.set_sum_msg_to_transcheck(pet)
	ns.msg_pet_summoned_content = ns.db.verbosityLevel >= 3 and format('%sSummoned your last saved pet %s.', CO.bn, ns.id_to_link(pet) or '???') or nil
end

-- Called by the safesummon func
function ns.msg_pet_summon_success()
	if ns.msg_pet_summoned_content then
		chat_user_notification(ns.msg_pet_summoned_content)
	end
end

-- Called by the safesummon func
function ns.msg_pet_summon_failed()
	if ns.db.verbosityLevel < 1 then return end
	chat_user_notification(CO.bw .. "You don't meet the conditions for summoning a pet right now.")
end

-- If we block a command bc auto-summoning is disabled (aka events unregistered). Currently not used.
-- function ns.MsgAutoIsDisabled()
-- 	chat_user_notification(format("%sAuto-summoning must be enabled for this! %s(%s/pw a%2$s)", CO.bw, CO.bn, CO.c))
-- end


--[[---------------------------------------------------------------------------
Three big messages: Status, Low Pet Pool, and Help
---------------------------------------------------------------------------]]--

function ns.help_display()

	local header = {
		CO.bn .. 'Help: ',
		CO.c .. '\n/pw ', 'or ', CO.c .. '/petwalker ', 'supports these commands: ',
	}

	local body = {
		CO.c .. '\nd', ': ', CO.k .. 'Dismiss ', 'current pet and ', CO.k .. 'disable auto-summoning ', '(new pet / restore).',
		CO.c .. '\na', ': ', 'Toggle ', CO.k .. 'auto-summoning ', '(new pet / restore).',
		CO.c .. '\nsr', ': ', 'Toggle ', CO.k .. 'auto-summoning ', 'also ', CO.k .. 'while mounted for Skyriding: ', CO.s .. 'allowed / not allowed', '.',
		CO.c .. '\nn', ': ', 'Summon ', CO.k .. 'new pet ', 'from pool.',
		CO.c .. '\nf', ': ', 'Toggle ', CO.k .. 'pet pool: ', CO.s .. 'Favorites Only', ', or ', CO.s .. 'All Pets', '.',
		CO.c .. '\nc', ': ', 'Toggle ', CO.k .. 'favorites: ', CO.s .. 'Per-character', ', or ', CO.s .. 'Global Favorites', '.',
		CO.c .. '\n<number>', ': ', 'Set ', CO.k .. 'Summon Timer ', 'in minutes (', CO.c .. '1 ', 'to ', CO.c .. '1440', '; ', CO.c .. '0 ', 'to ', CO.k .. 'disable', ').',
		CO.c .. '\np', ': ', 'Summon ', CO.k .. 'previous pet ', '.',
		CO.c .. '\nv', ': ', CO.k .. 'Verbosity: ', CO.s .. 'silent ', '(only failures and warnings are printed to chat); ', CO.c .. 'vv ', 'for ', CO.s .. 'medium ', CO.k .. 'verbosity ', '(new summons); ', CO.c .. 'vvv ', 'for ', CO.s .. 'full ', CO.k .. 'verbosity ', '(also restored pets).',
		CO.c .. '\ns', ': ', 'Display current ', CO.k .. 'status/settings.',
		CO.c .. '\nh', ': ', 'This help text.',
	}

	local footer = {
		CO.bn .. '\nExamples: ', CO.c .. '/pw a', ' disables auto-summon/restore, or enables it if disabled. ', CO.c .. '/pw 20', ' sets the new-pet summon timer to 20 minutes.',
		'\nIn Options > Keybindigs you can directly bind some commands.',
	}

	local header_text = table.concat(header, CO.bn)
	local body_text = table.concat(body, CO.bn)
	local footer_text = table.concat(footer, CO.bn)

	chat_user_notification_large(header_text, body_text, nil, footer_text)
end


function ns.status_display()
	if not ns.pool_initialized then ns.initialize_pool() end
	local header = {
		CO.bn .. '[v', GetAddOnMetadata(addon_name, 'Version'), '] Status & Settings:',
	}
	local body = {
		CO.k ..'\nAutomatic Random-summoning / Restore ', 'is ', CO.s .. (ns.db.autoEnabled and 'enabled' or CO.bw .. 'disabled'), '.',
		CO.k .. '\nSummon Timer ', 'is ', CO.s .. (ns.db.newPetTimer > 0 and (ns.db.newPetTimer/60) .. CO.bn .. ' minutes' or 'disabled'), '. Next random pet in ', CO.e .. ns.remaining_timer_for_display(), '.',
		CO.k ..'\nAutomatic summoning while mounted for Skyriding ', 'is ', CO.s .. (ns.db.drSummoning and 'allowed' or 'not allowed'), '.',
		CO.k .. '\nVerbosity ', 'level of messages: ', CO.s .. ns.db.verbosityLevel, ' (of 3).',
		CO.k .. '\nPet Pool ', 'is set to ', CO.s .. (ns.db.favsOnly and 'Favorites Only' or 'All Pets'), '. Eligible pets: ', CO.e .. #ns.pet_pool, '.',
		CO.k .. '\nPer-character Favorites ', 'are ', CO.s .. (ns.dbc.charFavsEnabled and 'enabled' or 'disabled'), ' for ', CO.e .. this_char, '.',
	}
	-- Separating this bc it might be a longish list
	local charfavlist = {
		'\n', ns:list_charfavs(),
	}

	local header_text = table.concat(header, CO.bn)
	local body_text = table.concat(body, CO.bn)
	local charfavlist_text = table.concat(charfavlist, CO.bn)
	local extra_settings = (ns.db.eventAlt and table.concat({CO.k ..'\nAlternative Events ', 'are ', CO.s .. 'enabled ', 'for all chars.'}, CO.bn) or nil)

	chat_user_notification_large(header_text, body_text, extra_settings, charfavlist_text)
end


function ns.msg_low_petpool(nPool)
	if ns.db.verbosityLevel < 0 then return end
	local R = CO.bw
	local content = {
		(nPool < 1 and CO.k .. '0 (zero) ' ..R.. ' pets ' or R.. 'Only ' ..CO.k .. '1 ' ..R.. 'pet '),
		'eligible as random summon!',
		'\nYou should either ' .. (ns.db.favsOnly and 'flag more pets as favorite, or set the ramdom pool to ' .. CO.s ..'All Pets' or 'collect more pets'), ', or set the random-summon timer to ', CO.s .. '0', '.',
		'\nAlso check your ', CO.k .. 'Filter ', 'settings in the ', CO.k .. 'Blizz Pet Journal ', '(not in Rematch!), as they are affecting the pool of available pets!',
		'\nSome pets are ', CO.k .. 'faction-restricted ', 'and cannot be summoned on the other faction, so they may not be eligible on your current toon.',
		'\nPlease note that certain pets are intentionally ', CO.k .. 'excluded ', 'from random summoning, to not break their usability (for example ',
		CO.q .. 'Guild Herald', '). ',
		((ns.dbc.charFavsEnabled and ns.db.favsOnly) and '\nYou have set ' .. CO.e .. this_char ..R.. ' to use ' .. CO.s .. 'char-specific favorite ' ..R.. 'pets. Maybe switching to ' .. CO.s .. 'global favorites ' ..R.. '(' .. CO.c .. '/pw c' ..R.. ') will help.' or ''),
	}
	local content = table.concat(content, R)
	chat_user_notification(content)
end


--[[===========================================================================
Slash UI
===========================================================================]]--

SLASH_PetWalker1, SLASH_PetWalker2 = '/pw', '/petwalker'
function SlashCmdList.PetWalker(cmd)
	if cmd == 'd' or cmd == 'dis' then
		ns:dismiss_and_disable()
	elseif cmd == 'dd' or cmd == 'debd' then
		ns:debug_display()
	elseif cmd == 'dm' or cmd == 'debm' then
		ns.debugmode_toggle()
	elseif cmd == 'vvv' then
		ns.verbosity_full()
	elseif cmd == 'vv' then
		ns.verbosity_medium()
	elseif cmd == 'v' then
		ns.verbosity_silent()
	elseif cmd == 'v0' then
		ns.verbosity_mute()
	elseif cmd == 'a' or cmd == 'auto' then
		ns:auto_toggle()
	elseif cmd == 'n' or cmd == 'new' then
		local actpet = C_PetJournalGetSummonedPetGUID()
		ns:new_pet()
	elseif cmd == 'f' or cmd == 'fav' then
		ns:favs_toggle()
	elseif cmd == 'aev' or cmd == 'altevents' then -- Probably better to leave this undocumented
		ns:event_toggle()
	elseif cmd == 'c' or cmd == 'char' then
		ns.charfavs_slash_toggle()
	elseif cmd == 'p' or cmd == 'prev' then
		ns.previous_pet()
	elseif cmd == 's' or cmd == 'status' then
		ns.status_display()
	elseif tonumber(cmd) then
		ns:timer_slash_cmd(cmd)
	elseif cmd == 'sr' then
		ns.dr_summoning_toggle()
	elseif cmd == 't' or cmd == 'target' then
		ns.summon_targetpet()
	elseif cmd == 'h' or cmd == 'help' then
		ns.help_display()
	elseif cmd == '' then
		ns.help_display()
		ns.status_display()
	else
		chat_user_notification(format('%sInvalid command or arguments. Enter %s/pw help %sfor a list of commands.', CO.bw, CO.c, CO.bw))
	end
end

--[[---------------------------------------------------------------------------
Toggles, Commands
---------------------------------------------------------------------------]]--

function ns:dismiss_and_disable()
	local actpet = C_PetJournalGetSummonedPetGUID()
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

function ns:favs_toggle()
	ns.db.favsOnly = not ns.db.favsOnly
	ns.pool_initialized, ns.pet_verified = false, false
	if ns.db.autoEnabled then ns:new_pet() end
	chat_user_notification(format('%sPet pool: %s%s.', CO.bn, ns.db.favsOnly and 'favorites' or 'all pets', ns.db.favsOnly and ns.dbc.charFavsEnabled and ' (char-specific)' or ns.db.favsOnly and ' (global)' or ''))
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
	chat_user_notification(format('%sCharacter-specific favorites %s for %s%s.', CO.bn, ns.dbc.charFavsEnabled and 'enabled' or 'disabled', CO.e, this_char))
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
		chat_user_notification(format('%s%s.',CO.bn, ns.db.newPetTimer == 0 and 'Summon timer disabled' or 'Summoning a new pet every ' .. ns.db.newPetTimer/60 .. ' minutes'))
	else
		chat_user_notification(format('%sNot a valid timer value. Enter a number from %s1%1$s to %2$s1440%1$s for a timer in minutes, or %2$s0%1$s (zero) to %3$sdisable%1$s the timer. \nExamples: %2$s/pw 20%1$s will summon a new pet every 20 minutes, %2$s/pw 0%1$s disables the timer. Note that there is a space between "/pw" and the number.', CO.bw, CO.c, CO.k))
	end
end

-- Used for info print
function ns:list_charfavs()
	local favlinks, count, name = {}, 0, nil
	for id, _ in pairs(ns.dbc.charFavs) do
		count = count + 1
		name = C_PetJournalGetBattlePetLink(id)
		table.insert(favlinks, name)
	end
	local favlinks_text = table.concat(favlinks, ' ')
	return CO.e .. this_char .. CO.bn .. ' has ' .. CO.e .. count .. CO.bn ..
	' character-specific favorite pet' .. (count > 1 and 's:\n' or count > 0 and ':\n' or 's.') .. favlinks_text
end


--[[ License ===================================================================

	Copyright © 2022-2023 Thomas Floeren

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
