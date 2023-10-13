local addon_name, ns = ...
-- _G[addon_name] = ns -- Debug
local db_version = 1

--[[===========================================================================
	§ API references
===========================================================================]]--

local _

local C_PetJournalPetIsFavorite = _G.C_PetJournal.PetIsFavorite
local C_PetJournalSetFavorite = _G.C_PetJournal.SetFavorite
local C_PetJournalGetPetInfoByIndex = _G.C_PetJournal.GetPetInfoByIndex

local C_PetJournalSummonPetByGUID -- We have a hook further down!
local C_PetJournalGetSummonedPetGUID = _G.C_PetJournal.GetSummonedPetGUID
local C_PetJournalGetPetInfoByPetID = _G.C_PetJournal.GetPetInfoByPetID
local C_PetJournalGetPetInfoBySpeciesID = _G.C_PetJournal.GetPetInfoBySpeciesID
local C_PetJournalFindPetIDByName = _G.C_PetJournal.FindPetIDByName
local C_PetJournalGetBattlePetLink = _G.C_PetJournal.GetBattlePetLink
local C_PetJournalGetOwnedBattlePetString = _G.C_PetJournal.GetOwnedBattlePetString
local C_PetJournalGetPetSummonInfo = _G.C_PetJournal.GetPetSummonInfo
local C_PetBattlesIsInBattle = _G.C_PetBattles.IsInBattle
local C_MapGetBestMapForUnit = _G.C_Map.GetBestMapForUnit
local C_UnitAurasGetPlayerAuraBySpellID = _G.C_UnitAuras.GetPlayerAuraBySpellID
local UnitAffectingCombat = _G.UnitAffectingCombat
local IsFlying = _G.IsFlying
local IsMounted = _G.IsMounted
local IsAdvancedFlyableArea = _G.IsAdvancedFlyableArea
local UnitOnTaxi = _G.UnitOnTaxi
local UnitHasVehicleUI = _G.UnitHasVehicleUI
local UnitIsGhost = _G.UnitIsGhost
local UnitIsBattlePet = _G.UnitIsBattlePet
local GetInstanceInfo = _G.GetInstanceInfo
local IsInInstance = _G.IsInInstance
local IsStealthed = _G.IsStealthed
local UnitIsControlling = _G.UnitIsControlling
local UnitChannelInfo = _G.UnitChannelInfo
local GetTime = _G.GetTime


--[[===========================================================================
	§ Some Variables/Constants
===========================================================================]]--

ns.pet_pool = {}
ns.pool_initialized = false
--[[ This prevents the "wrong" active pet from being saved. We get a "wrong" pet
mainly after login, if the game summons the last active pet on this toon,
instead of the last saved pet in our DB (which can be the last active pet of the
alt we just logged out). Caution, to not lock out manually summoned pets from
being saved.
]]
ns.pet_verified = false
-- ns.skipNextSave = false
ns.in_battlesleep = false
local time_safesummon_failed = 0
--[[ Last time AutoRestore() was called. ]]
local time_restore_pet = 0
local time_save_pet = 0
local time_pool_msg = 0
local time_transitioncheck = 0
local delay_after_login = 12
local delay_after_reload = 8
local delay_after_instance = 5
local delay_login_msg = 22 -- Timer starts with ADDON_LOADED
local delay_after_battle = 15 -- Post-petbattle sleep
local instasummon_after_battlesleep = true -- Summon without waiting for trigger event
local msg_onlyfavisactive_alreadydisplayed = false
local check_against_flying = false
local time_responded_to_summoning_event = 0
local throttle_min = 3
local throttle = 0 --  throttle_min * 2
local bypass_throttle = false
local savedpet_is_summonable = true

local excluded_species = {
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
See the extra checks in is_excluded_by_species() and transitioncheck(). ]]
	3247, -- Pocopoc
--[[ Dummy ID for debugging. Keep this commented out! ]]
-- 	2403, -- Abyssal Eel
}

-- Debug
ns.time_summonspell = 0

local excluded_auras = {
	32612, -- Mage: Invisibility
	110960, -- Mage: Greater Invisibility
	131347, -- DH: Gliding -- Prolly not needed, should be caught by IsFlying() (?)
	311796, -- Pet: Daisy as backpack (/beckon)
	312993, -- Carrying Forbidden Tomes (Scrivener Lenua event, Revendreth)
	43880, -- Ramstein's Swift Work Ram (Brewfest daily; important bc the quest cannot be restarted if messed up)
	43883, -- Rental Racing Ram (Brewfest daily)
	290460, -- Battlebot Champion (Forbidden Reach: Zskera Vault)
	5384, -- Hunter: Feign Death (only useful to avoid accidental summoning via keybind, or if we use a different event than PLAYER_STARTED_MOVING)
} -- More exclusions in the Summon function itself

local function offlimits_aura()
	for _, aura in ipairs(excluded_auras) do
		if C_UnitAurasGetPlayerAuraBySpellID(aura) then
			ns:debugprint 'Excluded aura found!'
			return true
		end
	end
	return false
end

local function forbidden_instance()
	local in_instance, instance_type = IsInInstance()
	if not in_instance then return false end
	if instance_type == 'arena' then return true end
	if instance_type == 'party' then
		local _, _, difficulty_id = GetInstanceInfo()
		if difficulty_id == 8 then return true end
	end
end


