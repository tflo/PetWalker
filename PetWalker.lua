local addonName, ns = ...


ns = CreateFrame("Frame","PetWalker")

ns:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)
ns:RegisterEvent("ADDON_LOADED")

BINDING_HEADER_ThisAddon = addonName
BINDING_NAME_Auto = "Toggle Auto-summon"
BINDING_NAME_Manual = "Summon New Pet"
BINDING_NAME_Dismiss = "Dismiss Pet & Disable Auto-summon"

local _
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
local poolMsgLockout = 0 -- ATM needed to prevent chat spam with our "too less favorites" message. TODO: Find the exact cause of the pool initialization spam, which must be somewhere in the Favorite Selection function! I think it would be also OK to initialize only after closing the pet journal (or Rematch!) frame.

-- Guild Page and Herald don't have fix IDs, so we have to go by speciesID
-- Nor sure what to do with the Argent Squire pet: CD activates only if we access the bank/mail/vendor, and it is also a valid pet for random favorite summons. But maybe we should just give him a guaranteed minimum live time of 3 min or so? Or just rely on the user intelligence to switch off auto-summoning when he accesses the bank? Or maybe test for the pony bridle achiev and not auto-unsummon him if present?
-- TODO: check the Hordies speciesID
local excludedSpecies = {
	280, -- Guild Page -- Pet is vendor and has CD
	282, -- Guild Herald -- Pet is vendor and has CD
-- 	214, -- Argent Squire (Pony Bridle char achievement: 3736)
-- 	216, -- Argent Gruntling
}

local function IsExcluded(species)
	for _, s in pairs(excludedSpecies) do
		if s == species then
			ns:debugprintL1("Excluded pet found!")
			return true
		end
	end
	return false
end


--[[---------------------------------------------------------------------------
Messages
---------------------------------------------------------------------------]]--

-- TODO: Do we need a warning at 1 selectable pet? Or should this be considered a valid use-case? (User manually summons a pet from Journal, but wants to get back his (only) fav pet when the timer is due.)
local function MsgLowPetPool(nPool)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. (nPool < 1 and "0 (zero) pets" or "Only 1 pet") .. " eligible for summoning! You should either " .. (ns.db.favsOnly and "flag more pets as favorite, or set the ramdom pool to 'All Pets'" or "collect more pets") .. ", or set the random-summon timer to '0'. Please note that certain pets are excluded from random summoning, to not break their usability (for example Guild Herald)." .. ((ns.dbc.cfavs_enabled and ns.db.favsOnly) and "\nNote that you have set this char to use char-specific favorite pets. Maybe switching to global favorites ('/pw c') will help."),0,1,0.7)
end

local function MsgNoSavedPet()
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": No 'current pet' has been saved yet" .. (ns.dbc.cfavs_enabled and " on this character" or "") .. ". Could not restore pet.", 0,1,0.7)
end

local function MsgAutoRestoreDone(pet)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Your last pet (" .. ns.PetIDtoName(pet) .. ") has been re-summoned.", 0,1,0.7)
end

local function MsgNewPetDone(pet, nPool)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. (nPool >1 and "A new random" or "Your only eligible") .. " pet (" .. ns.PetIDtoName(pet) .. ") has been summoned" .. (nPool == 1 and " or was already active" or "") .. ".", 0,1,0.7)
end


--[[===========================================================================
LOADING
===========================================================================]]--

function ns.ADDON_LOADED(self,event,arg1)
	if arg1 == addonName then
		PetWalkerDB = PetWalkerDB or {}
		PetWalkerPerCharDB = PetWalkerPerCharDB or {}
		ns.db, ns.dbc = PetWalkerDB, PetWalkerPerCharDB
		ns.dbc.cfavs = ns.dbc.cfavs or {}
		ns.dbc.cfavs_enabled = ns.dbc.cfavs_enabled or false
		ns.db.timer = ns.db.timer or 12
		ns.db.favsOnly = ns.db.favsOnly == nil and true or ns.db.favsOnly
		ns.db.enable = ns.db.enable == nil and true or ns.db.enable
		ns.db.debugmode = ns.db.debugmode or false

		lastCall = GetTime() + 20
		savePetDelay = savePetLoginDelay

		-- Is this needed?
		-- Seems we also get - sometimes - a COMPANION_UPDATE event after login (which triggers a SavePet()). Also it doesn't find the variables from the ns.db, if run too early. So, this is difficult to time, and also depends on the load time of the char.
		-- So, let's try with PLAYER_ENTERING_WORLD:
