PetKeeper = CreateFrame("Frame","PetKeeper")

PetKeeper:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)
PetKeeper:RegisterEvent("ADDON_LOADED")

BINDING_HEADER_PETKEEPER = "PetKeeper"
BINDING_NAME_PETKEEPERAUTOTOGGLE = "Toggle Auto-summoning"
BINDING_NAME_PETKEEPERMANUALSUMMON = "Summon New Pet"
BINDING_NAME_PETKEEPEROFF = "Dismiss Pet and Disable Auto-summoning"

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

function PetKeeper.ADDON_LOADED(self,event,arg1)
	if arg1 == "PetKeeper" then
		PetKeeperCharDB = PetKeeperCharDB or {}
		PetKeeperDB = PetKeeperDB  or {}
		PetKeeperCharDB.cfavs = PetKeeperCharDB.cfavs or {}
		if PetKeeperCharDB.cfavs_enabled == nil then PetKeeperCharDB.cfavs_enabled = false end
		PetKeeperDB.timer = PetKeeperDB.timer or 0
		PetKeeperDB.favsOnly = (PetKeeperDB.favsOnly == nil) and true or PetKeeperDB.favsOnly
		PetKeeperDB.enable = (PetKeeperDB.enable == nil) and true or PetKeeperDB.enable

		lastCall = GetTime() + 20
		savePetDelay = savePetLoginDelay

		-- Is this needed?
		-- Seems we also get - sometimes - a COMPANION_UPDATE event after login (which triggers a SavePet()). Also it doesn't find the variables from the DB, if run too early. So, this is difficult to time, and also depends on the load time of the char.
		-- So, let's try with PLAYER_ENTERING_WORLD:
-- 		self:RegisterEvent("PLAYER_ENTERING_WORLD")
-- 		self.PLAYER_ENTERING_WORLD = PetKeeper.LoginCheck
		C_Timer.After(16, function() PetKeeper.LoginCheck() end)

		self:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
		self.PET_JOURNAL_LIST_UPDATE = self.InitializePool

		PetKeeper:CFavsUpdate()

		-- this event basically is only needed for the timed summon
		self:RegisterEvent("PLAYER_STARTED_MOVING")
		self.PLAYER_STARTED_MOVING = PetKeeper.AutoAction

		-- experimental: for not-much-moving chars at the auction house
		self:RegisterEvent("PLAYER_STARTED_LOOKING")
		function PetKeeper.PLAYER_STARTED_LOOKING(self,event)
			local zone = GetMinimapZoneText()
			if zone == 'Booty Bay' then
				PetKeeper.AutoAction()
			end
		end

		self:RegisterEvent("COMPANION_UPDATE")
		function PetKeeper.COMPANION_UPDATE(self,event,arg1)
			if arg1 == "CRITTER" then
			C_Timer.After(savePetDelay, function() PetKeeper.SavePet() end)
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

-- 		PetKeeper.Auto_Button = self:CreateAutoCheckBox()
		PetKeeper.CFavs_Button = self:CreateCfavsCheckBox()
-- 		PetKeeper.Timer_EditBox = self:CreateTimerEditBox()
		hooksecurefunc("CollectionsJournal_UpdateSelectedTab", function(self)
			local selected = PanelTemplates_GetSelectedTab(self);
			if selected == 2 then
-- 				PetKeeper.Auto_Button:Show()
				PetKeeper.CFavs_Button:Show()
-- 				PetKeeper.Timer_EditBox:Show()
			else
-- 				PetKeeper.Auto_Button:Hide()
				PetKeeper.CFavs_Button:Hide()
-- 				PetKeeper.Timer_EditBox:ClearFocus()
-- 				PetKeeper.Timer_EditBox:Hide()
			end
		end)
	end
end


--------------------------------------------------------------------------------
-- Main Functions
--------------------------------------------------------------------------------


-- pet is lost --> restore prev one
function PetKeeper.AutoRestore()
-- 	PetKeeper:dbp("AutoRestore() was called")
-- 	if not poolInitialized then PetKeeper:InitializePool() end
	if not PetKeeperDB.enable then return end
	if GetTime() - lastSummonTime < 2 then return end
	if GetTime() - lastAutoRestoreRunTime < 2 then return end
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if not actualPet then
		if PetKeeperCharDB.cfavs_enabled then
			PetKeeper:SafeSummon(PetKeeperCharDB.currentPet)
		else
			PetKeeper:SafeSummon(PetKeeperDB.currentPet)
		end
	end
	PetKeeper:dbp("AutoRestore() has run")
	lastAutoRestoreRunTime = GetTime()