-- TODO: WiP
local function forbidden_or_throttled()
	-- if not not ns.db.autoEnabled then return true end
	-- Always-active throttle
	if not bypass_throttle then
		throttle = max(throttle, throttle_min)
		local now = GetTime()
		if now - time_responded_to_summoning_event < throttle then return true end
		time_responded_to_summoning_event, throttle = now, 0
	end
	local forbidden = false
	if check_against_flying and
		-- We need these tests only at events that can occure during it
		(IsFlying() or UnitOnTaxi 'player') then
		forbidden, throttle = true, 20
	elseif forbidden_instance then
		forbidden, throttle = true, 120
	elseif UnitAffectingCombat 'player'
		or IsStealthed() -- Includes Hunter Camouflage
		or C_UnitAurasGetPlayerAuraBySpellID(32612) -- Mage: Invisibility
		or C_UnitAurasGetPlayerAuraBySpellID(110960) -- Mage: Greater Invisibility
		or C_UnitAurasGetPlayerAuraBySpellID(131347) -- DH: Gliding -- Prolly not needed, should be caught by IsFlying() (?)
		or C_UnitAurasGetPlayerAuraBySpellID(5384) -- Hunter: Feign Death (only useful to avoid accidental summoning via keybind, or if we use a different event than PLAYER_STARTED_MOVING)
		or (UnitIsControlling 'player' and UnitChannelInfo 'player')
	then
		forbidden, throttle = true, 8
	elseif UnitIsGhost 'player'
		or UnitHasVehicleUI 'player'
		or C_UnitAurasGetPlayerAuraBySpellID(311796) -- Pet: Daisy as backpack (/beckon)
		or C_UnitAurasGetPlayerAuraBySpellID(312993) -- Carrying Forbidden Tomes (Scrivener Lenua event, Revendreth)
		or C_UnitAurasGetPlayerAuraBySpellID(43880) -- Ramstein's Swift Work Ram (Brewfest daily; important bc the quest cannot be restarted if messed up)
		or C_UnitAurasGetPlayerAuraBySpellID(43883) -- Rental Racing Ram (Brewfest daily)
		or C_UnitAurasGetPlayerAuraBySpellID(290460) -- Battlebot Champion (Forbidden Reach: Zskera Vault)
	then
		forbidden, throttle = true, 40
	end
	return forbidden
end

local unsummonable_species
local player_faction = UnitFactionGroup 'player'

-- Add only pets here that are bugged, i.e. not detectable as unsummonable by `GetPetSummonInfo`.
if player_faction == 'Alliance' then
	unsummonable_species = {
		[2777] = true, -- Gillvanas
		[342] = true, -- Festival Lantern
	}
else
	unsummonable_species = {
		[2778] = true, -- Finduin
		[341] = true, -- Lunar Lantern
	}
end

local EnumPetJournalError = _G.Enum.PetJournalError
-- Couldn't find a Blizz constant for the string
-- This should match the output of C_PetJournal.GetPetSummonInfo for Enum.PetJournalError.InvalidFaction (3).
local ERROR_TEXT_WRONG_PET_FACTION = 'You are not the right faction for this companion.'

local function is_pet_summonable(guid)
	local is_summonable, error, error_text
	local species_id = ns.id_to_species(guid)
	if unsummonable_species[species_id] then
		is_summonable, error, error_text = false, EnumPetJournalError.InvalidFaction, ERROR_TEXT_WRONG_PET_FACTION
	else
		is_summonable, error, error_text = C_PetJournalGetPetSummonInfo(guid)
	end
	if not is_summonable then
		return false, error, error_text
	end
	return true
end

local function saved_pet_summonability_check() --- After login
	local priorities, perchar = {}, nil

	if ns.dbc.charFavsEnabled then
		perchar = true
		priorities = {
			ns.dbc.currentPet,
			ns.dbc.previousPet,
			ns.db.currentPet,
			ns.db.previousPet
		}
	else
		priorities = {
			ns.db.currentPet,
			ns.db.previousPet,
			ns.dbc.currentPet,
			ns.dbc.previousPet
		}
	end

	for i, guid in ipairs(priorities) do
		if guid then
			local is_summonable, error, error_text = is_pet_summonable(guid)
			if i == 1 then
				if is_summonable then return end
				ns.msg_saved_pet_unsummonable(error_text, error)
			else
				if is_summonable then
					if perchar then
						ns.dbc.currentPet = guid
					else
						ns.db.currentPet = guid
					end
					return
				end
			end
		elseif i == 1 then
			return
		end
	end
	ns.msg_previous_pet_unsummonable()
	savedpet_is_summonable = false
end


--[[---------------------------------------------------------------------------
	§ For the Bindings file
---------------------------------------------------------------------------]]--

-- BINDING_HEADER_PETWALKER = "PetWalker  "
BINDING_NAME_PETWALKER_TOGGLE_AUTO = 'Toggle Auto-Summoning'
BINDING_NAME_PETWALKER_NEW_PET = 'Summon New Pet'
BINDING_NAME_PETWALKER_TARGET_PET = 'Try to Summon Same Pet as Target'
BINDING_NAME_PETWALKER_DISMISS_PET = 'Dismiss Pet & Disable Auto-Summoning'

function PetWalker_binding_toggle_autosummon() ns:auto_toggle() end
function PetWalker_binding_new_pet() ns:new_pet(nil, true) end
function PetWalker_binding_target_pet() ns:summon_targetpet() end
function PetWalker_binding_dismiss_and_disable() ns:dismiss_and_disable() end


