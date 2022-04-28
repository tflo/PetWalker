# What is this?

An add-on for World of Warcraft (WoW) Retail. Probably/maybe works also with the Classic variants (untested).

# Purpose

The add-on helps you to always have a pet out (summoned). Optionally it can summon a random pet (from a configurable pool) every n minutes.

## Notes

This add-on started out as an improved version of [NugMiniPet](https://www.curseforge.com/wow/addons/nugminipet), but in the meantime not much of the original code is left. Currently, only the approach for marking char-specific pets is shamelessly copied from NugMiniPet. Will be improved soon.
Credits for the idea, and for some of the coding to [d87_](https://www.curseforge.com/members/d87_/projects), the author of NugMiniPets and [all the other “Nug” add-ons](https://www.curseforge.com/members/d87_/projects).

# Features

## General

* No nasty Minimap button, and thus no conflicts with LeatrixPlus.
* Works without any external library.
* Extremely resource (CPU/memory) friendly.
* For obvious reasons conflicting with: [NugMiniPet](https://www.curseforge.com/wow/addons/nugminipet), [Zone Pet](https://www.curseforge.com/wow/addons/zonepet) and probably any similar add-on that auto-summons pets.
* Not conflicting with: [Rematch](https://www.curseforge.com/wow/addons/rematch). Usage of Rematch is recommended along with PetWalker.

## Functionality

* 'Last summoned pet' is saved across chars. So, if you log out with a given pet on your Hunter, then login with your Warlock, you should see the same pet summoned, right from the login.
* Takes care to not not disturb various activities/circumstances: M+, Arena, Stealthed, In Combat, and more.
* The pool of eligible pets to be summoned can be char-specific or account-wide. You can change this setting at any time and as often as you want, the char-specific list (if created) will be preserved.
* Easy switch between 'random-summoning new pet' and 'just keep my pet out'. ('/pw 0', see Usage)

# Usage

/pw a: Toggle automatic summoning of pets  
/pw d: Dismiss current pet and disable auto-summoning  
/pw \<n\>: Interval [minutes] for summoning a new pet. n has to be a number. '0' disables summoning of new pets, though the pet-restore functionality is still active (use '/pw a' to disable it).  
/pw f: Toggle the random-summon pool between Favorites and All Pets. When set to All Pets, the currently active filters of the Pet Journal still apply.  
/pw c: Toggle char-specific favorites list. (Only applies if set to Favorites via '/pw f'.)    
/pw h: Help text  
/pw s: Status report  

Also check the Key Bindings section of your client. You'll find three bindable commands for PetWalker there.

A more detailed description is in work!


