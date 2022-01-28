local addonName, ns = ...
local dbVersion = 1
local _


--[[===========================================================================
Some Variables
===========================================================================]]--

local thisChar = UnitName("player")
local lastCall
local petPool = {}
local poolInitialized = false
local petVerified = false
local lastSummonTime = GetTime() - 20
local lastAutoRestoreRunTime = GetTime() - 20
local lastSavePetTime = GetTime() - 20
local savePetDelay
local savePetLoginDelay = 10
local savePetNormalDelay = 3
--[[
ATM needed to prevent chat spam with our "too less favorites" message. TODO:
Find the exact cause of the pool initialization spam, which must be somewhere in
the Favorite Selection function! I think it would be also OK to initialize only
after closing the pet journal (or Rematch!) frame.
--> Partially solved now, by inverting the initialization logic (event only sets
the var to false)
]]
local poolMsgLockout = 0

--[[
Guild Page and Herald don't have fix IDs, so we have to go by speciesID Nor
sure what to do with the Argent Squire pet: CD activates only if we access the
bank/mail/vendor, and it is also a valid pet for random favorite summons.
But maybe we should just give him a guaranteed minimum live time of 3 min or so?

Or just rely on the user intelligence to switch off auto-summoning when he
accesses the bank? Or maybe test for the pony bridle achiev and not
auto-unsummon him if present?

TODO:
- Maybe add the self-unsummoning pets, like the different Snowman (though, it
  could be considered fun to auto-resummon the Snowman repeatedly :)
]]
local excludedSpecies = {
	280, -- Guild Page, Alliance -- Pet is vendor and has CD
	281, -- Guild Page, Horde -- Pet is vendor and has CD
	282, -- Guild Herald, Alliance-- Pet is vendor and has CD
	283, -- Guild Herald, Horde-- Pet is vendor and has CD
-- 	214, -- Argent Squire (Pony Bridle char achievement: 3736)
-- 	216, -- Argent Gruntling
}

local function IsExcluded(species)
	for _, s in pairs(excludedSpecies) do
		if s == species then
-- 			ns:debugprintL1("Excluded pet found!")
			return true
		end
	end
	return false
end


ns = CreateFrame("Frame","PetWalker")

ns:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)
ns:RegisterEvent("ADDON_LOADED")

BINDING_HEADER_ThisAddon = addonName
BINDING_NAME_Auto = "Toggle Auto-summon"
BINDING_NAME_Manual = "Summon New Pet"
BINDING_NAME_Dismiss = "Dismiss Pet & Disable Auto-summon"


--[[===========================================================================
LOADING
===========================================================================]]--

function ns.ADDON_LOADED(self,event,arg1)

--[[---------------------------------------------------------------------------
ADDON_LOADED: PetWalker
---------------------------------------------------------------------------]]--

	if arg1 == addonName then

		PetWalkerDB = PetWalkerDB or {}
		PetWalkerPerCharDB = PetWalkerPerCharDB or {}
		ns.db, ns.dbc = PetWalkerDB, PetWalkerPerCharDB

		if not ns.db.dbVersion or ns.db.dbVersion ~= dbVersion then
			table.wipe(ns.db)
		end
		if not ns.dbc.dbVersion or ns.dbc.dbVersion ~= dbVersion then
			local tmpCharFavs = ns.dbc.charFavs -- charFavs
			table.wipe(ns.dbc)
			ns.dbc.charFavs = tmpCharFavs
		end
		ns.db.dbVersion  = dbVersion
		ns.dbc.dbVersion = ns.db.dbVersion

		ns.db.autoEnabled = ns.db.autoEnabled == nil and true or ns.db.autoEnabled
		ns.db.newPetTimer = ns.db.newPetTimer or 12
		ns.db.favsOnly = ns.db.favsOnly == nil and true or ns.db.favsOnly
		ns.dbc.charFavsEnabled = ns.dbc.charFavsEnabled or false
		ns.dbc.charFavs = ns.dbc.charFavs or {}
		ns.dbc.eventAlt = ns.dbc.eventAlt or false
		ns.db.debugMode = ns.db.debugMode or false

		lastCall = GetTime() + 20
		savePetDelay = savePetLoginDelay

		--[[
		Is this needed?
		Seems we also get - sometimes - a COMPANION_UPDATE event after login
		(which triggers a SavePet()). Also it doesn't find the variables from
		the ns.db, if run too early. So, this is difficult to time, and also
		depends on the load time of the char.
		So, let's try with PLAYER_ENTERING_WORLD:
		]]