--[[===========================================================================
	§ Event frame
===========================================================================]]--

---@class frame Our event frame
ns.events = CreateFrame 'Frame'

ns.events:SetScript('OnEvent', function(self, event, ...)
	if ns[event] then ns[event](self, ...) end
end)

ns.events:RegisterEvent 'ADDON_LOADED'

function ns.events:register_summon_events()
	ns:debugprint 'Registering summon events.'
	if ns.db.eventAlt then -- Alt events, experimental
		--[[ Pointless if it fires while flying, which is quite often. But this doesn't harm either. ]]
		self:RegisterEvent 'ZONE_CHANGED'
		--[[ Probably good, still testing.
		Fires often together with zoneCh, but not always. ]]
		self:RegisterEvent 'ZONE_CHANGED_INDOORS'
		--[[ Good event ]]
		self:RegisterEvent 'PLAYER_MOUNT_DISPLAY_CHANGED'
		--[[ Fires pretty frequently, sometimes in quick succession. Chain-firing when posting auctions.
		Redundancy: Seems to get triggered by plEntWorld and/or zoneChNewA and/or plLogin ]]
		-- self:RegisterEvent 'BAG_UPDATE_DELAYED'
	else -- Traditional (default) event(s)
		self:RegisterEvent 'PLAYER_STARTED_MOVING'
	end
end

function ns.events:unregister_summon_events()
	ns:debugprint 'Unregistering summon events.'
	self:UnregisterEvent 'ZONE_CHANGED'
	self:UnregisterEvent 'ZONE_CHANGED_INDOORS'
	self:UnregisterEvent 'PLAYER_MOUNT_DISPLAY_CHANGED'
	self:UnregisterEvent 'PLAYER_STARTED_MOVING'
end

function ns.events:register_meta_events()
	ns:debugprint 'Registering meta events.'
	self:RegisterEvent 'PLAYER_ENTERING_WORLD'
	self:RegisterEvent 'PET_JOURNAL_LIST_UPDATE'
	self:RegisterEvent 'PET_BATTLE_OPENING_START'
	self:RegisterEvent 'PLAYER_LOGOUT'
end

function ns.events:unregister_meta_events()
	ns:debugprint 'Unregistering meta events.'
	self:UnregisterEvent 'PLAYER_ENTERING_WORLD'
	self:UnregisterEvent 'PET_JOURNAL_LIST_UPDATE'
	self:UnregisterEvent 'PET_BATTLE_OPENING_START'
	self:UnregisterEvent 'PLAYER_LOGOUT'
end

function ns.events:register_pw_events()
	ns:debugprint 'Registering PW events.'
	self:register_meta_events()
	self:register_summon_events()
end

function ns.events:unregister_pw_events()
	ns:debugprint 'Unregistering PW events (`UnregisterAllEvents`).'
	self:UnregisterAllEvents()
end

--[[===========================================================================
	§ Loading and event handlers
===========================================================================]]--

function ns:ADDON_LOADED(addon)

--[[---------------------------------------------------------------------------
	§ Our addon has loaded (init)
---------------------------------------------------------------------------]]--

	if addon == addon_name then

		PetWalkerDB = PetWalkerDB or {}
		PetWalkerPerCharDB = PetWalkerPerCharDB or {}
		ns.db, ns.dbc = PetWalkerDB, PetWalkerPerCharDB
		ns.db.dbVersion, ns.dbc.dbVersion = db_version, db_version

		ns.db.autoEnabled = ns.db.autoEnabled == nil and true or ns.db.autoEnabled
		ns.db.newPetTimer = ns.db.newPetTimer or 720
		ns.db.remainingTimer = ns.db.remainingTimer or 360
		ns.db.favsOnly = ns.db.favsOnly == nil and true or ns.db.favsOnly
		ns.dbc.charFavsEnabled = ns.dbc.charFavsEnabled or false
		ns.dbc.charFavs = ns.dbc.charFavs or {}
		ns.db.eventAlt = ns.db.eventAlt or false
		ns.db.debugMode = ns.db.debugMode or false
		ns.db.verbosityLevel = ns.db.verbosityLevel or 3
		ns.db.drSummoning = ns.db.drSummoning == nil and true or ns.db.drSummoning

		--[[
		if not ns.db.dbVersion or ns.db.dbVersion ~= db_version then table.wipe(ns.db) end
		if not ns.dbc.dbVersion or ns.dbc.dbVersion ~= db_version then
			local tmpCharFavs = ns.dbc.charFavs -- charFavs
			table.wipe(ns.dbc)
			ns.dbc.charFavs = tmpCharFavs
		end
		]]

		ns.time_newpet_success = GetTime() - (ns.db.newPetTimer - ns.db.remainingTimer)

		-- *Not* with PLAYER_ENTERING_WORLD so that it is not affected when all events get unregistered via /pw a
		C_Timer.After(delay_login_msg, ns.msg_login)
		ns:debugprint('Event: ADDON_LOADED:', addon)

--[[---------------------------------------------------------------------------
	§ Events
---------------------------------------------------------------------------]]--

		-- The summon events are now registered with transitioncheck or delayed after PLAYER_ENTERING_WORLD
		if ns.db.autoEnabled then ns.events:register_meta_events() end

		-- For transition check
		--[[ Two suitable events here:
		1) PLAYER_ENTERING_WORLD and 2) ZONE_CHANGED_NEW_AREA
		Still not sure which one is better:
		1) needs a significant delay (min 8s timer), due to unpredictable rest
		load time at login (after the event).
		2) fires later (which is good), but also fires when we do not really
		need it, and it does _not_ fire in all cases where 1) is fired (bad). 2
		or 3s timer is OK.
		In any case, we should make sure to be completely out of the loading process,
		otherwise we might unsummon our - not yet spawned - pet.
		]]
		function ns:PLAYER_ENTERING_WORLD(is_login, is_reload)
			local delay
			-- We do not want summon events before transitioncheck has finished
			ns.events:unregister_summon_events()
			if is_login then
				ns:debugprint 'Event: PLAYER_ENTERING_WORLD: Login'
				delay = delay_after_login
				-- This must run before transitioncheck
				C_Timer.After(delay - 1, saved_pet_summonability_check)
			elseif is_reload then
				ns:debugprint 'Event: PLAYER_ENTERING_WORLD: Reload'
				delay = delay_after_reload
			else
				-- Needed for zone-specific pet exclusions
				ns:debugprint 'Event: PLAYER_ENTERING_WORLD: Instance change'
				delay = delay_after_instance
			end
			ns.pet_verified = false
			-- C_Timer.After(delay, ns.transitioncheck)
			C_Timer.After(delay, function()
				ns.transitioncheck()
				-- For the moment, calling this separately, since `transitioncheck` in its current form is abortable
				ns.events:register_summon_events()
			end)
		end

		-- Regular main event
		function ns:PLAYER_STARTED_MOVING()
			if
				UnitAffectingCombat 'player'
				or IsFlying()
				or IsMounted() and IsAdvancedFlyableArea() and not ns.db.drSummoning -- API since 10.0.7
			then
				return
			end
			ns:debugprint 'Event: PLAYER_STARTED_MOVING --> autoaction'
			ns.autoaction()
		end

		-- Experimental alternative events
		function ns:ZONE_CHANGED()
			if UnitAffectingCombat 'player' or IsFlying() then return end
			ns:debugprint 'Event: ZONE_CHANGED --> autoaction'
			ns.autoaction()
		end
		function ns:ZONE_CHANGED_INDOORS()
			if UnitAffectingCombat 'player' or IsFlying() then return end
			ns:debugprint 'Event: ZONE_CHANGED_INDOORS --> autoaction'
			ns.autoaction()
		end
		function ns:PLAYER_MOUNT_DISPLAY_CHANGED()
			if UnitAffectingCombat 'player' or IsFlying() then return end
			ns:debugprint 'Event: PLAYER_MOUNT_DISPLAY_CHANGED --> autoaction'
			ns.autoaction()
		end

