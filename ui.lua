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
		keyword = '00FA9A',
		state = '32CD32',
		command = 'D2691E',
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

local function ChatUserNotification(msg)
	DEFAULT_CHAT_FRAME:AddMessage(CO.an .. addonName .. ": " .. msg)
end

-- TODO: Do we need a warning at 1 selectable pet? Or should this be considered a valid use-case? (User manually summons a pet from Journal, but wants to get back his (only) fav pet when the timer is due.)
function ns.MsgLowPetPool(nPool)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. (nPool < 1 and "0 (zero) pets" or "Only 1 pet") .. " eligible as random summon! You should either " .. (ns.db.favsOnly and "flag more pets as favorite, or set the ramdom pool to 'All Pets'" or "collect more pets") .. ", or set the random-summon timer to '0'. Please note that certain pets are excluded from random summoning, to not break their usability (for example Guild Herald)." .. ((ns.dbc.charFavsEnabled and ns.db.favsOnly) and "\nNote that you have set this char to use char-specific favorite pets. Maybe switching to global favorites ('/pw c') will help." or ""),0,1,0.7)
end

function ns.MsgNoSavedPet()
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": No 'current pet' has been saved yet" .. (ns.dbc.charFavsEnabled and " on this character" or "") .. ". Could not restore pet.", 0,1,0.7)
end

function ns.MsgAutoRestoreDone(pet)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Restored your last pet " .. ns.PetIDtoLink(pet), 0,1,0.7)
end

function ns.MsgNewPetDone(ap, np, n)
	ChatUserNotification("Summoned " .. (n >1 and "a new random" or "your only eligible random") .. " pet " .. ns.PetIDtoLink(np))
end

function ns.MsgOnlyFavIsActive(ap)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Your only eligible random pet " .. ns.PetIDtoLink(ap) .. " is already active", 0,1,0.7)
end

function ns.HelpText()
	local content = {
		CO.bn .. "Help: ",
		CO.c .. "\n/pw ",
		"or ",
		CO.c .. "/petw ",
		"supports these commands: ",
		CO.c .. "\n  d",
		": ",
		CO.k .. "Dismiss ",
		"current pet and ",
		CO.k .. "disable auto-summon ",
		"(new pet / restore)",
		CO.c .. "\n  a",
		": ",
		"Toggle ",
		CO.k .. "auto-summon ",
		"(new pet / restore)",
		CO.c .. "\n  n",
		": ",
		"Summon ",
		CO.k .. "new pet ",
		"from pool",
		CO.c .. "\n  f",
		": ",
		"Toggle ",
		CO.k .. "pet pool: ",
		CO.s .. "Favorites Only",
		", or ",
		CO.s .. "All Pets",
		CO.c .. "\n  c",
		": ",
		"Toggle ",
		CO.k .. "favorites: ",
		CO.s .. "Per-character",
		", or ",
		CO.s .. "Global Favorites",
		CO.c .. "\n  <number>",
		": ",
		"Set ",
		CO.k .. "Summon Timer ",
		"in minutes (",
		CO.c .. "1 ",
		"to ",
		CO.c .. "999",
		"; ",
		CO.c .. "0 ",
		"to ",
		CO.k .. "disable",
		")",
		CO.c .. "\n  p",
		": ",
		"Summon ",
		CO.k .. "previous pet ",
		CO.c .. "\n  s",
		": ",
		"Display current ",
		CO.k .. "status/settings",
		CO.c .. "\n  h",
		": ",
		"This help text",
		"\nIn ",
		"Key Bindigs > AddOns ",
		"you can directly bind some commands",
	}
	local content = table.concat(content, CO.bn)
	ChatUserNotification(content)
end


function ns.Status()
	if not poolInitialized then ns.InitializePool() end
	local content = {
		CO.bn .. "Status & Settings:",
		CO.k .."\n  Automatic Random-summon / Restore ",
		"is ",
		CO.s .. (ns.db.autoEnabled and "enabled" or "disabled"),
		CO.k .. "\n  Summon Timer ",
		"is ",
		CO.s .. (ns.db.newPetTimer > 0 and ns.db.newPetTimer .. CO.bn .. " minutes" or "disbled"),
		" • Next random pet in ",
		CO.e .. ns.RemainingTimer(),
		CO.k .. "\n  Pet Pool ",
		"is set to ",
		CO.s .. (ns.db.favsOnly and "Favorites Only" or "All Pets"),
		" • Eligible pets: ",
		CO.e .. #ns.petPool,
		CO.k .. "\n  Per-character Favorites ",
		"are ",
		CO.s .. (ns.dbc.charFavsEnabled and "enabled" or "disabled"),
		" for ",
		CO.e .. thisChar,
		"\n",
		ns:ListCharFavs(),
	}
	local content = table.concat(content, CO.bn)
	ChatUserNotification(content)
