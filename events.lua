-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-- Copyright (c) 2022-2026 Thomas Floeren

local MYNAME, ns = ...


local C_PetJournal_GetSummonedPetGUID = _G.C_PetJournal.GetSummonedPetGUID
local C_PetBattles_IsInBattle = _G.C_PetBattles.IsInBattle
local C_Timer_After = _G.C_Timer.After

-- C_Timer launched at PLAYER_MAP_CHANGED
-- We can afford a short delay, since PMC is only used for walk-in instances.
-- Never use less than 2s.
local DELAY_AFTER_PMC = 4
-- C_Timer launched at LOADING_SCREEN_DISABLED
local DELAY_AFTER_LOADINGSCREEN = 1
-- C_Timer launched at FIRST_FRAME_RENDERED
local DELAY_LOGIN_MSG = 10
-- TODO: Should we delay also after we change or select pet teams in Rematch / PJ
local DELAY_AFTER_BATTLE = 15 -- Post-petbattle sleep
local instasummon_after_battlesleep = true -- Summon without waiting for trigger event

local eventthrottle_companionupdate

-- BEGIN PMDC finetuning (usable as temporary user settings):
-- Once experimental, this is now standard.
-- This is for the experimental usage of PLAYER_MOUNT_DISPLAY_CHANGED as second summoning event;
-- see v2.5.0 change notes for more info.
-- Disable/enable usage of the event
local USE_PMDC = true -- true/false
-- Delay after dismounting (applies also to mounting, but this is irrelevant)
-- The shorter the better, but the risk of colliding with a summoning attempt by the game will probably be higher.
local DELAY_PMDC = 0.4 -- [seconds] reasonable range: 0 to 1; 0 means 'next frame'
-- Disable/enable the above delay
-- If false, no delay will be used, not even a single frame (risk of colliding will be high).
local USE_DELAY_PMDC = true -- true/false
-- END PMDC finetuning

--[[===========================================================================
	Events
===========================================================================]]--

local MONITORED_ADDONS = {
	[MYNAME] = true,
	['Blizzard_Collections'] = true,
}

local function ADDON_LOADED(addon)
	if not MONITORED_ADDONS[addon] then return end
	if addon == MYNAME then
		ns.time_newpet_success = time() - (ns.db.newPetTimer - ns.db.remainingTimer)

		-- The summon events are now registered with transitioncheck or delayed after PLAYER_ENTERING_WORLD
		if ns.db.autoEnabled then ns.events:register_meta_events() end

		-- This raises an error if PJ is not loaded yet, so OK doing it here.
		hooksecurefunc(C_PetJournal, 'SetPetLoadOutInfo', function()
			-- Note that SetPetLoadOutInfo summons the slot #1 pet, but it does so _not_ via SummonPetByGUID
			ns.debugprint '‹SetPetLoadOutInfo()› hook called, ‹pet_verified› = false'
			ns.pet_verified = false
		end)

	elseif addon == 'Blizzard_Collections' then
		-- By all measures, this should come after all 3rd-party addons, so safe to stop here.
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

local function PLAYER_ENTERING_WORLD(islogin, isreload)
	-- v3.1: We delegated everything to LOADING_SCREEN_DISABLED and
	-- PLAYER_MAP_CHANGED, so we need P_E_W only as initial-login detector;
	ns.events:UnregisterEvent 'PLAYER_ENTERING_WORLD'
	if islogin then
		ns.debugprint '"PLAYER_ENTERING_WORLD": login'
		ns.is_initial_login = true
	elseif isreload then
		-- Currently not needed
	end
end

local function LOADING_SCREEN_ENABLED()
	ns.events:unregister_summon_events()
	-- Not a walk-in instance, P_M_C not needed
	ns.events:UnregisterEvent 'PLAYER_MAP_CHANGED'
	ns.debugprint '"LOADING_SCREEN_ENABLED": summon events unregistered'
	ns.pet_verified = false
end