--[[---------------------------------------------------------------------------
	§ Pet battle and misc
---------------------------------------------------------------------------]]--

		--[[ TOOD: Check if we really have to set the flag here. We could modify autoaction() to always check against
		the saved pet if pet_verified is true. ]]
		hooksecurefunc(C_PetJournal, 'SetPetLoadOutInfo', function()
			-- Note that SetPetLoadOutInfo summons the slot pet, but it does so _not_ via SummonPetByGUID
			ns:debugprint 'Hook: SetPetLoadOutInfo --> pet_verified = false'
			ns.pet_verified = false
		end)

		hooksecurefunc(C_PetJournal, 'SummonPetByGUID', function()
			-- ns.time_summonspell = GetTime() -- Debug
			ns:debugprint('Hook: SummonPetByGUID runs; in_battlesleep: ' .. tostring(ns.in_battlesleep))
			-- 			if ns.skipNextSave then ns.skipNextSave = false return end
			if ns.in_battlesleep then return end
			ns:debugprint 'Hook: SummonPetByGUID --> register COMPANION_UPDATE'
			ns.events:RegisterEvent 'COMPANION_UPDATE' -- Timer better?
			-- 			C_Timer.After(0.2, ns.save_pet) -- 0.2 is the minimum
		end)

		C_PetJournalSummonPetByGUID = _G.C_PetJournal.SummonPetByGUID

		function ns:COMPANION_UPDATE(what)
			if what == 'CRITTER' then
				ns.events:UnregisterEvent 'COMPANION_UPDATE'
				ns:debugprint('Event: COMPANION_UPDATE (actpet: ' .. ns.id_to_name(C_PetJournalGetSummonedPetGUID()) .. ') --> save_pet')
				ns.save_pet()
			end
		end

		function ns:PET_BATTLE_OPENING_START()
			ns:debugprint 'Event: PET_BATTLE_OPENING_START --> Unregister events'
			ns.events:unregister_pw_events()
			ns.events:RegisterEvent 'PET_BATTLE_OVER' -- Alternative: PET_BATTLE_CLOSE (fires twice)
			ns.in_battlesleep = true
		end

		function ns:PET_BATTLE_OVER()
			ns:debugprint(
				format(
					'Event: PET_BATTLE_OVER --> Re-register events in %ss, unless we are in the next battle',
					delay_after_battle
				)
			)
			C_Timer.After(delay_after_battle, function()
				if C_PetBattlesIsInBattle() then return end
				ns:debugprint 'Re-registering events now'
-- 				ns.events:register_summon_events()
				ns.events:UnregisterEvent 'PET_BATTLE_OVER'
				ns.in_battlesleep = false
				ns.events:register_pw_events()
				-- Summon without waiting for trigger event
				if instasummon_after_battlesleep then ns.transitioncheck() end
			end)
		end

		--[[ This thing fires very often
		Let's do a test:
		Unset the 'pool_initialized' var with that event, and initialize only when
		needed, that is before selecting a random pet.
		--> This seems to work, so far!
		]]
		function ns:PET_JOURNAL_LIST_UPDATE()
			ns:debugprint 'Event: PET_JOURNAL_LIST_UPDATE --> pool_initialized = false'
			ns.pool_initialized = false
		end

		function ns:PLAYER_LOGOUT()
			ns:debugprint 'Event: PLAYER_LOGOUT --> remainingTimer'
			ns.db.remainingTimer = ns.remaining_timer(GetTime())
		end


