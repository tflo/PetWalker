To see all commits, including all alpha changes, [***go here***](https://github.com/tflo/PetWalker/commits/master/).

---

## Releases

#### 2.6.0 (2025-11-05)

- **New: Multiple “previous pets” instead of just one.** See it as history of your recently summoned pets:
    - The existing “previous pet” command (`/pw p` or your keybind) now cycles through the recent pets (and the “current” one), instead of just swapping previous/current back and forth. 
    - Default is 3. But you can change the number of recorded recent pets with `/pw p <number>` between 1 and 20 (global setting).
        - To replicate the old behavior, just set it to 1.
    - The history is independent of any favorites or auto-summoning, i.e., it remembers also your manually summoned pets.
    - This involves a significant change to the save-pet mechanics. Bugs might still be alive; please report them to the [GitHub Issues](https://github.com/tflo/PetWalker/issues) page of the addon.
- Better database handling, cleanup; migrate obsolete entries.
    - You might loose some data from your existing SV file. I hope not, but it might happen.
- Updated ReadMe/description.

#### 2.5.16 (2025-11-04)

- Improved icon 64x64.

#### 2.5.15 (2025-11-04)

- Seems we messed up the scope of `pet_restored` in ba20a32.
- toc: add 110207.

#### 2.5.14 (2025-10-07)

- toc bumped to 110205, no changes.

#### 2.5.13 (2025-09-14)

- ReadMe/description: fixed wrong URL; added my new addon [Auto Discount Repair](https://www.curseforge.com/wow/addons/auto-discount-repair) to the “Other addons” list.

#### 2.5.12 (2025-09-14)

- Standardized licensing information in the files.
- ReadMe/description: minor changes; added my new addon [Auto Discount Repair](https://github.com/tflo/AutoDiscountRepair) to the “Other addons” list.

#### 2.5.11 (2025-08-25)

- Removed the hook to a BattlePetBreedID (BPBID) addon function:
    - See change notes 2.4.2 (2025-02-27), where it was introduced.
    - No longer needed, since the author fixed the event spam: See [issue 32, BPBID](https://github.com/MMOSimca/BattlePetBreedID/issues/32) and this [commit](https://github.com/MMOSimca/BattlePetBreedID/commit/ed640ed0b34696902ed7a5fe026bd842df276046).

#### 2.5.10 (2025-08-19)

- Major code refactoring and cleanup, part 1/WiP.
    - There’s a chance that this introduces a bug or two, e.g. no longer accessible local functions. My testing was fine, but please report to the [issues tracker](https://github.com/tflo/PetWalker/issues) if you notice something weird or get an error in BugSack.
- When switching between char favs and global favs via the Pet Journal checkbox, immediately summon a pet from the respective list (it’s the same behavior now as when switching via `/pw c` console command).
- Finetuning for the PLAYER_MOUNT_DISPLAY_CHANGED event has now moved to _events.lua._ If you want to experiment with it (see 2.5.0 change notes), search for the string `BEGIN PMDC finetuning`. Experimenting is optional, ofc; the default settings seem fine to me. (Accordingly removed the “experimental” words from the respective comments.)

#### 2.5.9 (2025-08-05)

- toc: Added interface `110200`

#### 2.5.8 (2025-06-18)

- toc: Added `AllowAddOnTableAccess: 1`
- toc: Removed Interface `110105`

#### 2.5.7 (2025-06-04)

- Added missing changelog for 2.5.6.
- Minor formal internal changes.

#### 2.5.6 (2025-06-01)

- Added `IsFalling` exclusion to the is_flying bunch. Should fix https://legacy.curseforge.com/wow/addons/petwalker?comment=32.
- Restructured/renamed the “not on ground” conditions.

#### 2.5.5 (2025-05-09)

- Fixes an infinite loop (“script ran too long”) in situations where the pet pool is zero and no Current Pet has been saved yet (issue #20).
    - We now fall back to `C_PetJournal.SummonRandomPet` if there isn’t a saved pet. This force-populates the missing DB entry.
    - We no longer immediately restore the saved pet when a new-pet summoning fails due to a zero pet pool. You’ll just get the “low pet pool” warning as usual. (If your pet is missing, it will be restored at the next trigger anyway.)
    - Updated related user and debug messages.
- Removed some unused code.
- Added a few checks to the debug display.
- Added pet GUIDs to the debug display.
- Added currently summoned pet to the debug display.

#### 2.5.4 (2025-04-18)

- toc: Flagged upcoming client version 110105 as compatible.
- Added 9 tests to the debug display:
    - This includes things like `HasOverrideActionBar()` and similar GUI/UI states.
    - Conditions that are currently considered by PW are marked with “(used)”, i.e. PW does not summon a pet when the condition is met.
    - This is mainly for my debugging QoL.
    - You can make use of it when you are going to report an issue about PW summoning a pet when it shouldn’t. The command for the debug display is `/pw dd` (unchanged).
    - If you’re a curious person, these tests might give you insight. AFAIK, there is no other addon that reports all these UI/GUI states with one single command ;) (Might be useful when writing macros, since many of the tested conditions are usable in macros.)

#### 2.5.3 (2025-03-22)

- Modified a *do-not-autosummon* conditional so that it now covers *any* channeling done by the player.
    - In particular, this should prevent PW from interrupting a Fishing channeling started while still mounted. This interference became possible with the “PLAYER_MOUNT_DISPLAY_CHANGED as additional event to trigger summoning”, recently introduced with v2.5.0.

#### 2.5.2 (2025-03-16)

- Small change that may improve the resummoning of the correct pet after a pet battle.
    - The changes to the save pet logic in v2.3.0 (to ensure that pets summoned in unusual ways are saved) had a negative impact on the reliability of resummoning the correct pet after a pet battle under certain circumstances. This change may help (experimental).
- Merged pull request from @milotic (typo in console message).

#### 2.5.1 (2025-03-04)

- Added `HasVehicleActionBar()` to the *do-not-autosummon* conditions.
    - This allows to do the quests “The Hole Deal” (84142) and “Boomball” (85263) in the TWW Undermine zone without interference by PetWalker. Might be useful for some other quests as well.
    - Similar conditions that were already implemented are `UnitHasVehicleUI('player')` and `IsPossessBarVisible()`; these cover most of the controller-style toys and some sensible vehicle quests (see change notes of version 2.2.1 (2024-09-11)).
    - But remember, if you encounter a quest (or toy) where PetWalker’s autosummoning interferes and it is not covered by the built-in *do-not-autosummon* conditions, you can always toggle PW’s autosummoning with `/pw a`.

#### 2.5.0 (2025-03-02)

- **Some improvements** (probably):
    - We now run the summoning prevention checks with *every* type of summoning function (unless throttled). This should make checks like the ones against auras even more reliable.
    - Being in a taboo instance (e.g. M+) will now cause PW to unregister all summoning events, instead of applying a long throttle time. The events will be re-registered after the next load screen.
    - Slightly reduced the delays after load screens (login, reload, instance change). I have a fast computer now 😁, but it should still work fine on slower setups.
    - Cleanup and misc optimizations.
- **Experimental:** 
    - We now use PLAYER_MOUNT_DISPLAY_CHANGED as additional event to trigger summoning. This event notably fires when you mount/dismount.
    - The idea is to smooth out the behavior when you land with your mount and dismount, i.e. to summon a missing pet as soon as possible after dismounting, to minimize the risk of GCD conflicts. This change is somewhat important, since flying is one of the most common reasons for losing a pet.
    - The difference should be noticeable especially if you land and dismount immediately (without having started moving on the ground while still mounted), or if you have deactivated the “summoning while mounted for Skyriding” option (the `/pw sr` toggle). 
    - This is *experimental* because the catch is that sometimes the game itself will correctly re-summon your pet when you dismount (yes, it does, but not reliably). When this happens, PW’s summoning attempt may collide with the game’s summoning, causing the pet to be unsummoned in the worst case. This is not catastrophic, since PW will re-summon the pet 3s later when you start moving, but it defeats the purpose of this change.
    - We are trying to avoid this with the help of a timer (currently trying values between 0 and 0.6s), but only play and observation can tell if it is an improvement or what the best delay is.
    - *If you want to, you can experiment on your own:* you find a couple of related variables in *main.lua*, around line 105 (search for “BEGIN Experimental”). There are some explicative comments there too. You can toggle debug mode with `/pw dm` to see what is exactly going on.

#### 2.4.2 (2025-02-27)

- Added protection against event spam caused by the BattlePetBreedID addon.
    - If a pet tooltip is displayed and you have BattlePetBreedID’s “Current pet’s collected breeds” option enabled, BPBID calls an API function which in turn triggers the PET_JOURNAL_LIST_UPDATE event (for every single tooltip). PetWalker relies on this event to know if the pet pool needs to be reinitialized, but BPBID triggers the event also without any actual pet list changes.
    - To avoid the unnecessary load caused by this, we hook into the responsible BPBID function and set a flag that tells PetWalker to ignore the next PET_JOURNAL_LIST_UPDATE.

#### 2.4.1 (2025-02-26)

- Fixed an oversight in the aura protection (see 2.4.0) that leads to failure if per-char favs are enabled but not favs-only.

#### 2.4.0 (2025-02-26)

- Added a protection for the Daisy, Feathers, Crackers, and Cap’n Crackers auras. See [issue 18](https://github.com/tflo/PetWalker/issues/18). Thanks to @gizzmo on GitHub for the aura list and suggestion.
- Updated readme/description.
- Added category to toc.
- toc bump to 110100.

#### 2.3.1 (2024-12-19)

- toc bump to 110007 (WoW Retail 11.0.7).
- No content changes. If I notice that the addon needs an update for 11.0.7, I will release one.
- I currently do not have much time to play, so if you notice weird/unusual behavior with 11.0.7 and don’t see an update from my part, please let me know [here](https://github.com/tflo/PetWalker/issues).

#### 2.3.0 (2024-10-05)

- Reworked the logic behind “when should a pet that was not summoned by PetWalker be saved as the ‘correct’ pet” from *including* to *excluding*.
    - PetWalker now considers any pet that is summoned by the user, no matter how, as “intentionally summoned” (aka ‘correct’) and saves it for later restore.
    - *This namely includes pets that are summoned using an action bar button,* as well as pets summoned via the “Summon Random Favorite Pet” button in the Pet Journal or the `/randompet` slash command, and possibly other summoning methods
    - A pet that is force-summoned because you put in a pet battle slot (Pet Journal), or because Rematch loads a pet battle team, is excluded from this. *So, you should still get back your ‘correct’ (previous) pet after a pet battle.*
    - This should fix [Issue #12](https://github.com/tflo/PetWalker/issues/12). If you still experience related glitches, please report them to Issue #12. If you were using the 2.3.0 beta versions, this is basically beta3 plus some cleanup.

#### 2.2.1 (2024-09-11)

- Added `IsPossessBarVisible` to the summoning prevention checks. (Thanks to [Legolando](https://www.curseforge.com/members/legolando/projects)!; [Issue #11](https://github.com/tflo/PetWalker/issues/11))
    - This replaces a couple of previously blacklisted auras by ID.
    - This also covers most controller-style toys that weren’t excluded before.
    - *Note 1:* The purpose of the summoning prevention checks is to ensure that PW does not summon pets in situations where it may be disruptive or undesirable (e.g. arena, M+, stealth, invisibility, vehicle, certain quest-related or toy-related auras). This update should significantly improve behavior in the toy department.
    - *Note 2:* However, it is likely that not all situations where auto-summoning is unwanted are covered. In such a case, remember that you can always quickly toggle PW’s auto-summoning with the `/pw a` command or your hotkey.

#### 2.2.0 (2024-08-10)

- Implemented the totally reworked summoning prevention and throttling system (probably needs finetuning).
    - This is the thing I started almost 12 months ago (see the change notes for v2.0.8!) and then fell victim to my laziness.
    - This doesn’t bring any groundbreaking changes, but we will save a few CPU milliseconds.
    - New or changed Summon Check throttle times for some situations: e.g. 20s when flying, 8s when in combat or with certain auras, 40s for certain other auras, 120s when in certain instance types.
- Adapted to modern times: Properly detect if we are in Skyride mode and mounted on a Skyride mount. Needed for the `/pw sr` toggle to allow/disallow pet summoning in this situation (while still on ground, of course).
- Changed the Dragonride/Skyride ‘Allow Summoning’ toggle from `/pw r`/`/pw drsum` to `/pw sr`.
- Manually summoning a new pet via slash command (`/pw n`) now correctly sets the “manual” parameter (like it does with hotkey summoning). This should prevent errors when you accidentally try to summon in combat.
- Added flying/taxi check also to the manual summoning methods. This should prevent false “summoned pet” messages.
- Removed “Daisy as backpack (/beckon)” aura from the blacklist:
    - It was on the blacklist because if you summon Daisy while she is on your back, she will disappear.
    - Removed because it is perfectly fine to summon other pets while Daisy is on your back (she will not disappear).
- Removed PDF version of the readme.md. I think nowadays most people know how to preview a Markdown document, and a rendered view is on the [GitHub page](https://github.com/tflo/PetWalker?tab=readme-ov-file#petwalker) anyway.
- Changes to the readme/description.
- Added `debug` word as debug mode toggle, in addition to `dm` (replaces `debm`)
- Various optimizations; cleanup.


#### 2.1.8 (2024-07-24)

- Seems to work fine with TWW 110000 — so far; further tests will follow.
- toc updated for TWW 110000.

#### 2.1.7 (2024-05-08)

- toc bump only (100207). Addon update will follow as needed.

#### 2.1.6 (2024-03-22)

- Fixed a nil value in a notification that could occur when PW tried to summon a saved pet that is no longer summonable (e.g. removed from the collection).

#### 2.1.5 (2024-03-19)

- toc bump only. If necessary, the addon will be updated in the next days.

#### 2.1.4 (2024-02-17)

- Added a keybinding for ‘Summon Previous Pet’
  - You can set it in Options > Game > Keybindings > PetWalker, along with the other 4 keybindings.
  - This does the same as the command `/pw p` (which still exists).
  - This function is more useful than you may think. A few tips:
    - If you're a Blacksmith or Engi, you probably have Alvin the Anvil on your action bar or OPie ring. Well, Alvin is useful, but, let's face it, a bit boring as a companion. So when you are done with your work, say thanks to Alvin and hit the Previous Pet key and you will have your previous companion back.
    - Press the key repeatedly to toggle between two pets. This allows you to have two temporary favorites (or "favorites of the day") without changing your Pet Journal favorites: Disable the autosummon timer (`/pw 0`), summon the first pet, and then the second pet. Now you can switch between them with a single keystroke.
    - ‘Previous Pet’ also works in conjunction with the autosummon timer, and it resets the timer. So if the timer summons a new pet, but you'd like to have the other one for a little longer, just press the Previous Pet key and you'll have it for another 30 minutes (or whatever your timer is set to).

#### 2.1.3 (2024-01-16)

- Just a toc bump for 10.2.5. Compatibility update will follow if needed.

#### 2.1.2 (2023-11-08)

- Added two aura exclusions (i.e. no pet summoning when aura is present):
  - Eye of Kilrogg in the context of the Eye See You quest (Azsuna); thanks @gizzmo for reporting.
  - Jerry the Snail (Gastropod Shell toy).
- `/pw` now prints help first, then status (it used to be the other way around). So you don't have to scroll up to see the status info (you can still get it individually with `/pw h` and `/pw s`).
- Slightly longer delay after login.
- `debugprint` changes.
- toc updated for 10.2.

#### 2.1.1 (2023-10-13)

- Fixed wrong type.
- Better wording in the 'nothing eligible' warning.

#### 2.1 (2023-10-13)

- Proper handling of pets that require a specific faction (Issue [#7](https://github.com/tflo/PetWalker/issues/7)). This should fix all glitches and incorrect messages when…
  - …switching between an Alliance and Horde toon and the last pet was a faction-restricted pet.
  - …random summoning with faction-restricted pets set as favorites.
  - Special thanks to [@gizzmo](https://github.com/gizzmo) for discovering anomalies with certain (presumably bugged) faction-restricted pets and bringing this to my attention.
- More robust behavior after login, reload, and instance/map transitions (pet detection and restore).
- Tweaks to the PetWalker Char Favs checkbox (in the Pet Journal) and improved tooltip.
- Squished a fat bug that could prevent a pet summoned via PW from being correctly saved as valid 'current pet'.
- Note: The event throttling and summoning prevention rework (see 2.0.8) is still WiP (but don't worry, the current system is fully functional and bugfree™️; the rework is just for efficiency).

#### 2.0.8 (2023-09-06)

- Code preparations for a revamped event throttling and summoning prevention implementation (coming soon).
- Already more efficient detection of arena and mythic dungeons (for the summoning prevention) with this version.
- Minor code cleanup and improvements.
- toc bump tp 100107.

#### 2.0.7 (2023-07-26)

- Attempt to fix an error that occures when trying to summon the same pet as the target (`/pw t`) and the pet is not in the
  collection (not owned).

#### 2.0.6 (2023-07-23)

- Minor code and readme fixes.

#### 2.0.5 (2023-07-12)

- Readme improved.

#### 2.0.4 (2023-07-12)

- toc updated for 10.1.5.
- I've only tested it briefly with 10.1.5, but it seems OK, and as far as I know there are no relevant API changes. If I discover any problems, you'll get a content update soon.

#### 2.0.3 (2023-05-03)

- Added in-game icon.

#### 2.0.2 (2023-05-02)

- Code optimization (and embellishment).
- toc updated for 10.1.

#### 2.0.1 (2023-04-28)

- Updated readme.pdf. (For the big change notes, see 2.0.0.)

#### 2.0.0 (2023-04-28)

- Completely reworked the handling of intentional user summoning versus automatic (unwanted) summoning in the context of pet battles:
  - As you probably know, when a pet is slotted into a battle team, it is automatically summoned. PetWalker has always had trouble distinguishing between this unwanted summoning and the user's intentional summoning, resulting in the "wrong" pet being at your side after a pet battle.
  - This should now be a thing of the past. PetWalker now reliably ignores any pet that is summoned via team slotting, and is therefore able to reliably re-summon your previous pet after the pet battle.
  - This works regardless of Rematch's "Keep Companion" setting. After a pet battle ends, PetWalker will "sleep" for 15 seconds. If you have Rematch's "Keep Companion" enabled, Rematch will (probably) resummon your previous pet immediately after the battle, without any risk of collision with PetWalker's activities.
  - If you don't have Rematch's "Keep Companion" enabled, PetWalker will re-summon your previous pet if you don't start a new pet battle after 15 seconds.
  - This 15 second sleep also allows you to chain-battle (e.g. when power-leveling) without the annoyance of pets repeatedly re-summoning/disappearing between battles (assuming you have Rematch's Keep Companion turned off!). Sure, you could turn PetWalker off manually for the duration of your power-leveling session, but this will save you the hassle.
  - So the old recommendation to keep Rematch's "Keep Companion" enabled has now changed to "Do whatever you want". Rematch will restore your pet immediately after a battle, PetWalker will wait 15 seconds.
  - Along with this overhaul, the detection of regular (intentional) pet summons has also been greatly improved and streamlined: Instead of relying on a wonky combination of events, we now hook directly into the summoning function. This should make it impossible for PetWalker to miss that the player has manually summoned a new pet and erroneously returns the old pet.
  - Since two core mechanics of the addon have drastically changed, it is likely that all this will see some fine tuning in the next weeks.
- Also:
  - Added login message: The message will appear shortly after login in the chat, and will display the most important current settings in one line (sort of a mini Status Display). You must have the verbosity level set to 2 or higher for the message to appear. On verbosity level 3, the message additionally shows the current pet and, if current pet and saved pet are out of sync, also the last saved pet.
  - When you enable Favorites, the confirmation message will now indicate whether the toon has per-char favorites or global favorites enabled.
  - The Status Display now also shows the version of the addon.
  - Enabling Auto (`/pw a`) now instantly triggers the main action (random pet or restore pet).
  - When switching between char and global favs while PW is deactivated (Auto off), the Pet Journal now reflects the correct favs.
  - Miscellaneous minor improvements and corrections to the UI.
  - Miscellaneous minor code cleanup and fixes, updated description/readme.

#### 1.3.0 (2023-04-16)

- If you now disable auto-summoning with the usual command (`/pw a`), all events will be unregistered.
- This means … actually nothing for you from a CPU perspective, but it is a cleaner way to disable auto-summoning. And you can now rest assured that when PW's auto-summoning is off, it won't interfere with or delay anything. It will do exactly _nothing_ then, unless you use a PW hotkey or slash command.

#### 1.2.3 (2023-04-07)

- Updated readme.md, readme.pdf, description on CurseForge and Wago:
  - Added a point to the FAQ to make it clearer that the Pet Journal filters (and not the Rematch filters) are affecting the pool of pets that is used for summoning. Fixes [issue#6](https://github.com/tflo/PetWalker/issues/6).
- Modified the Pet Pool warning message to make it clearer to the user that he should verify the Pet Journal filters, not the Rematch ones.

#### 1.2.2 (2023-03-31)

- Added: Automatic removal of orphaned pet IDs from the char favorites table.
  - A pet ID becomes "orphaned" when the server assigns a new ID to the pet in your collection (for whatever reason), and also when you cage a pet. As a result you could have a wrong char favorites count in the Status display (e.g. it says your char has 8 favorites but displays only 5 pet links), and permanently invalid pet entries in your Saved Variables file. The removal happens automatically in the background whenever the pet pool is updated.
  - If PW removes an orphaned pet ID, you'll get a message in the chat, so you know that something has changed with your char favs.
- Fixed: The "Your only eligible random pet is already active" message appeared more often than intended.
- Some code cleanup.

#### 1.2.1 (2023-03-27)

- Added aura 290460 to excluded auras. This is the aura you get when you mount the Battlebot Champion in Zskera Vault (Forbidden Reach). PW tried to summon a pet, which threw you out of the Battlebot; this no longer happens.

#### 1.2.0.1 (2023-03-22)

- Fixed: "Summoning while mounted in Dragonriding zone" setting was not correctly reflected in the Status display.

#### 1.2.0 (2023-03-22)

- Pet summoning can now occur while mounted (not flying). This is a significant change:
  - With normal mounts, this is clearly a good thing, because: A problem with (auto-)summoning pets can be that it triggers the Global Cooldown (GCD), which can prevent you from casting a spell or using an ability at that moment. You are usually less likely to want to cast a spell while mounted, so it is good if the pet is summoned before you dismount. This reduces the chance of a GCD conflict later.
  - With Dragonriding mounts, it's a bit different: The Dragonriding abilities require you to be off GCD. While on the ground, this applies to "Lift Off" and "Skyward Ascent". This means that, unlike with normal mounts, the GCD triggered by summoning a pet while DR-mounted has a realistic chance of interfering with other abilities (the DR abilities), especially when landing, moving a few yards, and quickly taking off again.
  - So I've added a setting to allow/disallow auto-summoning while mounted in a Dragonriding zone. The toggle command is `/pw r` or `/pw drsum`. I recommend experimenting with this to see if it produces more or less GCD conflicts for you. As with most PW settings, this is an account-wide setting.
  - By default, this setting is _enabled,_ so auto-summoning while mounted in a Dragonriding zone will happen. Depending on user feedback, I may change the default setting in the future.
  - Personally, I'm using it because even if I have an occasional GCD conflict with a Dragonriding ability, it still reduces the chance of a GCD conflict after dismounting. But your experience may vary depending on your personal Dragonriding landing/lift-off "style".
  - To be clear, the GCD is not caused by PetWalker, it's a Blizz thing: any summoning of a pet triggers the GCD. It's stupid IMO, but there's nothing we can do about it. The summoning-while-mounted feature is meant to reduce the chance of GCD conflicts, but it cannot be eliminated.
- Changes to the in-game Help display (`/pw h`) and Status display (`/pw s`).
- Added a hint to the Pet Journal Filter settings to the zero-pets-in-pool warning message.
- Fixed double printing of the zero-pets-in-pool warning message under certain conditions.
- toc updated for 10.0.7.
- Updated ReadMe/Description.

#### 1.1.7 (2023-02-19)

- New message logic for pools of only one pet: You can now have only a single pet in the "random" summon pool (e.g. only one favorite pet or only one char-specific favorite pet) without getting spammed with warnings. Thanks to Syrusel for his constructive input in [#5](https://github.com/tflo/PetWalker/issues/5).
- Finished implementation of the new Summon Target Pet feature. Trying to summon an uncollected target pet gives you a link to the pet's page on warcraftpets.com now, or on wowhead.com if it's not collectible.
- Changed 2nd slash command to `/petwalker` (formerly `/petw`). This should be more intuitive for new users. The short command `/pw` remains unchanged, of course.
- Fixed prefix of the 'invalid command' message and punctuation/formatting of some other messages.
- Changes to some debug functionalities.
- ReadMe/description updated.

#### 1.1.6 (2023-02-17)

- Attempt to prevent that char favs are not correctly intitialized in some situations ([#5](https://github.com/tflo/PetWalker/issues/5))
- Adaptive delays for the initial check after login/reload/other
- Some additions to the ReadMe, mainly concerning Pet Journal filters and search box
- Added a PDF version of the ReadMe (description) to the addon folder. This is mainly due to CurseForge's broken Markdown parser, but may be useful in other ways as well.

#### 1.1.5 (2023-01-25)

- toc: Updated for 10.0.5.
- New (beta) feature: Summon same pet as targeted pet:
    1. Target a summoned pet of another player
    2. Enter `/pw t` or `/pw target` or set and use the new keybind in the Keybinding section
    3. If the targeted pet is in your collection, it should be summoned
- Changes to the ReadMe.

#### 1.1.4 (2022-12-31)

- Added Curseforge project ID.
- Adapted ReadMe for Curseforge's broken Markdown parser.

#### 1.1.3 (2022-11-17)

- Added PetWalker category for the keybinds panel (free of taint, tested), as Blizz has broken the display of headers in the AddOn category.
- Other, minor, changes in the binding system. You'll have to rebind your PetWalker hotkeys though. Sorry for that!
- toc: Updated for 10.0.2.

#### 1.1.2 (2022-10-26)

- Adapted the aura check to the new DF unit aura API.
- For the moment disabled the possibility to Cmd/Ctrl-click a pet in the Pet Journal list to make it a favorite. (Due to DF changes.)
- toc: Updated for 10.0.0.
- TODO (non-critical): Add a check for orphaned pet GUIDs in the char favorites table, and remove them.

#### 1.1.1 (2022-09-25)

- Fix for Brewfest: No pet summoning allowed while we are riding a Ram for the daily quests.
  - Summoning attempts could cancel the Ram aura (43880 and 43883).

#### 1.1.0 (2022-08-24)

- Squished `/pw n` bug.
- Help and Status message (`/pw h` and `/pw s`): added examples, fixed punctuation; split into chunks for better scrolling.
- Added many infos to the ReadMe.
- New setting: verbosity level for messages:
  - `/pw v`: silent; only important messages (missing favorites, failed summons, etc.) are printed to chat.
  - `/pw vv`: medium; message when a new pet is summoned (via timer or via keybind / slash command).
  - `/pw vvv`: full; all messages, also when a lost pet is auto-restored, which happens quite often.

#### 1.0.4.1 (2022-08-24)

- Meta changes for packager.
- toc: Updated for 9.2.7.

#### 1.0.4 (2022-05-31)

- Added UnitOnTaxi check.
- Fixed error in description.
- Reverted back to PLAYER_ENTERING_WORLD for the TransitionCheck (instead of ZONE_CHANGED_NEW_AREA).
- toc: Added Wago ID.
- toc: Updated for 9.2.5.
- toc: Changed my Author Name to my Wago account name.

#### 1.0.3 (2022-04-30)

- Improved description.

#### 1.0.2 (2022-04-29)

- Improved description.

#### 1.0.1 (2022-04-29)

- Improved description.

#### 1.0.0 (2022-04-28)

- Initial public release.