end

--[=[
function PetKeeper.AutoRestore() -- extended version
-- 	if not poolInitialized then PetKeeper:InitializePool() end
	if not PetKeeperDB.enable then return end
	if GetTime() - lastSummonTime < 0.5 then return end
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if PetKeeperCharDB.cfavs_enabled then
		if not actualPet or actualPet ~=  PetKeeperCharDB.currentPet then
			PetKeeper:SafeSummon(PetKeeperCharDB.currentPet)
		end
	else
		if not actualPet or actualPet ~=  PetKeeperDB.currentPet then
			PetKeeper:SafeSummon(PetKeeperDB.currentPet)
		end
	end
	PetKeeper:dbp("AutoRestore() has run")
	lastSummonTime = GetTime()
end
--]=]

-- After login, try to restore the same pat as the last logged-in char had active
function PetKeeper.LoginCheck()
-- 	if not poolInitialized then PetKeeper:InitializePool() end
	if not PetKeeperDB.enable then return end
	petVerified = true
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if PetKeeperCharDB.cfavs_enabled then
		if not actualPet or actualPet ~= PetKeeperCharDB.currentPet then
			PetKeeper:SafeSummon(PetKeeperCharDB.currentPet)
		end
	else
		if not actualPet or actualPet ~= PetKeeperDB.currentPet then
			PetKeeper:SafeSummon(PetKeeperDB.currentPet)
		end
	end
	PetKeeper:dbp("LoginCheck() has run")
end

-- timed summoning of a new pet from the pool
function PetKeeper.AutoAction()
-- 	PetKeeper:dbp("AutoAction() was called")
	if not PetKeeperDB.enable then return end
	petVerified = true
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	local timerDue
	if PetKeeperDB.timer ~= 0 then
		if lastCall + PetKeeperDB.timer * 60 < GetTime() then
			timerDue = true
		end
	end
	if not actualPet or timerDue then
		PetKeeper:dbp("AutoAction() has run")
		if not timerDue then
			PetKeeper.AutoRestore()
		else
			PetKeeper.AutoNew()
		end
	end
end

function PetKeeper.AutoNew()
	if not poolInitialized then PetKeeper:InitializePool() end
	local newPet = PetKeeper:Shuffle()
	if newPet == actualPet then return end
	if newPet and (lastCall+1.5 < GetTime()) then
		lastCall = GetTime()
		PetKeeper:SafeSummon(newPet)
	end
end

function PetKeeper.SavePet()
	savePetDelay = savePetNormalDelay
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	if not actualPet or (GetTime() - lastSavePetTime < 1) or not petVerified then return end
	if PetKeeperCharDB.cfavs_enabled then
		if PetKeeperCharDB.currentPet == actualPet then return end
		PetKeeperCharDB.previousPet = PetKeeperCharDB.currentPet
		PetKeeperCharDB.currentPet = actualPet
	else
		if PetKeeperDB.currentPet == actualPet then return end
		PetKeeperDB.previousPet = PetKeeperDB.currentPet
		PetKeeperDB.currentPet = actualPet
	end
	PetKeeper:dbp("SavePet() has run")
	lastSavePetTime = GetTime()
end


--- SafeSummon -----------------------------------------------------------------

local function FindAura(unit, spellID, filter)
	for i=1, 100 do
		-- rank will be removed in bfa
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, auraSpellID = UnitAura(unit, i, filter)
		if not name then return nil end
		if spellID == auraSpellID then
			return name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, auraSpellID
		end
	end
end


local function InMythicKeystone()
	local name, instanceType, difficultyID = GetInstanceInfo()
	return instanceType == "party" and difficultyID == 8
end

local function InArena()
	local name, instanceType, difficultyID = GetInstanceInfo()
	return instanceType == "arena"
end


function PetKeeper:SafeSummon(pet)
	if not pet then return end
-- Probably not covered: casting a longish pre-pull spell, still out of combat and aggro. Pet-summoning could interrupt this(?). Acc. to wowpedia it is not covered by "UnitAffectingCombat"
	if not UnitAffectingCombat("player")
