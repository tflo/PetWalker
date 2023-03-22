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


