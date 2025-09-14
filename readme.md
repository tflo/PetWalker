# PetWalker

Never lose your pet again.

## Summary

The addon helps you to always have a companion pet out (summoned). You can choose between two operating modes:

- __Auto Restore only:__ Whenever your pet is lost – for whatever reason –, it will be restored. This works across logouts and characters.
- __Random Summon:__ Automatically summons a random pet (from a configurable pool) every n minutes, or via keybind or slash command. This pet will be auto-restored whenever it is lost, until a new one is summoned.

___If you’re having trouble reading this description on CurseForge, you might want to try switching to the [REPO PAGE](https://github.com/tflo/PetWalker?tab=readme-ov-file#petwalker). You’ll find the exact same text there, but it’s much easier to read and free from CurseForge’s rendering errors.___

## Notes

In early 2022 this project started out as an improved version of [NugMiniPet](https://www.curseforge.com/wow/addons/nugminipet), but in the meantime not much of the original code is left.
Credits for the concept, the inspiration and for the initial code base though to the [author](https://www.curseforge.com/members/d87_/projects) of NugMiniPet.

PetWalker was first published on [GitHub](https://github.com/tflo/PetWalker) and [Wago](https://addons.wago.io/addons/petwalker) in April 2022; starting with version 1.1.4 (Dec 2022) now also available on [CurseForge](https://www.curseforge.com/wow/addons/petwalker).

## Features

### Main Features

- Resummon (restore) your pet if it has “disappeared”. Most of the time this happens due to faulty game mechanics: using portals or teleports, mounting/dismounting, end of combat, entering or exiting instances, and other seemingly random occasions.
- You can set a repeating timer to auto-summon a new pet from a configurable random pool every n minutes.
- You can manually summon a new pet from a configurable random pool via keybind or slash command.
- Your ‘current pet’ is saved across chars. So, if you log out with a given pet on toon A, then login with your toon B, you should see the same pet summoned, right at (or very shortly after) login. (You can exclude a toon from that by setting it to char-specific favorites.)
- Your remaining auto-summon timer is saved at logout and re-applied when you log in again (on any toon). So, if you have set your timer to two hours, you will see a new pet every two hours of gaming time, no matter how often you log out/in or for how long you have been offline. You can see the current remaining timer in the Status report (command `/pw s`, see Usage).
- The addon does its best not to interfere with various activities/circumstances: M+ keys, Arena, Stealthed, In Combat, and more.
- The pool of favorite pets to summon can be char-specific or account-wide. You can change this on a per-char basis at any time, and your char-specific list will be retained for later if you switch from char-specific to global favourites.
- Easy switching between ‘random-summoning of new pets’ and ‘just keep my pet out’. (`/pw 0` to disable the auto-timer, see Usage)
- The addon knows about special pets and does not try to summon pets that can or should not be summoned, e.g. the Pocopoc pet in Zereth Mortis, the Winter Veil pets, or the vendor pets with CD like Guild Herald.
- PetWalker ignores pets that are automatically summoned because they are slotted into a team. It will reliably restore your previous pet 15 seconds after a pet battle. (See also FAQ.)

### Other Features / Notes

- No GUI settings. Basically it’s a set-and-forget addon.
- No nasty Minimap button, and thus no conflicts with minimap mods.
- 100% standalone, no libraries or other dependencies.
- Resource friendly in terms of CPU and memory usage.
- Alt friendly: All settings are account wide (except for char-specific favorite pets, ofc).
- For obvious reasons conflicting with [NugMiniPet](https://www.curseforge.com/wow/addons/nugminipet), [Zone Pet](https://www.curseforge.com/wow/addons/zonepet), [Mount Mini-Me](https://www.curseforge.com/wow/addons/mount-mini-me) and probably any similar addon that auto-summons pets.
- Fully compatible with [Rematch](https://www.curseforge.com/wow/addons/rematch).

## Usage

PetWalker has a rich chat console interface:

- __`/pw a`:__ Toggle all automatic summoning of pets. Basically the main switch of the addon (all events are unregistered/registered), but manual summoning via keybind or slash command (see below) is still available.
- __`/pw sr`:__ Allow/disallow automatic summoning of pets while _mounted_ (and on the ground) _and in Skyride mode._
    - As of version 1.2.0 (March 2023), automatic pet summoning can also happen while you are mounted. With “normal” mounts, this behavior is trouble-free and only beneficial, but in Skyride mode it can cause occasional GCD glitches. Therefore, you can disable it with this toggle. _It is enabled by default._ More on that topic in the FAQ below!
- __`/pw d`:__ Dismiss current pet and disable auto-summoning. A kind of emergency command, if you want to get rid of your pet immediately and prevent all automatic summoning. Re-enable with `/pw a`.
- __`/pw <number>`:__ Interval [minutes] for summoning a new pet. ‘0’ disables summoning of new pets, though the pet-_restore_ functionality is still active (use `/pw a` to disable it).
- __`/pw f`:__ Toggle the random-summon pool between Favorites and All Pets.
    - With the All Pets setting, the currently active filters of the Pet Journal still apply (Pet Family and Sources). Since these filters can be combined, this offers quite some possibilities to create varied pools for random summoning, without the need to select favorites.
    - Hint: You can also use the search box of the Pet Journal as filter: If your summon pool is set to All Pets and the search box contains “rabbit”, PetWalker will only summon pets with “rabbit” in their name.
    - Note that this works only with the filters or search box in Blizz’s Pet Journal, not in Rematch.
    - If you set the pool to Favorites, make sure that your favorites are not excluded by the Pet Journal filters or search string.
- __`/pw c`:__ Toggle char-specific favorites list. (Applies if Favorites are enabled via `/pw f`.)
- __`/pw n`:__ Summon new pet (from the active pet pool: Favs or All, see commands explained above). Summoning a pet with `/pw n` (or the keybind) resets your current auto-summon timer.
- __`/pw p`:__ Summon previous pet. By ‘previous’ we don‘t mean a pet you just lost (this is covered by the core functionality of the addon), but the one before that. For example, if your auto-summon timer gives you a new pet, but you actually liked the last one, you can quickly get it back with this command.
- __`/pw v[vv]`:__ Verbosity level for messages:
    - `/pw v`: _silent:_ only important messages (missing favorites, failed summons, etc.) are printed to the chat.
    - `/pw vv`: _medium:_ you get a message when a _new_ pet is summoned (either via auto-timer or manually via `/pw n` or keybind).
    - `/pw vvv`: _full:_ all messages; you get a message also when a lost pet is restored, which happens quite often.
- __`/pw h`:__ Display the Help text in the console. (Also `/pw help` or just `/pw`.)
- __`/pw s`:__ Display the Status & Settings report in the console, with these infos:
    - Addon version.
    - If the addon is active (auto-summoning/restore enabled or disabled).
    - The summon timer interval and the remaining time (that is, when you will get the next new pet).
    - Verbosity level of messages.
    - Whether the pet pool is set to Favorites or to All Pets, and the number of eligible pets for auto-summoning:
        - In Favorites mode, the number of eligible pets corresponds to the number of selected favorites (either per char or globally via `/pw c`)
        - In All Pet mode, the number of eligible pets reflects the result of your Pet Journal filters (or the total number of summonable pets, if no filters are set).
  - Type of favorites: global or character-specific.
  - A list of character-specific favorite pets (if you have set any).
        - A list of global favorites is not displayed because you can easily get that list by sorting the Pet Journal or Rematch by favorites.

If `/pw` is conflicting with another addon’s command, then use the long form `/petwalker` instead.

Also check the Key Bindings section of your client. You’ll find three bindable commands for PetWalker there:

- Toggle automatic summoning of pets (same as `/pw a`)
- Dismiss current pet and disable auto-summoning (same as `/pw d`)
- Summon new pet (same as `/pw n`)

### New feature since version 1.1.5: Summon same pet as targeted pet

1. Target a summoned pet of another player.
2. Enter `/pw t` or `/pw target` or set and use the new keybind in the Keybinding section.
3. If the targeted pet is in your collection, it should be summoned.

If the target pet is not in your collection, you get a weblink to the pet’s page on warcraftpets.com, or on wowhead.com if it’s not collectible.

---

## FAQ

### How to set char-specific favorite pets?

1. Set PetWalker to ‘char-specific favorites’ (toggle command: `/pw c`).
2. Set your favorites as usual in the Pet Journal (or Rematch).

In the Pet Journal, char-specific favorites are only visually marked with the fav star when you are in char-specific favorites mode; in normal favorites mode, your normal (global) favourites are marked with a star. (In Rematch, they are never visually marked. However, you can set/unset them there using the context menu (right-click), just like in the Pet Journal).

Unlike the global favorites, these char-specific favorites are not sorted at the top of the Pet Journal list. However, the Status display (`/pw s` command) will show you a list of your current char-specific favorites. This makes them easier to identify, for example if you want to remove a pet from your favorites.

### I do not want to summon a new pet every `n` minutes, I just want to keep my current pet out

Simply set the Summon New Pet timer to ‘0’ (zero). You can set it to 0 with the command `/pw 0`. With this setting, the addon will never give you a new pet, and will do its best to keep your current pet out, until _you_ decide to summon a different one. _How_ the pet is summoned, is irrelevant: it can be summoned via Pet Journal, or via PetWalker keybind, or whatever. PetWalker will remember it, treat is as your “valid” current pet and will try to re-summon it whenever it is lost.

### PetWalker only summons a few pets out of my pool, or I get the “0 (zero) eligible pets” message

The Filter settings in the Pet Journal can actually restrict the pet pool, i.e. you can actively use the filters to “shape” your pet pool without using favorites. This includes any text in the search box(!).

However, it is also possible that the game has messed up the filters (I often see this after a hard disconnect), or you have been searching for a pet and forgot to reset the filters.

First, check PetWalker’s status with `/pw s`. If it reports that your pool is set to All Pets, but also says that there are only (for example) 5 pets “eligible”, while you have 500 pets in your collection, then you can be pretty sure that the Pet Journal filters or the search box are restricting the pool.

If this is not what you want, open Pet Journal (not Rematch!) and remove all filters by clicking the “X” badge on the Filter drop-down menu, and clear the search box of any text.

Note that you must have access to the _Blizz Pet Journal_ to do this, so make sure that Rematch does not overwrite it! (Go to Rematch > Options > Miscellaneous Options and check “Use Default Pet Journal” or uncheck the Rematch checkbox at the bottom of the Pet Journal. With this setting, you can still invoke Rematch with its own hotkey).

See also [issue#6](https://github.com/tflo/PetWalker/issues/6).

### Where/when does PetWalker fail to keep my pet out?

~~The most difficult situation is when you select a team for a pet battle. If you are using Rematch, you should select the “Keep Companion” option (in “Miscellaneous Options”). This will definitely help, but it is not guaranteed that, after the pet battle, you have the same pet out as before.~~

__As of version 2.0.0 (April 2023),__ PetWalker’s behavior in the context of pet battles has dramatically improved. For the gory details, see the change notes of version 2.0.0 from 2023-04-28.

TL;DR: PetWalker now reliably restores your previous pet 15 seconds after a pet battle. The delay is intentional and allows you to chain pet battles, without any annoying automatic summoning/unsummoning of your pet in-between. Pets that were auto-summoned because they are slotted into a team are ignored and the pet restoration now works reliably also without Rematch’s “Keep Companion” setting. But, if you prefer, you can still enable Rematch’s “Keep Companion”. (The difference is that Rematch restores your pet more or less immediately after a battle.)

### What events does PetWalker monitor?

The main event that causes PetWalker to check for the pet and summon it if necessary is `PLAYER_STARTED_MOVING`.
This is a fairly common event. I have experimented with several other events, but overall I have found that this one gives the best results. (After all, the aim of PetWalker is to ensure that your pet is _always_ out, not that it’s out from time to time).

On rare occasions, a summoning action can interfere with other casts (GCD conflict), e.g. Druids who shape-shift immediately after they start moving. But since PetWalker does nothing in combat (and other sensitive situations), it should be pretty safe.

### Should I disable “auto-summoning while mounted for Skyriding” (`/pw sr`)?

Since version 1.2.0 (March 2023), automatic pet summoning can also happen while you are mounted (not flying).

With ground mounts or on ground and in Steady Flight mode, this is clearly a good thing, because: A problem with (auto-)summoning pets can be that it triggers the Global Cooldown (GCD), which can prevent you from casting a spell or using an ability until the GCD is over (1–1.5s). You are usually less likely to want to cast a spell while mounted, so it is good if the pet is summoned before you dismount. This reduces the chance of a GCD conflict later.

With Skyriding, it’s a bit different: The Skyriding abilities require you to be off GCD. While on the ground, this applies to “Lift Off” and “Skyward Ascent”. This means that, unlike with ground mounts or in Steady Flight mode, the GCD triggered by summoning a pet while Skyride-mounted has a realistic chance of interfering with other abilities (the Skyride abilities), especially when landing, moving a few meters, and quickly taking off again.

So I’ve added the possibility to allow/disallow auto-summoning while mounted for Skyriding. The toggle command is `/pw sr`. I recommend experimenting with this to see if it produces more or less GCD conflicts for you. As with most PW settings, this is an account-wide setting.

By default, this setting is _enabled,_ so auto-summoning while mounted for Skyriding will happen.

Personally, I’m using it because even if I have an occasional GCD conflict with a Skyriding ability, it still reduces the chance of a GCD conflict after dismounting. But your experience may vary depending on your personal Skyriding landing/lift-off “style”.

To be clear, the GCD is not caused by PetWalker, it’s a Blizz thing: any pet summoning, no matter how it is done, triggers the GCD. It’s stupid IMO, but there’s nothing we can do about it. The summoning-while-mounted feature is meant to reduce the chance of GCD conflicts, but it cannot be eliminated.

### Pet auras (Daisy, Feathers, Crackers, and Cap’n Crackers) prevent PW from summoning pets

Yes, this is working as intended. If you /whistle for example Crackers (to have him on the shoulder), and then resummon Crackers or summon Feathers or Cap’n Crackers, the Crackers aura would be cancelled. So, if PW detects that one of the auras is active, and your last saved pet is a competing one (which is usually the case, since you had to summon Crackers before /whistle’ing him), it will stop autosummoning/restoring.

If you want to have another pet out while Crackers sits on your shoulder, just summon one from the Pet Journal, or press your Previous Pet shortcut (if the previous pet is not competing with the aura). From that moment on, PW will resume working as normal, e.g the pet will be restored as usual when lost. (If your random summon timer is active, you should make sure that there is no competing pet in the pool.) See also [issue 18](https://github.com/tflo/PetWalker/issues/18).

---

## Known Issues / To Do

- ~~Remove erroneous “summoned” messages in a few situations where actually no pet was summoned.~~
- ~~As mentioned in the FAQ, there is a chance that after a pet battle your previous companion is not re-summoned. This needs to be improved.~~
- ~~Add an optional login message.~~

---

Feel free to share your suggestions or report issues on the [GitHub Issues](https://github.com/tflo/PetWalker/issues) page of the repository.  
__Please avoid posting suggestions or issues in the comments on Curseforge.__

---

__Other addons by me:__

- [___Auto Quest Tracker Mk III___](https://www.curseforge.com/wow/addons/auto-quest-tracker-mk-iii): Continuation of the one and only original. Up to date and tons of new features.
- [___Move 'em All___](https://www.curseforge.com/wow/addons/move-em-all): Mass move items/stacks from your bags to wherever. Works also fine with most bag addons.
- [___Auto Discount Repair___](https://github.com/tflo/AutoDiscountRepair): Automatically repair your gear – where it’s cheap.
- [___Auto-Confirm Equip___](https://www.curseforge.com/wow/addons/auto-confirm-equip): Less (or no) confirmation prompts for BoE gear.
- [___Action Bar Button Growth Direction___](https://www.curseforge.com/wow/addons/action-bar-button-growth-direction): Fix the button growth direction of multi-row action bars to what is was before Dragonflight (top --> bottom).
- [___EditBox Font Improver___](https://www.curseforge.com/wow/addons/editbox-font-improver): Better fonts for your macro/script edit boxes.

__WeakAuras:__

- [___Stats Mini___](https://wago.io/S4023p3Im): A *very* compact but beautiful and feature-loaded stats display: primary/secondary stats, *all* defensive stats (also against target), GCD, speed (rating/base/actual/Skyriding), iLevel (equipped/overall/difference), char level +progress.
