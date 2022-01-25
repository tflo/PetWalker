local addonName, ns = ...

ns.db = PetWalkerDB
ns.dbc = PetWalkerPerCharDB

ns = CreateFrame("Frame","PetKeeper")

ns:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)
ns:RegisterEvent("ADDON_LOADED")

BINDING_HEADER_ThisAddon = addonName
BINDING_NAME_Auto = "Toggle Auto-summon"
BINDING_NAME_Manual = "Summon New Pet"
BINDING_NAME_Dismiss = "Dismiss Pet & Disable Auto-summon"

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

-- Guild Page and Herald don't have fix IDs, so we have to go by speciesID
-- TODO: We must also make sure that we do not unsummon these pets via AutoRestore or AutoNew. The Guild pets despawn automatically, so we can simply check if they are there, but the Argent Tourny pet should be treated differently: CD activates only if we access the bank, and it is also a valid pet for random favorite summons. Difficult. But maybe we should just give him a fix live time of 20 min or so? Or just hope that the user disables PetKeeper when he accesses the bank? Or maybe check for the pony bridle achiev and not autosummon /autounsummon him then? (GetAchievementInfo)
-- --> make two categories of petspeciesIDs: 'doNotSummon' and 'doNotUnsummon'.
-- TODO: check the Hordies speciesID
local excludedSpecies = {
	280, -- Guild Page
	282, -- Guild Herald
}
-- TODO: What about Feign Death?!
local excludedAuras = {
	32612, -- Mage: Invisibility
	110960, -- Mage: Greater Invisibility
	131347, -- DH: Gliding
	311796, -- Pet: Daisy as backpack (/beckon)
} -- More exclusions in the Summon function itself

function ns.ADDON_LOADED(self,event,arg1)
	if arg1 == addonName then
		ns.dbc = ns.dbc or {}
		ns.db = ns.db  or {}
		ns.dbc.cfavs = ns.dbc.cfavs or {}
		if ns.dbc.cfavs_enabled == nil then ns.dbc.cfavs_enabled = false end
		ns.db.timer = ns.db.timer or 0
		ns.db.favsOnly = (ns.db.favsOnly == nil) and true or ns.db.favsOnly
		ns.db.enable = (ns.db.enable == nil) and true or ns.db.enable

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

		-- this event basically is only needed for the timed summon
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


--------------------------------------------------------------------------------
-- Main Functions
--------------------------------------------------------------------------------


-- pet is lost --> restore prev one
function ns.AutoRestore()
--	ns:dbpp("AutoRestore() was called")
--	if not poolInitialized then ns:InitializePool() end
	if not ns.db.enable then return end
	if GetTime() - lastSummonTime < 2 then return end
	if GetTime() - lastAutoRestoreRunTime < 2 then return end
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if not actualPet then
		if ns.dbc.cfavs_enabled then
			ns:SafeSummon(ns.dbc.currentPet)
		else
			ns:SafeSummon(ns.db.currentPet)
		end
	end
	ns:dbpp("AutoRestore() has run")
	lastAutoRestoreRunTime = GetTime()
end

--[=[
function ns.AutoRestore() -- extended version
--	if not poolInitialized then ns:InitializePool() end
	if not ns.db.enable then return end
	if GetTime() - lastSummonTime < 0.5 then return end
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if ns.dbc.cfavs_enabled then
		if not actualPet or actualPet ~=  ns.dbc.currentPet then
			ns:SafeSummon(ns.dbc.currentPet)
		end
	else
		if not actualPet or actualPet ~=  ns.db.currentPet then
			ns:SafeSummon(ns.db.currentPet)
		end
	end
	ns:dbpp("AutoRestore() has run")
	lastSummonTime = GetTime()
end
--]=]

-- After login, try to restore the same pat as the last logged-in char had active
function ns.LoginCheck()
--	if not poolInitialized then ns:InitializePool() end
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
	ns:dbpp("LoginCheck() has run")
end

