local addonName, ns = ...
-- _G[addonName] = ns -- Debug
local dbVersion = 1
local _

ns.events = CreateFrame("Frame")

ns.events:SetScript("OnEvent", function(self, event, ...)
	if ns[event] then
		ns[event](self,...)
	end
end)

-- ns.events:RegisterEvent("ADDON_LOADED")
ns.events:RegisterEvent("PLAYER_LOGIN")

--[[---------------------------------------------------------------------------
For the Bindings file
---------------------------------------------------------------------------]]--

BINDING_HEADER_THISADDON = addonName
BINDING_NAME_AUTO = "Toggle Auto-summon"
BINDING_NAME_NEW = "Summon New Pet"
BINDING_NAME_DISMISS = "Dismiss Pet & Disable Auto-summon"

function F86D9DE5C_814D_4EEA_A84B_CB9BE07756BE()
	ns:AutoToggle()
end
function F849A3D45_B1BD_4CA8_BA29_6DD2A8B78470()
	ns:NewPet(C_PetJournal.GetSummonedPetGUID())
end
function F76DE57DF_295D_40B4_B8CE_E45A3DF02C18()
	ns:DismissAndDisable()
end

--[[===========================================================================
Some Variables
===========================================================================]]--

ns.petPool = {}
ns.poolInitialized = false
local petVerified = false
local lastSummonTime = 0
local lastAutoRestoreRunTime = 0
local lastSavePetTime = 0
local lastPoolMsgTime = 0
local lastPlayerCastTime = 0

--[[
TODO: Maybe add the self-unsummoning pets, like the different Snowman
(repeatedly auto-resummoning the Snowman during summer could be considered an
act of barbarity :)
]]
local excludedSpecies = {
	280, -- Guild Page, Alliance -- Pet is vendor and has CD
	281, -- Guild Page, Horde -- Pet is vendor and has CD
	282, -- Guild Herald, Alliance-- Pet is vendor and has CD
	283, -- Guild Herald, Horde-- Pet is vendor and has CD
-- 	214, -- Argent Squire -- Should be safe (Pony Bridle achiev: 3736)
-- 	216, -- Argent Gruntling -- Should be safe
-- 	2403, Dummy ID for debugging! Keep this out-commented!
}


--[[===========================================================================
LOADING
===========================================================================]]--

function ns:PLAYER_LOGIN()

--[[---------------------------------------------------------------------------
Init
---------------------------------------------------------------------------]]--

	PetWalkerDB = PetWalkerDB or {}
	PetWalkerPerCharDB = PetWalkerPerCharDB or {}
	ns.db, ns.dbc = PetWalkerDB, PetWalkerPerCharDB
	ns.db.dbVersion  = dbVersion

	ns.dbc.dbVersion = ns.db.dbVersion
	ns.db.autoEnabled = ns.db.autoEnabled == nil and true or ns.db.autoEnabled
	ns.db.newPetTimer = ns.db.newPetTimer or 12
	ns.db.lastNewPetTime = ns.db.lastNewPetTime or 0
	ns.db.favsOnly = ns.db.favsOnly == nil and true or ns.db.favsOnly
	ns.dbc.charFavsEnabled = ns.dbc.charFavsEnabled or false
	ns.dbc.charFavs = ns.dbc.charFavs or {}
	ns.dbc.eventAlt = ns.dbc.eventAlt or false
	ns.db.debugMode = ns.db.debugMode or false

	if not ns.db.dbVersion or ns.db.dbVersion ~= dbVersion then
		table.wipe(ns.db)
	end
	if not ns.dbc.dbVersion or ns.dbc.dbVersion ~= dbVersion then
		local tmpCharFavs = ns.dbc.charFavs -- charFavs
		table.wipe(ns.dbc)
		ns.dbc.charFavs = tmpCharFavs
	end

--[[
	Is this needed?
	Seems we also get - sometimes - a COMPANION_UPDATE event after login
	(which triggers a SavePet()). Also it doesn't find the variables from
	the ns.db, if run too early. So, this is difficult to time, and also
	depends on the load time of the char.
	]]
	ns.events:RegisterEvent("PLAYER_ENTERING_WORLD")
	function ns.PLAYER_ENTERING_WORLD()
		C_Timer.After(2, ns.LoginCheck)
		ns:CFavsUpdate()
	end


	--[[
	This thing fires very often
	Let's do a test:
	Unset the 'isInitialized' var with that event, and initialize only when
	needed, that is before selecting a random pet.
	--> This seems to work, so far!
	]]
	ns.events:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
	function ns.PET_JOURNAL_LIST_UPDATE()
		ns.poolInitialized = false
		ns:debugprintL1("ns.PET_JOURNAL_LIST_UPDATE has run. ns.poolInitialized =="
		.. tostring(ns.poolInitialized))
	end


	if ns.dbc.eventAlt then
		ns.events:RegisterEvent("PLAYER_STARTED_LOOKING")
		function ns:PLAYER_STARTED_LOOKING()
			ns.AutoAction()
		end
	else
		ns.events:RegisterEvent("PLAYER_STARTED_MOVING")
		function ns:PLAYER_STARTED_MOVING()
			ns.AutoAction()
		end
	end