--		self:RegisterEvent("PLAYER_ENTERING_WORLD")
--		self.PLAYER_ENTERING_WORLD = ns.LoginCheck
		C_Timer.After(16, function() ns.LoginCheck() end)


		--[[
		This thing fires very often
		Let's do a test:
		Unset the 'isInitialized' var with that event, and initialize only when
		needed, that is before selecting a random pet.
		--> This seems to work, so far!
		]]
		ns:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
-- 		ns.PET_JOURNAL_LIST_UPDATE = ns.InitializePool
		function ns.PET_JOURNAL_LIST_UPDATE()
			poolInitialized = false
			ns:debugprintL1("ns.PET_JOURNAL_LIST_UPDATE has run. poolInitialized =="
			.. tostring(poolInitialized))
		end

		ns:CFavsUpdate()

		if ns.dbc.eventAlt then
			self:RegisterEvent("PLAYER_STARTED_LOOKING")
			self.PLAYER_STARTED_LOOKING = ns.AutoAction
		else
			self:RegisterEvent("PLAYER_STARTED_MOVING")
			self.PLAYER_STARTED_MOVING = ns.AutoAction
		end


		--[[
		TODO: Does this fire too often? (see
		https://wowpedia.fandom.com/wiki/COMPANION_UPDATE)
		]]
		self:RegisterEvent("COMPANION_UPDATE")
		function ns.COMPANION_UPDATE(self,event,arg1)
			if arg1 == "CRITTER" then
			C_Timer.After(savePetDelay, function() ns.SavePet() end)
			end
		end


--[[---------------------------------------------------------------------------
ADDON_LOADED: Blizzard_Collections
---------------------------------------------------------------------------]]--

	-- TODO: the same for Rematch
	elseif arg1 == "Blizzard_Collections" then
		for i, btn in ipairs(PetJournal.listScroll.buttons) do
			btn:SetScript("OnClick",function(self, button)
				if IsControlKeyDown() then
					local isFavorite = C_PetJournal.PetIsFavorite(self.petID)
					C_PetJournal.SetFavorite(self.petID, isFavorite and 0 or 1)
				else
					return PetJournalListItem_OnClick(self,button)
				end
			end)
		end

		-- TODO: the same for Rematch
		ns.CFavs_Button = self:CreateCfavsCheckBox()
		hooksecurefunc("CollectionsJournal_UpdateSelectedTab", function(self)
			local selected = PanelTemplates_GetSelectedTab(self);
			if selected == 2 then
				ns.CFavs_Button:SetChecked(ns.dbc.charFavsEnabled)
				ns.CFavs_Button:Show()
			else
				ns.CFavs_Button:Hide()
			end
		end)
	end
end


--[[===========================================================================
Messages
===========================================================================]]--

-- TODO: Do we need a warning at 1 selectable pet? Or should this be considered a valid use-case? (User manually summons a pet from Journal, but wants to get back his (only) fav pet when the timer is due.)
local function MsgLowPetPool(nPool)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. (nPool < 1 and "0 (zero) pets" or "Only 1 pet") .. " eligible as random summon! You should either " .. (ns.db.favsOnly and "flag more pets as favorite, or set the ramdom pool to 'All Pets'" or "collect more pets") .. ", or set the random-summon timer to '0'. Please note that certain pets are excluded from random summoning, to not break their usability (for example Guild Herald)." .. ((ns.dbc.charFavsEnabled and ns.db.favsOnly) and "\nNote that you have set this char to use char-specific favorite pets. Maybe switching to global favorites ('/pw c') will help." or ""),0,1,0.7)
end

local function MsgNoSavedPet()
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": No 'current pet' has been saved yet" .. (ns.dbc.charFavsEnabled and " on this character" or "") .. ". Could not restore pet.", 0,1,0.7)
end

local function MsgAutoRestoreDone(pet)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Restored your last pet (" .. ns.PetIDtoName(pet) .. ")", 0,1,0.7)
end

local function MsgNewPetDone(ap, np, n)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Summoned " .. (n >1 and "a new random" or "your only eligible random") .. " pet (" .. ns.PetIDtoName(np) .. ")", 0,1,0.7)
end