-- 		and not IsMounted() -- testing if this is needed
		and not IsFlying()
		and not UnitHasVehicleUI("player")
		and not (UnitIsControlling("player") and UnitChannelInfo("player")) -- If player is mind-controlling
		and not IsStealthed()
		and not UnitIsGhost("player")
		and not FindAura("player",199483,"HELPFUL") -- Camouflage
		and not FindAura("player",32612,"HELPFUL") -- Invisibility
		and not FindAura("player",110960,"HELPFUL") -- Geater Invisibility
		and not FindAura("player",311796,"HELPFUL") -- Daisy
		and not InMythicKeystone()
		and not InArena()
	then
		C_PetJournal.SummonPetByGUID(pet)
		PetKeeper:dbp("SafeSummon() has summoned \"" .. (PetKeeper.PetGUIDtoName(pet) or "-NONE-") .. "\" ")
		lastSummonTime = GetTime()
-- 		PetKeeper.SavePet() -- already done with the event directly
	end
end


--------------------------------------------------------------------------------
-- Manual Summon
--------------------------------------------------------------------------------

function PetKeeper.ManualSummonNew()
	if not poolInitialized then PetKeeper:InitializePool() end
	local newPet, maxFavs
	local actualPet = C_PetJournal.GetSummonedPetGUID()
	repeat
		newPet, maxFavs = PetKeeper:Shuffle()
	until not actualPet or newPet ~= actualPet or maxFavs < 2
	if actualPet == newPet then return end
	lastCall = GetTime()
	C_PetJournal.SummonPetByGUID(newPet)
	lastSummonTime = lastCall
	PetKeeper:dbp("ManualSummonNew() has summoned \"" .. PetKeeper.PetGUIDtoName(newPet) .. "\" ")
end

function PetKeeper.ManualSummonPrevious()
-- 	if not poolInitialized then PetKeeper:InitializePool() end
	if PetKeeperCharDB.cfavs_enabled then
		C_PetJournal.SummonPetByGUID(PetKeeperCharDB.previousPet)
	else
		C_PetJournal.SummonPetByGUID(PetKeeperDB.previousPet)
	end
	lastCall = GetTime()
	--PetKeeper.SavePet() -- already with the event
	lastSummonTime = lastCall
end


--------------------------------------------------------------------------------
-- Pool
--------------------------------------------------------------------------------

function PetKeeper.InitializePool(self)
	table.wipe(petPool)
	local index = 1
	while true do
		local petGUID, speciesID, isOwned, customName, level, favorite,
			 isRevoked, name, icon, petType, creatureID, sourceText,
			 description, isWildPet, canBattle = C_PetJournal.GetPetInfoByIndex(index);
		if not petGUID then break end
		if PetKeeperDB.favsOnly then
			if favorite then
				table.insert(petPool, petGUID)
			end
		else
			table.insert(petPool, petGUID)
		end
		index = index + 1
	end
	poolInitialized = true  -- added this bc otherwise the query makes no sense
end


function PetKeeper.CFavsUpdate()
	local enable = PetKeeperCharDB.cfavs_enabled
	if enable then
		C_PetJournal.PetIsFavorite1 = C_PetJournal.PetIsFavorite1 or C_PetJournal.PetIsFavorite
		C_PetJournal.SetFavorite1 = C_PetJournal.SetFavorite1 or C_PetJournal.SetFavorite
		C_PetJournal.GetPetInfoByIndex1 = C_PetJournal.GetPetInfoByIndex1 or C_PetJournal.GetPetInfoByIndex
		C_PetJournal.PetIsFavorite = function(petGUID)
			return PetKeeperCharDB.cfavs[petGUID] or false
		end
		C_PetJournal.SetFavorite = function(petGUID, new)
			if new == 1 then
				PetKeeperCharDB.cfavs[petGUID] = true
			else
				PetKeeperCharDB.cfavs[petGUID] = nil
			end
			if PetJournal then PetJournal_OnEvent(PetJournal, "PET_JOURNAL_LIST_UPDATE") end
			PetKeeper:PET_JOURNAL_LIST_UPDATE()
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
	PetKeeper:PET_JOURNAL_LIST_UPDATE()
end


function PetKeeper.Shuffle(self)
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

function PetKeeper:DismissAndDisable()
	local activePetGUID = C_PetJournal.GetSummonedPetGUID()
	if activePetGUID then
		C_PetJournal.SummonPetByGUID(activePetGUID);
	end
	PetKeeperDB.enable = false
	if PetKeeper.Auto_Button then PetKeeper.Auto_Button:SetChecked(PetKeeperDB.enable) end
	DEFAULT_CHAT_FRAME:AddMessage("Pet dismissed and auto-summon "..(PetKeeperDB.enable and "enabled" or "disabled"),0,1,0.7)
