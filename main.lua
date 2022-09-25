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

ns.events:RegisterEvent("ADDON_LOADED")

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
	ns:NewPet()
end
function F76DE57DF_295D_40B4_B8CE_E45A3DF02C18()
	ns:DismissAndDisable()
end

--[[===========================================================================
Some Variables
===========================================================================]]--

ns.petPool = {}
ns.poolInitialized = false
--[[ This prevents the "wrong" active pet from being saved. We get a "wrong" pet
mainly after login, if the game summons the last active pet on this toon,
instead of the last saved pet in our DB (which can be the last active pet of the
alt we just logged out). Caution, to not lock out manually summoned pets from
being saved. ]]
ns.petVerified = false
local timeSafeSummonFailed = 0
--[[ Last time AutoRestore() was called. ]]
local timeRestorePet = 0
local timeSavePet = 0
local timePoolMsg = 0
local timePlayerCast = 0
local timeTransitionCheck = 0

local excludedSpecies = {
--[[  Pet is vendor and goes on CD when summoned ]]
	280, -- Guild Page, Alliance
	281, -- Guild Page, Horde
	282, -- Guild Herald, Alliance
	283, -- Guild Herald, Horde
--[[ Pet is vendor/bank/mail, if the char has the Pony Bridle achiev (ID 3736).
But it should be safe, bc CD starts only after activating the ability via dialog. ]]
-- 	214, -- Argent Squire (Alliance)
-- 	216, -- Argent Gruntling (Horde)
--[[ Self-unspawns outside of Weinter Veil. Makes no sense summoning these. ]]
	1349, -- Rotten Little Helper
	117, -- Tiny Snowman
	119, -- Father Winter's Helper
	120, -- Winter's Little Helper
--[[ Pocopoc is special: he cannot be summoned in Zereth Mortis (1970)).
See the extra checks in IsExcludedBySpecies() and TransitionCheck(). ]]
	3247, -- Pocopoc
--[[ Dummy ID for debugging! Keep this commented out! ]]
-- 2403,
}


--[[===========================================================================
LOADING
===========================================================================]]--

function ns.ADDON_LOADED(_, addon)

	if addon == addonName then

--[[---------------------------------------------------------------------------
Init
---------------------------------------------------------------------------]]--

		PetWalkerDB = PetWalkerDB or {}
		PetWalkerPerCharDB = PetWalkerPerCharDB or {}
		ns.db, ns.dbc = PetWalkerDB, PetWalkerPerCharDB
		ns.db.dbVersion  = dbVersion

		ns.dbc.dbVersion = ns.db.dbVersion
		ns.db.autoEnabled = ns.db.autoEnabled == nil and true or ns.db.autoEnabled
		ns.db.newPetTimer = ns.db.newPetTimer or 720
		ns.db.remainingTimer = ns.db.remainingTimer or 360
		ns.db.favsOnly = ns.db.favsOnly == nil and true or ns.db.favsOnly
		ns.dbc.charFavsEnabled = ns.dbc.charFavsEnabled or false
		ns.dbc.charFavs = ns.dbc.charFavs or {}
		ns.dbc.eventAlt = ns.dbc.eventAlt or false
		ns.db.debugMode = ns.db.debugMode or false
		ns.db.verbosityLevel = ns.db.verbosityLevel or 3

		if not ns.db.dbVersion or ns.db.dbVersion ~= dbVersion then
			table.wipe(ns.db)
		end
		if not ns.dbc.dbVersion or ns.dbc.dbVersion ~= dbVersion then
			local tmpCharFavs = ns.dbc.charFavs -- charFavs
			table.wipe(ns.dbc)
			ns.dbc.charFavs = tmpCharFavs
		end

		ns.timeNewPetSuccess = GetTime() - (ns.db.newPetTimer - ns.db.remainingTimer)

		--[[
		Two suitable events here:
		1) PLAYER_ENTERING_WORLD and 2) ZONE_CHANGED_NEW_AREA
		Still not sure which one is better:
		1) needs a significant delay (min 8s timer), due to unpredictable rest
		load time at login (after the event).
		2) fires later (which is good), but also fires when we do not really
		need it, and it does _not_ fire in all cases where 1) is fired (bad). 2
		or 3s timer is OK.
		In any case, we should make sure to be out of the loading process here,
		otherwise we might unsummon our - not yet spawned - pet.
		]]
		ns.events:RegisterEvent("PLAYER_ENTERING_WORLD")
		function ns.PLAYER_ENTERING_WORLD()
			--[[ To prevent saving the wrong pet if we get an arbitrary
			COMPANION_UPDATE before the TransitionCheck could summon a pet ]]
			ns.petVerified = false
			C_Timer.After(10, ns.TransitionCheck)
		end

		--[[
		This thing fires very often
		Let's do a test:
		Unset the 'poolInitialized' var with that event, and initialize only when
		needed, that is before selecting a random pet.
		--> This seems to work, so far!
		]]
		ns.events:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
		function ns.PET_JOURNAL_LIST_UPDATE()
			ns.poolInitialized = false
