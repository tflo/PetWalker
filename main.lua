local addon_name, ns = ...
-- _G[addon_name] = ns -- Debug
local db_version = 1

--[[===========================================================================
	API references
===========================================================================]]--

local _

local C_PetJournalPetIsFavorite = _G.C_PetJournal.PetIsFavorite
local C_PetJournalSetFavorite = _G.C_PetJournal.SetFavorite
local C_PetJournalGetPetInfoByIndex = _G.C_PetJournal.GetPetInfoByIndex

local C_PetJournalSummonPetByGUID  = _G.C_PetJournal.SummonPetByGUID
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
local InCombatLockdown = _G.InCombatLockdown
local IsFlying = _G.IsFlying
local IsMounted = _G.IsMounted
local UnitOnTaxi = _G.UnitOnTaxi
local UnitHasVehicleUI = _G.UnitHasVehicleUI
local IsPossessBarVisible = _G.IsPossessBarVisible
local UnitIsGhost = _G.UnitIsGhost
local UnitIsBattlePet = _G.UnitIsBattlePet
local GetInstanceInfo = _G.GetInstanceInfo
local IsInInstance = _G.IsInInstance
local IsStealthed = _G.IsStealthed
local UnitIsControlling = _G.UnitIsControlling
local UnitChannelInfo = _G.UnitChannelInfo
local time = _G.time
local C_PlayerInfoGetGlidingInfo = C_PlayerInfo.GetGlidingInfo
local C_TimerAfter = _G.C_Timer.After

--[[===========================================================================
	Some Variables/Constants
===========================================================================]]--

ns.pet_pool = {}
ns.pool_initialized = false
--[[ This prevents the "wrong" active pet from being saved. We get a "wrong" pet
mainly after login, if the game summons the last active pet on this toon,
instead of the last saved pet in our DB (which can be the last active pet of the
alt we just logged out). Also when slotting a pet into a team in the Pet Journal
(slot#1 gets force-summoned). Caution, to not lock out manually summoned pets
from being saved.
]]
ns.pet_verified = false
-- ns.skipNextSave = false
ns.in_battlesleep = false
--[[ Last time AutoRestore() was called. ]]
local time_restore_pet = 0
local time_save_pet = 0
local time_pool_msg = 0
local time_transitioncheck = 0
-- C_Timers launched at PLAYER_ENTERING_WORLD
local delay_after_login = 14
local delay_after_reload = 8
local delay_after_instance = 6
-- C_Timer launched at ADDON_LOADED
local delay_login_msg = 22
-- TODO: Should we delay also after we change or select pet teams in Rematch / PJ
local delay_after_battle = 15 -- Post-petbattle sleep
local instasummon_after_battlesleep = true -- Summon without waiting for trigger event
local msg_onlyfavisactive_alreadydisplayed = false
local time_responded_to_summoning_event = 0
local throttle_min = 3
local throttle = 0 --  throttle_min * 2
local throttle_reason
local bypass_throttle = false
local savedpet_is_summonable = true
local eventthrottle_companionupdate, pet_restored, ignoreevent_listupdate
local excluded_species = {
-- Pet is vendor and goes on CD when summoned
	280, -- Guild Page, Alliance
	281, -- Guild Page, Horde
	282, -- Guild Herald, Alliance
	283, -- Guild Herald, Horde
-- Pet is vendor/bank/mail, if the char has the Pony Bridle achievement (ID 3736).
-- But it should be safe, bc CD starts only after activating the ability via dialog.
-- 	214, -- Argent Squire (Alliance)
-- 	216, -- Argent Gruntling (Horde)
-- Self-despawns outside of Winter Veil event. Makes no sense to summon these.
	1349, -- Rotten Little Helper
	117, -- Tiny Snowman
	119, -- Father Winter's Helper
	120, -- Winter's Little Helper
-- Pocopoc is special: he cannot be summoned in Zereth Mortis (1970)).
-- See the extra checks in is_excluded_by_species() and transitioncheck().
	3247, -- Pocopoc
-- Dummy ID for debugging. Keep this commented out!
-- 	2403, -- Abyssal Eel
}