local function MsgOnlyFavIsActive(ap)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Your only eligible random pet (" .. ns.PetIDtoName(np) .. ") is already active", 0,1,0.7)
end


--[[===========================================================================
MAIN ACTIONS
===========================================================================]]--

--[[---------------------------------------------------------------------------
The main function that runs when player started moving.
It DECIDES whether to restore a (lost) pet, or summoning a new one (if the timer is set and due).
---------------------------------------------------------------------------]]--

function ns.AutoAction()
	if not ns.db.autoEnabled then return end
	petVerified = true
	local actpet = C_PetJournal.GetSummonedPetGUID()
	if ns.db.newPetTimer ~= 0 and lastCall + ns.db.newPetTimer * 60 < GetTime() then
		ns:debugprintL2("AutoAction() has run and decided for New Pet.")
		ns:NewPet(actpet)
	elseif not actpet then
		ns:debugprintL2("AutoAction() has run and decided to Restore Pet.")
		ns:RestorePet()
	end
end

--[[---------------------------------------------------------------------------
RESTORE: Pet is lost --> restore it
---------------------------------------------------------------------------]]--

function ns:RestorePet()
	if GetTime() - lastSummonTime < 2 then return end
	if GetTime() - lastAutoRestoreRunTime < 2 then return end
	if ns.dbc.charFavsEnabled then
		if ns.dbc.currentPet then
			ns:SafeSummon(ns.dbc.currentPet)
			MsgAutoRestoreDone(ns.dbc.currentPet)
		else
			MsgNoSavedPet()
		end
	elseif ns.db.currentPet then
		ns:SafeSummon(ns.db.currentPet)
		MsgAutoRestoreDone(ns.db.currentPet)
	else
		MsgNoSavedPet()
	end
	ns:debugprintL1("AutoRestore() has run")
	lastAutoRestoreRunTime = GetTime()
end


--[[---------------------------------------------------------------------------
NEW PET SUMMON: Runs when timer is due
---------------------------------------------------------------------------]]--
-- Called by 1: ns.AutoAction

function ns:NewPet(actpet)
	if lastCall + 1.5 > GetTime() then return end
	lastCall = GetTime()
	if IsExcluded(actpet) then return end
	if not poolInitialized then
		ns:debugprintL1("ns.NewPet --> InitializePool")
		ns.InitializePool()
	end
	local npool = #petPool
	ns.debugprintL1("ns.AutoAction: npool==" .. npool)
	local newpet
	if npool == 0 then
		MsgLowPetPool(npool)
		if not actpet then ns:RestorePet() end
	else
		if npool == 1 then
			newpet = petPool[1]
			if actpet == newpet then
				MsgOnlyFavIsActive(actpet)
			end
		else
			repeat
				newpet = petPool[math.random(npool)]
			until actpet ~= newpet
		end
		MsgNewPetDone(actpet, newpet, npool)
		ns:SafeSummon(newpet)
	end
end


--[[---------------------------------------------------------------------------
MANUAL SUMMON of the previously summoned pet
---------------------------------------------------------------------------]]--

function ns.ManualSummonPrevious()
	if ns.dbc.charFavsEnabled then
		C_PetJournal.SummonPetByGUID(ns.dbc.previousPet)
	else
		C_PetJournal.SummonPetByGUID(ns.db.previousPet)
	end
	lastCall = GetTime()
	lastSummonTime = lastCall
end


--[[---------------------------------------------------------------------------
One time action,  somewhere AFTER LOGIN. Try to restore the same pat as the last logged-in char had active.
---------------------------------------------------------------------------]]--

function ns.LoginCheck()
	if not ns.db.autoEnabled then return end
	petVerified = true
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if ns.dbc.charFavsEnabled then
		if not actualPet or actualPet ~= ns.dbc.currentPet then
			ns:SafeSummon(ns.dbc.currentPet)
		end
	else
		if not actualPet or actualPet ~= ns.db.currentPet then
			ns:SafeSummon(ns.db.currentPet)
		end
	end
	ns:debugprintL2("LoginCheck() has run")
end


--[[---------------------------------------------------------------------------
SAVING: Save a newly summoned pet, no matter how it was summoned.
Should run with the COMPANION_UPDATE event.
---------------------------------------------------------------------------]]--

