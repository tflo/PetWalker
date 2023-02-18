local addonName, ns = ...
local _

local thisChar = UnitName("player")

--[[===========================================================================
Colors
===========================================================================]]--

local colSchemeGreen = {
	basetext = {
		notification = '8FBC8F',
		warning = 'FA8072',
	},
	element = {
		addonname = '7CFC00',
		quote = '808000',
		emphasis = 'ADFF2F',
		keyword = '00FA9A', -- TODO: heading? (see below)
		state = '32CD32',
		command = 'FF00FF',
	}
}

local function SetColors(scheme)
	local prefix = '|r|cff'
	local colorstrings = {
		bn = prefix .. scheme.basetext.notification,
		bw = prefix .. scheme.basetext.warning,
		an = prefix .. scheme.element.addonname,
		q = prefix .. scheme.element.quote,
		e = prefix .. scheme.element.emphasis,
		k = prefix .. (scheme.element.heading or scheme.element.emphasis),
		s = prefix .. (scheme.element.state or scheme.element.emphasis),
		c = prefix .. (scheme.element.command or scheme.element.emphasis),
	}
	return colorstrings
end

local CO = SetColors(colSchemeGreen)

--[[===========================================================================
Messages
===========================================================================]]--

local sep = "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --"

local function ChatUserNotification(msg)
	print(CO.an .. addonName .. ":", msg)
end

local function ChatUserNotificationBlock(msg)
	print("\n" .. CO.an .. sep .. "\n" .. addonName .. ":", msg, "\n" .. CO.an .. sep , "\n ")
end

local function ChatUserNotificationLarge(first, second, third, last)
	print("\n" .. CO.an .. sep .. "\n" .. addonName .. ":", first)
	if second then print(second) end
	if third then print(third) end
	print(last, "\n" .. CO.an .. sep)
end

-- TODO: Do we need a warning at 1 selectable pet? Or should this be considered a valid use-case? (User manually summons a pet from Journal, but wants to get back his (only) fav pet when the timer is due.)
-- function ns.MsgLowPetPool(nPool)
-- 	ChatUserNotification(CO.bw .. ": " .. (nPool < 1 and "0 (zero) pets" or "Only 1 pet") .. " eligible as random summon! You should either " .. (ns.db.favsOnly and "flag more pets as favorite, or set the ramdom pool to 'All Pets'" or "collect more pets") .. ", or set the random-summon timer to '0'. Please note that certain pets are excluded from random summoning, to not break their usability (for example Guild Herald)." .. ((ns.dbc.charFavsEnabled and ns.db.favsOnly) and "\nNote that you have set this char to use char-specific favorite pets. Maybe switching to global favorites ('/pw c') will help." or ""))
-- end

function ns.MsgNoSavedPet()
	if ns.db.verbosityLevel < 0 then return end
	ChatUserNotification(CO.bw .. "No 'current pet' has been saved yet" .. (ns.dbc.charFavsEnabled and " for " .. CO.e .. thisChar or "") .. " --> could not restore pet.")
end

function ns.MsgOnlyFavIsActive(ap)
	if ns.db.verbosityLevel < 1 then return end
	ChatUserNotification(CO.bn .. "Your only eligible random pet " .. (ns.PetIDtoLink(ap) or "???") .. " is already active")
end

--[[---------------------------------------------------------------------------
The main, success, message when a pet was summoned. Either by RestorePet or
NewPet, or PreviousPet or the TransitionCheck.
---------------------------------------------------------------------------]]--

-- Called by the NewPet func
function ns.SetSumMsgToNewPet(ap, np, n)
	ns.msgPetSummonedContent = ns.db.verbosityLevel >= 2 and CO.bn .. "Summoned " .. (n > 1 and "a new random" or "your only eligible random") .. " pet " .. ns.PetIDtoLink(np) or nil
end

-- Called by the RestorePet func
function ns.SetSumMsgToRestorePet(pet)
	ns.msgPetSummonedContent = ns.db.verbosityLevel >= 3 and CO.bn .. "Restored your last pet " .. (ns.PetIDtoLink(pet) or "???") or nil
end

-- Called by the PreviousPet func
function ns.SetSumMsgToPreviousPet(pet)
	ns.msgPetSummonedContent = ns.db.verbosityLevel >= 2 and CO.bn .. "Summoned your previous pet " .. (ns.PetIDtoLink(pet) or "???") or nil