-- BEGIN Experimental (usable as temporary user settings):
-- This is for the experimental usage of PLAYER_MOUNT_DISPLAY_CHANGED as second summoning event;
-- see v2.5.0 change notes for more info.
-- Disable/enable usage of the event
local use_PMDC = true -- true/false
-- Delay after dismounting (applies also to mounting, but this is irrelevant)
-- The shorter the better, but the risk of colliding with a summoning attempt by the game will probably be higher.
local delay_PMDC = 0.4 -- [seconds] reasonable range: 0 to 1; 0 means 'next frame'
-- Disable/enable the above delay
-- If false, no delay will be used, not even a single frame (risk of colliding will be high).
local use_delay_PMDC = true -- true/false
-- END Experimental

-- Debug
ns.time_summonspell = 0


--[[---------------------------------------------------------------------------
	Summoning prevention
---------------------------------------------------------------------------]]--

local function is_flying()
	-- The taxi condition should only ever trigger if we use zone events, since we cannot "move" while on taxi,
	-- or when manually calling `new_pet`
	return IsFlying() or UnitOnTaxi 'player'
end

-- Other possibility: UnitPowerBarID('player') == 631
local function is_skyride_mounted()
	return select(2, C_PlayerInfoGetGlidingInfo())
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

-- To test against if pet-on-back aura is found (AFAIK, only Daisy)
local function saved_pet_is_backpet()
	local backpet = 2780 -- Daisy
	if ns.dbc.charFavsEnabled and ns.db.favsOnly then
		return ns.id_to_species(ns.dbc.currentPet) == backpet
	else
		return ns.id_to_species(ns.db.currentPet) == backpet
	end
end

-- To test against if pet-on-shoulder aura is found
local function saved_pet_is_shoulderpet()
	local shoulderpets = { 2526, 1997, 2185 } -- Feathers, Crackers, Cap'n Crackers
	if ns.dbc.charFavsEnabled and ns.db.favsOnly then
		for _, species in ipairs(shoulderpets) do
			if ns.id_to_species(ns.dbc.currentPet) == species then return true end
		end
	else
		for _, species in ipairs(shoulderpets) do
			if ns.id_to_species(ns.db.currentPet) == species then return true end
		end
	end
end

-- To be called from autoaction (and - testwise- from transitioncheck)
local function stop_auto_summon(t)

	-- Base/existing throttle

	if not bypass_throttle then
		throttle = max(throttle, throttle_min)
		local now = t or time()
		if now - time_responded_to_summoning_event < throttle then
			ns.debugprint('`stop_auto_summon`: existing throttle found:', throttle)
			return true
		end
		time_responded_to_summoning_event, throttle = now, 0
	end

	-- Prevent summoning and add extra throttle

	throttle_reason = nil
	-- Impossible to summon in flight, but this prevents wrong 'restored' messages
	if is_flying() then
		throttle, throttle_reason = 5, 'flying'
		ns.debugprint 'In the air!'
	elseif InCombatLockdown()
		or not ns.db.drSummoning and is_skyride_mounted()
		or IsStealthed() -- Includes Hunter Camouflage
		or C_UnitAurasGetPlayerAuraBySpellID(32612) -- Mage: Invisibility
		or C_UnitAurasGetPlayerAuraBySpellID(110960) -- Mage: Greater Invisibility
		or C_UnitAurasGetPlayerAuraBySpellID(131347) -- DH: Gliding -- Prolly not needed, should be caught by IsFlying() (?)
