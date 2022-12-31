This is an addon for Modern World of Warcraft (“Retail”).

# Summary

The addon helps you to always have a companion pet out (summoned). You can choose between two operating modes:

- __Auto Restore only:__ Whenever your pet is lost – for whatever reason –, it will be restored. This works across logouts and characters.
- __Random Summon:__ Automatically summons a random pet (from a configurable pool) every n minutes, or via keybind or slash command. This pet will be auto-restored whenever it is lost, until a new one is summoned.

# Notes

In early 2022 this project started out as an improved version of [NugMiniPet](https://www.curseforge.com/wow/addons/nugminipet), but in the meantime not much of the original code is left. 
Credits for the concept, the inspiration and for the initial code base though to the [author](https://www.curseforge.com/members/d87_/projects) of NugMiniPet.

PetWalker was first published on [Github](https://github.com/tflo/PetWalker) and [Wago](https://addons.wago.io/addons/petwalker) in April 2022; starting with version 1.1.4 (Dec 2022) now also available on [Curseforge](https://www.curseforge.com/wow/addons/petwalker).

# Features

## Main Features

- Re-summons (restores) your pet when it has “disappeared”. Most of the time this happens due to flawed game mechanics: using portals or teleports, mounting/dismounting, end of combat, resurrection, entering/leaving instances, etc.
- You can set a repeating timer to auto-summon a new pet from a configurable random pool every n minutes (or hours).
- You can manually summon a new pet from a configurable random pool via keybind or slash command.
- Your ‘current pet’ is saved across chars. So, if you log out with a given pet on toon A, then login with your toon B, you should see the same pet summoned, right at (or very shortly after) login. (You can exclude a toon from that by setting him to char-specific favorites.)
- Also your remaining auto-summon timer is saved at logout and re-applied when you log in again (on any toon). So, if you have set your timer to two hours, you will see a new pet every two hours of gaming time, no matter how often you log out/in or for how long you have been offline. You can see the current remaining timer in the Status report (command `/pw s`, see Usage).
- The addon does its best not to interfere with various activities/circumstances: Higher M+, Arena, Stealthed, In Combat, and more.
- The pool of favorite pets to be summoned can be char-specific or account-wide. You can change this setting at any time: the char-specific list (if created) will be preserved even if you switch from char-specific to global favorites.
- Easy switch between ‘random-summoning new pet’ and ‘just keep my pet out’. (`/pw 0` to disable the auto-timer, see Usage)
- The addon knows about special pets and does not try to summon pets that can or should not be summoned, e.g. the Pocopoc pet in Zereth Mortis, the Winter Veil pets, or the vendor pets with CD like Guild Herald.

## Other Features / Notes

- No GUI settings. Basically it’s a set-and-forget addon.
- No nasty Minimap button, and thus no conflicts with LeatrixPlus or other minimap mods.
- 100% standalone, no libraries or other dependencies.
- Resource friendly in terms of CPU and memory usage. 
- Alt friendly: All settings are account wide (except for char-specific favorite pets, ofc).
- For obvious reasons conflicting with: [NugMiniPet](https://www.curseforge.com/wow/addons/nugminipet), [Zone Pet](https://www.curseforge.com/wow/addons/zonepet) and probably any similar addon that auto-summons pets.
- Not conflicting with: [Rematch](https://www.curseforge.com/wow/addons/rematch). Usage of Rematch is recommended.

# Usage

- __`/pw a`__: Toggle automatic summoning of pets. (Basically enabling/disabling the addon.)  
- __`/pw d`__: Dismiss current pet and disable auto-summoning. A kind of emergency command, if you want to get rid of your pet immediately and prevent any automatic summoning.   
- __`/pw <number>`__: Interval [minutes] for summoning a new pet. ‘0’ disables summoning of new pets, though the pet-_restore_ functionality is still active (use `/pw a` to disable it).
- __`/pw f`__: Toggle the random-summon pool between Favorites and All Pets. 
    - With the All Pets setting, the currently active filters of the Pet Journal apply (Pet Family and Sources). Since these filters can be combined, this offers quite some possibilities to create varied pools for random summoning, without the need to select favorites.
    - Note that this works only with the filters set in Blizz’s Pet Journal, not the filters in Rematch.
- __`/pw c`__: Toggle char-specific favorites list. (Only applies if set to Favorites via `/pw f`.)      
- __`/pw n`__: Summon new pet (from the active pet pool: Favs or All, see commands explained above). Summoning a pet with `/pw n` (or the keybind) resets your current auto-summon timer.
- __`/pw p`__: Summon previous pet. By ‘previous’ we don‘t mean a pet you just lost (this is covered by the core functionality of the addon), but the one before that. For example, if your auto-summon timer gives you a new pet, but you actually liked the last one, you can quickly get it back with this command.
- __`/pw v[vv]`__: Verbosity level for messages:
    - `/pw v`: _silent_: only important messages (missing favorites, failed summons, etc.) are printed to the chat.
    - `/pw vv`: _medium_: you get a message when a _new_ pet is summoned (either via auto-timer or manually via `/pw n` or keybind).
    - `/pw vvv`: _full_: all messages; you get a message also when a lost pet is restored, which happens quite often.
- __`/pw h`__: Display the Help text in the console. (Also `/pw help` or just `/pw`.) 
- __`/pw s`__: Display the Status & Settings report in the console, with these infos:
    - If the addon is active (auto-summoning/restore enabled or disabled).
    - The summon timer interval and the remaining time (that is, when you will get the next new pet).
    - Verbosity level of messages.
    - Whether the pet pool is set to Favorites or to All Pets, and the number of eligible pets for auto-summoning:
        - In Favorites mode, the number of eligible pets corresponds to the number of selected favorites (either per char or globally via `/pw c`)
        - In All Pet mode, the number of eligible pets reflects the result of your Pet Journal filters (or the total number of summonable pets, if no filters are set).
    - Type of favorites: global or character-specific.
    - A list of character-specific favorite pets (if you have set any).
        - A list of global favorites is not displayed because you can easily get that list by sorting the Pet Journal or Rematch by favorites.

If `/pw` is conflicting with any of your other addons’ commands, then use `/petw` instead.  

Also check the Key Bindings section of your client. You’ll find three bindable commands for PetWalker there:
- Toggle automatic summoning of pets (same as `/pw a`)
- Dismiss current pet and disable auto-summoning (same as `/pw d`)
- Summon new pet (same as `/pw n`)   


---

# FAQ

## How to set char-specific favorite pets?

1. Set PetWalker to ‘char-specific favorites’ (command `/pw c`)
2. Set your favorites as usual in the Pet Journal (or Rematch)

In the Pet Journal, they will be visually flagged with the fav star only when you are in char-specific-favorites mode; in normal-favorites mode you will see your normal (global) favorites star-flagged. (In Rematch, they are never visually flagged. Though you can set/unset them there via right-click just as in the Pet Journal.)

Unlike the global favorites, these char-specific favorites will not be sorted at top of the Pet Journal list. However, the Status message (command `/pw s`) shows you a list of your current char-specific favorites. This makes it easier to identify them, for example if you want to remove a pet from the favorites.

## I do not want to summon a new pet every `n` minutes, I just want to keep my current pet out!

Simply set the Summon New Pet timer to ‘0’ (zero). You can set it to 0 with the command `/pw 0`. With this setting, the addon will never give you a new pet, and will do its best to keep your current pet out, until _you_ decide to summon a different one. _How_ the pet is summoned, is irrelevant: it can be summoned via Pet Journal, or via PetWalker keybind, or whatever. PetWalker will remember it, treat is as your “valid” current pet and will try to re-summon it whenever it is lost.

## Where/when does PetWalker fail to keep my pet out?

The most difficult situation is when you select a team for a pet battle. If you are using Rematch, you should select the “Keep Companion” option (in “Miscellaneous Options”). This will definitely help, but it is not guaranteed that, after the pet battle, you have the same pet out as before.

## What are the events PetWalker is reacting to?

The main event that makes PetWalker check for the pet and summon it if necessary, is `PLAYER_STARTED_MOVING`.  
This is a very frequent event, yes. I have experimented with various other events, but this one turned out to be best. (After all, the goal of PetWalker is to assure that your pet is _always_ out, not that it’s out every once in a while.)  

In rare occasions, PetWalker’s summoning might interfere with other casts, notably with Druids shapeshifting immediately after starting to move. But, since PetWalker does nothing in combat situations (and other critical situations), it should be pretty safe.  

---

# Known Issues / To Do 

- Remove erroneous “summoned” messages in a few situations where actually no pet was summoned (eg flying, probably vehicle UI).
- As mentioned in the FAQ, there is a chance that after a pet battle your previous companion does not get re-summoned. This needs to be improved.
- Check for and remove orphaned pet GUIDs from the char-specific favorites table. (Not sure if this was an issue just in the Dragonflight prepatch phase, or if it still happens.)

Feel free to post suggestions or issues in the [Github Issues](https://github.com/tflo/PetWalker/issues) of the repo!
__Please do not post issues or suggestions in the comments on Curseforge.__

___

This ReadMe was last updated 2022-12-31.