function ns.SavePet()
	savePetDelay = savePetNormalDelay
	local actpet = C_PetJournal.GetSummonedPetGUID()
	if not actpet
		or IsExcluded(actpet)
		or (GetTime() - lastSavePetTime < 1)
		or not petVerified then
		return
	end
	if ns.dbc.charFavsEnabled then
		if ns.dbc.currentPet == actpet then return end
		ns.dbc.previousPet = ns.dbc.currentPet
		ns.dbc.currentPet = actpet
	else
		if ns.db.currentPet == actpet then return end
		ns.db.previousPet = ns.db.currentPet
		ns.db.currentPet = actpet
	end
	ns:debugprintL2("SavePet() has run")
	lastSavePetTime = GetTime()
end


--[[---------------------------------------------------------------------------
SAFE-SUMMON: Used in the AutoSummon function, and currently also in the
Manual Summon function
---------------------------------------------------------------------------]]--

-- TODO: What about Feign Death?!
local excludedAuras = {
	32612, -- Mage: Invisibility
	110960, -- Mage: Greater Invisibility
	131347, -- DH: Gliding
	311796, -- Pet: Daisy as backpack (/beckon)
} -- More exclusions in the Summon function itself

local function OfflimitsAura(auras)
	for _, a in pairs(auras) do
		if GetPlayerAuraBySpellID(a) then
			ns.dbp("Excluded Aura found!")
			return true
		end
	end
	return false
end

local function InMythicKeystone()
	local _, instanceType, difficultyID = GetInstanceInfo()
	return instanceType == "party" and difficultyID == 8
end

local function InArena()
	local _, instanceType = IsInInstance()
	return instanceType == "arena"
end

-- Called by 3: ns:RestorePet, ns:NewPet, ns.ManualSummonNew
function ns:SafeSummon(pet)
	if not pet then return end -- needed?
	if not UnitAffectingCombat("player")
--		and not IsMounted() -- TODO: test if this is needed
		and not IsFlying()
		and not OfflimitsAura(excludedAuras)
		and not IsStealthed()
		and not (UnitIsControlling("player") and UnitChannelInfo("player"))
		and not UnitHasVehicleUI("player")
		and not UnitIsGhost("player")
		and not InMythicKeystone()
		and not InArena()
	then
		C_PetJournal.SummonPetByGUID(pet)
		ns:debugprintL2("SafeSummon() has summoned \"" .. (ns.PetIDtoName(pet) or "-NONE-") .. "\" ")
		lastSummonTime = GetTime()
	end
end


--[[===========================================================================
Creating the POOL, from where the random pet is summoned.
This can be, depending on user setting:
— Global favorites
— Per-character favorites
— All available pets (except the exclusions)
===========================================================================]]--