-- timed summoning of a new pet from the pool
function ns.AutoAction()
--	ns:dbpp("AutoAction() was called")
	if not ns.db.enable then return end
	petVerified = true
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	local timerDue
	if ns.db.timer ~= 0 then
		if lastCall + ns.db.timer * 60 < GetTime() then
			timerDue = true
		end
	end
	if not actualPet or timerDue then
		ns:dbpp("AutoAction() has run")
		if not timerDue then
			ns.AutoRestore()
		else
			ns.AutoNew()
		end
	end
end

function ns.AutoNew()
	if not poolInitialized then ns:InitializePool() end
	local newPet = ns:Shuffle()
	if newPet == actualPet then return end
	if newPet and (lastCall+1.5 < GetTime()) then
		lastCall = GetTime()
		ns:SafeSummon(newPet)
	end
end

function ns.SavePet()
	savePetDelay = savePetNormalDelay
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if not actualPet or (GetTime() - lastSavePetTime < 1) or not petVerified then return end
	if ns.dbc.cfavs_enabled then
		if ns.dbc.currentPet == actualPet then return end
		ns.dbc.previousPet = ns.dbc.currentPet
		ns.dbc.currentPet = actualPet
	else
		if ns.db.currentPet == actualPet then return end
		ns.db.previousPet = ns.db.currentPet
		ns.db.currentPet = actualPet
	end
	ns:dbpp("SavePet() has run")
	lastSavePetTime = GetTime()
end


--- SafeSummon -----------------------------------------------------------------

local function InMythicKeystone()
	local _, instanceType, difficultyID = GetInstanceInfo()
	-- TODO: instanceType redundant if we query for difficultyID?
	return instanceType == "party" and difficultyID == 8
end

local function InArena()
	local _, instanceType = IsInInstance()
	return instanceType == "arena"
end

local function OfflimitsAura(auras)
	for _, a in pairs(auras) do
		if GetPlayerAuraBySpellID(a) then
			ns.dbp("Excluded Aura found!")
			return true
		end
	end
	return false
end

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
		ns:dbpp("SafeSummon() has summoned \"" .. (ns.PetGUIDtoName(pet) or "-NONE-") .. "\" ")
		lastSummonTime = GetTime()
--		ns.SavePet() -- already done with the event directly
	end
end


--------------------------------------------------------------------------------
-- Manual Summon
--------------------------------------------------------------------------------

function ns.ManualSummonNew()
	if not poolInitialized then ns:InitializePool() end
	local newPet, maxFavs
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	repeat
		newPet, maxFavs = ns:Shuffle()
	until not actualPet or newPet ~= actualPet or maxFavs < 2
	if actualPet == newPet then return end
	lastCall = GetTime()
	ns:SafeSummon(newPet)
-- 	C_PetJournal.SummonPetByGUID(newPet)
	lastSummonTime = lastCall
	ns:dbpp("ManualSummonNew() has summoned \"" .. ns.PetGUIDtoName(newPet) .. "\" ")
end

function ns.ManualSummonPrevious()
--	if not poolInitialized then ns:InitializePool() end
	if ns.dbc.cfavs_enabled then
		C_PetJournal.SummonPetByGUID(ns.dbc.previousPet)
	else
		C_PetJournal.SummonPetByGUID(ns.db.previousPet)
	end
	lastCall = GetTime()
	--ns.SavePet() -- already with the event
	lastSummonTime = lastCall
end


--------------------------------------------------------------------------------
-- Pool
--------------------------------------------------------------------------------

local function IsExcluded(species)
	for _, s in pairs(excludedSpecies) do
		if s == species then
			ns:dbp("Excluded pet found!")
			return true
		end
	end
	return false
end

function ns.InitializePool(self)
	table.wipe(petPool)
	local index = 1
	while true do
		local petID, speciesID, _, _, _, favorite = C_PetJournal.GetPetInfoByIndex(index)
		if not petID then break end
		if ns.db.favsOnly then
			if favorite and not IsExcluded(speciesID) then
				table.insert(petPool, petID)
			end
		else
			if not IsExcluded(speciesID) then
				table.insert(petPool, petID)
			end
		end
		index = index + 1
	end
	poolInitialized = true	-- added this bc otherwise the query makes no sense