end

--[[===========================================================================
Slash UI
===========================================================================]]--

SLASH_PetWalker1, SLASH_PetWalker2 = '/pw', '/petw'
function SlashCmdList.PetWalker(cmd)
	if cmd == 'd' or cmd == 'dis' then
		ns:DismissAndDisable()
	elseif cmd == 'dd' or cmd == 'debd' then
		ns:DebugDisplay()
	elseif cmd == 'dm' or cmd == 'debm' then
		ns.DebugModeToggle()
	elseif cmd == 'a' or cmd == 'auto' then
		ns:AutoToggle()
	elseif cmd == 'n' or cmd == 'new' then
		local actpet = C_PetJournal.GetSummonedPetGUID()
		ns:NewPet(actpet)
	elseif cmd == 'f' or cmd == 'fav' then
		ns:FavsToggle()
	elseif cmd == 'e' or cmd == 'eve' then
		ns:EventAlt()
	elseif cmd == 'c' or cmd == 'char' then
		ns.CharFavsSlashToggle()
	elseif cmd == 'p' or cmd == 'prev' then
		ns.ManualSummonPrevious()
	elseif cmd == 's' or cmd == 'status' then
		ns.Status()
	elseif tonumber(cmd) then
		ns:TimerSlashCmd(cmd)
	elseif cmd == 'h' or cmd == 'help' then
		ns.HelpText()
	elseif cmd == '' then
		ns.Status()
		ns.HelpText()
	else
		DEFAULT_CHAT_FRAME:AddMessage("ns: Invalid command or/and arguments. Enter '/pk help' for a list of commands.", 0,1,0.7)
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
	DEFAULT_CHAT_FRAME:AddMessage("Pet dismissed and auto-summon " .. (ns.db.autoEnabled and "enabled" or "disabled"),0,1,0.7)
end

function ns:AutoToggle()
	ns.db.autoEnabled = not ns.db.autoEnabled
	if ns.Auto_Button then ns.Auto_Button:SetChecked(ns.db.autoEnabled) end
	DEFAULT_CHAT_FRAME:AddMessage("Pet auto-summon " .. (ns.db.autoEnabled and "enabled" or "disabled"),0,1,0.7)
end

function ns:EventAlt()
	ns.dbc.eventAlt = not ns.dbc.eventAlt
	DEFAULT_CHAT_FRAME:AddMessage("Listening to Event " .. (ns.dbc.eventAlt and "PLAYER_STARTED_LOOKING" or "PLAYER_STARTED_MOVING (default)") .. " # Requires reload",0,1,0.7)
end

function ns:FavsToggle()
	ns.db.favsOnly = not ns.db.favsOnly
	poolInitialized = false
	DEFAULT_CHAT_FRAME:AddMessage("Selection pool: " .. (ns.db.favsOnly and "favorites only" or "all pets"),0,1,0.7)
end

function ns.CharFavsSlashToggle() -- for slash command only
	ns.dbc.charFavsEnabled = not ns.dbc.charFavsEnabled
	ns:CFavsUpdate()
	--[[ This is redundant, _if_ we leave the 'poolInitialized = false' in the
	PET_JOURNAL_LIST_UPDATE function, which gets called by the ns:CFavsUpdate above ]]
	poolInitialized = false
	DEFAULT_CHAT_FRAME:AddMessage("Character-specific favorites "..(ns.dbc.charFavsEnabled and "enabled" or "disabled"),0,1,0.7)
end

function ns.DebugModeToggle() -- for slash command only
	ns.db.debugMode = not ns.db.debugMode
	DEFAULT_CHAT_FRAME:AddMessage("Debug mode "..(ns.db.debugMode and "enabled" or "disabled"),0,1,0.7)
end

function ns:TimerSlashCmd(value)
	value = tonumber(value)
	if value >= 0 and value < 1000 then
		ns.db.newPetTimer = value
	--			ns.TimerEditBox:SetText(ns.db.newPetTimer) -- only needed for GUI edit box, which is currently disabled
	DEFAULT_CHAT_FRAME:AddMessage(ns.db.newPetTimer == 0 and "Summon timer disabled" or "Summoning a new pet every " .. ns.db.newPetTimer .. " minutes",0,1,0.7)
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
	" character-specific favorite pets" .. (count > 0 and ":" or "") .. "\n" .. (favlinks or "")
end

