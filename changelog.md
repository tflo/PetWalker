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