end


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


function ns.Shuffle(self)
	local maxn = #petPool
	local random
	if maxn == 1 then
		random = petPool[1]
	elseif maxn > 1 then
		repeat
			random = petPool[math.random(maxn)]
		until C_PetJournal.GetSummonedPetGUID() ~= random
	end
	return random, maxn
end


--------------------------------------------------------------------------------
-- Toggles, Commands
--------------------------------------------------------------------------------

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


--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

local helpText = "\nPetKeeper Help: '/pk' or '/petk' supports these commands:\n  d: Dismiss current pet and disable auto-summoning\n  a: Toggle auto-summoning\n  n: Summon new pet from pool\n  f: Toggle selection pool: favorites only, or all pets\n  c: Toggle character-specific favorites, or global\n  <number>: Summon timer in minutes (1 to 999, 0 to disable)\n  p: Summon previous pet\n  s: Display current status/settings\n  h: This help text\nIn Key Bindigs > AddOns you can directly bind some commands."

function ns.Status()
	local text = "\nPetKeeper Status:\n  Auto-summoning is " .. (ns.db.enable and "enabled" or "disabled") .. "\n  Summon timer is " .. (ns.db.timer > 0 and ns.db.timer .. " minutes" or "disbled") .. "\n  Selection pool is set to " .. (ns.db.favsOnly and "favorites only" or "all pets") .. "\n  Character-specific favorites are " .. (ns.dbc.cfavs_enabled and "enabled" or "disabled") .. " for " .. thisChar .. "\n " .. ns:ListCharFavs()
	return text
end

SLASH_PetKeeper1, SLASH_PetKeeper2 = '/pk', '/petk'
function SlashCmdList.PetKeeper(cmd)
	if cmd == 'd' or cmd == 'dis' then
		ns:DismissAndDisable()
	elseif cmd == 'db' or cmd == 'deb' then
		ns:DebugDisplay()
	elseif cmd == 'a' or cmd == 'auto' then
		ns:AutoToggle()
	elseif cmd == 'n' or cmd == 'new' then
		ns:ManualSummonNew()
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


--------------------------------------------------------------------------------
-- GUI stuff for Pet Journal
--------------------------------------------------------------------------------

-- We disabled most of the GUI stuff, since now we have more settings than we can fit there. We leave the CharFavorites checkbox, because it makes sense to see at a glance (in the opened Pet Journal) which type of favs are enabled.

function ns.CreateCheckBoxBase(self)
	local f = CreateFrame("CheckButton", "PetKeeperAutoCheckbox",PetJournal,"UICheckButtonTemplate")
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


--------------------------------------------------------------------------------
-- Debugging
--------------------------------------------------------------------------------

function ns.PetGUIDtoName(guid)
	local index = 1
	while true do
		local petGUID, _, _, _, _, _, _, name = C_PetJournal.GetPetInfoByIndex(index)
		if not petGUID then break end
		if petGUID == guid then
			return name
		end
		index = index + 1
	end
end

function ns:DebugDisplay()
	DEFAULT_CHAT_FRAME:AddMessage("\nDebug:\n  Current pet: " .. (ns.PetGUIDtoName(ns.db.currentPet) or "-none-") .. "\n  Previous pet: " .. (ns.PetGUIDtoName(ns.db.previousPet) or "-none-") .. "\n	 Current char pet: " .. (ns.PetGUIDtoName(ns.dbc.currentPet) or "-none-") .. "\n  Previous char pet: " .. (ns.PetGUIDtoName(ns.dbc.previousPet) or "-none-") .. "\n" .. ns.Status(),0,1,0.7)
end

-- with pet info
---[=[
function ns:dbpp(msg)
	print("\n|cffFFA500--- PETKEEPER DEBUG: " .. msg .. " - Current ns.db pet: " .. (ns.PetGUIDtoName(ns.db.currentPet) or "-none-"))
end
--]=]

-- without pet info
function ns:dbp(msg)
	print("\n|cffFFA500--- PETKEEPER DEBUG: " .. msg)
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
