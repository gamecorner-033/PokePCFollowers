-- PokePC Followers – Unified Mod for Pokémon Red, Blue, Yellow (Gen1Recomp)
-- Merges:
--   • Full follower mechanics (draw/resolve overrides) from main0.0.1
--   • Red/Blue support, persistent selection, talk wrapper from main0.0.2
--   • Dex‑numbered assets, icon patches, purge logic from main0.0.3
-- All improvements are integrated without breaking the core follower behaviour.

return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local version = GameVersion.get()

  -- Only Red, Blue, and Yellow are supported
  if version ~= "red" and version ~= "blue" and version ~= "yellow" then
    if mod.log then mod.log:info("PokéPC Followers: unsupported version %s", tostring(version)) end
    if mod.exports then mod.exports.supported = false end
    return
  end

  print(string.format("[PokePCFollowers] Initializing for %s", version:upper()))

  -- Core modules
  local Game = require("src.core.Game")
  local PaletteFX = require("src.render.PaletteFX")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local Assets = require("src.render.Assets")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Strings = require("src.core.Strings")
  local Sound = require("src.core.Sound")
  local TextBox = require("src.render.TextBox")
  local PartyMenu = require("src.ui.PartyMenu")

  -- Constants
  local FALLBACK_SPECIES = "CHARMANDER"
  local SPRITE_ID = "SPRITE_PIKACHU"
  local STATE_KEY = "__pokepcFollowersUniversal"
  local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

  -- ----------------------------------------------------------------------
  -- 1. Asset path helpers (dex‑numbered files, e.g. follower_004.png)
  -- ----------------------------------------------------------------------
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

  local function assetPath(species)
    local key = tostring(species or FALLBACK_SPECIES):upper()
    local dex = speciesToDex[key]
    local filename = dex and string.format("follower_%03d.png", dex)
                  or "follower_CHARMANDER.png"
    return mod.path .. "/assets/sprites/" .. filename
  end

  -- Image cache (keyed by dex number string)
  local followerImgCache = {}
  local function getFollowerImage(species)
    local key = tostring(species or FALLBACK_SPECIES):upper()
    local dex = speciesToDex[key] or 4
    local dexStr = string.format("%03d", dex)
    if not followerImgCache[dexStr] then
      local path = assetPath(key)
      local ok, img = pcall(Assets.image, path)
      followerImgCache[dexStr] = ok and img or Assets.image(assetPath(FALLBACK_SPECIES))
    end
    return followerImgCache[dexStr]
  end

  -- ----------------------------------------------------------------------
  -- 2. Helper functions: health, mon fingerprint, selection
  -- ----------------------------------------------------------------------
  local function healthy(mon)
    return type(mon) == "table" and (tonumber(mon.hp) or 0) > 0
  end

  local function monKey(mon)
    if type(mon) ~= "table" then return nil end
    local dvs = type(mon.dvs) == "table" and mon.dvs or {}
    return table.concat({
      tostring(mon.otId or -1),
      tostring(dvs.attack or -1),
      tostring(dvs.defense or -1),
      tostring(dvs.speed or -1),
      tostring(dvs.special or -1),
      tostring(mon.catchRate or -1),
    }, ":")
  end

  -- Returns the currently selected follower mon and its party slot
  local function getActiveFollowerMon(game, needHealthy)
    if not (game and game.save and game.save.party) then return nil end
    local party = game.save.party
    if #party == 0 then return nil end

    -- 1) Persistent selection (from mod.save)
    if mod.save then
      local selKey = mod.save:get("selected_mon")
      local selSlot = tonumber(mod.save:get("selected_slot"))
      if selKey then
        local atSlot = selSlot and party[selSlot]
        if atSlot and monKey(atSlot) == selKey and (not needHealthy or healthy(atSlot)) then
          return atSlot, selSlot
        end
        for i, mon in ipairs(party) do
          if monKey(mon) == selKey and (not needHealthy or healthy(mon)) then
            return mon, i
          end
        end
      end
    end

    -- 2) Legacy followerPartyIndex (from original mod)
    local idx = game.save.followerPartyIndex
    if idx and type(idx) == "number" and party[idx] and (not needHealthy or healthy(party[idx])) then
      return party[idx], idx
    end

    -- 3) First healthy mon, or first overall if needHealthy is false
    for i, mon in ipairs(party) do
      if not needHealthy or healthy(mon) then return mon, i end
    end
    if needHealthy then return nil end
    return party[1], 1
  end

  -- ----------------------------------------------------------------------
  -- 3. Purge any follower entities from the overworld
  -- ----------------------------------------------------------------------
  local function purgeFollowerEntities(ow)
    if not (ow and ow.entities) then return end
    local j = 1
    for i = 1, #ow.entities do
      local ent = ow.entities[i]
      local isFollower = ent and (ent.id == "pikachu" or
                                  (ent.sprite and ent.sprite.def and ent.sprite.def.id == SPRITE_ID))
      if not isFollower then
        ow.entities[j] = ent
        j = j + 1
      end
    end
    for i = j, #ow.entities do ow.entities[i] = nil end
  end

  -- ----------------------------------------------------------------------
  -- 4. Register / patch the SPRITE_PIKACHU sprite definition
  -- ----------------------------------------------------------------------
  local function colorMode()
    return not (mod.options and mod.options:get("color_mode") == "gbc")
  end

  local followerSpriteDef = {
    id = SPRITE_ID,
    image = assetPath(FALLBACK_SPECIES),
    frames = 6,
    walker = true,
    trueColor = colorMode(),
  }

  if mod.content.sprites:get(SPRITE_ID) then
    mod.content.sprites:patch(SPRITE_ID, followerSpriteDef)
  else
    mod.content.sprites:register(SPRITE_ID, followerSpriteDef)
  end

  -- ----------------------------------------------------------------------
  -- 5. Icon patching (for party menu and UI)
  -- ----------------------------------------------------------------------
  -- Patch mod.content.icons for each species
  if mod.content and mod.content.icons then
    for species, dex in pairs(speciesToDex) do
      local dexStr = string.format("%03d", dex)
      local path = mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"
      local iconDef = { image = path, width = 16, height = 16, frames = 1 }
      pcall(function()
        mod.content.icons:patch(species, iconDef)
        mod.content.icons:patch(dex, iconDef)
        mod.content.icons:patch(dexStr, iconDef)
      end)
    end
    -- Also patch generic icon IDs used by the engine
    local fallbacks = {
      "ICON_MON", "ICON_BIRD", "ICON_QUADRUPED", "ICON_PIKACHU",
      "ICON_FAIRY", "ICON_WATER", "ICON_BUG", "ICON_SNAKE",
      "ICON_BALL", "ICON_HELIX", "ICON_GRASS"
    }
    for _, id in ipairs(fallbacks) do
      pcall(function()
        mod.content.icons:patch(id, {
          image = mod.path .. "/assets/sprites/follower_CHARMANDER.png",
          width = 16, height = 16, frames = 1
        })
      end)
    end
  end

  -- Also patch the generated.icons table (used by some UI elements)
  local ok, baseIcons = pcall(require, "generated.icons")
  if not ok then
    ok, baseIcons = pcall(require, "src.generated.icons")
  end
  if baseIcons and baseIcons.byDex and baseIcons.icons then
    for species, dex in pairs(speciesToDex) do
      local dexStr = string.format("%03d", dex)
      local iconKey = "FOLLOWER_" .. species
      local path = mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"
      baseIcons.byDex[dex] = iconKey
      baseIcons.icons[iconKey] = path
    end
  end

  -- ----------------------------------------------------------------------
  -- 6. Core follower sprite configuration and live sync
  -- ----------------------------------------------------------------------
  local function configureSpriteDef(game, mon)
    local sprites = game and game.data and game.data.sprites
    local def = sprites and sprites[SPRITE_ID]
    if not def or not mon then return nil end
    local species = mon.species or FALLBACK_SPECIES
    def.image = assetPath(species)
    def.frames = 6
    def.walker = true
    def.trueColor = colorMode()
    return def, species
  end

  local function syncLiveFollowerDef(game, ow)
    if not (game and ow) then return nil end
    local mon = getActiveFollowerMon(game, true)
    if not mon then
      purgeFollowerEntities(ow)
      return nil
    end

    local def, species = configureSpriteDef(game, mon)
    if not def then return nil end

    local npc = PikachuFollower.current(ow)
    if not npc then return nil end

    local newImage = getFollowerImage(species)
    if npc._pokepcFollowerSpecies ~= species or not npc.sprite or npc.sprite.image ~= newImage then
      npc.sprite = SpriteRenderer.new(def, npc.id)
      npc._pokepcFollowerSpecies = species
    else
      -- Update the definition in case trueColor or path changed
      npc.sprite.def.image = assetPath(species)
      npc.sprite.def.frames = 6
      npc.sprite.def.walker = true
      npc.sprite.def.trueColor = colorMode()
    end
    return npc
  end

  -- ----------------------------------------------------------------------
  -- 7. Upvalue patching (shouldSpawn, starterInParty)
  -- ----------------------------------------------------------------------
  local function replaceUpvalue(fn, wanted, replacement)
    if type(fn) ~= "function" or not (debug and debug.getupvalue and debug.setupvalue) then
      return false
    end
    local i = 1
    while true do
      local name, old = debug.getupvalue(fn, i)
      if not name then return false end
      if name == wanted then
        debug.setupvalue(fn, i, replacement)
        return true, old
      end
      i = i + 1
    end
  end

  -- Hot‑reload cleanup
  local previous = rawget(PikachuFollower, STATE_KEY)
  if previous and type(previous.restore) == "function" then
    pcall(previous.restore)
  end

  local originalUpdate = PikachuFollower.update
  local originalOnMapEntered = PikachuFollower.onMapEntered
  local originalTalk = PikachuFollower.talk
  local originalStarterInParty = PikachuFollower.starterInParty
  local vanillaShouldSpawn

  -- New shouldSpawn: works for all versions and checks our selection
  local function shouldSpawn(game, ow)
    local save = game and game.save
    if not (save and ow) then return false end
    if not save.party or #save.party == 0 then return false end
    if save.onBike or (ow.player and ow.player.surfing) then return false end
    if not (game.data and game.data.sprites and game.data.sprites[SPRITE_ID]) then
      return false
    end
    return getActiveFollowerMon(game, true) ~= nil
  end

  -- Patch the upvalue in the original update function (also affects onMapEntered)
  if originalUpdate then
    local _, oldSpawn = replaceUpvalue(originalUpdate, "shouldSpawn", shouldSpawn)
    vanillaShouldSpawn = oldSpawn
  end
  -- Also patch onMapEntered directly in case it has its own closure
  pcall(function() replaceUpvalue(PikachuFollower.onMapEntered, "shouldSpawn", shouldSpawn) end)

  -- starterInParty – return any healthy mon, not just Pikachu
  local function wrappedStarterInParty(save, needHealthy)
    local game = Game
    local active = getActiveFollowerMon(game, needHealthy)
    if active then return active end
    -- fallback: first healthy in party
    for _, mon in ipairs(save and save.party or {}) do
      if not needHealthy or healthy(mon) then return mon end
    end
    return nil
  end
  PikachuFollower.starterInParty = wrappedStarterInParty

  -- ----------------------------------------------------------------------
  -- 8. SpriteRenderer overrides (for dynamic texture and 3D voxel)
  -- ----------------------------------------------------------------------
  local origResolveImage = SpriteRenderer.resolveImage
  SpriteRenderer.resolveImage = function(self, ...)
    if self and self.def and self.def.id == SPRITE_ID then
      local activeMon = getActiveFollowerMon(Game, false)
      if activeMon then
        return getFollowerImage(activeMon.species)
      end
    end
    return origResolveImage(self, ...)
  end

  local origSpriteDraw = SpriteRenderer.draw
  SpriteRenderer.draw = function(self, px, py, camX, camY, facing, walkPhase, stepFlip)
    if self and self.def and self.def.id == SPRITE_ID then
      local activeMon = getActiveFollowerMon(Game, false)
      if not activeMon then return end
      local followerImg = getFollowerImage(activeMon.species)

      local x = math.floor(px - camX)
      local y = math.floor(py - camY) - 4

      local STAND = SpriteRenderer.STAND or {}
      local WALK = SpriteRenderer.WALK or {}
      local dirMap = (walkPhase == 1) and WALK or STAND
      local frameIdx = dirMap[facing] or 0
      local quad = self.frames and self.frames[frameIdx] or self.frames[1] or {0,0,16,16}
      local flip = (facing == "right") or (stepFlip and (facing == "up" or facing == "down"))

      local drawX = flip and (x + 16) or x
      local flipSx = flip and -1 or 1

      PaletteFX.markSpriteRedraw(followerImg, quad, drawX, y, flipSx, nil, false)
      return
    end
    return origSpriteDraw(self, px, py, camX, camY, facing, walkPhase, stepFlip)
  end

  -- ----------------------------------------------------------------------
  -- 9. PikachuFollower function wrappers
  -- ----------------------------------------------------------------------
  local function wrappedOnMapEntered(game, ow, opts)
    local mon = getActiveFollowerMon(game, true)
    if mon then configureSpriteDef(game, mon) end
    local result = originalOnMapEntered and originalOnMapEntered(game, ow, opts)
    if ow and ow.entities and not shouldSpawn(game, ow) then
      purgeFollowerEntities(ow)
    else
      syncLiveFollowerDef(game, ow)
    end
    return result
  end

  local function wrappedUpdate(game, ow, ...)
    if ow and not shouldSpawn(game, ow) then
      purgeFollowerEntities(ow)
      return
    end
    local mon = getActiveFollowerMon(game, true)
    if mon then configureSpriteDef(game, mon) end
    local result = originalUpdate and originalUpdate(game, ow, ...)
    pcall(syncLiveFollowerDef, game, ow)
    return result
  end

  -- Talk wrapper for Red/Blue (and fallback for Yellow if needed)
  local function wrappedTalk(a, b, c, d)
    -- Normalise arguments
    local game = type(a) == "table" and a.save and a or Game
    local ow = type(b) == "table" and b.entities and b or game.overworld
    local done = type(c) == "function" and c or d

    local npc = PikachuFollower.current(ow)
    local mon = getActiveFollowerMon(game, true)

    if not mon then
      if originalTalk then return originalTalk(a, b, c, d) end
      if done then done() end
      return
    end

    -- For Yellow's Pikachu, keep vanilla behaviour
    if version == "yellow" and mon.species == "PIKACHU" and originalTalk then
      return originalTalk(a, b, c, d)
    end

    -- Finish any movement and face player
    if npc then
      if npc.moving then
        npc.cellX = npc.targetX or npc.cellX
        npc.cellY = npc.targetY or npc.cellY
        npc.targetX, npc.targetY = nil, nil
        npc.px, npc.py = npc.cellX * 16, npc.cellY * 16
        npc.moving, npc.marching = false, false
        npc.progress, npc.hopStep = 0, nil
      end
      npc.idle, npc.goalX, npc.goalY = nil, nil, nil
      if npc.facePlayer and ow and ow.player then
        pcall(npc.facePlayer, npc, ow.player)
      end
      if ow and ow.player and npc.facing then
        ow.player.facing = OPPOSITE[npc.facing] or ow.player.facing
      end
    end

    -- Play cry and show message
    pcall(Sound.playCry, game.data, mon.species)
    local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
    local name = mon.nickname or (def and def.name) or mon.species
    local text = Strings("%s is following\nyou!", name)
    game.stack:push(TextBox.new(game, text, done))
  end

  -- Apply wrappers
  if originalOnMapEntered then PikachuFollower.onMapEntered = wrappedOnMapEntered end
  if originalUpdate then PikachuFollower.update = wrappedUpdate end
  if originalTalk then PikachuFollower.talk = wrappedTalk end

  -- ----------------------------------------------------------------------
  -- 10. PartyMenu enhancements (true‑color and sync)
  -- ----------------------------------------------------------------------
  local origPartyMenuDraw = PartyMenu.draw
  PartyMenu.draw = function(self, ...)
    local result = origPartyMenuDraw and origPartyMenuDraw(self, ...)
    if colorMode() then
      local party = (self.game and self.game.save and self.game.save.party) or {}
      for i = 1, #party do
        pcall(function()
          PaletteFX.markTrueColor(0, (i - 1) * 16, 32, 16)
        end)
      end
    end
    return result
  end

  local origPartyMenuUpdate = PartyMenu.update
  PartyMenu.update = function(self, dt)
    local result = origPartyMenuUpdate and origPartyMenuUpdate(self, dt)
    pcall(function()
      local game = self.game
      local ow = game and game.overworld
      if not game or not ow then return end
      local follower = PikachuFollower.current(ow)
      if not follower then return end
      local active = getActiveFollowerMon(game, false)
      if not active then return end
      if follower._pokepcFollowerSpecies ~= active.species then
        syncLiveFollowerDef(game, ow)
      end
    end)
    return result
  end

  -- ----------------------------------------------------------------------
  -- 11. Party submenu hook (FOLLOWER / FOLLOWING)
  -- ----------------------------------------------------------------------
  local function selectFollower(mon, game, quiet)
    if not (mon and game and healthy(mon)) then return false end
    local party = game.save and game.save.party or {}
    local slot
    for i, candidate in ipairs(party) do
      if candidate == mon then slot = i break end
    end
    if not slot then return false end

    if mod.save then
      mod.save:set("selected_mon", monKey(mon))
      mod.save:set("selected_slot", slot)
    end
    game.save.followerPartyIndex = slot
    game.save.followerSpecies = mon.species

    syncLiveFollowerDef(game, game.overworld)

    if not quiet then
      pcall(Sound.play, game.data, "Swap")
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
      local name = mon.nickname or (def and def.name) or mon.species
      local text = Strings("%s is now\nyour follower!", name)
      game.stack:push(TextBox.new(game, text))
    end
    return true
  end

  -- Use mod.hooks:wrap to add the menu item (preferred method)
  if mod.hooks then
    mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
      local out = next(game, items, mon, ctx)
      if type(out) ~= "table" or (ctx and ctx.battle) or not healthy(mon) then
        return out
      end
      local active = getActiveFollowerMon(game, true)
      local label = Strings(active == mon and "FOLLOWING" or "FOLLOWER")
      out[#out + 1] = {
        label = label,
        onSelect = function(selected, selectedGame)
          selectFollower(selected, selectedGame, false)
        end,
      }
      return out
    end)
  end

  -- Fallback event listener (for older mod API)
  if mod.events then
    mod.events:on("ui.party.submenu", function(e)
      if not e.ctx or e.ctx.battle or not e.items or not e.mon or not e.game then return end
      if not healthy(e.mon) then return end
      local active = getActiveFollowerMon(e.game, true)
      local isCurrent = (active == e.mon)
      local label = Strings(isCurrent and "FOLLOWING" or "FOLLOWER")
      table.insert(e.items, {
        label = label,
        onSelect = function(selectedMon, game)
          selectFollower(selectedMon, game, false)
        end
      })
    end)
  end

  -- ----------------------------------------------------------------------
  -- 12. Yellow‑specific story overrides (optional)
  -- ----------------------------------------------------------------------
  if version == "yellow" then
    mod.content.strings:override("PIKACHU", "CHARMANDER")
    mod.content.text:override("_OaksLabPikachuDislikesPokeballsText1", "OAK: What?")
    mod.content.text:override("_OaksLabPikachuDislikesPokeballsText2",
      "OAK: It's strange!\nCHARMANDER hates being\nin a POKéBALL!\fYou should keep it\nwith you!\fIt should be happy\nif it walks with\nyou!")
    mod.content.text:override("_OaksLabOak1YouShouldTalkToIt",
      "OAK: Look at it!\nCHARMANDER seems to\nlike you!")

    -- Patch the wild encounter in Oak's lab to give Charmander instead of Pikachu
    local BattleState = require("src.battle.BattleState")
    local origNewWild = BattleState.newWild
    BattleState.newWild = function(game, species, level, ...)
      if species == "PIKACHU" and level == 5 then species = "CHARMANDER" end
      return origNewWild(game, species, level, ...)
    end
  end

  -- ----------------------------------------------------------------------
  -- 13. Hot‑reload restore state
  -- ----------------------------------------------------------------------
  local state = {
    originalUpdate = originalUpdate,
    originalOnMapEntered = originalOnMapEntered,
    originalTalk = originalTalk,
    originalStarterInParty = originalStarterInParty,
    wrapperUpdate = wrappedUpdate,
    wrapperOnMapEntered = wrappedOnMapEntered,
    wrapperTalk = wrappedTalk,
    wrapperStarterInParty = wrappedStarterInParty,
    originalShouldSpawn = vanillaShouldSpawn,
  }

  state.restore = function()
    if originalUpdate and vanillaShouldSpawn then
      replaceUpvalue(originalUpdate, "shouldSpawn", vanillaShouldSpawn)
    end
    if PikachuFollower.update == wrappedUpdate then
      PikachuFollower.update = originalUpdate
    end
    if PikachuFollower.onMapEntered == wrappedOnMapEntered then
      PikachuFollower.onMapEntered = originalOnMapEntered
    end
    if PikachuFollower.talk == wrappedTalk then
      PikachuFollower.talk = originalTalk
    end
    if PikachuFollower.starterInParty == wrappedStarterInParty then
      PikachuFollower.starterInParty = originalStarterInParty
    end
    if SpriteRenderer.resolveImage == SpriteRenderer.resolveImage and origResolveImage then
      SpriteRenderer.resolveImage = origResolveImage
    end
    if SpriteRenderer.draw == SpriteRenderer.draw and origSpriteDraw then
      SpriteRenderer.draw = origSpriteDraw
    end
    if rawget(PikachuFollower, STATE_KEY) == state then
      rawset(PikachuFollower, STATE_KEY, nil)
    end
  end
  rawset(PikachuFollower, STATE_KEY, state)

  -- ----------------------------------------------------------------------
  -- 14. Mod exports
  -- ----------------------------------------------------------------------
  if mod.exports then
    mod.exports.supported = true
    mod.exports.activeMon = function(game) return getActiveFollowerMon(game, true) end
    mod.exports.assetPath = assetPath
    mod.exports.shouldSpawn = shouldSpawn
    mod.exports.sync = syncLiveFollowerDef
    mod.exports.select = selectFollower
    mod.exports.restore = state.restore
  end

  if mod.log then
    mod.log:info("PokéPC Followers loaded for %s", version)
  end
  print(string.format("[PokePCFollowers] Mod initialized successfully for %s.", version:upper()))
end