end

-- Called by the TransitionCheck func
function ns.SetSumMsgToTransCheck(pet)
	ns.msgPetSummonedContent = ns.db.verbosityLevel >= 3 and CO.bn .. "Summoned your last saved pet " ..( ns.PetIDtoLink(pet) or "???") or nil
end

-- Called by the SafeSummon func
function ns.MsgPetSummonSuccess()
	if ns.msgPetSummonedContent then
		ChatUserNotification(ns.msgPetSummonedContent)
	end
end

-- Called by the SafeSummon func
function ns.MsgPetSummonFailed()
	if ns.db.verbosityLevel < 1 then return end
	ChatUserNotification(CO.bw .. "You don't meet the conditions for summoning a pet right now.")
end


--[[---------------------------------------------------------------------------
Three big messages: Status, Low Pet Pool, and Help
---------------------------------------------------------------------------]]--

function ns.HelpText()

	local header = {
		CO.bn .. "Help: ",
		CO.c .. "\n/pw ", "or ", CO.c .. "/petwalker ", "supports these commands: ",
	}

	local body = {
		CO.c .. "\nd", ": ", CO.k .. "Dismiss ", "current pet and ", CO.k .. "disable auto-summon ", "(new pet / restore).",
		CO.c .. "\na", ": ", "Toggle ", CO.k .. "auto-summon ", "(new pet / restore).",
		CO.c .. "\nn", ": ", "Summon ", CO.k .. "new pet ", "from pool.",
		CO.c .. "\nf", ": ", "Toggle ", CO.k .. "pet pool: ", CO.s .. "Favorites Only", ", or ", CO.s .. "All Pets", ".",
		CO.c .. "\nc", ": ", "Toggle ", CO.k .. "favorites: ", CO.s .. "Per-character", ", or ", CO.s .. "Global Favorites", ".",
		CO.c .. "\n<number>", ": ", "Set ", CO.k .. "Summon Timer ", "in minutes (", CO.c .. "1 ", "to ", CO.c .. "1440", "; ", CO.c .. "0 ", "to ", CO.k .. "disable", ").",
		CO.c .. "\np", ": ", "Summon ", CO.k .. "previous pet ", ".",
		CO.c .. "\nv", ": ", CO.k .. "Verbosity: ", CO.s .. "silent ", "(only failures and warnings are printed to chat). ", CO.c .. "vv ", "for ", CO.s .. "medium ", CO.k .. "verbosity ", "(new summons), ", CO.c .. "vvv ", "for ", CO.s .. "full ", CO.k .. "verbosity ", "(also restored pets).",
		CO.c .. "\ns", ": ", "Display current ", CO.k .. "status/settings.",
		CO.c .. "\nh", ": ", "This help text.",
	}

	local footer = {
		CO.bn .. "\nExamples: ", CO.c .. "/pw a", " disables auto-summon/restore, or enables it if disabled. ", CO.c .. "/pw 20", " sets the new-pet summon timer to 20 minutes.",
		"\nIn 'Key Bindigs > AddOns' you can directly bind some commands.",
	}

	header = table.concat(header, CO.bn)
	body = table.concat(body, CO.bn)
	footer = table.concat(footer, CO.bn)

	ChatUserNotificationLarge(header, body, nil, footer)
end




function ns.Status()
	if not ns.poolInitialized then ns.InitializePool() end
	local header = {
		CO.bn .. "Status & Settings:",
	}
	local body = {
		CO.k .."\nAutomatic Random-summon / Restore ", "is ", CO.s .. (ns.db.autoEnabled and "enabled" or "disabled"), ".",
		CO.k .. "\nSummon Timer ", "is ", CO.s .. (ns.db.newPetTimer > 0 and (ns.db.newPetTimer/60) .. CO.bn .. " minutes" or "disabled"), ". Next random pet in ", CO.e .. ns.RemainingTimerForDisplay(), ".",
		CO.k .. "\nVerbosity ", "level of messages: ", CO.s .. ns.db.verbosityLevel, " (of 3).",
		CO.k .. "\nPet Pool ", "is set to ", CO.s .. (ns.db.favsOnly and "Favorites Only" or "All Pets"), ". Eligible pets: ", CO.e .. #ns.petPool, ".",
		CO.k .. "\nPer-character Favorites ", "are ", CO.s .. (ns.dbc.charFavsEnabled and "enabled" or "disabled"), " for ", CO.e .. thisChar, ".",
	}
	-- Separating this bc it might be a longish list
	local charfavlist = {
		"\n", ns:ListCharFavs(),
	}

	header = table.concat(header, CO.bn)
	body = table.concat(body, CO.bn)
	charfavlist = table.concat(charfavlist, CO.bn)

	ChatUserNotificationLarge(header, body, nil, charfavlist)
