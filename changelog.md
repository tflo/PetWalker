## PetWalker – Changes

### 1.1.2 (2022-10-26)
- Adapted the aura check to the new DF unit aura API.
- For the moment disabled the possibility to Cmd/Ctrl-click a pet in the Pet Journal list to make it a favorite. (Due to DF changes.)
- toc: Updated for 10.0.0
- TODO (non-critical): Add a check for orphaned pet GUIDs in the char favorites table, and remove them.

### 1.1.1 (2022-09-25)
- Fix for Brewfest: No pet summoning allowed while we are riding a Ram for the daily quests.
    - Summoning attempts could cancel the Ram aura (43880 and 43883).

### 1.1.0 (2022-08-24)
- Squished `/pw n` bug.
- Help and Status message (`/pw h` and `/pw s`): added examples, fixed punctuation; split into chunks for better scrolling.
- Added many infos to the ReadMe.
- New setting: verbosity level for messages:
    - `/pw v`: silent; only important messages (missing favorites, failed summons, etc.) are printed to chat.
    - `/pw vv`: medium; message when a new pet is summoned.
    - `/pw vvv`: full; all messages, also when a lost pet is restored, which happens quite often.
    
### 1.0.4.1 (2022-08-24)
- Meta changes for packager.
- toc: Updated for 9.2.7.

### 1.0.4 (2022-05-31)
- Added UnitOnTaxi check.
- Fixed error in description.
- Reverted back to PLAYER_ENTERING_WORLD for the TransitionCheck (instead of ZONE_CHANGED_NEW_AREA).
- toc: Added Wago ID.
- toc: Updated for 9.2.5.
- toc: Changed my Author Name to my Wago account name.

### 1.0.3 (2022-04-30)
- Improved description.

### 1.0.2 (2022-04-29)
- Improved description.

### 1.0.1 (2022-04-29)
- Improved description.

### 1.0.0 (2022-04-28)
- Initial public release.