--[[---------------------------------------------------------------------------
	§ Blizzard_Collections has loaded
---------------------------------------------------------------------------]]--

	elseif addon == 'Blizzard_Collections' then
		ns.events:UnregisterEvent 'ADDON_LOADED'
		--[[ -- Currently disabled due to DF changes
		-- TODO: the same for Rematch
		for i, btn in ipairs(PetJournal.listScroll.buttons) do
		for i, btn in ipairs(PetJournal.ScrollBox.ScrollTarget) do
			btn:SetScript('OnClick', function(self, button)
				if IsMetaKeyDown() or IsControlKeyDown() then
					local isFavorite = C_PetJournal.PetIsFavorite(self.petID)
					C_PetJournal.SetFavorite(self.petID, isFavorite and 0 or 1)
				else
					return PetJournalListItem_OnClick(self, button)
				end
			end)
		end
		--]]


		-- TODO: the same for Rematch
		ns.cfavs_button = ns:create_cfavs_checkbox()
		hooksecurefunc('CollectionsJournal_UpdateSelectedTab', function(self)
			local selected = PanelTemplates_GetSelectedTab(self)
			if selected == 2 then
				ns.cfavs_button:SetChecked(ns.dbc.charFavsEnabled)
				ns.cfavs_button:Show()
			else
				ns.cfavs_button:Hide()
			end
		end)

		-- TODO: This should be redundant here(?), since we do this now in the transitioncheck (v1.1.6)
		ns:cfavs_update()

	end
end


--[[===========================================================================
	§ Main actions
===========================================================================]]--

--[[ To be used only in func initialize_pool and is_excluded_by_id ]]
local function is_excluded_by_species(spec)
	for _, e in ipairs(excluded_species) do
		if e == spec then
			if e ~= 3247 or ns.current_zone == 1970 then -- Pocopoc
				return true
			end
		end
	end
	return false
end

--[[ To be used only in func new_pet and save_pet ]]
local function is_excluded_by_id(id)
	local species_id = C_PetJournalGetPetInfoByPetID(id)
	return is_excluded_by_species(species_id)
end

--[[---------------------------------------------------------------------------
	§ Auto action
	The main function that runs when player started moving. It decides whether to
	restore a lost pet, or summon a new one (if the timer is set and due).
---------------------------------------------------------------------------]]--

function ns.autoaction()
	-- 	Moved this to the event, because we use a C_Timer now if the player is mounted
	-- 	if not ns.db.autoEnabled or UnitAffectingCombat("player") then return end
	if ns.db.newPetTimer ~= 0 then
		local now = GetTime()
		if ns.remaining_timer(now) == 0 and now - time_safesummon_failed > 40 then
			ns:debugprint_pet 'autoaction decided for new_pet'
			ns:new_pet(now, false)
			return
		end
	end
	if not ns.pet_verified then
		ns:debugprint_pet 'autoaction decided for transitioncheck (pet_verified failed)'
		ns.transitioncheck()
		return
	end
	local actpet = C_PetJournalGetSummonedPetGUID()
	if not actpet then
		ns:debugprint_pet 'autoaction decided for restore_pet'
		ns:restore_pet()
	end
end

--[[---------------------------------------------------------------------------
	§ Restore pet
	Pet is lost --> restore it.
	To be called only by autoaction func!
	No need to check against the current pet, since by definition, if we do have a
	pet out, then it must be the correct one.
---------------------------------------------------------------------------]]--

function ns:restore_pet()
	local now = GetTime()
	if now - time_safesummon_failed < 10 or now - time_restore_pet < 3 then return end
	local savedpet
	if ns.dbc.charFavsEnabled and ns.db.favsOnly then
		savedpet = ns.dbc.currentPet
	else
		savedpet = ns.db.currentPet
	end
	time_restore_pet = now
	if savedpet then
		ns:debugprint 'restore_pet() is restoring saved pet'
		ns.set_sum_msg_to_restore_pet(savedpet)
		ns:safesummon(savedpet, false)
	else
		ns:debugprint 'restore_pet() could not find saved pet --> summoning new pet'
		ns.msg_no_saved_pet()
		ns:new_pet(now, false)
	end
end


--[[---------------------------------------------------------------------------
	§ New pet
	Called by autoaction when timer is due
---------------------------------------------------------------------------]]--

