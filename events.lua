-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2022-2025 Thomas Floeren

local ADDON_NAME, ns = ...


local C_AddOnsIsAddOnLoaded = _G.C_AddOns.IsAddOnLoaded
local C_PetJournalGetSummonedPetGUID = _G.C_PetJournal.GetSummonedPetGUID
local C_PetBattlesIsInBattle = _G.C_PetBattles.IsInBattle
local C_TimerAfter = _G.C_Timer.After

-- C_Timers launched at PLAYER_ENTERING_WORLD
local delay_after_login = 14
local delay_after_reload = 8
local delay_after_instance = 6
-- C_Timer launched at ADDON_LOADED
local delay_login_msg = 22
-- TODO: Should we delay also after we change or select pet teams in Rematch / PJ
local delay_after_battle = 15 -- Post-petbattle sleep
local instasummon_after_battlesleep = true -- Summon without waiting for trigger event

local eventthrottle_companionupdate

-- BEGIN PMDC finetuning (usable as temporary user settings):
-- Once experimental, this is now standard.
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
-- END PMDC finetuning


--[[===========================================================================
	Events
===========================================================================]]--

local monitored_addons = {
	[ADDON_NAME] = true,
	['Blizzard_Collections'] = true,
}
-- dtd(monitored_addons)

local function ADDON_LOADED(addon)
	if not monitored_addons[addon] then return end
	if addon == ADDON_NAME then
		ns.debugprint 'Addon "PetWalker" loaded.'
		ns.time_newpet_success = time() - (ns.db.newPetTimer - ns.db.remainingTimer)
		-- *Not* with PLAYER_ENTERING_WORLD so that it is not affected
		-- when all events get unregistered via /pw a
		C_TimerAfter(delay_login_msg, ns.msg_login)

		-- The summon events are now registered with transitioncheck or delayed after PLAYER_ENTERING_WORLD
		if ns.db.autoEnabled then ns.events:register_meta_events() end

		-- This would raise an error if not loaded yet, so OK here.
		hooksecurefunc(C_PetJournal, 'SetPetLoadOutInfo', function()
			-- Note that SetPetLoadOutInfo summons the slot #1 pet, but it does so _not_ via SummonPetByGUID
			ns.debugprint 'Hook: `SetPetLoadOutInfo` --> Setting `pet_verified` to false'
			ns.pet_verified = false
		end)

	elseif addon == 'Blizzard_Collections' then
		-- By all measures, this should come after all 3rd-party addons, so safe to stop here.
		ns.events:UnregisterEvent 'ADDON_LOADED'
		ns.debugprint 'Addon "Blizzard_Collections" loaded.'
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
local function PLAYER_ENTERING_WORLD(is_login, is_reload)
	local delay
	-- We do not want summon events before transitioncheck has finished
	ns.events:unregister_summon_events()
	if is_login then
		ns.debugprint 'Event: PLAYER_ENTERING_WORLD: Login'
		delay = delay_after_login
		-- This must run before transitioncheck
		C_TimerAfter(delay - 1, ns.saved_pet_summonability_check)
	elseif is_reload then
		ns.debugprint 'Event: PLAYER_ENTERING_WORLD: Reload'
		delay = delay_after_reload
	else
		-- Needed for zone-specific pet exclusions
		ns.debugprint 'Event: PLAYER_ENTERING_WORLD: Instance change'
		delay = delay_after_instance
	end
	ns.pet_verified = false
	C_TimerAfter(delay, function()
		ns.transitioncheck()
		-- For the moment, calling this separately, since `transitioncheck` in its current form is abortable
		ns.events:register_summon_events()
	end)
end

-- Regular main event
local function PLAYER_STARTED_MOVING()
	ns.debugprint 'Event: PLAYER_STARTED_MOVING --> `autoaction`'
	ns.autoaction()
end

-- Experimental alternative events
local function ZONE_CHANGED()
	ns.debugprint 'Event: ZONE_CHANGED --> `autoaction`'
	ns.autoaction()
end
local function ZONE_CHANGED_INDOORS()
	ns.debugprint 'Event: ZONE_CHANGED_INDOORS --> `autoaction`'
	ns.autoaction()
end
local function PLAYER_MOUNT_DISPLAY_CHANGED()
	ns.debugprint 'Event: PLAYER_MOUNT_DISPLAY_CHANGED --> `autoaction`, flight throttle canceled'
