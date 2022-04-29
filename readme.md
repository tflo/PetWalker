# What is this?

An add-on for World of Warcraft (WoW) Retail. Probably/maybe works also with the Classic variants (untested).

# Purpose

The add-on helps you to always have a pet out (summoned). Optionally it can summon a random pet (from a configurable pool) every n minutes.

# Notes

This add-on started out as an improved version of [NugMiniPet](https://www.curseforge.com/wow/addons/nugminipet), but in the meantime not much of the original code is left. Currently, only the approach for char-specific favorite pets is shamelessly copied from NugMiniPet. Will be improved soon.
Credits for the idea, and for some of the coding to [d87_](https://www.curseforge.com/members/d87_/projects), the author of NugMiniPets.

## Sources

### Repo:
https://github.com/tflo/PetWalker

### All releases:
https://github.com/tflo/PetWalker/releases

### Issues/suggestions/praise/discussion:
https://github.com/tflo/PetWalker/issues

### Wiki (NYI):
https://github.com/tflo/PetWalker/wiki


# Features

## General

* No GUI settings. Basically it’s a set-and-forget add-on.
* No nasty Minimap button, and thus no conflicts with LeatrixPlus.
* 100% standalone, no libraries or other dependencies.
* Extremely resource (CPU/memory) friendly.
* Alt friendly: All settings are account wide (except for char-specific favorite pets, ofc).
* For obvious reasons conflicting with: [NugMiniPet](https://www.curseforge.com/wow/addons/nugminipet), [Zone Pet](https://www.curseforge.com/wow/addons/zonepet) and probably any similar add-on that auto-summons pets.
* Not conflicting with: [Rematch](https://www.curseforge.com/wow/addons/rematch). Usage of Rematch is recommended.

## Functionality

* Re-summons your pet when it got lost due to game flaws/bugs: using portals or teleports, mounting/dismounting, end of combat, resurrection, nuclear fallout, etc.
* ‘Last summoned pet’ is saved across chars. So, if you log out with a given pet on your Mage, then login with your Dracthyr Evoker, you should see the same pet summoned, right from the login.
* Takes care to not not disturb during various activities/circumstances: Higher M+, Arena, Stealthed, In Combat, and more.
* The pool of eligible pets to be summoned can be char-specific or account-wide. You can change this setting at any time and as often as you want, the char-specific list (if created) will be preserved.
* Easy switch between ‘random-summoning new pet’ and ‘just keep my pet out’. (‘/pw 0’, see Usage)
* Does not try to summon pets that can/should not be summoned, e.g. Pocopoc in Zereth Mortis, the Winter Veil pets, or the vendor pets with CD like Guild Herald.

# Usage basics

**/pw a**: Toggle automatic summoning of pets. (Basically enabling/disabling the add-on.)  
**/pw d**: Dismiss current pet and disable auto-summoning.   
**/pw n**: Summon new pet (from the active pet pool**: Favs or All, see commands explained below).    
**/pw p**: Summon previous pet.  
**/pw \<n\>**: Interval [minutes] for summoning a new pet. \<n\> has to be a number. ‘0’ disables summoning of new pets, though the pet-restore functionality is still active (use ‘/pw a’ to disable it).  
**/pw f**: Toggle the random-summon pool between Favorites and All Pets. When set to All Pets, the currently active filters of the Pet Journal still apply.  
**/pw c**: Toggle char-specific favorites list. (Only applies if set to Favorites via ‘/pw f’.)      
**/pw h**: Help text.    
**/pw s**: Status report.    

If ‘/pw’ is conflicting with any of your other add-ons’ commands, then use ‘/petw’ instead.  

Also check the Key Bindings section of your client. You’ll find three bindable commands for PetWalker there:
* Dismiss current pet and disable auto-summoning (same as ‘/pw d’)
* Toggle automatic summoning of pets (same as ‘/pw a’)
* Summon new pet (same as ‘/pw n’)   

***

A more detailed description is in work!

***

# FAQ

## How to set char-specific favorite pets?

1. Set PetWalker to ‘char-specific favorites’ (command ‘/pw c’)
2. Mark your favorites as usual in Rematch / Pet Journal

Unlike the “normal” favorites, these char-specific favorites will not be visually flagged with a star in the pet list. However, you can display a list of your current char-specific favorites in the chat console by entering ‘/pw s’.

## I do not want to summon a new pet every n minutes, I just want to keep my pet.

Simply make sure that the Summon New Pet timer is set to ‘0’ (zero). You can set it to 0 with the command ‘/pw 0’. With this setting, the add-on will never give you a new pet, and will do its best to keep your current pet out, until *you* decide to summon a different one. *How* the pet is summoned, is irrelevant: can be summoned via Pet Journal, or via PetWalker keybind, or whatever. PetWalker will remember it, and re-summon it whenever it is lost.

## Where/when does PetWalker fail to keep my pet out?

Almost never. The most difficult situation is when you select a team for a pet battle. If you are using Rematch, you should select the “Keep Companion” option (in “Miscellaneous Options”). This will definitely help, but it is not 100% assured that, after the pet battle, you have the same pet out as before.

## Which are the events PetWalker is reacting to?

The main event that makes PetWalker check for the pet and summon it if necessary, is PLAYER_STARTED_MOVING.  
This is a very frequent event, yes. I have experimented with various other events, but this one turned out to be best. (After all, the goal of PetWalker is to assure that your pet is *always* out, not that it’s out every once in a while.)  

In rare occasions, PetWalker’s summoning might interfere with other casts, notably with Druids shapeshifting immediately after starting to move. But, since PetWalker does nothing in combat situations (and other critical situations), it should be pretty safe.  

Other noteworthy events PetWalker is listening to are: ZONE_CHANGED_NEW_AREA, PET_JOURNAL_LIST_UPDATE, UNIT_SPELLCAST_SUCCEEDED, COMPANION_UPDATE.