function ns:new_pet(time, via_hotkey)
	ns:debugprint(format('new_pet() runs with args %s / %s ', tostring(time), tostring(via_hotkey)))
	local now = time or GetTime()
	if now - ns.time_newpet_success < 1.5 then return end
	local actpet = C_PetJournalGetSummonedPetGUID()
	if actpet and is_excluded_by_id(actpet) then
		ns:debugprint 'new_pet(): actpet is excluded'
		return
	end
	if not ns.pool_initialized then
		ns:debugprint 'new_pet() --> initialize_pool'
		ns.initialize_pool()
	end
	local npool = #ns.pet_pool
	local newpet
	if npool == 0 then
		if now - time_pool_msg > 30 then
			ns.msg_low_petpool(npool)
			time_pool_msg = now
		end
		if not actpet then ns:restore_pet() end
	else
		if npool == 1 then
			newpet = ns.pet_pool[1]
			if actpet == newpet then
				if not msg_onlyfavisactive_alreadydisplayed or via_hotkey then
					ns.msg_onlyfavisactive(actpet)
					msg_onlyfavisactive_alreadydisplayed = true
				end
				return
			end
		else
			repeat
				newpet = ns.pet_pool[math.random(npool)]
			until actpet ~= newpet
		end
		ns.set_sum_msg_to_newpet(actpet, newpet, npool)
		ns:safesummon(newpet, true)
	end
end


--[[---------------------------------------------------------------------------
	§ Summon previous
---------------------------------------------------------------------------]]--

function ns.previous_pet()
	local prevpet
	if ns.dbc.charFavsEnabled then
		prevpet = ns.dbc.previousPet
	else
		prevpet = ns.db.previousPet
	end
	if prevpet then
		ns.set_sum_msg_to_previouspet(prevpet)
		ns:safesummon(prevpet, true)
	else
		ns.msg_no_previous_pet()
	end
end

--[[---------------------------------------------------------------------------
	§ Summon targeted pet
---------------------------------------------------------------------------]]--

function ns.summon_targetpet()
	if not UnitIsBattlePet 'target' then
		ns.msg_target_is_not_battlepet()
		return
	end

	local target_species_id = UnitBattlePetSpeciesID 'target'
	local target_pet_name = C_PetJournalGetPetInfoBySpeciesID(target_species_id) or ''
	local _, tarpet = C_PetJournalFindPetIDByName(target_pet_name)
	local target_pet_link = tarpet and C_PetJournalGetBattlePetLink(tarpet) or '[link: UNKNOWN]'

	if not C_PetJournalGetOwnedBattlePetString(target_species_id) then
		if not UnitIsBattlePetCompanion 'target' then
			ns.msg_target_is_not_companion_battlepet(target_pet_name)
		else
			ns.msg_target_not_in_collection(target_pet_link, target_pet_name)
		end
		return
	end

	local current_pet = C_PetJournalGetSummonedPetGUID()

	if not current_pet or C_PetJournalGetPetInfoByPetID(current_pet) ~= target_species_id then
		ns:safesummon(tarpet, true)
		ns.msg_target_summoned(target_pet_link)
	else
		ns.msg_target_is_same(target_pet_link) -- Without web link
		-- ns.msg_target_is_same(target_pet_link, target_pet_name) -- With web link
	end
end


--[[--------------------------------------------------------------------------------------------------------------------
	§ Transition check
	One time action, after big transitions, like login, portals, entering instance, etc. Basically a standalone
	restore_pet func; in addition, it not only checks for presence of a pet, but also against the saved pet. This makes
	sure that a newly logged toon gets the same pet as the previous toon had at logout. We need more checks here than
	in restore_pet, bc restore_pet is "prefiltered" by autoaction, and here we are not.
--------------------------------------------------------------------------------------------------------------------]]--

function ns.transitioncheck()
	if not ns.db.autoEnabled or ns.pet_verified or UnitAffectingCombat 'player' or IsFlying() or UnitOnTaxi 'player' then
		ns:debugprint 'transitioncheck() returned early'
		return
	end
	local now = GetTime()
	--[[ If toon starts moving immediately after transition, then restore_pet
	might come before us. Also prevents redundant run in case we use both events
	NEW_AREA and ENTERING_WORLD. ]]
	if now - time_restore_pet < 6 then return end
	ns.current_zone = C_MapGetBestMapForUnit 'player'
	local savedpet
	ns:cfavs_update()
	local actpet = C_PetJournalGetSummonedPetGUID()
	if ns.dbc.charFavsEnabled and ns.db.favsOnly then
		if not actpet or actpet ~= ns.dbc.currentPet then savedpet = ns.dbc.currentPet end
	elseif not actpet or actpet ~= ns.db.currentPet then
		savedpet = ns.db.currentPet
	end
	if ns.current_zone == 1970 then -- Pocopoc issue
		if ns.id_to_species(savedpet) == 3247 or ns.id_to_species(actpet) == 3247 then
			savedpet = ns.db.previousPet
		end
	end
	if savedpet and savedpet_is_summonable then
		ns:debugprint 'transitioncheck() is restoring saved pet'
		ns.set_sum_msg_to_transcheck(savedpet)
		ns:safesummon(savedpet, false)
	--[[ Should only come into play if savedpet is still nil due to a slow
	loading process ]]
	elseif not actpet then
		ns:debugprint 'transitioncheck() could not find saved pet --> summoning new pet'
		ns.msg_no_saved_pet()
		ns:new_pet(now, false)
	end
	time_restore_pet = now
	--[[ This is not 100% reliable here, but should do the trick most of the time. ]]
	ns.pet_verified, savedpet_is_summonable = true, true
	-- Because we are unregistering now with every type of PLAYER_ENTERING_WORLD
	-- HACK: Called separately after entering world, bc of the possible early return
	-- ns.events:register_summon_events()
	ns:debugprint 'transitioncheck() complete'
end