end


function ns.MsgLowPetPool(nPool)
	if ns.db.verbosityLevel < 0 then return end
	local R = CO.bw
	local content = {
		(nPool < 1 and CO.e .. "0 (zero) " ..R.. " pets " or R.. "Only " ..CO.e .. "1 " ..R.. "pet "),
		"eligible as random summon!",
		"\nYou should either " .. (ns.db.favsOnly and "flag more pets as favorite, or set the ramdom pool to " .. CO.s .."All Pets" or "collect more pets"),
		", or set the random-summon timer to ",
		CO.s .. "0",
		". \nPlease note that certain pets are excluded from random summoning, to not break their usability (for example ",
		CO.q .. "Guild Herald",
		"). ",
		((ns.dbc.charFavsEnabled and ns.db.favsOnly) and "\nYou have set " .. CO.e .. thisChar ..R.. " to use " .. CO.s .. "char-specific favorite " ..R.. "pets. Maybe switching to " .. CO.s .. "global favorites " ..R.. "(" .. CO.c .. "/pw c" ..R.. ") will help." or ""),
	}
	local content = table.concat(content, R)
	ChatUserNotification(content)
end


--[[===========================================================================
Slash UI
===========================================================================]]--

SLASH_PetWalker1, SLASH_PetWalker2 = '/pw', '/petwalker'
function SlashCmdList.PetWalker(cmd)
	if cmd == 'd' or cmd == 'dis' then
		ns:DismissAndDisable()
	elseif cmd == 'dd' or cmd == 'debd' then
		ns:DebugDisplay()
	elseif cmd == 'dm' or cmd == 'debm' then
		ns.DebugModeToggle()
	elseif cmd == 'vvv' then
		ns.VerbosityFull()
	elseif cmd == 'vv' then
		ns.VerbosityMedium()
	elseif cmd == 'v' then
		ns.VerbositySilent()
	elseif cmd == 'v0' then
		ns.VerbosityMute()
	elseif cmd == 'a' or cmd == 'auto' then
		ns:AutoToggle()
	elseif cmd == 'n' or cmd == 'new' then
		local actpet = C_PetJournal.GetSummonedPetGUID()
		ns:NewPet()
	elseif cmd == 'f' or cmd == 'fav' then
		ns:FavsToggle()
	elseif cmd == 'e' or cmd == 'eve' then -- Not meant for the user; undocumented
		ns:EventAlt()
	elseif cmd == 'c' or cmd == 'char' then
		ns.CharFavsSlashToggle()
	elseif cmd == 'p' or cmd == 'prev' then
		ns.PreviousPet()
	elseif cmd == 's' or cmd == 'status' then
		ns.Status()
	elseif tonumber(cmd) then
		ns:TimerSlashCmd(cmd)
	elseif cmd == 't' or cmd == 'target' then
		ns.SummonTargetPet()
	elseif cmd == 'h' or cmd == 'help' then
		ns.HelpText()
	elseif cmd == '' then
		ns.Status()
		ns.HelpText()
	else
		ChatUserNotification(format("%sInvalid command or arguments. Enter %s/pw help %sfor a list of commands.", CO.bw, CO.c, CO.bw))
	end
end

--[[---------------------------------------------------------------------------
Toggles, Commands
---------------------------------------------------------------------------]]--

function ns:DismissAndDisable()
	local actpet = C_PetJournal.GetSummonedPetGUID()
	if actpet then
		C_PetJournal.SummonPetByGUID(actpet)
	end
	ns.db.autoEnabled = false
	if ns.Auto_Button then ns.Auto_Button:SetChecked(ns.db.autoEnabled) end
	ChatUserNotification(CO.bn .. "Pet dismissed and auto-summon " .. (ns.db.autoEnabled and "enabled" or "disabled"))
