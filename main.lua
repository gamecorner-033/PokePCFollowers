return function(mod)
  print("[PokePCFollowers-VoxelMerge] Initializing Followers Mod (All 151 + 3D Voxel Compatible)...")

  local Game = require("src.core.Game")
  local PaletteFX = require("src.render.PaletteFX")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local Assets = require("src.render.Assets")
  local BattleState = require("src.battle.BattleState")
  local PikachuFollower = require("src.world.PikachuFollower")
  local GameVersion = require("src.core.GameVersion")
  local Strings = require("src.core.Strings")
  local PartyMenu = require("src.ui.PartyMenu")

  -- Map species names to National Dex IDs (1 to 151)
  local speciesToDex = {
    BULBASAUR=1, IVYSAUR=2, VENUSAUR=3, CHARMANDER=4, CHARMELEON=5, CHARIZARD=6,
    SQUIRTLE=7, WARTORTLE=8, BLASTOISE=9, CATERPIE=10, METAPOD=11, BUTTERFREE=12,
    WEEDLE=13, KAKUNA=14, BEEDRILL=15, PIDGEY=16, PIDGEOTTO=17, PIDGEOT=18,
    RATTATA=19, RATICATE=20, SPEAROW=21, FEAROW=22, EKANS=23, ARBOK=24,
    PIKACHU=25, RAICHU=26, SANDSHREW=27, SANDSLASH=28, NIDORAN_F=29, NIDORINA=30,
    NIDOQUEEN=31, NIDORAN_M=32, NIDORINO=33, NIDOKING=34, CLEFAIRY=35, CLEFABLE=36,
    VULPIX=37, NINETALES=38, JIGGLYPUFF=39, WIGGLYTUFF=40, ZUBAT=41, GOLBAT=42,
    ODDISH=43, GLOOM=44, VILEPLUME=45, PARAS=46, PARASECT=47, VENONAT=48,
    VENOMOTH=49, DIGLETT=50, DUGTRIO=51, MEOWTH=52, PERSIAN=53, PSYDUCK=54,
    GOLDUCK=55, MANKEY=56, PRIMEAPE=57, GROWLITHE=58, ARCANINE=59, POLIWAG=60,
    POLIWHIRL=61, POLIWRATH=62, ABRA=63, KADABRA=64, ALAKAZAM=65, MACHOP=66,
    MACHOKE=67, MACHAMP=68, BELLSPROUT=69, WEEPINBELL=70, VICTREEBEL=71, TENTACOOL=72,
    TENTACRUEL=73, GEODUDE=74, GRAVELER=75, GOLEM=76, PONYTA=77, RAPIDASH=78,
    SLOWPOKE=79, SLOWBRO=80, MAGNEMITE=81, MAGNETON=82, FARFETCHD=83, DODUO=84,
    DODRIO=85, SEEL=86, DEWGONG=87, GRIMER=88, MUK=89, SHELLDER=90,
    CLOYSTER=91, GASTLY=92, HAUNTER=93, GENGAR=94, ONIX=95, DROWZEE=96,
    HYPNO=97, KRABBY=98, KINGLER=99, VOLTORB=100, ELECTRODE=101, EXEGGCUTE=102,
    EXEGGUTOR=103, CUBONE=104, MAROWAK=105, HITMONLEE=106, HITMONCHAN=107, LICKITUNG=108,
    KOFFING=109, WEEZING=110, RHYHORN=111, RHYDON=112, CHANSEY=113, TANGELA=114,
    KANGASKHAN=115, HORSEA=116, SEADRA=117, GOLDEEN=118, SEAKING=119, STARYU=120,
    STARMIE=121, MR_MIME=122, SCYTHER=123, JYNX=124, ELECTABUZZ=125, MAGMAR=126,
    PINSIR=127, TAUROS=128, MAGIKARP=129, GYARADOS=130, LAPRAS=131, DITTO=132,
    EEVEE=133, VAPOREON=134, JOLTEON=135, FLAREON=136, PORYGON=137, OMANYTE=138,
    OMASTAR=139, KABUTO=140, KABUTOPS=141, AERODACTYL=142, SNORLAX=143, ARTICUNO=144,
    ZAPDOS=145, MOLTRES=146, DRATINI=147, DRAGONAIR=148, DRAGONITE=149, MEWTWO=150, MEW=151
  }

  -- 1. Register SPRITE_PIKACHU with walker = true and trueColor = true for 3D Voxel compatibility
  mod.content.sprites:patch("SPRITE_PIKACHU", {
    image = mod.path .. "/assets/sprites/follower_CHARMANDER.png",
    frames = 6,
    walker = true,
    trueColor = true,
  })

  -- 2. Direct Patch: Overwrite generated icon references in-memory
  local okIcons, baseIcons = pcall(require, "generated.icons")
  if not okIcons or not baseIcons then
    okIcons, baseIcons = pcall(require, "src.generated.icons")
  end

  if baseIcons and baseIcons.byDex and baseIcons.icons then
    for speciesName, dexNum in pairs(speciesToDex) do
      local dexStr = string.format("%03d", dexNum)
      local iconKey = "FOLLOWER_" .. speciesName
      local spritePath = mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"

      baseIcons.byDex[dexNum] = iconKey
      baseIcons.icons[iconKey] = spritePath
    end
  end

  -- 3. Mod framework icon patch (Cropping 16x96 walker sheets for 16x16 UI icons)
  if mod.content and mod.content.icons then
    for speciesName, dexNum in pairs(speciesToDex) do
      local dexStr = string.format("%03d", dexNum)
      local spritePath = mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"

      pcall(function()
        local iconDef = {
          image = spritePath,
          width = 16,
          height = 16,
          frames = 1
        }
        mod.content.icons:patch(speciesName, iconDef)
        mod.content.icons:patch(dexNum, iconDef)
        mod.content.icons:patch(dexStr, iconDef)
      end)
    end

    local fallbackIcons = {
      "ICON_MON", "ICON_BIRD", "ICON_QUADRUPED", "ICON_PIKACHU",
      "ICON_FAIRY", "ICON_WATER", "ICON_BUG", "ICON_SNAKE",
      "ICON_BALL", "ICON_HELIX", "ICON_GRASS"
    }
    for _, iconId in ipairs(fallbackIcons) do
      pcall(function()
        mod.content.icons:patch(iconId, {
          image = mod.path .. "/assets/sprites/follower_004.png",
          width = 16,
          height = 16,
          frames = 1
        })
      end)
    end
  end

  -- 4. Dynamic Sprite Cache: Loads and caches follower_<001-151>.png on demand
  local followerImgCache = {}
  local function getFollowerImage(species)
    local key = tostring(species or "CHARMANDER"):upper()
    local dexNum = speciesToDex[key] or 4
    local dexStr = string.format("%03d", dexNum)

    if not followerImgCache[dexStr] then
      local spritePath = mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"
      local ok, img = pcall(Assets.image, spritePath)
      if ok and img then
        followerImgCache[dexStr] = img
      else
        followerImgCache[dexStr] = Assets.image(mod.path .. "/assets/sprites/follower_CHARMANDER.png")
      end
    end
    return followerImgCache[dexStr]
  end

  local function getFollowerSpritePath(species)
    local key = tostring(species or "CHARMANDER"):upper()
    local dexNum = speciesToDex[key] or 4
    local dexStr = string.format("%03d", dexNum)
    return mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"
  end

  -- 5. Resolve Active Follower Mon from Save Data
  local function getActiveFollowerMon(game)
    if not game or not game.save or not game.save.party then return nil end
    local party = game.save.party
    if #party == 0 then return nil end

    local idx = game.save.followerPartyIndex
    if idx and type(idx) == "number" and party[idx] and (party[idx].hp or 0) > 0 then
      return party[idx]
    end

    if party[1] and (party[1].hp or 0) > 0 then
      return party[1]
    end

    for _, mon in ipairs(party) do
      if (mon.hp or 0) > 0 then return mon end
    end

    return party[1]
  end

  -- 6. 3D Voxel compatibility & live texture resolution
  local origResolveImage = SpriteRenderer.resolveImage
  SpriteRenderer.resolveImage = function(self, ...)
    if self.def and self.def.id == "SPRITE_PIKACHU" then
      local activeMon = getActiveFollowerMon(Game)
      local species = activeMon and activeMon.species or "CHARMANDER"
      return getFollowerImage(species)
    end
    return origResolveImage(self, ...)
  end

  local function syncLiveFollowerDef(game, ow)
    local npc = ow and PikachuFollower.current and PikachuFollower.current(ow)
    if not npc or not npc.sprite or not npc.sprite.def then return end
    local activeMon = getActiveFollowerMon(game)
    local species = activeMon and activeMon.species or "CHARMANDER"
    local path = getFollowerSpritePath(species)
    local ok, image = pcall(Assets.image, path)
    if not ok or not image then return end

    if npc._pokepcFollowerSpecies ~= species
       or npc.sprite.image ~= image
       or npc.sprite.def.image ~= path then
      npc.sprite.def.image = path
      npc.sprite.def.frames = 6
      npc.sprite.def.walker = true
      npc.sprite.def.trueColor = true
      npc.sprite = SpriteRenderer.new(npc.sprite.def, npc.id)
      npc._pokepcFollowerSpecies = species
    else
      npc.sprite.def.image = path
      npc.sprite.def.frames = 6
      npc.sprite.def.walker = true
      npc.sprite.def.trueColor = true
    end
  end

  local origFollowerUpdate = PikachuFollower.update
  PikachuFollower.update = function(game, ow, ...)
    local result = origFollowerUpdate(game, ow, ...)
    pcall(syncLiveFollowerDef, game, ow)
    return result
  end

  -- 7. Single Post-Zone Redraw: Draws ONE single full-color GBA follower sprite matching active species
  local origSpriteDraw = SpriteRenderer.draw
  function SpriteRenderer:draw(px, py, camX, camY, facing, walkPhase, stepFlip)
    if self.def and self.def.id == "SPRITE_PIKACHU" then
      local activeMon = getActiveFollowerMon(Game)
      local species = activeMon and activeMon.species or "CHARMANDER"
      local followerImg = getFollowerImage(species)

      local x = math.floor(px - camX)
      local y = math.floor(py - camY) - 4

      local STAND = SpriteRenderer.STAND
      local WALK = SpriteRenderer.WALK
      local dirMap = (walkPhase == 1) and WALK or STAND
      local frameIdx = dirMap[facing] or 0
      local quad = self.frames and (self.frames[frameIdx] or self.frames[1]) or {0, 0, 16, 16}
      local flip = (facing == "right") or (stepFlip and (facing == "up" or facing == "down"))

      local drawX = flip and (x + 16) or x
      local flipSx = flip and -1 or 1

      PaletteFX.markSpriteRedraw(followerImg, quad, drawX, y, flipSx, nil, false)
      return
    end

    return origSpriteDraw(self, px, py, camX, camY, facing, walkPhase, stepFlip)
  end

  -- 8. Party Menu UI Drawing Override
  if PartyMenu then
    local origPartyMenuDraw = PartyMenu.draw
    PartyMenu.draw = function(self, ...)
      if origPartyMenuDraw then
        origPartyMenuDraw(self, ...)
      end

      local party = (self.game and self.game.save and self.game.save.party) or {}
      for i, pmon in ipairs(party) do
        if pmon and pmon.species then
          local img = getFollowerImage(pmon.species)
          if img then
            local iconX = 16 
            local iconY = 16 + ((i - 1) * 16)

            pcall(function()
              if PaletteFX and PaletteFX.markSpriteRedraw then
                local iconQuad = {0, 0, 16, 16}
                PaletteFX.markSpriteRedraw(img, iconQuad, iconX, iconY, 1, nil, false)
              end
            end)
          end
        end
      end
    end
  end

  -- 9. Hook Party Menu Submenu ("FOLLOWER" UI Option)
  mod.events:on("ui.party.submenu", function(e)
    if not e.ctx or e.ctx.battle or not e.items or not e.mon or not e.game then return end

    local mon = e.mon
    local party = e.game.save.party or {}
    local partyIndex = 1
    for i, pmon in ipairs(party) do
      if pmon == mon then partyIndex = i; break end
    end

    local activeMon = getActiveFollowerMon(e.game)
    local isCurrent = (activeMon == mon)
    local label = isCurrent and "FOLLOWING" or "FOLLOWER"

    table.insert(e.items, {
      label = Strings(label),
      onSelect = function(selectedMon, game)
        game.save.followerPartyIndex = partyIndex
        game.save.followerSpecies = selectedMon.species

        pcall(function() syncLiveFollowerDef(game, game.overworld) end)

        local Sound = require("src.core.Sound")
        Sound.play(game.data, "Swap")

        local def = game.data.pokemon[selectedMon.species]
        local name = selectedMon.nickname or (def and def.name) or selectedMon.species

        local TextBox = require("src.render.TextBox")
        game.stack:push(TextBox.new(game, Strings("%s is now\nyour follower!", name)))
      end
    })
  end)

  -- PartyMenu update hook for party order swaps
  local origPartyMenuUpdate = PartyMenu.update
  PartyMenu.update = function(self, dt)
    local result = origPartyMenuUpdate(self, dt)
    pcall(function()
      local game = self.game
      local ow = game and game.overworld
      if not game or not ow then return end
      local follower = PikachuFollower.current and PikachuFollower.current(ow)
      if not follower then return end
      local active = getActiveFollowerMon(game)
      local species = active and active.species or "CHARMANDER"
      if follower._pokepcFollowerSpecies ~= species then
        syncLiveFollowerDef(game, ow)
      end
    end)
    return result
  end

  -- 10. Yellow-only Oak/Pikachu story edits
  if GameVersion.isYellow() then
    mod.content.strings:override("PIKACHU", "CHARMANDER")
    mod.content.text:override("_OaksLabPikachuDislikesPokeballsText1", "OAK: What?")
    mod.content.text:override("_OaksLabPikachuDislikesPokeballsText2", "OAK: It's strange!\nCHARMANDER hates being\nin a POKéBALL!\fYou should keep it\nwith you!\fIt should be happy\nif it walks with\nyou!")
    mod.content.text:override("_OaksLabOak1YouShouldTalkToIt", "OAK: Look at it!\nCHARMANDER seems to\nlike you!")

    local origNewWild = BattleState.newWild
    BattleState.newWild = function(game, species, level, ...)
      if species == "PIKACHU" and level == 5 then
        species = "CHARMANDER"
      end
      return origNewWild(game, species, level, ...)
    end
  end

  -- 11. Multi-version follower spawning hook (Red, Blue, Yellow)
  PikachuFollower.starterInParty = function(save, needHealthy)
    for _, mon in ipairs(save.party or {}) do
      if not needHealthy or (mon.hp or 0) > 0 then
        return mon
      end
    end
    return nil
  end

  local newShouldSpawn = function(game, ow)
    local version = GameVersion.get()
    if version ~= "red" and version ~= "blue" and version ~= "yellow" then
      return false
    end

    local save = game.save
    if save.onBike or (ow.player and ow.player.surfing) then return false end
    if not (game.data.sprites and game.data.sprites.SPRITE_PIKACHU) then
      return false
    end

    for _, mon in ipairs(save.party or {}) do
      if (mon.hp or 0) > 0 then return true end
    end
    return false
  end

  local function patchUpvalue(fn, upvalueName, newVal)
    local i = 1
    while true do
      local name = debug.getupvalue(fn, i)
      if not name then break end
      if name == upvalueName then
        debug.setupvalue(fn, i, newVal)
        break
      end
      i = i + 1
    end
  end

  patchUpvalue(PikachuFollower.update, "shouldSpawn", newShouldSpawn)
  patchUpvalue(PikachuFollower.onMapEntered, "shouldSpawn", newShouldSpawn)

  print("[PokePCFollowers-VoxelMerge] Mod initialized successfully.")
end