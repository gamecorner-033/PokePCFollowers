# PokéPC Followers Mod — VoxelFixed Red/Blue/Yellow

An all-species overworld follower mod for **Pokémon Yellow (Gen 1 Recomp)**. This mod allows every single Gen 1 Pokémon to walk behind you in full overworld color as your companion!

---

## 🌟 Features

* **All 151 Gen 1 Pokémon Supported**: Every single Gen 1 Pokémon (from Bulbasaur `#001` to Mew `#151`) has full overworld sprite animations!
* **Automatic Party Slot 1 Follower**: By default, your overworld follower automatically mirrors whichever Pokémon is in **Party Slot 1**. Swapping your party order or receiving a new lead Pokémon dynamically updates your overworld companion.
* **Party Menu UI Selection**:
  1. Press `START` -> select `POKéMON`.
  2. Choose any Pokémon in your party.
  3. Select the new **`FOLLOWER`** option.
  4. Your chosen Pokémon will instantly become your active follower!
* **Full-Color Overworld Graphics**: Sprites render with rich true-color graphics directly over 100% colorized overworld terrain tiles (grass, paths, dirt, water) with zero background artifacts.
* **Smooth Movement Mechanics**:
  * Smooth 1-tile trailing behind the player.
  * In-place turning (no teleporting or jumping tiles when turning around).
  * Seamless map transition spawning across route seams and indoor/outdoor warps.

---

## 📋 Installation

1. Place the `pokepcfollowers` folder inside your `mods/` directory:
   ```
   pokemon-gen1-recomp/
   └── mods/
       └── pokepcfollowers/
           ├── manifest.json
           ├── mod.card
           ├── main.lua
           ├── README.md
           └── assets/
               └── sprites/
   ```
2. Launch `gen1recomp` — the mod will load automatically!

---

## 👥 Credits & Acknowledgments

* **Overworld Sprites**: Huge credit and special thanks to ShockSlayer and the makers of the legendary ROM hack **Pokémon Crystal Clear** for creating and providing the incredible Gen 1 & Gen 2 Pokémon overworld sprite sheets!
* **Development**: Built with **vibe coding** and pair programming for the `pokemon-gen1-recomp` project.

## Voxel compatibility

This build includes a compatibility fix for **Dramatic Shape Voxel Mod 1.3.0**.
The follower sprite is now resolved dynamically through `SpriteRenderer:resolveImage()`
as well as the normal 2D draw hook. This prevents voxel mode from sampling the
registered Charmander fallback sheet for every follower.

The follower sprite is also marked `trueColor` for render-pipeline use so the
voxel renderer does not run the fixed `SPRITE_PIKACHU` image through its palette
bake.

## Experimental Red/Blue + Voxel Fix

This build extends the follower entity to Pokémon Red and Pokémon Blue.
The stock `PikachuFollower` logic is Yellow-only, so the mod replaces its
spawn condition with a version-neutral healthy-party check.

It also keeps the Dramatic Shape compatibility fix: voxel/tilt rendering
resolves the active follower's `follower_<species>.png` instead of the
registered Charmander fallback.

Yellow-only Oak story/encounter overrides remain restricted to Yellow and
are not applied to Red or Blue.


## Animation fix

Version 1.1.1 explicitly marks the follower sprite definition as a walking sprite (`walker=true`). Gen1Recomp uses this flag to provide the `walkPhase` state used by the 6-frame overworld sheets, so the follower now switches between standing and walking frames correctly.
