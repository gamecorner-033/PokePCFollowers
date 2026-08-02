# PokéPC Followers Mod — Red/Blue/Yellow

An all-species overworld follower mod for **Pokémon Red, Blue, and Yellow
(Gen1Recomp)**. Every Gen 1 Pokémon can walk behind you in full overworld color.

---

## 🌟 Features

* **All 151 Gen 1 Pokémon Supported**: Every single Gen 1 Pokémon (from Bulbasaur `#001` to Mew `#151`) has full overworld sprite animations!
* **Automatic Healthy-Lead Follower**: By default, the first healthy Pokémon in your party follows you.
* **Persistent Selection**: An explicitly selected Pokémon remains your follower after party reordering and evolution. If it faints or is deposited, the first healthy teammate temporarily takes over; the selection returns when that Pokémon is available again.
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
* **Field-State Rules**: Biking, surfing, or having no healthy party member hides the follower until it can return.
* **Red/Blue Interaction**: Talking to the follower uses the active Pokémon's name and cry.

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
* Thanks to these Discord members for the contribution to the recomp, this mod and voxel:
Sleepy
TheKingOfSpain
bryanthaboi


## Voxel compatibility

This build includes a compatibility fix for **Dramatic Shape Voxel Mod 1.3.0**.
The live follower owns a `SpriteRenderer` built from the active species sheet,
so `SpriteRenderer:resolveImage()` and the normal 2D draw path resolve the same
image. This prevents voxel mode from sampling the registered Charmander fallback
sheet for every follower.

The follower sprite is also marked `trueColor` for render-pipeline use so the
voxel renderer does not run the fixed `SPRITE_PIKACHU` image through its palette
bake.

## Red/Blue support

Version 1.3.0 makes Red and Blue support stable. Those games do not contain
Yellow's `SPRITE_PIKACHU` content record, so the mod registers it for Red/Blue
and patches the existing record in Yellow.

The private `shouldSpawn` closure is patched on the original follower update
function before the mod installs its wrappers. The party action uses the public
`ui.party.submenu` hook. These two details prevent the follower from being
removed every frame and make the `FOLLOWER` action appear reliably.

Yellow-only Oak story/encounter overrides remain restricted to Yellow and
are not applied to Red or Blue.


## Animation fix

Version 1.1.1 explicitly marks the follower sprite definition as a walking sprite (`walker=true`). Gen1Recomp uses this flag to provide the `walkPhase` state used by the 6-frame overworld sheets, so the follower now switches between standing and walking frames correctly.