end

function PetKeeper:AutoToggle()
	PetKeeperDB.enable = not PetKeeperDB.enable
	if PetKeeper.Auto_Button then PetKeeper.Auto_Button:SetChecked(PetKeeperDB.enable) end
	DEFAULT_CHAT_FRAME:AddMessage("Pet auto-summon "..(PetKeeperDB.enable and "enabled" or "disabled"),0,1,0.7)
end

function PetKeeper:FavsToggle()
	PetKeeperDB.favsOnly = not PetKeeperDB.favsOnly
	poolInitialized = false
	DEFAULT_CHAT_FRAME:AddMessage("Selection pool: "..(PetKeeperDB.favsOnly and "favorites only" or "all pets"),0,1,0.7)
end

function PetKeeper:CharFavsSlashToggle() -- for slash command only
	PetKeeperCharDB.cfavs_enabled = not PetKeeperCharDB.cfavs_enabled
	PetKeeper:CFavsUpdate()
	PetKeeper.CharFavsCheckBox:SetChecked(PetKeeperCharDB.cfavs_enabled)
	DEFAULT_CHAT_FRAME:AddMessage("Character-specific favorites "..(PetKeeperCharDB.cfavs_enabled and "enabled" or "disabled"),0,1,0.7)
end

function PetKeeper:TimerSlashCmd(value)
	value = tonumber(value)
	if value >= 0 and value < 1000 then
		PetKeeperDB.timer = value
	-- 			PetKeeper.TimerEditBox:SetText(PetKeeperDB.timer) -- only needed for GUI edit box, which is currently disabled
	DEFAULT_CHAT_FRAME:AddMessage(PetKeeperDB.timer == 0 and "Summon timer disabled" or "Summoning a new pet every " .. PetKeeperDB.timer .. " minutes",0,1,0.7)
	end
end

-- Used for info print
function PetKeeper:ListCharFavs()
	local charFavsNames = {}
	local count = 0
	for id, _ in pairs(PetKeeperCharDB.cfavs) do
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

function PetKeeper.Status()
	local text = "\nPetKeeper Status:\n  Auto-summoning is " .. (PetKeeperDB.enable and "enabled" or "disabled") .. "\n  Summon timer is " .. (PetKeeperDB.timer > 0 and PetKeeperDB.timer .. " minutes" or "disbled") .. "\n  Selection pool is set to " .. (PetKeeperDB.favsOnly and "favorites only" or "all pets") .. "\n  Character-specific favorites are " .. (PetKeeperCharDB.cfavs_enabled and "enabled" or "disabled") .. " for " .. thisChar .. "\n  " .. PetKeeper:ListCharFavs()
	return text
end

SLASH_PetKeeper1, SLASH_PetKeeper2 = '/pk', '/petk'
function SlashCmdList.PetKeeper(cmd)
	if cmd == 'd' or cmd == 'dis' then
		PetKeeper:DismissAndDisable()
	elseif cmd == 'db' or cmd == 'debug' then
		PetKeeper:DebugDisplay()
	elseif cmd == 'a' or cmd == 'auto' then
		PetKeeper:AutoToggle()
	elseif cmd == 'n' or cmd == 'new' then
		PetKeeper:ManualSummon()
	elseif cmd == 'f' or cmd == 'fav' then
		PetKeeper:FavsToggle()
	elseif cmd == 'c' or cmd == 'char' then
		PetKeeper:CharFavsSlashToggle()
	elseif cmd == 'p' or cmd == 'prev' then
		PetKeeper.ManualSummonPrevious()
	elseif cmd == 's' or cmd == 'status' then
		DEFAULT_CHAT_FRAME:AddMessage(PetKeeper.Status(),0,1,0.7)
	elseif tonumber(cmd) then
		PetKeeper:TimerSlashCmd(cmd)
	elseif cmd == 'h' or cmd == 'help' then
		DEFAULT_CHAT_FRAME:AddMessage(helpText,0,1,0.7)
	elseif cmd == '' then
		DEFAULT_CHAT_FRAME:AddMessage(PetKeeper.Status() .. helpText,0,1,0.7)
	else
		DEFAULT_CHAT_FRAME:AddMessage("PetKeeper: Invalid command or/and arguments. Enter '/pk help' for a list of commands.", 0,1,0.7)
	end
end


--------------------------------------------------------------------------------
-- Disabled GUI stuff for Pet Journal
--------------------------------------------------------------------------------