--		self:RegisterEvent("PLAYER_ENTERING_WORLD")
--		self.PLAYER_ENTERING_WORLD = ns.LoginCheck
		C_Timer.After(16, function() ns.LoginCheck() end)

		self:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
		self.PET_JOURNAL_LIST_UPDATE = self.InitializePool

		ns:CFavsUpdate()

		-- This is our main event, and it happens quite frequently. Resource usage is pretty low, since we are only checking the timer and if a pet is out. Nevertheless, we should - maybe - consider some less frequent event in place of this. (e.g. ZONE_CHANGED, mount/unmount or such)
		self:RegisterEvent("PLAYER_STARTED_MOVING")
		self.PLAYER_STARTED_MOVING = ns.AutoAction

		-- experimental: for not-much-moving chars at the auction house
		self:RegisterEvent("PLAYER_STARTED_LOOKING")
		function ns.PLAYER_STARTED_LOOKING(self,event)
			local zone = GetMinimapZoneText()
			if zone == 'Booty Bay' then
				ns.AutoAction()
			end
		end

		-- TODO: Does this fire too often? (see https://wowpedia.fandom.com/wiki/COMPANION_UPDATE)
		self:RegisterEvent("COMPANION_UPDATE")
		function ns.COMPANION_UPDATE(self,event,arg1)
			if arg1 == "CRITTER" then
			C_Timer.After(savePetDelay, function() ns.SavePet() end)
			end
		end

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

		ns.CFavs_Button = self:CreateCfavsCheckBox()
		hooksecurefunc("CollectionsJournal_UpdateSelectedTab", function(self)
			local selected = PanelTemplates_GetSelectedTab(self);
			if selected == 2 then
				ns.CFavs_Button:SetChecked(ns.dbc.cfavs_enabled)
				ns.CFavs_Button:Show()
			else
				ns.CFavs_Button:Hide()
			end
		end)
	end
end


--[[===========================================================================
MAIN ACTIONS
===========================================================================]]--

--[[---------------------------------------------------------------------------
The main function that runs when player started moving.
It DECIDES whether to restore a (lost) pet, or summoning a new one (if the timer is set and due).
---------------------------------------------------------------------------]]--

function ns.AutoAction()
	if not ns.db.enable then return end
	petVerified = true
	local actpet = C_PetJournal.GetSummonedPetGUID()
	if IsExcluded(actpet) then return end
	if ns.db.timer ~= 0 and lastCall + ns.db.timer * 60 < GetTime() then
		ns:debugprintL2("AutoAction() has run and decided for New Pet.")
		ns:NewPet(actpet)
	elseif not actpet then
		ns:debugprintL2("AutoAction() has run and decided to Restore Pet.")
		ns:RestorePet(actpet)
	end
end

--[[---------------------------------------------------------------------------
RESTORE: Pet is lost --> restore it
---------------------------------------------------------------------------]]--

function ns:RestorePet()
	if GetTime() - lastSummonTime < 2 then return end
	if GetTime() - lastAutoRestoreRunTime < 2 then return end
	if ns.dbc.cfavs_enabled then
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
	if not poolInitialized then
		ns:InitializePool()
	end
	local n = #petPool
	local newpet
	if n == 0 then
		MsgLowPetPool(n)
		if not actpet then ns:RestorePet() end
	else
		if n == 1 then
			newpet = petPool[1]
		else
			repeat
				newpet = petPool[math.random(n)]
			until actpet ~= newpet
		end
		ns:SafeSummon(newpet)
		MsgNewPetDone(newpet, n)
	end
	lastCall = GetTime()
end


--[[---------------------------------------------------------------------------
MANUAL SUMMON of the previously summoned pet
---------------------------------------------------------------------------]]--

function ns.ManualSummonPrevious()
	if ns.dbc.cfavs_enabled then
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
	if not ns.db.enable then return end
	petVerified = true
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if ns.dbc.cfavs_enabled then
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
SAVING: Save a newly summoned pet, no matter how it was summoned. Should run with the COMPANION_UPDATE event.
---------------------------------------------------------------------------]]--

function ns.SavePet()
	savePetDelay = savePetNormalDelay
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if not actualPet or IsExcluded(actualPet) or (GetTime() - lastSavePetTime < 1) or not petVerified then
		return
	end
	if ns.dbc.cfavs_enabled then
		if ns.dbc.currentPet == actualPet then return end
		ns.dbc.previousPet = ns.dbc.currentPet
		ns.dbc.currentPet = actualPet
	else
		if ns.db.currentPet == actualPet then return end
		ns.db.previousPet = ns.db.currentPet
		ns.db.currentPet = actualPet
	end
	ns:debugprintL2("SavePet() has run")
	lastSavePetTime = GetTime()
end