local function LOADING_SCREEN_DISABLED()
-- 	if ns.db.autoEnabled then
-- 		ns.events:register_summon_events()
-- 		ns.debugprint '"LOADING_SCREEN_DISABLED": summon events registered'
-- 	else
-- 		ns.debugprint '"LOADING_SCREEN_DISABLED": Auto is disabled'
-- 	end
	ns.debugprint '"LOADING_SCREEN_DISABLED": calling ‹transitioncheck()›'
	ns.events:RegisterEvent 'PLAYER_MAP_CHANGED'
	C_Timer_After(DELAY_AFTER_LOADINGSCREEN, function()
		ns.transitioncheck() -- register_summon_events will be done here
	end)
end

-- Fires reliably after *any* instance change, also the ones w/o P_E_W or loading screen (e.g. delves).
-- Does *not* fire after login/reload, so P_E_W, P_L, or F_F_R is still needed.
-- Caution: It fires very early, so if we use GetInstanceInfo and friends, we need a delay of 2+ seconds.
-- NOTE: We could maybe use WALK_IN_DATA_UPDATE, which presumably fires when the data for GetInstanceInfo
-- becomes available; problem is that it doesn't fire when leaving a delve.
local function PLAYER_MAP_CHANGED()
	ns.debugprint '"PLAYER_MAP_CHANGED": calling ‹transitioncheck()›'
	C_Timer_After(DELAY_AFTER_PMC, function()
		ns.transitioncheck()
	end)
end

-- Regular main event
local function PLAYER_STARTED_MOVING()
	ns.debugprint 'Triggered by "PLAYER_STARTED_MOVING"'
	ns.autoaction()
end

-- Experimental alternative events
local function ZONE_CHANGED()
	ns.debugprint 'Triggered by "ZONE_CHANGED"'
	ns.autoaction()
end
local function ZONE_CHANGED_INDOORS()
	ns.debugprint 'Triggered by "ZONE_CHANGED_INDOORS"'
	ns.autoaction()
end
local function PLAYER_MOUNT_DISPLAY_CHANGED()
	-- This can lead to a summoning conflict *if* the game itself re-summons the pet after dismounting
	-- Let's try it with a little delay
	if USE_DELAY_PMDC then
		ns.debugprint 'Triggered (delayed) by "PLAYER_MOUNT_DISPLAY_CHANGED"'
		C_Timer_After(DELAY_PMDC, ns.autoaction)
	else
		ns.debugprint 'Triggered by "PLAYER_MOUNT_DISPLAY_CHANGED"'
		ns.autoaction()
	end
end

local function COMPANION_UPDATE(what)
	-- This event fires always 2 times, so let's listen to the last one.
	if what ~= 'CRITTER' or eventthrottle_companionupdate then return end
	eventthrottle_companionupdate = true
	C_Timer_After(0.7, function()
		eventthrottle_companionupdate = nil
		if not ns.pet_restored then
			ns.save_pet()
			if ns.db.debugMode then
				ns.debugprint(
					'"COMPANION_UPDATE" triggers ‹save_pet()›; ‹actpet›:',
					ns.id_to_name(C_PetJournal_GetSummonedPetGUID())
				)
			end
		else
			ns.pet_restored = nil
			if ns.db.debugMode then
				ns.debugprint(
					'"COMPANION_UPDATE": pet restored, not saving; ‹actpet›:',
					ns.id_to_name(C_PetJournal_GetSummonedPetGUID())
				)
			end
		end
	end)
end

-- See bottom of file for complete pet battle event chain

local function PET_BATTLE_OPENING_START()
	ns.debugprint '"PET_BATTLE_OPENING_START" unregisters events'
	ns.events:unregister_summon_events()
	ns.events:RegisterEvent 'PET_BATTLE_OVER'
	ns.in_battlesleep = true
	-- In theory, this is redundant here. However I noticed that since the
	-- change of the save-pet logic (2.3.0), the correct pet isn't always
	-- restored after a battle (maybe 5–10%, possibly in conjunction with a
	-- second battle or with entering combat while in battlesleep).
	-- TODO: Observe if this improves the behavior.
	ns.pet_verified = false
