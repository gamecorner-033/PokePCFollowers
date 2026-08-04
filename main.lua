return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local version = GameVersion.get()

  -- Supported versions check (Red, Blue, Yellow)
  if version ~= "red" and version ~= "blue" and version ~= "yellow" then
    if mod.log then
      mod.log:info("PokéPC Followers: unsupported game version %s", tostring(version))
    end
    if mod.exports then mod.exports.supported = false end
    return
  end

  print("[PokePCFollowers-Merged] Initializing Followers Mod (All 151 + 3D Voxel & R/B/Y Compatible)...")

  -- Core Module Dependencies
  local Game = require("src.core.Game")
  local PaletteFX = require("src.render.PaletteFX")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local Assets = require("src.render.Assets")
  local BattleState = (version == "yellow") and require("src.battle.BattleState") or nil
  local PikachuFollower = pcall(require, "src.world.PikachuFollower") and require("src.world.PikachuFollower") or nil
  local Strings = require("src.core.Strings")
  local PartyMenu = pcall(require, "src.ui.PartyMenu") and require("src.ui.PartyMenu") or nil

  local FALLBACK_SPECIES = "CHARMANDER"
  local SPRITE_ID = "SPRITE_PIKACHU"
  local STATE_KEY = "__pokepcFollowersUniversal"
  local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }
  local function colorMode()
	return PaletteFX and PaletteFX.mode == "redpp"
  end

  -- Helper to scrub active follower/pikachu entities entirely from overworld state
  local function purgeFollowerEntities(ow)
    if not (ow and ow.entities) then return end
    local j = 1
    for i = 1, #ow.entities do
      local ent = ow.entities[i]
      local isFollower = ent and (ent.id == "pikachu" or (ent.sprite and ent.sprite.def and ent.sprite.def.id == SPRITE_ID))
      if not isFollower then
        ow.entities[j] = ent
        j = j + 1
      end
    end
    for i = j, #ow.entities do
      ow.entities[i] = nil
    end
  end

  -- National Dex mapping (1 to 151)
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

  -- Fallback structure if PikachuFollower isn't pre-loaded
  if not PikachuFollower then
    PikachuFollower = {
      current = function() return nil end,
      update = function() end,
      onMapEntered = function() end,
      talk = function(_, _, _, done) if type(done) == "function" then done() end end,
      starterInParty = function(save, needHealthy)
        if not save or not save.party then return nil end
        for _, m in ipairs(save.party) do
          if not needHealthy or (tonumber(m.hp) or 0) > 0 then return m end
        end
        return nil
      end
    }
  end

  -- Dynamic Path Resolution Helpers
  local function getFollowerSpritePath(species)
    local key = tostring(species or FALLBACK_SPECIES):upper()
    local dexNum = speciesToDex[key]
    if dexNum then
      local dexStr = string.format("%03d", dexNum)
      return mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"
    end
    return mod.path .. "/assets/sprites/follower_" .. (species or FALLBACK_SPECIES) .. ".png"
  end

  local followerImgCache = {}
  local function getFollowerImage(species)
    local key = tostring(species or FALLBACK_SPECIES):upper()
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

  -- 1. Register/Patch SPRITE_PIKACHU record
  local followerSpriteDef = {
    id = SPRITE_ID,
    image = getFollowerSpritePath(FALLBACK_SPECIES),
    frames = 6,
    walker = true,
    trueColor = colorMode(),
  }

  if mod.content and mod.content.sprites then
    if mod.content.sprites:get(SPRITE_ID) then
      mod.content.sprites:patch(SPRITE_ID, followerSpriteDef)
    else
      mod.content.sprites:register(SPRITE_ID, followerSpriteDef)
    end
  end

  -- 2. Direct Patching of Icons Database
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

  -- 3. Mod framework UI icon patching (Fixes Party Menu Portraits)
  if mod.content and mod.content.icons then
    for speciesName, dexNum in pairs(speciesToDex) do
      local dexStr = string.format("%03d", dexNum)
      local spritePath = mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"

      pcall(function()
        local iconDef = { image = spritePath, width = 16, height = 16, frames = 1 }
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
          image = mod.path .. "/assets/sprites/follower_CHARMANDER.png",
          width = 16, height = 16, frames = 1
        })
      end)
    end
  end

  -- Selection & Health Helper Functions
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

  -- Hybrid Active Pokemon Selection
  local function getActiveFollowerMon(game, needHealthy)
    if needHealthy == nil then needHealthy = true end
    local g = game or Game
    if not (g and g.save and g.save.party) then return nil end
    local party = g.save.party
    if #party == 0 then return nil end

    if mod.save then
      local selectedKey = mod.save:get("selected_mon")
      local selectedSlot = tonumber(mod.save:get("selected_slot"))

      if selectedKey then
        local atSlot = selectedSlot and party[selectedSlot]
        if atSlot and monKey(atSlot) == selectedKey and (not needHealthy or healthy(atSlot)) then
          return atSlot, selectedSlot
        end
        for i, mon in ipairs(party) do
          if monKey(mon) == selectedKey and (not needHealthy or healthy(mon)) then
            return mon, i
          end
        end
      end
    end

    local idx = g.save.followerPartyIndex
    if idx and type(idx) == "number" and party[idx] and (not needHealthy or healthy(party[idx])) then
      return party[idx], idx
    end

    for i, mon in ipairs(party) do
      if not needHealthy or healthy(mon) then return mon, i end
    end

    if needHealthy then return nil end
    return party[1], 1
  end

  local function configureSpriteDef(game, mon)
    local g = game or Game
    local sprites = g and g.data and g.data.sprites
    local def = sprites and sprites[SPRITE_ID]
    if not def then return nil end
    if not mon then return nil end
    local species = mon.species or FALLBACK_SPECIES
    local path = getFollowerSpritePath(species)
    def.image = path
    def.frames = 6
    def.walker = true
    def.trueColor = colorMode()
    return def, species, path
  end

  local function syncLiveFollowerDef(game, ow)
    local g = game or Game
    if not (g and ow) then return nil end
    local mon = getActiveFollowerMon(g, true)
    if not mon then 
      purgeFollowerEntities(ow)
      return nil 
    end

    local def, species, path = configureSpriteDef(g, mon)
    if not (def and mon) then return nil end

    local npc = PikachuFollower.current and PikachuFollower.current(ow)
    if not npc then return nil end

    local ok, image = pcall(Assets.image, path)
    if not ok or not image then image = getFollowerImage(species) end

    if npc._pokepcFollowerSpecies ~= species or not npc.sprite or npc.sprite.image ~= image then
      npc.sprite = SpriteRenderer.new(def, npc.id)
      npc._pokepcFollowerSpecies = species
      npc._pokepcFollowerMonKey = monKey(mon)
    else
      npc.sprite.def.image = path
      npc.sprite.def.frames = 6
      npc.sprite.def.walker = true
      npc.sprite.def.trueColor = colorMode()
    end
    return npc
  end

  -- 4. Upvalue Patching Engine
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

  -- Hot-reload restoration (F5 support)
  local previous = rawget(PikachuFollower, STATE_KEY)
  if previous and type(previous.restore) == "function" then
    pcall(previous.restore)
  end

  local originalUpdate = PikachuFollower.update
  local originalOnMapEntered = PikachuFollower.onMapEntered
  local originalTalk = PikachuFollower.talk
  local originalStarterInParty = PikachuFollower.starterInParty
  local vanillaShouldSpawn

  local function shouldSpawn(game, ow)
    local g = game or Game
    local save = g and g.save
    if not (save and ow) then return false end

    -- Base checks: valid party, not biking, not surfing
    if not save.party or #save.party == 0 then return false end
    if save.onBike or (ow.player and ow.player.surfing) then return false end
    if getActiveFollowerMon(g, true) == nil then return false end

    -- Sprite registry check
    if not (g.data and g.data.sprites and g.data.sprites[SPRITE_ID]) then
      return false
    end

    return true
  end

  if originalUpdate then
    local _, oldSpawn = replaceUpvalue(originalUpdate, "shouldSpawn", shouldSpawn)
    vanillaShouldSpawn = oldSpawn
  end
  pcall(function() replaceUpvalue(PikachuFollower.onMapEntered, "shouldSpawn", shouldSpawn) end)

  -- 5. Starter/Party Spawning Hooks
  local wrappedStarterInParty = function(save, needHealthy)
    local game = Game
    local active = getActiveFollowerMon(game, needHealthy)
    if active then return active end

    if save and save.party then
      for _, mon in ipairs(save.party) do
        if not needHealthy or healthy(mon) then return mon end
      end
    end
    return nil
  end
  PikachuFollower.starterInParty = wrappedStarterInParty

  -- 6. Dynamic Texture Resolution Hooks
  local origResolveImage = SpriteRenderer.resolveImage
  if origResolveImage then
    SpriteRenderer.resolveImage = function(self, ...)
      if self and self.def and self.def.id == SPRITE_ID then
        local activeMon = getActiveFollowerMon(Game, true) or getActiveFollowerMon(Game, false)
        if activeMon then
          local species = activeMon.species or FALLBACK_SPECIES
          return getFollowerImage(species)
        end
      end
      return origResolveImage(self, ...)
    end
  end

  local origSpriteDraw = SpriteRenderer.draw
  function SpriteRenderer:draw(px, py, camX, camY, facing, walkPhase, stepFlip)
    if self.def and self.def.id == SPRITE_ID then
      -- ONLY draw raw PNG if colorMode() (PaletteFX.mode == "redpp") is active
      if colorMode() then
        local activeMon = getActiveFollowerMon(Game, false)
        if not activeMon then return end
        local species = activeMon.species or FALLBACK_SPECIES
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
    end
    
    -- In OG / SGB / non-advanced modes, fall back to standard game boy drawing
    return origSpriteDraw(self, px, py, camX, camY, facing, walkPhase, stepFlip)
  end

  -- Update / Map / Interaction Hooks
  local wrappedOnMapEntered = function(game, ow, opts)
    local g = game or Game
    local mon = getActiveFollowerMon(g, true)
    if mon then configureSpriteDef(g, mon) end

    local result = originalOnMapEntered and originalOnMapEntered(g, ow, opts) or nil

    if ow and ow.entities and not shouldSpawn(g, ow) then
      purgeFollowerEntities(ow)
    else
      syncLiveFollowerDef(g, ow)
    end
    return result
  end

  local wrappedUpdate = function(game, ow, ...)
    local g = game or Game
    if not shouldSpawn(g, ow) then
      if ow then purgeFollowerEntities(ow) end
      return
    end

    local mon = getActiveFollowerMon(g, true)
    if mon then configureSpriteDef(g, mon) end

    local result = originalUpdate and originalUpdate(g, ow, ...) or nil
    pcall(syncLiveFollowerDef, g, ow)
    return result
  end

  -- Hardened talk wrapper to ensure NPC interaction never fails or locks state
  local wrappedTalk = function(a, b, c, d)
    local game = Game
    local ow = game and game.overworld
    local done = d

    -- Normalize arguments based on engine signatures
    if type(a) == "table" and a.save then game = a end
    if type(b) == "table" and b.entities then ow = b end
    if type(c) == "function" then done = c end
    if type(d) == "function" then done = d end

    local npc = PikachuFollower.current and PikachuFollower.current(ow)
    local mon = getActiveFollowerMon(game, true)

    if not mon then
      if originalTalk then return originalTalk(a, b, c, d) end
      if done then done() end
      return
    end

    -- If the current follower is Pikachu on Yellow, route back to vanilla logic safely
    if version == "yellow" and mon.species == "PIKACHU" and originalTalk then
      return originalTalk(a, b, c, d)
    end

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
        pcall(function() npc:facePlayer(ow.player) end) 
      end
      if ow and ow.player and npc.facing then
        ow.player.facing = OPPOSITE[npc.facing] or ow.player.facing
      end
    end

    pcall(function()
      require("src.core.Sound").playCry(game.data, mon.species)
    end)

    local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
    local name = mon.nickname or (def and def.name) or mon.species
    local text = Strings("%s is following\nyou!", name)
    local TextBox = require("src.render.TextBox")

    if game.stack then
      game.stack:push(TextBox.new(game, text, done))
    elseif done then
      done()
    end
  end

  if originalOnMapEntered then PikachuFollower.onMapEntered = wrappedOnMapEntered end
  if originalUpdate then PikachuFollower.update = wrappedUpdate end
  if originalTalk then PikachuFollower.talk = wrappedTalk end

  -- 7. Party Menu updates & rendering hooks
  if PartyMenu then
    local origPartyMenuDraw = PartyMenu.draw
    PartyMenu.draw = function(self, ...)
      local result = origPartyMenuDraw and origPartyMenuDraw(self, ...)
      local party = (self.game and self.game.save and self.game.save.party) or {}
      if colorMode() then
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
        local follower = PikachuFollower.current and PikachuFollower.current(ow)
        if not follower then return end
        local active = getActiveFollowerMon(game, true)
        if not active then return end
        local species = active.species or FALLBACK_SPECIES
        if follower._pokepcFollowerSpecies ~= species then
          syncLiveFollowerDef(game, ow)
        end
      end)
      return result
    end
  end

  -- 8. Follower Selection Handler
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
      pcall(function()
        require("src.core.Sound").play(game.data, "Swap")
      end)
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
      local name = mon.nickname or (def and def.name) or mon.species
      local text = Strings("%s is now\nyour follower!", name)
      local TextBox = require("src.render.TextBox")
      if game.stack then
        game.stack:push(TextBox.new(game, text))
      end
    end
    return true
  end

  -- Event Listener Hook
  if mod.events then
    mod.events:on("ui.party.submenu", function(e)
      if not e.ctx or e.ctx.battle or not e.items or not e.mon or not e.game then return end
      if not healthy(e.mon) then return end

      local activeMon = getActiveFollowerMon(e.game, true)
      local isCurrent = (activeMon == e.mon)
      local label = Strings(isCurrent and "FOLLOWING" or "FOLLOWER")

      table.insert(e.items, {
        label = label,
        onSelect = function(selectedMon, game)
          selectFollower(selectedMon, game, false)
        end
      })
    end)
  end

  -- Wrap Hook
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

  -- 10. Module Export Surface & Restore State Management
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
    if origResolveImage and SpriteRenderer.resolveImage ~= origResolveImage then
      SpriteRenderer.resolveImage = origResolveImage
    end
    if origSpriteDraw and SpriteRenderer.draw ~= origSpriteDraw then
      SpriteRenderer.draw = origSpriteDraw
    end
    if rawget(PikachuFollower, STATE_KEY) == state then
      rawset(PikachuFollower, STATE_KEY, nil)
    end
  end
  rawset(PikachuFollower, STATE_KEY, state)

  if mod.exports then
    mod.exports.supported = true
    mod.exports.activeMon = function(game) return getActiveFollowerMon(game, true) end
    mod.exports.assetPath = getFollowerSpritePath
    mod.exports.shouldSpawn = shouldSpawn
    mod.exports.sync = syncLiveFollowerDef
    mod.exports.select = selectFollower
    mod.exports.restore = state.restore
  end

  if mod.log then
    mod.log:info("PokéPC Followers loaded for version %s", tostring(version))
  end
  print(string.format("[PokePCFollowers-%s] Mod initialized successfully.", tostring(version):upper()))
end