-- 			if throttle_reason == 'inair' then throttle = 0 end  -- WTF?!
	-- This can lead to a summoning conflict *if* the game itself re-summons the pet after dismounting
	-- Let's try it with a little delay
	if use_delay_PMDC then
		C_TimerAfter(delay_PMDC, ns.autoaction)
	else
		ns.autoaction()
	end
end

local function COMPANION_UPDATE(what)
	-- This event fires always 2 times, so let's listen to the last one.
	if what ~= 'CRITTER' or eventthrottle_companionupdate then return end
	eventthrottle_companionupdate = true
	C_TimerAfter(0.7, function()
		eventthrottle_companionupdate = nil
		if not ns.pet_restored then
			ns.save_pet()
			if ns.db.debugMode then
				ns.debugprint(
					'Event: COMPANION_UPDATE (`actpet`: '
						.. ns.id_to_name(C_PetJournalGetSummonedPetGUID())
						.. ') --> `save_pet`'
				)
			end
		else
			ns.pet_restored = nil
			if ns.db.debugMode then
				ns.debugprint(
					'Event: COMPANION_UPDATE (`actpet`: '
						.. ns.id_to_name(C_PetJournalGetSummonedPetGUID())
						.. '): not saving bc `pet_restored`'
				)
			end
		end
	end)
end

-- See bottom of file for complete pet battle event chain

local function PET_BATTLE_OPENING_START()
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

local function PET_BATTLE_OVER()
	ns.debugprint(
		format(
			'Event: PET_BATTLE_OVER --> Re-register events in %ss, unless we are in the next battle',
			delay_after_battle
		)
	)
	C_TimerAfter(delay_after_battle, function()
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
]]
local function PET_JOURNAL_LIST_UPDATE()
	ns.debugprint 'Event: PET_JOURNAL_LIST_UPDATE --> Setting `pool_initialized` to false'
	ns.pool_initialized = false
end
ns.PET_JOURNAL_LIST_UPDATE = PET_JOURNAL_LIST_UPDATE -- Used in main

local function PLAYER_LOGOUT()
	ns.db.remainingTimer = ns.remaining_timer(time())
end


--[[===========================================================================
	Event frame
===========================================================================]]--

local event_handlers = {
	['ADDON_LOADED'] = ADDON_LOADED,
	['PLAYER_ENTERING_WORLD'] = PLAYER_ENTERING_WORLD,
	['PLAYER_LOGOUT'] = PLAYER_LOGOUT,
	['PLAYER_STARTED_MOVING'] = PLAYER_STARTED_MOVING,
	['ZONE_CHANGED'] = ZONE_CHANGED,
	['ZONE_CHANGED_INDOORS'] = ZONE_CHANGED_INDOORS,
	['PLAYER_MOUNT_DISPLAY_CHANGED'] = PLAYER_MOUNT_DISPLAY_CHANGED,
	['COMPANION_UPDATE'] = COMPANION_UPDATE,
	['PET_BATTLE_OPENING_START'] = PET_BATTLE_OPENING_START,
	['PET_BATTLE_OVER'] = PET_BATTLE_OVER,
	['PET_JOURNAL_LIST_UPDATE'] = PET_JOURNAL_LIST_UPDATE,
}

ns.events = CreateFrame 'Frame'

ns.events:SetScript('OnEvent', function(_, event, ...)
	local handler = event_handlers[event] -- or ns[event]
	if handler then handler(...) end
end)

-- ns.events:SetScript('OnEvent', function(self, event, ...)
-- 	if ns[event] then ns[event](self, ...) end
-- end)

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


--[[ Typical pet battle event chain: ]]--[[

[player interacts with tamer --> Rematch loads team]
COMPANION_UPDATE "CRITTER"
[0ms]
COMPANION_UPDATE "CRITTER"
[player initiates pet pattle]
PET_BATTLE_OPENING_START
[2000ms]
PET_BATTLE_OPENING_DONE
[pet battling now…]
PET_BATTLE_OVER
[200ms]
PET_BATTLE_CLOSE
[1200ms]
PET_BATTLE_CLOSE
[0ms]
UPDATE_SUMMONPETS_ACTION
[0ms]
UPDATE_SUMMONPETS_ACTION

]]