end

local function PET_BATTLE_OVER()
	ns.debugprint('"PET_BATTLE_OVER" will reregister events in sec:', DELAY_AFTER_BATTLE)
	C_Timer_After(DELAY_AFTER_BATTLE, function()
		if C_PetBattles_IsInBattle() then return end
		ns.events:UnregisterEvent 'PET_BATTLE_OVER'
		ns.in_battlesleep = false
		-- Summon without waiting for trigger event
		-- TODO: change the default to not instasummon:
		-- Restoring the pet when moving should be sufficient, and it will eliminate possible
		-- glitches while standing still and selecting teams in Rematch.
		if instasummon_after_battlesleep then ns.transitioncheck() end
	end)
end

local function PET_JOURNAL_LIST_UPDATE()
	ns.debugprint '"PET_JOURNAL_LIST_UPDATE" sets ‹pool_initialized› = false'
	ns.pool_initialized = false
end
ns.PET_JOURNAL_LIST_UPDATE = PET_JOURNAL_LIST_UPDATE -- Used in main

-- This is the latest login-type event; use for login messages
local function FIRST_FRAME_RENDERED()
	-- *Not* with PLAYER_ENTERING_WORLD so that it is not affected
	-- when all events get unregistered via /pw a
	ns.events:UnregisterEvent 'FIRST_FRAME_RENDERED'
	C_Timer_After(DELAY_LOGIN_MSG, function()
		ns.msg_login()
		ns.msg_db_updated()
	end)
	ns.user_is_author = tf6 and tf6.user_is_tflo
end

local function PLAYER_LOGOUT()
	ns.db.remainingTimer = ns.remaining_timer(time())
end

--[[===========================================================================
	Event frame
===========================================================================]]--