--[[ What we are trying to do here ]]--[[
COMPANION_UPDATE can be pretty spammy. So, we let it fire the function only if
it comes very immediately after a UNIT_SPELLCAST_SUCCEEDED event by the player
(which is the pet summon spell). Not sure if this is economic(?)
]]

	ns.events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	function ns:UNIT_SPELLCAST_SUCCEEDED()
		if not UnitAffectingCombat("player") then lastPlayerCastTime = GetTime() end
	end

	ns.events:RegisterEvent("COMPANION_UPDATE")
	function ns:COMPANION_UPDATE(what)
		if GetTime() - lastPlayerCastTime < 0.2 and what == "CRITTER" then
		C_Timer.After(1, ns.SavePet)
		end
	end


--[[---------------------------------------------------------------------------
Pet Journal
---------------------------------------------------------------------------]]--

-- TODO: the same for Rematch
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
	ns.CFavs_Button = ns:CreateCfavsCheckBox()
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



--[[===========================================================================
MAIN ACTIONS
===========================================================================]]--

local debugflag = "blank"

--[[ To be used only in func InitializePool and IsExcludedByPetID ]]
local function IsExcludedBySpecies(spec, debugflag)
	for _, e in pairs(excludedSpecies) do
		if e == spec then
			ns:debugprintL1("Excluded pet found while doing: " .. debugflag)
			return true
		end
	end
	return false
end

--[[ To be used only in func NewPet and SavePet ]]
local function IsExcludedByPetID(id, debugflag)
	id, speciesID = '"'..id..'"', C_PetJournal.GetPetInfoByPetID(id)
	return IsExcludedBySpecies(speciesID, debugflag)
end

--[[---------------------------------------------------------------------------
The main function that runs when player started moving. It DECIDES whether to
restore a (lost) pet, or summoning a new one (if the timer is set and due).
---------------------------------------------------------------------------]]--

function ns.AutoAction()
	if not ns.db.autoEnabled then return end
	petVerified = true
	local actpet = C_PetJournal.GetSummonedPetGUID()
	if ns.db.newPetTimer ~= 0 and ns.db.lastNewPetTime + ns.db.newPetTimer * 60 < GetTime() then
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
	local now = GetTime()
	if now - lastSummonTime < 4 or now - lastAutoRestoreRunTime < 3 then return end
	if ns.dbc.charFavsEnabled then
		if ns.dbc.currentPet then
			ns:SafeSummon(ns.dbc.currentPet)
			ns.MsgAutoRestoreDone(ns.dbc.currentPet)
		else
			ns.MsgNoSavedPet()
		end
	elseif ns.db.currentPet then
		ns:SafeSummon(ns.db.currentPet)
		ns.MsgAutoRestoreDone(ns.db.currentPet)
	else
		ns.MsgNoSavedPet()
	end
	ns:debugprintL1("AutoRestore() has run")
	lastAutoRestoreRunTime = now
end


--[[---------------------------------------------------------------------------
NEW PET SUMMON: Runs when timer is due
---------------------------------------------------------------------------]]--
-- Called by 3: ns.AutoAction, NewPet keybind, NewPet slash command

function ns:NewPet(actpet)
	local now = GetTime()
	if now - ns.db.lastNewPetTime < 1.5 then return end
	ns.db.lastNewPetTime = now
	debugflag = "NewPet" -- TODO: remove this and the flag in the func
	if actpet and IsExcludedByPetID(actpet, debugflag) then return end
	if not ns.poolInitialized then
		ns:debugprintL1("ns.NewPet --> InitializePool")
		ns.InitializePool()
	end
	local npool = #ns.petPool
	local newpet
	if npool == 0 then
		ns.MsgLowPetPool(npool)
		if not actpet then ns:RestorePet() end
	else
		if npool == 1 then
			newpet = ns.petPool[1]
			if actpet == newpet then
				ns.MsgOnlyFavIsActive(actpet)
				return
			end
		else
			repeat
				newpet = ns.petPool[math.random(npool)]
			until actpet ~= newpet
		end
				ns.MsgNewPetDone(actpet, newpet, npool)
		ns:SafeSummon(newpet)
	end
end


--[[---------------------------------------------------------------------------
MANUAL SUMMON of the previously summoned pet
---------------------------------------------------------------------------]]--

function ns.PreviousPet()
	local prevpet
	if ns.dbc.charFavsEnabled then
		prevpet = ns.dbc.previousPet
	else
		prevpet = ns.db.previousPet
	end
	ns.db.lastNewPetTime = GetTime()
	ns:SafeSummon(prevpet)