-- We disabled most of the GUI stuff, since now we have more settings than we can fit there. We leave the CharFavorites checkbox, because it makes sense to see at a glance (in the opened Pet Journal) which type of favs are enabled.

function PetKeeper.CreateCheckBoxBase(self)
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

--[=[
function PetKeeper.CreateAutoCheckBox(self)
	local f, label = self:CreateCheckBoxBase()

	f:SetPoint("BOTTOMLEFT",PetJournal,"BOTTOMLEFT",290,1)
	f:SetChecked(PetKeeperDB.enable)
	f:SetScript("OnClick",function(self,button)
		PetKeeperDB.enable = not PetKeeperDB.enable
	end)
	f:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText("PetKeeper\nEnable/Disable Autosummon\n\nCtrlClick : Mark as favorite", nil, nil, nil, nil, 1);
		GameTooltip:Show();
	end)
	label:SetText("Auto")
	return f
end
--]=]

function PetKeeper.CreateCfavsCheckBox(self)
	local f, label = self:CreateCheckBoxBase()
	PetKeeper.CharFavsCheckBox = f -- Need this for the slash command
	f:SetPoint("BOTTOMLEFT",PetJournal,"BOTTOMLEFT",400,1)
	f:SetChecked(PetKeeperCharDB.cfavs_enabled)
	f:SetScript("OnClick",function(self,button)
		PetKeeperCharDB.cfavs_enabled = not PetKeeperCharDB.cfavs_enabled
		PetKeeper:CFavsUpdate()
	end)
	f:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText("Toggle character-specific favorites", nil, nil, nil, nil, 1);
		GameTooltip:Show();
	end)
	label:SetText("Character favorites")
	return f
end


--[=[
function PetKeeper.CreateTimerEditBox()
	local f = CreateFrame("EditBox",nil, PetJournal,"InputBoxTemplate")
	PetKeeper.TimerEditBox = f -- Need this for the slash command
	f:SetWidth(30)
	f:SetHeight(15)
	f:SetAutoFocus(false)
	f:SetMaxLetters(3)
	f:SetText(PetKeeperDB.timer)
	f:SetPoint("BOTTOMLEFT",PetJournal,"BOTTOMLEFT",355,6)
	f:SetScript("OnEnterPressed", function(self)
		if tonumber(self:GetText()) then
			PetKeeperDB.timer = tonumber(self:GetText())
		end
		self:ClearFocus()
	end)
	f:SetScript("OnEscapePressed", function(self)
		self:SetText(PetKeeperDB.timer)
		self:ClearFocus()
	end)

	f:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText("Summon new pet every X minutes\n0 = Disabled", nil, nil, nil, nil, 1);
		GameTooltip:Show();
	end)
	f:SetScript("OnLeave",function(self)
		GameTooltip:Hide();
	end)

	local label	 =	f:CreateFontString(nil, "OVERLAY")
	label:SetFontObject("GameFontNormal")
	label:SetPoint("LEFT",f,"RIGHT",1,0)
	label:SetText("m")

	return f
end
--]=]


--------------------------------------------------------------------------------
-- Debugging
--------------------------------------------------------------------------------

function PetKeeper.PetGUIDtoName(guid)
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

function PetKeeper:DebugDisplay()
	DEFAULT_CHAT_FRAME:AddMessage("\nDebug:\n  Current pet: " .. (PetKeeper.PetGUIDtoName(PetKeeperDB.currentPet) or "-none-") .. "\n  Previous pet: " .. (PetKeeper.PetGUIDtoName(PetKeeperDB.previousPet) or "-none-") .. "\n  Current char pet: " .. (PetKeeper.PetGUIDtoName(PetKeeperCharDB.currentPet) or "-none-") .. "\n  Previous char pet: " .. (PetKeeper.PetGUIDtoName(PetKeeperCharDB.previousPet) or "-none-") .. "\n" .. PetKeeper.Status(),0,1,0.7)
end

-- with pet info
---[=[
function PetKeeper:dbp(msg)
	print("\n|cffFFA500--- PETKEEPER DEBUG: " .. msg .. " - Current DB pet: " .. (PetKeeper.PetGUIDtoName(PetKeeperDB.currentPet) or "-none-"))
end
--]=]

-- without pet info
--[=[
function PetKeeper:dbp(msg)
	print("\n|cffFFA500--- PETKEEPER DEBUG: " .. msg)
end
--]=]