-- 		or C_UnitAurasGetPlayerAuraBySpellID(5384) -- Hunter: Feign Death (only useful if we use a different event than PLAYER_STARTED_MOVING)
		or (UnitIsControlling 'player' and UnitChannelInfo 'player')
	then
		throttle = 10
	elseif UnitIsGhost 'player'
		or UnitHasVehicleUI 'player' -- Alternative(?): `HasOverrideActionBar()`
		-- Potentially useful: `HasExtraActionBar()`
		-- Controller toys etc. and some quests; coincides sometimes with `HasVehicleActionBar()` (not in case of aura 212754!)
		or IsPossessBarVisible()
		 -- Quest 'The Hole Deal' (84142) and 'Boomball' (85263) in TWW Undermine zone; possibly more, who knows.
		or HasVehicleActionBar()
		 -- Daisy pet as backpack (/beckon). Disappears when Daisy is summoned.
		or C_UnitAurasGetPlayerAuraBySpellID(311796) and saved_pet_is_backpet() -- Daisy
		 -- Pets on shoulder (/whistle). Disappears when any of the "shoulder pets" is summoned.
		or C_UnitAurasGetPlayerAuraBySpellID(302954) and saved_pet_is_shoulderpet() -- Feathers
		or C_UnitAurasGetPlayerAuraBySpellID(232871) and saved_pet_is_shoulderpet() -- Crackers
		or C_UnitAurasGetPlayerAuraBySpellID(286268) and saved_pet_is_shoulderpet() -- Cap'n Crackers

		-- Game events
		or C_UnitAurasGetPlayerAuraBySpellID(312993) -- Carrying Forbidden Tomes (Scrivener Lenua event, Revendreth)
		or C_UnitAurasGetPlayerAuraBySpellID(43880) -- Ramstein's Swift Work Ram (Brewfest daily; important bc the quest cannot be restarted if messed up)
		or C_UnitAurasGetPlayerAuraBySpellID(43883) -- Rental Racing Ram (Brewfest daily)
	then
		throttle = 40
	elseif forbidden_instance() then
		-- These will be re-enabled at the next PLAYER_ENTERING_WORLD
		ns.events:unregister_summon_events()
		throttle = 1 -- Must be > 0 to stop the autoaction in progress
	end
	if throttle > 0 then
		ns.debugprint('`stop_auto_summon`: new throttle:', throttle)
		return true
	end

end

-- For a manual action, we don't want all the checks from `stop_auto_summon` or a throttle.
-- Combat check is needed though to not generate errors.
local function stop_manual_summon()
	if InCombatLockdown() or is_flying() then
		ns.msg_manual_summon_stopped()
		return true
	end
end

--[[---------------------------------------------------------------------------
	Unsummonable pets (faction-locked pets)
---------------------------------------------------------------------------]]--

--[[ This can happen when…
- Restore: Logging in to other-faction alt and the saved pet is locked to the previous toon's faction.
- Random summon: A faction-locked pet that is not detectable as such (Blizz bug, see below) gets selected from the pool.
]]

local unsummonable_species
local player_faction = UnitFactionGroup 'player'

-- Add only pets here that are bugged, i.e. not detected as unsummonable by `GetPetSummonInfo`.
if player_faction == 'Alliance' then
	unsummonable_species = {
		[2777] = true, -- Gillvanas
		[342] = true, -- Festival Lantern
		[332] = true, -- Horde Balloon
	}
else
	unsummonable_species = {
		[2778] = true, -- Finduin
		[341] = true, -- Lunar Lantern
		[331] = true, -- Alliance Balloon
	}
end

local EnumPetJournalError = _G.Enum.PetJournalError
-- Couldn't find a Blizz constant for the string
-- This should match the output of C_PetJournal.GetPetSummonInfo for Enum.PetJournalError.InvalidFaction (3).
local ERROR_TEXT_WRONG_PET_FACTION = 'You are not the right faction for this companion.'

local function is_pet_summonable(guid)
	local is_summonable, error_num, error_text
	local species_id = ns.id_to_species(guid)
	if unsummonable_species[species_id] then
		is_summonable, error_num, error_text = false, EnumPetJournalError.InvalidFaction, ERROR_TEXT_WRONG_PET_FACTION
	else
		is_summonable, error_num, error_text = C_PetJournalGetPetSummonInfo(guid)
	end
	if not is_summonable then
		return false, error_num, error_text
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
			local is_summonable, error_num, error_text = is_pet_summonable(guid)
			if i == 1 then
				if is_summonable then return end
				ns.msg_saved_pet_unsummonable(error_text, error_num)
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
	For the Bindings file
---------------------------------------------------------------------------]]--

-- BINDING_HEADER_PETWALKER = "PetWalker  "
BINDING_NAME_PETWALKER_TOGGLE_AUTO = 'Toggle Auto-Summoning'
BINDING_NAME_PETWALKER_NEW_PET = 'Summon New Pet'
BINDING_NAME_PETWALKER_PREVIOUS_PET = 'Summon Previous Pet'
BINDING_NAME_PETWALKER_TARGET_PET = 'Summon Same Pet as Target'
BINDING_NAME_PETWALKER_DISMISS_PET = 'Dismiss Pet & Disable Auto-Summoning'