end


--[[---------------------------------------------------------------------------
One time action, somewhere AFTER LOGIN. Try to restore the same pat as the last
logged-in char had active.
---------------------------------------------------------------------------]]--

-- Called by 1: ns:PLAYER_LOGIN()

function ns.LoginCheck()
	if not ns.db.autoEnabled then return end
	petVerified = true
	local actpet = C_PetJournal.GetSummonedPetGUID()
	if ns.dbc.charFavsEnabled then
		if not actpet or actpet ~= ns.dbc.currentPet then
			ns:SafeSummon(ns.dbc.currentPet)
		end
	else
		if not actpet or actpet ~= ns.db.currentPet then
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
	local actpet = C_PetJournal.GetSummonedPetGUID()
	local now = GetTime()
	debugflag = "SavePet" -- TODO: remove this and the flag in the func
	if not actpet
		or IsExcludedByPetID(actpet, debugflag)
		or now - lastSavePetTime < 3
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
	lastSavePetTime = now
end


--[[---------------------------------------------------------------------------
SAFE-SUMMON: Used in the AutoSummon function, and currently also in the
Manual Summon function
---------------------------------------------------------------------------]]--

local excludedAuras = {
	32612, -- Mage: Invisibility
	110960, -- Mage: Greater Invisibility
	131347, -- DH: Gliding
	311796, -- Pet: Daisy as backpack (/beckon)
	5384, -- Hunter: Feign Death (useful to avoid accidental summoning via keybind, or if we use a different event than PLAYER_STARTED_MOVING)
} -- More exclusions in the Summon function itself

local function OfflimitsAura(auras)
	for _, a in pairs(auras) do
		if GetPlayerAuraBySpellID(a) then
			ns:debugprintL1("Excluded Aura found!")
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
		and not IsStealthed() -- Includes Hunter Camouflage
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
— All available pets (except the exclusions). Note that this is affected by the
  filter settings in the Pet Journal, which means the player can create custom
  pools without changing his favorites.
===========================================================================]]--

-- Called by 3: PET_JOURNAL_LIST_UPDATE; conditionally by ns:NewPet, ns.ManualSummonNew
function ns.InitializePool(self)
	ns:debugprintL1("Running ns.InitializePool()")
	local debugflag = "InitializePool"
	table.wipe(ns.petPool)
	local index = 1
	while true do
		local petID, speciesID, _, _, _, favorite = C_PetJournal.GetPetInfoByIndex(index)
		if not petID then break end
		if not IsExcludedBySpecies(speciesID, debugflag) then
			if ns.db.favsOnly then
				if favorite then
					table.insert(ns.petPool, petID)
				end
			else
				table.insert(ns.petPool, petID)
			end
		end
		index = index + 1
	end
	ns.poolInitialized = true -- Condition in ns:NewPet and ns.ManualSummonNew
	local now = GetTime()
	if #ns.petPool <= 1 and ns.db.newPetTimer ~= 0 and now - lastPoolMsgTime > 30 then
		ns.MsgLowPetPool(#ns.petPool)
		lastPoolMsgTime = now
	end
end


--[[===========================================================================
Char Favs
===========================================================================]]--

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
GUI stuff for Pet Journal
===========================================================================]]--

--[[
We disabled most of the GUI elements, since now we have more settings than we
can fit there. We leave the CharFavorites checkbox, because it makes sense to
see at a glance (in the opened Pet Journal) which type of favs are enabled.
]]

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
if not id then return "<nil> from PetIDtoName" end
-- 	local id, name = '"'..id..'"', select(8, C_PetJournal.GetPetInfoByPetID(id))
	local name = select(8, C_PetJournal.GetPetInfoByPetID(id))
	return name
end

function ns.PetIDtoLink(id)
if not id then return "<nil> from PetIDtoLink" end
	local link = C_PetJournal.GetBattlePetLink(id)
	return link
end


function ns:DebugDisplay()
	ns.Status()
	DEFAULT_CHAT_FRAME:AddMessage("Debug:\n  DB current pet: " ..
	(ns.PetIDtoName(ns.db.currentPet) or "<nil>") ..
	"\n  DB previous pet: " .. (ns.PetIDtoName(ns.db.previousPet) or "<nil>") ..
	"\n  Char DB current pet: " .. (ns.PetIDtoName(ns.dbc.currentPet) or "<nil>") ..
	"\n  Char DB previous pet: " .. (ns.PetIDtoName(ns.dbc.previousPet) or "<nil>") .. "\n" ,0,1,0.7)
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
	local rem = ns.db.lastNewPetTime + ns.db.newPetTimer * 60 - GetTime()
	rem = rem > 0 and rem or 0
	return SecToMin(rem)
end