-- Called by 3: PET_JOURNAL_LIST_UPDATE; conditionally by ns:NewPet, ns.ManualSummonNew
function ns.InitializePool(self)
	ns:debugprintL1("Running ns.InitializePool()")
	table.wipe(petPool)
	local index = 1
	while true do
		local petID, speciesID, _, _, _, favorite = C_PetJournal.GetPetInfoByIndex(index)
		if not petID then break end
		if not IsExcluded(speciesID) then
			if ns.db.favsOnly then
				if favorite then
					table.insert(petPool, petID)
				end
			else
				table.insert(petPool, petID)
			end
		end
		index = index + 1
	end
	poolInitialized = true -- Condition in ns:NewPet and ns.ManualSummonNew
	if #petPool <= 1 and ns.db.newPetTimer ~= 0 and poolMsgLockout < GetTime() then
		MsgLowPetPool(#petPool)
		poolMsgLockout = GetTime() + 15
	end
end


-- Largely unaltered code from NugMiniPet
function ns.CFavsUpdate()
	if ns.dbc.charFavsEnabled then
		C_PetJournal.PetIsFavorite1 = C_PetJournal.PetIsFavorite1 or C_PetJournal.PetIsFavorite
		C_PetJournal.SetFavorite1 = C_PetJournal.SetFavorite1 or C_PetJournal.SetFavorite
		C_PetJournal.GetPetInfoByIndex1 = C_PetJournal.GetPetInfoByIndex1 or C_PetJournal.GetPetInfoByIndex
		C_PetJournal.PetIsFavorite = function(petGUID)
			return ns.dbc.charFavs[petGUID] or false
		end
		C_PetJournal.SetFavorite = function(petGUID, new)
			if new == 1 then
				ns.dbc.charFavs[petGUID] = true
			else
				ns.dbc.charFavs[petGUID] = nil
			end
			if PetJournal then PetJournal_OnEvent(PetJournal, "PET_JOURNAL_LIST_UPDATE") end
			ns:PET_JOURNAL_LIST_UPDATE()
		end
		local gpi = C_PetJournal.GetPetInfoByIndex1
		C_PetJournal.GetPetInfoByIndex = function(...)
			local petGUID, speciesID, isOwned, customName, level, favorite, isRevoked, name, icon, petType, creatureID, sourceText, description, isWildPet, canBattle, arg1, arg2, arg3 = gpi(...)
			local customFavorite = C_PetJournal.PetIsFavorite(petGUID)
			return petGUID, speciesID, isOwned, customName, level, customFavorite, isRevoked, name, icon, petType, creatureID, sourceText, description, isWildPet, canBattle, arg1, arg2, arg3
		end
	else
		if C_PetJournal.PetIsFavorite1 then C_PetJournal.PetIsFavorite = C_PetJournal.PetIsFavorite1 end
		if C_PetJournal.SetFavorite1 then C_PetJournal.SetFavorite = C_PetJournal.SetFavorite1 end
		if C_PetJournal.GetPetInfoByIndex1 then C_PetJournal.GetPetInfoByIndex = C_PetJournal.GetPetInfoByIndex1 end
	end
	if PetJournal then PetJournal_OnEvent(PetJournal, "PET_JOURNAL_LIST_UPDATE") end
	ns:PET_JOURNAL_LIST_UPDATE()
end


--[[===========================================================================
UI STUFF (Slash and Pet journal checkbox)
===========================================================================]]--

--[[---------------------------------------------------------------------------
Toggles, Commands
---------------------------------------------------------------------------]]--

function ns:DismissAndDisable()
	local actpet = C_PetJournal.GetSummonedPetGUID()
	if actpet then
		C_PetJournal.SummonPetByGUID(actpet);
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
	local charFavsNames = {}
	local count = 0
	for id, _ in pairs(ns.dbc.charFavs) do
	count = count + 1
	local index = 1
		while true do
			local petGUID, _, _, _, _, _, _, name = C_PetJournal.GetPetInfoByIndex(index)
			if not petGUID then break end
			if petGUID == id then
				table.insert(charFavsNames, name)
				break
			end
			index = index + 1
		end
	end
	charFavsNames = table.concat(charFavsNames, '; ')
	return thisChar .. " currently has " .. count .. " character-specific favorite pets" .. (count > 0 and ":" or "") .. "\n" .. (charFavsNames or "")
end


--[[---------------------------------------------------------------------------
Slash UI
---------------------------------------------------------------------------]]--

local helpText = "\nPetWalker Help: '/pw' or '/petw' supports these commands:\n  d: Dismiss current pet and disable auto-summon\n  a: Toggle auto-summon\n  n: Summon new pet from pool\n  f: Toggle selection pool: favorites only, or all pets\n  c: Toggle character-specific favorites, or global\n  <number>: Summon timer in minutes (1 to 999, 0 to disable)\n  p: Summon previous pet\n  s: Display current status/settings\n  h: This help text\nIn Key Bindigs > AddOns you can directly bind some commands."

function ns.Status()
	local text = "\nPetWalker Status:\n  Auto-summon is " .. (ns.db.autoEnabled and "enabled" or "disabled") .. "\n  Summon timer is " .. (ns.db.newPetTimer > 0 and ns.db.newPetTimer .. " minutes" .. " - Next random pet in " .. ns.RemainingTimer() or "disbled") .. "\n  Selection pool is set to " .. (ns.db.favsOnly and "favorites only" or "all pets") .. "\n  Character-specific favorites are " .. (ns.dbc.charFavsEnabled and "enabled" or "disabled") .. " for " .. thisChar .. "\n  " .. ns:ListCharFavs()
	return text
end

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
		ns:NewPet(C_PetJournal.GetSummonedPetGUID())
	elseif cmd == 'f' or cmd == 'fav' then
		ns:FavsToggle()
	elseif cmd == 'e' or cmd == 'eve' then
		ns:EventAlt()
	elseif cmd == 'c' or cmd == 'char' then
		ns.CharFavsSlashToggle()
	elseif cmd == 'p' or cmd == 'prev' then
		ns.ManualSummonPrevious()
	elseif cmd == 's' or cmd == 'status' then
		DEFAULT_CHAT_FRAME:AddMessage(ns.Status(),0,1,0.7)
	elseif tonumber(cmd) then
		ns:TimerSlashCmd(cmd)
	elseif cmd == 'h' or cmd == 'help' then
		DEFAULT_CHAT_FRAME:AddMessage(helpText,0,1,0.7)
	elseif cmd == '' then
		DEFAULT_CHAT_FRAME:AddMessage(ns.Status() .. helpText,0,1,0.7)
	else
		DEFAULT_CHAT_FRAME:AddMessage("ns: Invalid command or/and arguments. Enter '/pk help' for a list of commands.", 0,1,0.7)
	end
end


--[[---------------------------------------------------------------------------
-- GUI stuff for Pet Journal
---------------------------------------------------------------------------]]--

-- We disabled most of the GUI stuff, since now we have more settings than we can fit there. We leave the CharFavorites checkbox, because it makes sense to see at a glance (in the opened Pet Journal) which type of favs are enabled.

function ns.CreateCheckBoxBase(self)
	local f = CreateFrame("CheckButton", "PetWalkerAutoCheckbox",PetJournal,"UICheckButtonTemplate")
	f:SetWidth(25)
	f:SetHeight(25)

	f:SetScript("OnLeave",function(self)
		GameTooltip:Hide();
	end)

	local label	 =	f:CreateFontString(nil, "OVERLAY")
	label:SetFontObject("GameFontNormal")
	label:SetPoint("LEFT",f,"RIGHT",0,0)

	return f, label
end


function ns.CreateCfavsCheckBox(self)
	local f, label = self:CreateCheckBoxBase()
	f:SetPoint("BOTTOMLEFT",PetJournal,"BOTTOMLEFT",400,1)
	f:SetChecked(ns.dbc.charFavsEnabled)
	f:SetScript("OnClick",function(self,button)
		ns.dbc.charFavsEnabled = not ns.dbc.charFavsEnabled
		ns:CFavsUpdate()
	end)
	f:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText("Toggle character-specific favorites", nil, nil, nil, nil, 1);
		GameTooltip:Show();
	end)
	label:SetText("Character favorites")
	return f