--[[---------------------------------------------------------------------------
	§ Save pet
	Save a newly summoned pet, no matter how it was summoned.
---------------------------------------------------------------------------]]--

function ns.save_pet()
	ns:debugprint('save_pet() runs now: ' .. (GetTime() - ns.time_summonspell))
	if not ns.pet_verified then return end
	local actpet = C_PetJournalGetSummonedPetGUID()
	-- local now = GetTime()
	if
		not actpet
		-- or now - time_save_pet < 3
		or is_excluded_by_id(actpet)
	then
		ns:debugprint 'save_pet(): No actpet or actpet is excluded'
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
	ns:debugprint_pet 'save_pet() completed'
	-- time_save_pet = now
end


--[[---------------------------------------------------------------------------
	§ Safe-summon
	Used in the AutoSummon function, and currently also in the
	Manual Summon function
---------------------------------------------------------------------------]]--


function ns:safesummon(pet, resettimer)
	if not pet then -- TODO: needed?
		ns:debugprint "safesummon was called without 'pet' argument!"
		return
	end
	if ns.db.debugMode then
		local isSummonable, error, errorText = C_PetJournalGetPetSummonInfo(pet)
		if not isSummonable then
			ns:debugprint('Pet cannot be summoned. `GetPetSummonInfo` returned', isSummonable, error, errorText)
			return
		end
	end
	-- if pet_not_summonable(pet) then return end
	local now = GetTime()
	if
		not UnitAffectingCombat 'player'
		-- and not IsMounted() -- Not needed
		--[[ 'IsFlying()' is checked in autoaction and transitioncheck, for
		early return from any event-triggered action. Since it seems to be
		impossible to summon while flying, we don't need it here or in the
		manual summon functions. ]]
		and not offlimits_aura()
		and not IsStealthed() -- Includes Hunter Camouflage
		and not (UnitIsControlling 'player' and UnitChannelInfo 'player')
		and not UnitHasVehicleUI 'player'
		and not UnitIsGhost 'player'
		and not forbidden_instance()
	then
		ns.pet_verified = true
		-- ns.skipNextSave = true
		if resettimer then ns.time_newpet_success = now end
		ns.msg_pet_summon_success()
		C_PetJournalSummonPetByGUID(pet)
	else
		-- ns.msg_pet_summon_failed() -- Too spammy, remove that
		time_safesummon_failed = now
	end
end


--[[===========================================================================
	§ Pet pool
	Creating the POOL, from where the random pet is summoned.
	This can be, depending on user setting:
	— Global favorites
	— Per-character favorites
	— All available pets (except the exclusions). Note that this is affected by the
	filter settings in the Pet Journal, which means the player can create custom
	pools without changing his favorites.
===========================================================================]]--

local function clean_charfavs()
	local count, link = 0, nil
	for id, _ in pairs(ns.dbc.charFavs) do
		link = C_PetJournalGetBattlePetLink(id)
		if not link then
			ns.dbc.charFavs[id] = nil
			count = count + 1
		end
	end
	if count > 0 then ns.msg_removed_invalid_id(count) end
end