end

function ns.VerbosityFull()
	ns.db.verbosityLevel = 3
	ChatUserNotification(CO.bn .. "Verbosity: full (3)")
end

function ns.VerbosityMedium()
	ns.db.verbosityLevel = 2
	ChatUserNotification(CO.bn .. "Verbosity: medium (2)")
end

function ns.VerbositySilent()
	ns.db.verbosityLevel = 1
	ChatUserNotification(CO.bn .. "Verbosity: silent (1)")
end

function ns.VerbosityMute()
	ns.db.verbosityLevel = 0
	ChatUserNotification(CO.bn .. "Verbosity: Mute (0)")
end

function ns:AutoToggle()
	ns.db.autoEnabled = not ns.db.autoEnabled
	if ns.Auto_Button then ns.Auto_Button:SetChecked(ns.db.autoEnabled) end
	ChatUserNotification(CO.bn .. "Pet auto-summon " .. (ns.db.autoEnabled and "enabled" or "disabled"))
end

function ns:EventAlt()
	ns.db.eventAlt = not ns.db.eventAlt
	ChatUserNotification(CO.bn .. (ns.db.eventAlt and "Alternative event(s) activated." or "Default event activated (PLAYER_STARTED_MOVING).") .. " # Requires reload #")
end

function ns:FavsToggle()
	ns.db.favsOnly = not ns.db.favsOnly
	ns.poolInitialized, ns.petVerified = false, false
	if ns.db.autoEnabled then ns:NewPet() end
	ChatUserNotification(CO.bn .. "Selection pool: " .. (ns.db.favsOnly and "favorites only" or "all pets"))
end

function ns.CharFavsSlashToggle() -- for slash command only
	ns.dbc.charFavsEnabled = not ns.dbc.charFavsEnabled
-- 	ns:CFavsUpdate() -- Added this to TransitionCheck()
	--[[ This is redundant, _if_ we leave the 'ns.poolInitialized = false' in the
	PET_JOURNAL_LIST_UPDATE function, which gets called by the ns:CFavsUpdate above ]]
	ns.poolInitialized, ns.petVerified = false, false
	--[[ Since we are changing from one saved-pet table to another, we prefer to
	restore the pet from the new list, rather than doing NewPet like in the FavsToggle. ]]
	if ns.db.autoEnabled then ns.TransitionCheck() end
	ChatUserNotification(CO.bn .. "Character-specific favorites "..(ns.dbc.charFavsEnabled and "enabled" or "disabled"))
end

function ns.DebugModeToggle() -- for slash command only
	ns.db.debugMode = not ns.db.debugMode
	ChatUserNotification(CO.bn .. "Debug mode "..(ns.db.debugMode and "enabled" or "disabled"))
end

local function isAcceptableTimerValue(v)
	return (v >= 1 and v <= 1440 or v == 0)
end

function ns:TimerSlashCmd(value)
	value = tonumber(value)
	if isAcceptableTimerValue(value) or ns.db.debugMode then
		ns.db.newPetTimer = value * 60
		ChatUserNotification(CO.bn .. (ns.db.newPetTimer == 0 and "Summon timer disabled" or "Summoning a new pet every " .. ns.db.newPetTimer/60 .. " minutes"))
	else
		ChatUserNotification(CO.bw .. "Not an acceptable timer value. Enter a number from 1 to 1440 for a timer in minutes, or 0 (zero) to disable the timer. Examples: '/pw 20' will summon a new pet every 20 minutes, '/pw 0' disables the timer. Note that there is a space between '/pw' and the number.")
	end
end

-- Used for info print
function ns:ListCharFavs()
	local favlinks = {}
	local count = 0
	for id, _ in pairs(ns.dbc.charFavs) do
		count = count + 1
		name = C_PetJournal.GetBattlePetLink(id)
		table.insert(favlinks, name)
	end
	favlinks = table.concat(favlinks, ' ')
	return CO.e .. thisChar .. CO.bn .. " has " .. CO.e .. count .. CO.bn ..
	" character-specific favorite pets" .. (count > 0 and ":\n" or ".") .. favlinks
end


--[[ License ===================================================================

	Copyright © 2022 Thomas Floeren

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