end


--[[===========================================================================
-- Debugging and Utils
===========================================================================]]--


function ns.PetIDtoName(id)
	local id, name = '"'..id..'"', select(8, C_PetJournal.GetPetInfoByPetID(id))
	return name
end


function ns:DebugDisplay()
	DEFAULT_CHAT_FRAME:AddMessage("\nDebug:\n  Current pet: " .. (ns.PetIDtoName(ns.db.currentPet) or "-none-") .. "\n  Previous pet: " .. (ns.PetIDtoName(ns.db.previousPet) or "-none-") .. "\n  Current char pet: " .. (ns.PetIDtoName(ns.dbc.currentPet) or "-none-") .. "\n  Previous char pet: " .. (ns.PetIDtoName(ns.dbc.previousPet) or "-none-") .. "\n" .. ns.Status(),0,1,0.7)
end

-- without pet info
function ns:debugprintL1(msg)
if not ns.db.debugMode then return end
	print("\n|cffFFA500### PETWALKER DEBUG: " .. (msg or "<nil>") .. " ###")
end

-- with pet info
function ns:debugprintL2(msg)
if not ns.db.debugMode then return end
	print("\n|cffFFA500### PETWALKER DEBUG: " .. (msg or "<nil>") .. " ### Current DB pet: " .. (ns.PetIDtoName((ns.dbc.charFavs and ns.dbc.currentPet or ns.db.currentPet)) or "<nil>") .. " ###")
end

-- Table dump
function ns.dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

-- Seconds to minutes
local function SecToMin(seconds)
	local min, sec = tostring(math.floor(seconds / 60)), tostring(seconds % 60)
	return string.format('%.0f:%02.0f', min, sec)
end

function ns.RemainingTimer()
	local rem = lastCall + ns.db.newPetTimer * 60 - GetTime()
	rem = rem > 0 and rem or 0
	return SecToMin(rem)
end