function PetWalker_binding_toggle_autosummon() ns:auto_toggle() end
function PetWalker_binding_new_pet() ns:new_pet(nil, true) end
function PetWalker_binding_previous_pet() ns.previous_pet() end
function PetWalker_binding_target_pet() ns:summon_targetpet() end
function PetWalker_binding_dismiss_and_disable() ns:dismiss_and_disable() end


--[[===========================================================================
	Event frame
===========================================================================]]--

ns.events = CreateFrame 'Frame'

ns.events:SetScript('OnEvent', function(self, event, ...)
	if ns[event] then ns[event](self, ...) end
end)

ns.events:RegisterEvent 'ADDON_LOADED'

-- Groups

-- Used events that are not in any group:
-- ADDON_LOADED
-- PET_BATTLE_OVER (registered after PET_BATTLE_OPENING_START)

function ns.events:register_summon_events()
	ns.debugprint 'Registering summon events.'
	if ns.db.eventAlt then -- Alt events, experimental
		--[[ Pointless if it fires while flying, which is quite often. But this doesn't harm either. ]]
		self:RegisterEvent 'ZONE_CHANGED'
		--[[ Probably good, still testing.
		Fires often together with zoneCh, but not always. ]]
		self:RegisterEvent 'ZONE_CHANGED_INDOORS'
		--[[ Good event ]]
		self:RegisterEvent 'PLAYER_MOUNT_DISPLAY_CHANGED'
	else -- Default event(s)
		self:RegisterEvent 'PLAYER_STARTED_MOVING'
		-- Added this because:
			-- To cancel flight throttle instantly
			-- Possibly smoother summoning at dismounting
		if use_PMDC then self:RegisterEvent 'PLAYER_MOUNT_DISPLAY_CHANGED' end
	end
end

function ns.events:unregister_summon_events()
	ns.debugprint 'Unregistering summon events.'
	self:UnregisterEvent 'ZONE_CHANGED'
	self:UnregisterEvent 'ZONE_CHANGED_INDOORS'
	self:UnregisterEvent 'PLAYER_MOUNT_DISPLAY_CHANGED'
	self:UnregisterEvent 'PLAYER_STARTED_MOVING'
end

function ns.events:register_meta_events()
	ns.debugprint 'Registering meta events.'
	self:RegisterEvent 'PLAYER_ENTERING_WORLD'
	self:RegisterEvent 'PET_JOURNAL_LIST_UPDATE'
	self:RegisterEvent 'COMPANION_UPDATE'
	self:RegisterEvent 'PET_BATTLE_OPENING_START'
	self:RegisterEvent 'PLAYER_LOGOUT'
end

function ns.events:unregister_meta_events()
	ns.debugprint 'Unregistering meta events.'
	self:UnregisterEvent 'PLAYER_ENTERING_WORLD'
	self:UnregisterEvent 'PET_JOURNAL_LIST_UPDATE'
	self:UnregisterEvent 'COMPANION_UPDATE'
	self:UnregisterEvent 'PET_BATTLE_OPENING_START'
	self:UnregisterEvent 'PLAYER_LOGOUT'
end

function ns.events:register_pw_events()
	ns.debugprint 'Registering PW events.'
	self:register_meta_events()
	self:register_summon_events()
end

function ns.events:unregister_pw_events()
	ns.debugprint 'Unregistering PW events (`UnregisterAllEvents`).'
	self:UnregisterAllEvents()
end

--[[===========================================================================
	Loading and event handlers
===========================================================================]]--

function ns:ADDON_LOADED(addon)

--[[---------------------------------------------------------------------------
	Our addon has loaded (init)
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

		ns.time_newpet_success = time() - (ns.db.newPetTimer - ns.db.remainingTimer)

		-- *Not* with PLAYER_ENTERING_WORLD so that it is not affected when all events get unregistered via /pw a
		C_Timer.After(delay_login_msg, ns.msg_login)

--[[---------------------------------------------------------------------------
	Events
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
			-- Prevent event spam caused by BattlePetBreedID
			if is_login or is_reload then
				if C_AddOns.IsAddOnLoaded('BattlePetBreedID') then
					hooksecurefunc('BPBID_SetBreedTooltip', function(parent)
						-- Same conditions as used by the func to trigger `ClearSearchFilter`
						if BPBID_Options.Breedtip.Collected and (not PetJournalPetCardPetInfo or not PetJournalPetCardPetInfo:IsVisible() or parent == FloatingBattlePetTooltip) then
							ignoreevent_listupdate = true
							ns.debugprint 'Hook: BPBID_SetBreedTooltip --> ignoreevent_listupdate'
						end
					end)
				end
			end
			if is_login then
				ns.debugprint 'Event: PLAYER_ENTERING_WORLD: Login'
				delay = delay_after_login
				-- This must run before transitioncheck
				C_Timer.After(delay - 1, saved_pet_summonability_check)
			elseif is_reload then
				ns.debugprint 'Event: PLAYER_ENTERING_WORLD: Reload'
				delay = delay_after_reload
			else
				-- Needed for zone-specific pet exclusions
				ns.debugprint 'Event: PLAYER_ENTERING_WORLD: Instance change'
				delay = delay_after_instance
			end
			ns.pet_verified = false
			C_Timer.After(delay, function()
				ns.transitioncheck()
				-- For the moment, calling this separately, since `transitioncheck` in its current form is abortable
				ns.events:register_summon_events()
			end)
		end

		-- Regular main event
		function ns:PLAYER_STARTED_MOVING()
			ns.debugprint 'Event: PLAYER_STARTED_MOVING --> `autoaction`'
			ns.autoaction()
		end

		-- Experimental alternative events
		function ns:ZONE_CHANGED()
			ns.debugprint 'Event: ZONE_CHANGED --> `autoaction`'
			ns.autoaction()
		end
		function ns:ZONE_CHANGED_INDOORS()
			ns.debugprint 'Event: ZONE_CHANGED_INDOORS --> `autoaction`'
			ns.autoaction()
		end
		function ns:PLAYER_MOUNT_DISPLAY_CHANGED()
			ns.debugprint 'Event: PLAYER_MOUNT_DISPLAY_CHANGED --> `autoaction`, flight throttle canceled'
			if throttle_reason == 'flying' then throttle = 0 end
			-- This can lead to a summoning conflict *if* the game itself re-summons the pet after dismounting
			-- Let's try it with a little delay
			if use_delay_PMDC then
				C_TimerAfter(delay_PMDC, ns.autoaction)
			else
				ns.autoaction()
			end
		end

--[[---------------------------------------------------------------------------
	Pet battle, hooks, and misc
---------------------------------------------------------------------------]]--

		hooksecurefunc(C_PetJournal, 'SetPetLoadOutInfo', function()
			-- Note that SetPetLoadOutInfo summons the slot #1 pet, but it does so _not_ via SummonPetByGUID
			ns.debugprint 'Hook: `SetPetLoadOutInfo` --> Setting `pet_verified` to false'
			ns.pet_verified = false
		end)

		function ns:COMPANION_UPDATE(what)
			-- This event fires always 2 times, so let's just listen to the first one
			if what ~= 'CRITTER' or eventthrottle_companionupdate then return end
			eventthrottle_companionupdate = true
			if not pet_restored then
				ns.save_pet()
				if ns.db.debugMode then
					ns.debugprint(
						'Event: COMPANION_UPDATE (`actpet`: '
							.. ns.id_to_name(C_PetJournalGetSummonedPetGUID())
							.. ') --> `save_pet`'
					)
				end
			else
				pet_restored = nil
				if ns.db.debugMode then
					ns.debugprint(
						'Event: COMPANION_UPDATE (`actpet`: '
							.. ns.id_to_name(C_PetJournalGetSummonedPetGUID())
							.. '): not saving bc `pet_restored`'
					)
				end
			end
			-- It *seems* the pet is already summoned when the event fires the 1st time, so no need to delay the saving itself
			C_TimerAfter(0.5, function()
				eventthrottle_companionupdate = nil
			end)
		end

		function ns:PET_BATTLE_OPENING_START()
			ns.debugprint 'Event: PET_BATTLE_OPENING_START'
			ns.events:unregister_pw_events()
			ns.events:RegisterEvent 'PET_BATTLE_OVER' -- Alternative: PET_BATTLE_CLOSE (fires twice)
			ns.in_battlesleep = true
			-- In theory, this is redundant here. However I noticed that since the change of the save-pet logic (2.3.0),
			-- the correct pet isn't always restored after a battle (maybe 5–10%, possibly in conjunction with a second
			-- battle or with entering combat while in battlesleep).
			-- TODO: Observe if this improves the behavior.
			ns.pet_verified = false
		end

		function ns:PET_BATTLE_OVER()
			ns.debugprint(
				format(
					'Event: PET_BATTLE_OVER --> Re-register events in %ss, unless we are in the next battle',
					delay_after_battle
				)
			)
			C_Timer.After(delay_after_battle, function()
				if C_PetBattlesIsInBattle() then return end
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
		TODO: Just noticed that this fires each time I hover over a pet in the AH listing(!). Find out if this is triggered by an addon, or if it is Blizz crap. If needed, unregister PW events when the AH is opened.
		]]
		function ns:PET_JOURNAL_LIST_UPDATE()
			-- Hovering over any pet in the bags or the AH triggers the event.
			-- This is caused by the BattlePetBreedID addon: if the 'collected pets' option is active,
			-- it calls `C_PetJournal.ClearSearchFilter()`, in order to make the collected pets info fetchable.
			-- BreedTooltips.lua, line 116
			-- We set the `ignoreevent_listupdate` flag via a hook to BPBID's `BPBID_SetBreedTooltip` at login/reload.
			-- Works fine w/o timer (and with timer it gets out of sync if the spam rate is high).
			if ignoreevent_listupdate then
				ns.debugprint 'Event: PET_JOURNAL_LIST_UPDATE --> Ignored'
				ignoreevent_listupdate = nil
			else
				ns.debugprint 'Event: PET_JOURNAL_LIST_UPDATE --> Setting `pool_initialized` to false'
				ns.pool_initialized = false
			end
		end

		function ns:PLAYER_LOGOUT()
			ns.db.remainingTimer = ns.remaining_timer(time())
		end


--[[---------------------------------------------------------------------------
	Blizzard_Collections loaded
---------------------------------------------------------------------------]]--

	elseif addon == 'Blizzard_Collections' then
		ns.events:UnregisterEvent 'ADDON_LOADED'
		--[[ -- Currently disabled due to DF changes
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
	end
end


--[[===========================================================================
	Main actions
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
	Auto action
	The main function that runs when player started moving. It decides whether to
	restore a lost pet, or summon a new one (if the timer is set and due).
---------------------------------------------------------------------------]]--

function ns.autoaction()
	local now = time()
	if stop_auto_summon(now) then return end
	if ns.db.newPetTimer ~= 0 then
		if ns.remaining_timer(now) == 0 then
			ns.debugprint_pet '`autoaction` --> `new_pet`'
			ns:new_pet(now, false)
			return
		end
	end
	-- TODO: Could we not simply check against the saved db pet, and restore if it isn't correct or missing?
	if not ns.pet_verified then
		ns.debugprint_pet '`autoaction` --> `transitioncheck` (pet not verified)'
		ns.transitioncheck(true)
		return
	end
	local actpet = C_PetJournalGetSummonedPetGUID()
	if not actpet then
		ns.debugprint_pet '`autoaction` --> `restore_pet`'
		ns:restore_pet()
	end
end

--[[---------------------------------------------------------------------------
	Restore pet
	Pet is lost --> restore it.
	To be called only by autoaction func!
	No need to check against the current pet, since by definition, if we do have a
	pet out, then it must be the correct one.
---------------------------------------------------------------------------]]--

function ns:restore_pet()
	local now = time()
	local savedpet
	if ns.dbc.charFavsEnabled and ns.db.favsOnly then
		savedpet = ns.dbc.currentPet
	else
		savedpet = ns.db.currentPet
	end
	time_restore_pet = now
	if savedpet then
		ns.debugprint '`restore_pet` is restoring saved pet'
		ns.set_sum_msg_to_restore_pet(savedpet)
		pet_restored = true
		ns:summon_pet(savedpet, false)
	else
		ns.debugprint '`restore_pet` could not find saved pet --> summoning new pet'
		ns.msg_no_saved_pet()
		ns:new_pet(now, false)
	end
end


--[[---------------------------------------------------------------------------
	New pet
	Called by autoaction when timer is due, or via command/key
---------------------------------------------------------------------------]]--

function ns:new_pet(the_time, manually_called)
	if manually_called and stop_manual_summon() then return end
	if ns.db.debugMode then
		ns.debugprint(format('`new_pet` called with args %s, %s ', tostring(the_time), tostring(manually_called)))
	end
	local now = the_time or time()
	if now - ns.time_newpet_success < 1.5 then return end
	local actpet = C_PetJournalGetSummonedPetGUID()
	if actpet and is_excluded_by_id(actpet) then
		ns.debugprint '`new_pet`: `actpet` is excluded'
		return
	end
	if not ns.pool_initialized then
		ns.debugprint '`new_pet` --> `initialize_pool`'
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
				if not msg_onlyfavisactive_alreadydisplayed or manually_called then
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
		ns:summon_pet(newpet, true)
	end
end


--[[---------------------------------------------------------------------------
	Summon previous
---------------------------------------------------------------------------]]--

function ns.previous_pet()
	if stop_manual_summon() then return end
	local prevpet
	if ns.dbc.charFavsEnabled then
		prevpet = ns.dbc.previousPet
	else
		prevpet = ns.db.previousPet
	end
	if prevpet then
		ns.set_sum_msg_to_previouspet(prevpet)
		ns:summon_pet(prevpet, true)
	else
		ns.msg_no_previous_pet()
	end
end

--[[---------------------------------------------------------------------------
	Summon targeted pet
---------------------------------------------------------------------------]]--

function ns.summon_targetpet()
	if stop_manual_summon() then return end
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
		ns:summon_pet(tarpet, true)
		ns.msg_target_summoned(target_pet_link)
	else
		ns.msg_target_is_same(target_pet_link) -- Without web link
		-- ns.msg_target_is_same(target_pet_link, target_pet_name) -- With web link
	end
end


--[[--------------------------------------------------------------------------------------------------------------------
	Transition check
	One time action, after big transitions, like login, portals, entering instance, etc. Basically a standalone
	restore_pet func; in addition, it not only checks for presence of a pet, but also against the saved pet. This makes
	sure that a newly logged toon gets the same pet as the previous toon had at logout. We need more checks here than
	in restore_pet, bc restore_pet is "prefiltered" by autoaction, and here we are not.
--------------------------------------------------------------------------------------------------------------------]]--

function ns.transitioncheck(checks_done)
-- 	Can be called via the entering-world events, or via `autoaction`, so we
-- 	if ns.pet_verified or InCombatLockdown() or IsFlying() or UnitOnTaxi 'player' then
	-- TODO: Observe if stop_auto_summon works as expected here!
	-- Never run the stop_auto_summon check twice, as the 2nd one will always find a throttle then!
	if not checks_done and stop_auto_summon() then
		if ns.db.debugMode then
			ns.debugprint(format(
				'`transitioncheck` (`pet_verified`: %s) stopped by `stop_auto_summon`', tostring(ns.pet_verified)))
		end
		return
	end
	local now = time()
	--[[ If toon starts moving immediately after transition, then `restore_pet`
	might come before us. Also prevents redundant run in case we use both events
	NEW_AREA and ENTERING_WORLD. ]]
	if now - time_restore_pet < 6 then
		ns.debugprint('`transitioncheck` aborted bc less than 6s since `restore_pet`')
		return
	end
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
		ns.debugprint '`transitioncheck` is restoring saved pet'
		ns.set_sum_msg_to_transcheck(savedpet)
		ns:summon_pet(savedpet, false)
	--[[ Should only come into play if savedpet is still nil due to a slow
	loading process ]]
	elseif not actpet then
		ns.debugprint '`transitioncheck` could not find saved pet --> summoning new pet'
		ns.msg_no_saved_pet()
		ns:new_pet(now, false)
	end
	-- TODO: Do we still need this timestamp?
	time_restore_pet = now
	--[[ This is not 100% reliable here, but should do the trick most of the time. ]]
	ns.pet_verified, savedpet_is_summonable = true, true
	-- Because we are unregistering now with every type of PLAYER_ENTERING_WORLD
	-- HACK: Called separately after entering world, bc of the possible early return
	-- ns.events:register_summon_events()
	ns.debugprint '`transitioncheck` completed'
end


--[[---------------------------------------------------------------------------
	Save pet
	Save any summoned pet.
	Called by the COMPANION_UPDATE event func.
---------------------------------------------------------------------------]]--

function ns.save_pet()
	-- Flag must be unset …
	-- when a pet is force-summoned by the Pet Journal when we put in a team slot,
	-- after entering world events.
	if not ns.pet_verified then
		ns.debugprint '`save_pet` FAILURE, bc not `pet_verified`'
		return
	end
	local actpet = C_PetJournalGetSummonedPetGUID()
	if
		not actpet
		or is_excluded_by_id(actpet)
	then
		ns.debugprint '`save_pet` FAILURE: No `actpet` or `actpet` is excluded'
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
	ns.debugprint_pet '`save_pet` completed'
end


--[[---------------------------------------------------------------------------
	Summon Pet
	Used in the Auto Summon function, and currently also in the
	Manual Summon function
---------------------------------------------------------------------------]]--

function ns:summon_pet(pet, resettimer)
	if not pet then -- TODO: needed?
		ns.debugprint '`summon_pet` was called without `pet` argument!'
		return
	end
	if ns.db.debugMode then
		local is_summonable, error_num, error_text = C_PetJournalGetPetSummonInfo(pet)
		if not is_summonable then
			ns.debugprint('`summon_pet`: Something is wrong with our summonability check: pet cannot be summoned, `GetPetSummonInfo` returned', is_summonable, error_num, error_text)
			return
		end
	end
	local now = time()
	ns.pet_verified = true
	if resettimer then ns.time_newpet_success = now end
	ns.msg_pet_summon_success()
	C_PetJournalSummonPetByGUID(pet)
end


--[[===========================================================================
	Pet pool
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
	ns.debugprint 'Running `initialize_pool`'
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
	local now = time()
	if #ns.pet_pool <= 0 and ns.db.newPetTimer ~= 0 and now - time_pool_msg > 30 then
		ns.msg_low_petpool(#ns.pet_pool)
		time_pool_msg = now
	end
end


--[[===========================================================================
	Char Favs
===========================================================================]]--

local C_PetJournalPetIsFavorite1, C_PetJournalSetFavorite1, C_PetJournalGetPetInfoByIndex1

-- Largely unaltered code from NugMiniPet
function ns.cfavs_update()
	ns.debugprint 'Running `cfavs_update`'
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
			ns:PET_JOURNAL_LIST_UPDATE() -- Do not remove this
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
	ns:PET_JOURNAL_LIST_UPDATE() -- Do not remove this
end


--[[===========================================================================
	GUI stuff for Pet Journal
===========================================================================]]--

--[[
We disabled most of the GUI elements, since now we have more settings than we
can fit there. We leave the CharFavorites checkbox, because it makes sense to
see at a glance (in the opened Pet Journal) what type of favs are enabled.
]]

function ns:create_cfavs_checkbox()
	local btn = CreateFrame('CheckButton', 'PetWalkerCharFavsCheckbox', PetJournal, 'UICheckButtonTemplate')
	btn:SetSize(26, 26)
	btn:SetHitRectInsets(-2,-80,-2,-2)
	btn:SetPoint('BOTTOMLEFT', PetJournal, 'BOTTOMLEFT', 400, 1)
	-- btn:SetChecked(ns.dbc.charFavsEnabled)
	btn:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
		GameTooltip:AddLine('\124cnDIM_GREEN_FONT_COLOR:PetWalker')
		GameTooltip:AddLine('Select this to use per-character favorites, or toggle with \124cnORANGE_FONT_COLOR:/pw c\124r.')
		GameTooltip:AddLine('Toggle favs/all: \124cnORANGE_FONT_COLOR:/pw f\124r | Status: \124cnORANGE_FONT_COLOR:/pw s\124r | Help & all commands: \124cnORANGE_FONT_COLOR:/pw h\124r')
		GameTooltip:Show()
	end)
	btn:SetScript('OnClick', function()
		ns.dbc.charFavsEnabled = not ns.dbc.charFavsEnabled
		ns:cfavs_update()
	end)
	btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
	local label = btn:CreateFontString(nil, 'OVERLAY')
	label:SetFontObject(GameFontNormal)
	label:SetPoint('LEFT', btn, 'RIGHT', 0, 0)
	label:SetText 'Char Favs (PW)'
	return btn, label
end


--[[ License ===================================================================

	Copyright © 2022–2025 Thomas Floeren

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