function ns.initialize_pool(self)
	ns:debugprint 'Running initialize_pool()'
	table.wipe(ns.pet_pool)
	clean_charfavs()
	local index = 1
	while true do
		local pet_id, species_id, _, _, _, favorite = C_PetJournalGetPetInfoByIndex(index)
		if not pet_id then break end
		if not is_excluded_by_species(species_id) and is_pet_summonable(pet_id) then
			if ns.db.favsOnly then
				if favorite then table.insert(ns.pet_pool, pet_id) end
			else
				table.insert(ns.pet_pool, pet_id)
			end
		end
		index = index + 1
	end
	ns.pool_initialized = true -- Condition in ns:new_pet and ns.ManualSummonNew
	local now = GetTime()
	if #ns.pet_pool <= 0 and ns.db.newPetTimer ~= 0 and now - time_pool_msg > 30 then
		ns.msg_low_petpool(#ns.pet_pool)
		time_pool_msg = now
	end
end


--[[===========================================================================
	§ Char Favs
===========================================================================]]--

local C_PetJournalPetIsFavorite1, C_PetJournalSetFavorite1, C_PetJournalGetPetInfoByIndex1

-- Largely unaltered code from NugMiniPet
function ns.cfavs_update()
	if ns.dbc.charFavsEnabled then
		C_PetJournalPetIsFavorite1 = C_PetJournalPetIsFavorite1 or C_PetJournalPetIsFavorite
		C_PetJournalSetFavorite1 = C_PetJournalSetFavorite1 or C_PetJournalSetFavorite
		C_PetJournalGetPetInfoByIndex1 = C_PetJournalGetPetInfoByIndex1 or C_PetJournalGetPetInfoByIndex
		C_PetJournalPetIsFavorite = function(petGUID) return ns.dbc.charFavs[petGUID] or false end
		C_PetJournalSetFavorite = function(petGUID, new)
			if new == 1 then
				ns.dbc.charFavs[petGUID] = true
			else
				ns.dbc.charFavs[petGUID] = nil
			end
			if PetJournal then PetJournal_OnEvent(PetJournal, 'PET_JOURNAL_LIST_UPDATE') end
			ns:PET_JOURNAL_LIST_UPDATE()
		end
		local gpi = C_PetJournalGetPetInfoByIndex1
		C_PetJournalGetPetInfoByIndex = function(...)
			local petGUID, speciesID, isOwned, customName, level, favorite, isRevoked, name, icon, petType, creatureID, sourceText, description, isWildPet, canBattle, arg1, arg2, arg3 = gpi(...)
			local customFavorite = C_PetJournalPetIsFavorite(petGUID)
			return petGUID, speciesID, isOwned, customName, level, customFavorite, isRevoked, name, icon, petType, creatureID, sourceText, description, isWildPet, canBattle, arg1, arg2, arg3
		end
	else
		if C_PetJournalPetIsFavorite1 then C_PetJournalPetIsFavorite = C_PetJournalPetIsFavorite1 end
		if C_PetJournalSetFavorite1 then C_PetJournalSetFavorite = C_PetJournalSetFavorite1 end
		if C_PetJournalGetPetInfoByIndex1 then C_PetJournalGetPetInfoByIndex = C_PetJournalGetPetInfoByIndex1 end
	end
	_G.C_PetJournal.PetIsFavorite = C_PetJournalPetIsFavorite
	_G.C_PetJournal.SetFavorite = C_PetJournalSetFavorite
	_G.C_PetJournal.GetPetInfoByIndex = C_PetJournalGetPetInfoByIndex
	if PetJournal then PetJournal_OnEvent(PetJournal, 'PET_JOURNAL_LIST_UPDATE') end
	ns:PET_JOURNAL_LIST_UPDATE()
end


--[[===========================================================================
	§ GUI stuff for Pet Journal
===========================================================================]]--

--[[
We disabled most of the GUI elements, since now we have more settings than we
can fit there. We leave the CharFavorites checkbox, because it makes sense to
see at a glance (in the opened Pet Journal) what type of favs are enabled.
]]

function ns.create_checkbox_base(self)
	local f = CreateFrame('CheckButton', 'PetWalkerCharFavsCheckbox', PetJournal, 'UICheckButtonTemplate')
	f:SetWidth(25)
	f:SetHeight(25)
	f:SetScript('OnLeave', function(self) GameTooltip:Hide() end)
	local label = f:CreateFontString(nil, 'OVERLAY')
	label:SetFontObject 'GameFontNormal'
	label:SetPoint('LEFT', f, 'RIGHT', 0, 0)
	return f, label
end

function ns.create_cfavs_checkbox(self)
	local f, label = self:create_checkbox_base()
	f:SetPoint('BOTTOMLEFT', PetJournal, 'BOTTOMLEFT', 400, 1)
	f:SetChecked(ns.dbc.charFavsEnabled)
	f:SetScript('OnClick', function(self, button)
		ns.dbc.charFavsEnabled = not ns.dbc.charFavsEnabled
		ns:cfavs_update()
	end)
	f:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_BOTTOMRIGHT')
		GameTooltip:SetText(
			addon_name .. ': Select this to use per-character favorites. \nFor more info, enter "/pw" in the chat console.',
			nil,
			nil,
			nil,
			nil,
			1
		)
		GameTooltip:Show()
	end)
	label:SetText 'Character favorites'
	return f
end


--[[===========================================================================
-- Debugging and Utils
===========================================================================]]--


function ns.id_to_name(id)
	if not id then return '"no ID!" from id_to_name' end
	local name = select(8, C_PetJournalGetPetInfoByPetID(id))
	return name
end

function ns.id_to_species(id)
	if not id then return '"no ID!" from id_to_species' end
	local spec = C_PetJournalGetPetInfoByPetID(id)
	return spec
end

function ns.id_to_link(id)
	if not id then return '"no ID!" from id_to_link' end
	local link = C_PetJournalGetBattlePetLink(id)
	return link
end


function ns:debug_display()
	ns.status_display()
	print(
		'|cffEE82EEDebug:\n  DB current pet: ', (ns.id_to_name(ns.db.currentPet) or '<nil>'),
		'\n  DB previous pet: ', (ns.id_to_name(ns.db.previousPet) or '<nil>'),
		'\n  Char DB current pet: ', (ns.id_to_name(ns.dbc.currentPet) or '<nil>'),
		'\n  Char DB previous pet: ', (ns.id_to_name(ns.dbc.previousPet) or '<nil>'),
		'\n  pet_verified: ', ns.pet_verified, '\n'
	)
end

-- without pet info
function ns:debugprint(...)
	if ns.db.debugMode then print('|cffEE82EEPetWalker Debug:', ...) end
end

-- with pet info
function ns:debugprint_pet(msg)
	if ns.db.debugMode then
		print(
			'|cffEE82EEPetWalker Debug: '
				.. msg
				.. ' # Current DB ' .. (ns.dbc.charFavsEnabled and ns.db.favsOnly and '(char)' or '(global)') .. ' pet: '
				.. ns.id_to_name(ns.dbc.charFavsEnabled and ns.db.favsOnly and ns.dbc.currentPet or ns.db.currentPet)
		)
	end
end

function ns.remaining_timer(time)
	local rem = ns.time_newpet_success + ns.db.newPetTimer - time
	return rem > 0 and rem or 0
end

-- Seconds to minutes
local function sec_to_min(seconds)
	local min, sec = tostring(math.floor(seconds / 60)), tostring(seconds % 60)
	return format('%.0f:%02.0f', min, sec)
end

function ns.remaining_timer_for_display()
	local rem = ns.time_newpet_success + ns.db.newPetTimer - GetTime()
	rem = rem > 0 and rem or 0
	return sec_to_min(rem)
end


--[[ License ===================================================================

	Copyright © 2022–2023 Thomas Floeren

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
