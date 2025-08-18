local addon_name, ns = ...


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

local eventthrottle_companionupdate, pet_restored, ignoreevent_listupdate

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


local monitored_addons = {
	[addon_name] = true,
	['Blizzard_Collections'] = true,
}
-- dtd(monitored_addons)

function ns:ADDON_LOADED(addon)
	if not monitored_addons[addon] then return end
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
		ns.debugprint 'Addon "PetWalker" loaded.'
		ns.time_newpet_success = time() - (ns.db.newPetTimer - ns.db.remainingTimer)
		-- *Not* with PLAYER_ENTERING_WORLD so that it is not affected when all events get unregistered via /pw a
		C_TimerAfter(delay_login_msg, ns.msg_login)

		-- The summon events are now registered with transitioncheck or delayed after PLAYER_ENTERING_WORLD
		if ns.db.autoEnabled then ns.events:register_meta_events() end

		hooksecurefunc(C_PetJournal, 'SetPetLoadOutInfo', function()
			-- Note that SetPetLoadOutInfo summons the slot #1 pet, but it does so _not_ via SummonPetByGUID
			ns.debugprint 'Hook: `SetPetLoadOutInfo` --> Setting `pet_verified` to false'
			ns.pet_verified = false
		end)

	elseif addon == 'Blizzard_Collections' then
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
function ns:PLAYER_ENTERING_WORLD(is_login, is_reload)
	local delay
	-- We do not want summon events before transitioncheck has finished
	ns.events:unregister_summon_events()
	-- Prevent event spam caused by BattlePetBreedID
	if is_login or is_reload then
		if C_AddOnsIsAddOnLoaded('BattlePetBreedID') then
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
-- 			if throttle_reason == 'inair' then throttle = 0 end  -- WTF?!
	-- This can lead to a summoning conflict *if* the game itself re-summons the pet after dismounting
	-- Let's try it with a little delay
	if use_delay_PMDC then
		C_TimerAfter(delay_PMDC, ns.autoaction)
	else
		ns.autoaction()
	end
end

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