--[[---------------------------------------------------------------------------
SAFE-SUMMON: Used in the AutoSummon function, and currently also in the Manual Summon function
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
	if #petPool <= 1 and ns.db.timer ~= 0 and poolMsgLockout < GetTime() then
		MsgLowPetPool(#petPool)
		poolMsgLockout = GetTime() + 15
	end
end


-- Largely unaltered code from NugMiniPet
function ns.CFavsUpdate()
	local enable = ns.dbc.cfavs_enabled
	if enable then
		C_PetJournal.PetIsFavorite1 = C_PetJournal.PetIsFavorite1 or C_PetJournal.PetIsFavorite
		C_PetJournal.SetFavorite1 = C_PetJournal.SetFavorite1 or C_PetJournal.SetFavorite
		C_PetJournal.GetPetInfoByIndex1 = C_PetJournal.GetPetInfoByIndex1 or C_PetJournal.GetPetInfoByIndex
		C_PetJournal.PetIsFavorite = function(petGUID)
			return ns.dbc.cfavs[petGUID] or false
		end
		C_PetJournal.SetFavorite = function(petGUID, new)
			if new == 1 then
				ns.dbc.cfavs[petGUID] = true
			else
				ns.dbc.cfavs[petGUID] = nil
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
	local activePetGUID = C_PetJournal.GetSummonedPetGUID()
	if activePetGUID then
		C_PetJournal.SummonPetByGUID(activePetGUID);
	end
	ns.db.enable = false
	if ns.Auto_Button then ns.Auto_Button:SetChecked(ns.db.enable) end
	DEFAULT_CHAT_FRAME:AddMessage("Pet dismissed and auto-summon "..(ns.db.enable and "enabled" or "disabled"),0,1,0.7)
end

function ns:AutoToggle()
	ns.db.enable = not ns.db.enable
	if ns.Auto_Button then ns.Auto_Button:SetChecked(ns.db.enable) end
	DEFAULT_CHAT_FRAME:AddMessage("Pet auto-summon "..(ns.db.enable and "enabled" or "disabled"),0,1,0.7)
end

function ns:FavsToggle()
	ns.db.favsOnly = not ns.db.favsOnly
	poolInitialized = false
	DEFAULT_CHAT_FRAME:AddMessage("Selection pool: "..(ns.db.favsOnly and "favorites only" or "all pets"),0,1,0.7)
end

function ns.CharFavsSlashToggle() -- for slash command only
	ns.dbc.cfavs_enabled = not ns.dbc.cfavs_enabled
	ns:CFavsUpdate()
	DEFAULT_CHAT_FRAME:AddMessage("Character-specific favorites "..(ns.dbc.cfavs_enabled and "enabled" or "disabled"),0,1,0.7)
end

function ns.DebugModeToggle() -- for slash command only
	ns.db.debugmode = not ns.db.debugmode
	DEFAULT_CHAT_FRAME:AddMessage("Debug mode "..(ns.db.debugmode and "enabled" or "disabled"),0,1,0.7)
end

function ns:TimerSlashCmd(value)
	value = tonumber(value)
	if value >= 0 and value < 1000 then
		ns.db.timer = value
	--			ns.TimerEditBox:SetText(ns.db.timer) -- only needed for GUI edit box, which is currently disabled
	DEFAULT_CHAT_FRAME:AddMessage(ns.db.timer == 0 and "Summon timer disabled" or "Summoning a new pet every " .. ns.db.timer .. " minutes",0,1,0.7)
	end
end

-- Used for info print
function ns:ListCharFavs()
	local charFavsNames = {}
	local count = 0
	for id, _ in pairs(ns.dbc.cfavs) do
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
	local text = "\nPetWalker Status:\n  Auto-summon is " .. (ns.db.enable and "enabled" or "disabled") .. "\n  Summon timer is " .. (ns.db.timer > 0 and ns.db.timer .. " minutes" .. " - Next random pet in " .. ns.RemainingTimer() or "disbled") .. "\n  Selection pool is set to " .. (ns.db.favsOnly and "favorites only" or "all pets") .. "\n  Character-specific favorites are " .. (ns.dbc.cfavs_enabled and "enabled" or "disabled") .. " for " .. thisChar .. "\n  " .. ns:ListCharFavs()
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
	f:SetChecked(ns.dbc.cfavs_enabled)
	f:SetScript("OnClick",function(self,button)
		ns.dbc.cfavs_enabled = not ns.dbc.cfavs_enabled
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
	local index = 1
	while true do
		local petID, _, _, _, _, _, _, name = C_PetJournal.GetPetInfoByIndex(index)
		if not petID then break end
		if petID == id then
			return name
		end
		index = index + 1
	end
end


function ns:DebugDisplay()
	DEFAULT_CHAT_FRAME:AddMessage("\nDebug:\n  Current pet: " .. (ns.PetIDtoName(ns.db.currentPet) or "-none-") .. "\n  Previous pet: " .. (ns.PetIDtoName(ns.db.previousPet) or "-none-") .. "\n  Current char pet: " .. (ns.PetIDtoName(ns.dbc.currentPet) or "-none-") .. "\n  Previous char pet: " .. (ns.PetIDtoName(ns.dbc.previousPet) or "-none-") .. "\n" .. ns.Status(),0,1,0.7)
end

-- without pet info
function ns:debugprintL1(msg)
if not ns.db.debugmode then return end
	print("\n|cffFFA500### PETWALKER DEBUG: " .. msg .. " ###")
end

-- with pet info
function ns:debugprintL2(msg)
if not ns.db.debugmode then return end
	print("\n|cffFFA500### PETWALKER DEBUG: " .. msg .. " ### Current DB pet: " .. tostring(ns.PetIDtoName(ns.dbc.cfavs and ns.dbc.currentPet or ns.dbc.currentPet)) .. " ###")
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
	local rem = lastCall + ns.db.timer * 60 - GetTime()
	rem = rem > 0 and rem or 0
	return SecToMin(rem)
end