local event_handlers = {
	['ADDON_LOADED'] = ADDON_LOADED,
	['LOADING_SCREEN_ENABLED'] = LOADING_SCREEN_ENABLED,
	['LOADING_SCREEN_DISABLED'] = LOADING_SCREEN_DISABLED,
	['PLAYER_ENTERING_WORLD'] = PLAYER_ENTERING_WORLD,
	['FIRST_FRAME_RENDERED'] = FIRST_FRAME_RENDERED,
	['PLAYER_MAP_CHANGED'] = PLAYER_MAP_CHANGED,
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

ns.events:RegisterEvent 'ADDON_LOADED'
ns.events:RegisterEvent 'FIRST_FRAME_RENDERED' -- Only needed at initial login
ns.events:RegisterEvent 'PLAYER_ENTERING_WORLD' -- Only needed at initial login

-- Groups

-- Used events that are not in any group:
-- ADDON_LOADED
-- PET_BATTLE_OVER (registered after PET_BATTLE_OPENING_START)

function ns.events:register_summon_events()
	ns.debugprint '‹register_summon_events()› called'
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
		if USE_PMDC then self:RegisterEvent 'PLAYER_MOUNT_DISPLAY_CHANGED' end
	end
end

function ns.events:unregister_summon_events()
	ns.debugprint '‹unregister_summon_events()› called'
	self:UnregisterEvent 'ZONE_CHANGED'
	self:UnregisterEvent 'ZONE_CHANGED_INDOORS'
	self:UnregisterEvent 'PLAYER_MOUNT_DISPLAY_CHANGED'
	self:UnregisterEvent 'PLAYER_STARTED_MOVING'
end

function ns.events:register_meta_events()
	ns.debugprint '‹register_meta_events()› called'
	self:RegisterEvent 'LOADING_SCREEN_ENABLED'
	self:RegisterEvent 'LOADING_SCREEN_DISABLED'
-- 	self:RegisterEvent 'PLAYER_ENTERING_WORLD'
	self:RegisterEvent 'PLAYER_MAP_CHANGED'
	self:RegisterEvent 'PET_JOURNAL_LIST_UPDATE'
	self:RegisterEvent 'COMPANION_UPDATE'
	self:RegisterEvent 'PET_BATTLE_OPENING_START'
	self:RegisterEvent 'PLAYER_LOGOUT'
end

function ns.events:unregister_meta_events()
	ns.debugprint '‹unregister_meta_events()› called'
	self:UnregisterEvent 'LOADING_SCREEN_ENABLED'
	self:UnregisterEvent 'LOADING_SCREEN_DISABLED'
-- 	self:UnregisterEvent 'PLAYER_ENTERING_WORLD'
	self:UnregisterEvent 'PLAYER_MAP_CHANGED'
	self:UnregisterEvent 'PET_JOURNAL_LIST_UPDATE'
	self:UnregisterEvent 'COMPANION_UPDATE'
	self:UnregisterEvent 'PET_BATTLE_OPENING_START'
	self:UnregisterEvent 'PLAYER_LOGOUT'
end

-- v3.1: no longer needed.
-- We now call register_summon_events exclusively from transitioncheck, i.e.
-- register_meta_events and register_summon_events should never be called together
-- function ns.events:register_pw_events()
-- 	ns.debugprint '‹register_pw_events()› called'
-- 	self:register_meta_events()
-- 	self:register_summon_events()
-- end

function ns.events:unregister_pw_events()
	ns.debugprint '‹unregister_pw_events()› called'
	self:UnregisterAllEvents()
end

--[[ Typical event chain at login (not in instance): ]]--[[

[286.773] VARIABLES_LOADED
[287.869] PLAYER_LOGIN
[290.314] PLAYER_ENTERING_WORLD: Login
[291.881] LOADING_SCREEN_DISABLED
[294.388] FIRST_FRAME_RENDERED
[295.735] ZONE_CHANGED_NEW_AREA

]]

--[[ Typical event chain at reload (not in instance): ]]--[[

[423.132] VARIABLES_LOADED
[423.602] PLAYER_LOGIN
[426.664] PLAYER_ENTERING_WORLD: Reload
[426.897] LOADING_SCREEN_DISABLED
[427.212] FIRST_FRAME_RENDERED
]]

--[[ Typical event chain at instance change (not walk-in instance): ]]--[[

Entering a dungeon:

[783.837] LOADING_SCREEN_ENABLED
[784.742] PLAYER_LEAVING_WORLD
[784.787] PLAYER_MAP_CHANGED: -1 --> 2923
[784.788] ADDON_RESTRICTION_STATE_CHANGED : Map (4): Activating
[789.616] PLAYER_ENTERING_WORLD: Loadscreen
[789.701] LOADING_SCREEN_DISABLED
[789.951] ZONE_CHANGED_NEW_AREA

Leaving a dungeon:

[927.525] LOADING_SCREEN_ENABLED
[928.637] PLAYER_LEAVING_WORLD
[928.671] PLAYER_MAP_CHANGED: -1 --> 0
[928.671] ADDON_RESTRICTION_STATE_CHANGED : Map (4): Inactive
[938.913] PLAYER_ENTERING_WORLD: Loadscreen
[939.001] LOADING_SCREEN_DISABLED
[939.348] ZONE_CHANGED_NEW_AREA

]]

--[[ Typical event chain at instance change (walk-in instance): ]]--[[

Entering a delve:

[971.635] PLAYER_MAP_CHANGED: 0 --> 3038
[971.635] ADDON_RESTRICTION_STATE_CHANGED : Map (4): Activating
[971.653] ZONE_CHANGED_NEW_AREA
[972.166] WALK_IN_DATA_UPDATE

Leaving a delve:

[046.723] PLAYER_MAP_CHANGED: 3038 --> 0
[046.723] ADDON_RESTRICTION_STATE_CHANGED : Map (4): Inactive
[046.763] ZONE_CHANGED_NEW_AREA

]]


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