-- 			ns:debugprintL1("ns.PET_JOURNAL_LIST_UPDATE has run. ns.poolInitialized =="
-- 			.. tostring(ns.poolInitialized))
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
			if ns.db.autoEnabled and not UnitAffectingCombat("player") then
				timePlayerCast = GetTime()
			end
		end

		ns.events:RegisterEvent("COMPANION_UPDATE")
		function ns:COMPANION_UPDATE(what)
			if ns.db.autoEnabled and what == "CRITTER" and GetTime() - timePlayerCast < 0.2 then
				ns.SavePet()
-- 				C_Timer.After(1, ns.SavePet)
			end
		end

		ns.events:RegisterEvent("PLAYER_LOGOUT")
		function ns:PLAYER_LOGOUT()
			ns.db.remainingTimer = ns.RemainingTimer(GetTime())
		end


	elseif addon == "Blizzard_Collections" then
--[[---------------------------------------------------------------------------
Pet Journal
---------------------------------------------------------------------------]]--

		ns.events:UnregisterEvent("ADDON_LOADED")

	-- TODO: the same for Rematch
		for i, btn in ipairs(PetJournal.listScroll.buttons) do
			btn:SetScript("OnClick",function(self, button)
				--[[ Windows is lacking the Cmd (Meta) key, so we need Ctrl too.
				TODO: Find a way to detect the OS. ]]
				if IsMetaKeyDown() or IsControlKeyDown() then
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

		ns:CFavsUpdate()

	end
end



--[[===========================================================================
MAIN ACTIONS
===========================================================================]]--

local debugflag = "blank"

--[[ To be used only in func InitializePool and IsExcludedByPetID ]]
local function IsExcludedBySpecies(spec, debugflag)
	for _, e in pairs(excludedSpecies) do
		if e == spec then
			if e ~= 3247 or ns.currentZone == 1970 then -- Pocopoc
-- 				ns:debugprintL1("Excluded pet found while doing: " .. debugflag)
				return true
			end
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
	if not ns.db.autoEnabled or IsMounted() then return end -- was: IsFlying
	if ns.db.newPetTimer ~= 0 then
		local now = GetTime()
		if ns.RemainingTimer(now) == 0 and now - timeSafeSummonFailed > 40 then
			ns:debugprintL2("AutoAction() decided for NewPet.")
			ns:NewPet(now)
			return
		end
	end
	if not ns.petVerified then ns.TransitionCheck() return end
	local actpet = C_PetJournal.GetSummonedPetGUID()
	if not actpet then
		ns:debugprintL2("AutoAction() decided for RestorePet.")
		ns:RestorePet()
	end
end

--[[---------------------------------------------------------------------------
RESTORE: Pet is lost --> restore it.
To be called only by AutoAction func!
No need to check against the current pet, since by definition, if we do have a
pet out, then it must be the correct one.
---------------------------------------------------------------------------]]--

function ns:RestorePet()
	local now = GetTime()
	if now - timeSafeSummonFailed < 10 or now - timeRestorePet < 3 then return end
	local savedpet
	if ns.dbc.charFavsEnabled and ns.db.favsOnly then
		savedpet = ns.dbc.currentPet
	else
		savedpet = ns.db.currentPet
	end
	timeRestorePet = now
	if savedpet then
		ns:debugprintL1("RestorePet() is restoring saved pet")
		ns.SetSumMsgToRestorePet(savedpet)
		ns:SafeSummon(savedpet, false)
	else
		ns:debugprintL1("RestorePet() could not find saved pet --> summoning new pet")
		ns.MsgNoSavedPet()
		ns:NewPet()
	end
end


--[[---------------------------------------------------------------------------
NEW PET SUMMON: Runs when timer is due
---------------------------------------------------------------------------]]--
-- Called by: ns.AutoAction, ns.TransitionCheck, NewPet keybind, NewPet slash command

function ns:NewPet(time)
	local now = time or GetTime()
	if now - ns.timeNewPetSuccess < 1.5 then return end
	local actpet = C_PetJournal.GetSummonedPetGUID()
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
		ns.SetSumMsgToNewPet(actpet, newpet, npool)
		ns:SafeSummon(newpet, true)
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
	ns.SetSumMsgToPreviousPet(prevpet)
	ns:SafeSummon(prevpet, true)
end


--[[---------------------------------------------------------------------------
One time action, after big transitions, like login, portals, entering instance,
etc. Basically a standalone RestorePet func; in addition, it not only checks for
presence of a pet, but also against the saved pet.
This makes sure that a newly logged toon gets the same pet as the previous
toon had at logout.
We need more checks here than in RestorePet, bc RestorePet is "prefiltered" by
AutoAction, and here we are not.
---------------------------------------------------------------------------]]--

-- Called by 1: ns:ZONE_CHANGED_NEW_AREA(), or whatever we use as initial event

function ns.TransitionCheck()
	if not ns.db.autoEnabled
		or ns.petVerified
		or IsFlying()
		or UnitOnTaxi("player") then
		ns:debugprintL1("TransitionCheck() returned early")
		return
	end
	local now = GetTime()
	--[[ If toon starts moving immediately after transition, then RestorePet
	might come before us. Also prevents redundant run in case we use both events
	NEW_AREA and ENTERING_WORLD. ]]
	if now - timeRestorePet < 6 then return end
	ns.currentZone = C_Map.GetBestMapForUnit("player")
	local savedpet
	local actpet = C_PetJournal.GetSummonedPetGUID()
	if ns.dbc.charFavsEnabled and ns.db.favsOnly then
		if not actpet or actpet ~= ns.dbc.currentPet then
			savedpet = ns.dbc.currentPet
		end
	elseif not actpet or actpet ~= ns.db.currentPet then
		savedpet = ns.db.currentPet
	end
	if ns.currentZone == 1970 then -- Pocopoc issue
		if ns.PetIDtoSpecies(savedpet) == 3247 or ns.PetIDtoSpecies(actpet) == 3247 then
			savedpet = ns.db.previousPet
		end
	end
	if savedpet then
		ns:debugprintL1("TransitionCheck() is restoring saved pet")
		ns.SetSumMsgToTransCheck(savedpet)
		ns:SafeSummon(savedpet, false)
	--[[ Should only come into play if savedpet is still nil due to a slow
	loading process ]]
	elseif not actpet then
		ns:debugprintL1("TransitionCheck() could not find saved pet --> summoning new pet")
		ns.MsgNoSavedPet()
		ns:NewPet()
	end
	timeRestorePet = now
	--[[ This is not 100% reliable here, but should do the trick most of the time. ]]
	ns.petVerified = true
	ns:debugprintL1("TransitionCheck() complete")
end


--[[---------------------------------------------------------------------------
SAVING: Save a newly summoned pet, no matter how it was summoned.
Should run with the COMPANION_UPDATE event.
---------------------------------------------------------------------------]]--

--[[ TODO: Issue here: When loading a team via Rematch and Rematch's option
"restore pet that was active before selecting activating a team" is selected,
then we need to do this:
Do not save the wrong pet (summoned by selecting a team.
Do save the pet resummoned by Rematch.
Since it seems impossible to distinguish the pet summoning due to a team
selection from any normal pet summoning, we have to save both pets, hence a CD
for SavePet is detrimental.
Deselecting Rematch's restore option would make things not better. Unlesss: We
can determine if a pet was selected thru teams. It seems Rematch can do this.
Check the code.

So, for the moment: Trying without SavePet CD. Also check the C_Timer at the event.
]]
function ns.SavePet()
	if not ns.petVerified then return end
	local actpet = C_PetJournal.GetSummonedPetGUID()
-- 	local now = GetTime()
	debugflag = "SavePet" -- TODO: remove this and the flag in the func
	if not actpet
-- 		or now - timeSavePet < 3
		or IsExcludedByPetID(actpet, debugflag) then
		return
	end
	if ns.dbc.charFavsEnabled and ns.db.favsOnly then
		if ns.dbc.currentPet == actpet then return end
		ns.dbc.previousPet = ns.dbc.currentPet
		ns.dbc.currentPet = actpet
	else
		if ns.db.currentPet == actpet then return end
		ns.db.previousPet = ns.db.currentPet
		ns.db.currentPet = actpet
	end
	ns:debugprintL2("SavePet() has run")
-- 	timeSavePet = now
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
	312993, -- Carrying Forbidden Tomes (Scrivener Lenua event, Revendreth)
	43880, -- Ramstein's Swift Work Ram (Brewfest daily; important bc the quest cannot be restarted if messed up)
	43883, -- Rental Racing Ram (Brewfest daily)
	5384, -- Hunter: Feign Death (only useful to avoid accidental summoning via keybind, or if we use a different event than PLAYER_STARTED_MOVING)
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

-- Called by: RestorePet, TransitionCheck, NewPet, PreviousPet
function ns:SafeSummon(pet, resettimer)
	if not pet then -- TODO: needed?
		ns:debugprintL1("SafeSummon was called without 'pet' argument!")
		return
	end
	local now = GetTime()
	if not UnitAffectingCombat("player")
--		and not IsMounted() -- Not needed
		--[[ 'IsFlying()' is checked in AutoAction and TransitionCheck, for
		early return from any event-triggered action. Since it seems to be
		impossible to summon while flying, we don't need it here or in the
		manual summon functions. ]]
		and not OfflimitsAura(excludedAuras)
		and not IsStealthed() -- Includes Hunter Camouflage
		and not (UnitIsControlling("player") and UnitChannelInfo("player"))
		and not UnitHasVehicleUI("player")
		and not UnitIsGhost("player")
		and not InMythicKeystone()
		and not InArena()
	then
		ns.petVerified = true
		if resettimer then ns.timeNewPetSuccess = now end
		ns.MsgPetSummonSuccess()
		C_PetJournal.SummonPetByGUID(pet)
	else
-- 		ns.MsgPetSummonFailed() -- Too spammy, remove that
		timeSafeSummonFailed = now
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
	if #ns.petPool <= 1 and ns.db.newPetTimer ~= 0 and now - timePoolMsg > 30 then
		ns.MsgLowPetPool(#ns.petPool)
		timePoolMsg = now
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

	local label = f:CreateFontString(nil, "OVERLAY")
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
		GameTooltip:SetText(addonName .. ": Select this to use per-character favorites. \nFor more info, enter '/pw' in the chat console.", nil, nil, nil, nil, 1);
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

function ns.PetIDtoSpecies(id)
if not id then return "<nil> from PetIDtoSpecies" end
	local spec = C_PetJournal.GetPetInfoByPetID(id)
	return spec
end

function ns.PetIDtoLink(id)
if not id then return "<nil> from PetIDtoLink" end
	local link = C_PetJournal.GetBattlePetLink(id)
	return link
end


function ns:DebugDisplay()
	ns.Status()
	print("|cffEE82EEDebug:\n  DB current pet: ",
	(ns.PetIDtoName(ns.db.currentPet) or "<nil>"),
	"\n  DB previous pet: ", (ns.PetIDtoName(ns.db.previousPet) or "<nil>"),
	"\n  Char DB current pet: ", (ns.PetIDtoName(ns.dbc.currentPet) or "<nil>"),
	"\n  Char DB previous pet: ", (ns.PetIDtoName(ns.dbc.previousPet) or "<nil>"),
	"\n  ns.petVerified: ", ns.petVerified, "\n")
end

-- without pet info
function ns:debugprintL1(msg)
	if ns.db.debugMode then
		print("\n|cffEE82EE# PETWALKER DEBUG: " .. (msg or "<nil>") .. " #")
	end
end

-- with pet info
function ns:debugprintL2(msg)
	if ns.db.debugMode then
		print("\n|cffEE82EE# PETWALKER DEBUG: " .. (msg or "<nil>") .. " ### Current DB pet: " .. (ns.PetIDtoName(((ns.dbc.charFavs and ns.db.favsOnly) and ns.dbc.currentPet or ns.db.currentPet)) or "<nil>") .. " #")
	end
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

function ns.RemainingTimer(time)
	local rem = ns.timeNewPetSuccess + ns.db.newPetTimer - time
	return rem > 0 and rem or 0
end

-- Seconds to minutes
local function SecToMin(seconds)
	local min, sec = tostring(math.floor(seconds / 60)), tostring(seconds % 60)
	return string.format('%.0f:%02.0f', min, sec)
end

function ns.RemainingTimerForDisplay()
	local rem = ns.timeNewPetSuccess + ns.db.newPetTimer - GetTime()
	rem = rem > 0 and rem or 0
	return SecToMin(rem)
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
