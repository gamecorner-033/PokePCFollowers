-- PokéPC Followers for Pokémon Red, Blue, and Yellow (Gen1Recomp).
--
-- Red and Blue do not contain Yellow's SPRITE_PIKACHU record or companion
-- spawn flag.  Register the missing record in those games, patch it in
-- Yellow, and reuse Gen1Recomp's trailing movement in all three versions.

return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local version = GameVersion.get()
  if version ~= "red" and version ~= "blue" and version ~= "yellow" then
    mod.log:info("PokéPC Followers: unsupported game version %s",
      tostring(version))
    mod.exports.supported = false
    return
  end

  local FALLBACK_SPECIES = "CHARMANDER"
  local SPRITE_ID = "SPRITE_PIKACHU"
  local STATE_KEY = "__pokepcFollowersUniversal"
  local OPPOSITE = {
    up = "down", down = "up", left = "right", right = "left",
  }

  local PikachuFollower = require("src.world.PikachuFollower")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local Strings = require("src.core.Strings")

  local function assetPath(species)
    species = type(species) == "string" and species or FALLBACK_SPECIES
    return mod.path .. "/assets/sprites/follower_" .. species .. ".png"
  end

  -- Yellow already owns this record; Red and Blue do not.  trueColor
  -- preserves the supplied colors in 2D and makes resolveImage() return the
  -- same live sheet to voxel/tilt renderers.
  local followerSprite = {
    id = SPRITE_ID,
    image = assetPath(FALLBACK_SPECIES),
    frames = 6,
    walker = true,
    trueColor = true,
  }
  if mod.content.sprites:get(SPRITE_ID) then
    mod.content.sprites:patch(SPRITE_ID, followerSprite)
  else
    mod.content.sprites:register(SPRITE_ID, followerSprite)
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

  local function healthy(mon)
    return type(mon) == "table" and (tonumber(mon.hp) or 0) > 0
  end

  -- A DV/OT fingerprint follows the chosen individual across party
  -- reordering and evolution.  selected_slot disambiguates the extremely
  -- unlikely case of two party members with the same fingerprint.
  local function selectedMon(game, needHealthy)
    local party = game and game.save and game.save.party or {}
    local selectedKey = mod.save:get("selected_mon")
    local selectedSlot = tonumber(mod.save:get("selected_slot"))

    if selectedKey then
      local atSlot = selectedSlot and party[selectedSlot]
      if atSlot and monKey(atSlot) == selectedKey
          and (not needHealthy or healthy(atSlot)) then
        return atSlot, selectedSlot
      end
      for i, mon in ipairs(party) do
        if monKey(mon) == selectedKey and (not needHealthy or healthy(mon)) then
          return mon, i
        end
      end
    end

    -- Migrate the original release's save-table slot selection lazily.  A
    -- later explicit choice is stored in mod.save using the stable key above.
    if not selectedKey then
      local legacySlot = tonumber(game and game.save
        and game.save.followerPartyIndex)
      local legacy = legacySlot and party[legacySlot]
      if legacy and (not needHealthy or healthy(legacy)) then
        return legacy, legacySlot
      end
    end

    for i, mon in ipairs(party) do
      if not needHealthy or healthy(mon) then return mon, i end
    end
    return nil
  end

  local function configureSpriteDef(game, mon)
    local sprites = game and game.data and game.data.sprites
    local def = sprites and sprites[SPRITE_ID]
    if not def then return nil end
    local species = mon and mon.species or FALLBACK_SPECIES
    def.image = assetPath(species)
    def.frames = 6
    def.walker = true
    def.trueColor = true
    return def, species
  end

  local function syncFollower(game, ow)
    if not (game and ow) then return nil end
    local mon = selectedMon(game, true)
    local def, species = configureSpriteDef(game, mon)
    if not (def and mon) then return nil end

    local npc = PikachuFollower.current(ow)
    if not npc then return nil end
    if npc._pokepcFollowerSpecies ~= species
        or not npc.sprite then
      npc.sprite = SpriteRenderer.new(def, npc.id)
      npc._pokepcFollowerSpecies = species
    end
    return npc
  end

  -- Return the upvalue's old value as well as success.  update() and
  -- onMapEntered() share Yellow's local shouldSpawn closure, so patching the
  -- original update function (not our wrapper) changes both call sites.
  local function replaceUpvalue(fn, wanted, replacement)
    if type(fn) ~= "function" or not (debug and debug.getupvalue
        and debug.setupvalue) then
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

  -- Clean up our own wrappers before a developer-mode hot reload.  Direct
  -- engine patches are outside the registry journal, so making this
  -- idempotent prevents stacked update/talk callbacks after F5.
  local previous = rawget(PikachuFollower, STATE_KEY)
  if previous and type(previous.restore) == "function" then
    pcall(previous.restore)
  end

  local originalUpdate = PikachuFollower.update
  local originalOnMapEntered = PikachuFollower.onMapEntered
  local originalTalk = PikachuFollower.talk
  local originalStarterInParty = PikachuFollower.starterInParty
  local BattleState = version == "yellow"
    and require("src.battle.BattleState") or nil
  local originalNewWild = BattleState and BattleState.newWild or nil
  local wrappedNewWild
  local vanillaShouldSpawn

  local function shouldSpawn(game, ow)
    local activeVersion = GameVersion.get()
    if activeVersion ~= "red" and activeVersion ~= "blue"
        and activeVersion ~= "yellow" then
      return vanillaShouldSpawn and vanillaShouldSpawn(game, ow) or false
    end
    local save = game and game.save
    if not (save and ow) then return false end
    if save.onBike or (ow.player and ow.player.surfing) then return false end
    if not (game.data and game.data.sprites
        and game.data.sprites[SPRITE_ID]) then
      return false
    end
    return selectedMon(game, true) ~= nil
  end

  local patched, oldShouldSpawn =
    replaceUpvalue(originalUpdate, "shouldSpawn", shouldSpawn)
  if not patched then
    mod.log:error(
      "could not patch follower spawning; this Gen1Recomp build is unsupported")
    return
  end
  vanillaShouldSpawn = oldShouldSpawn

  -- Yellow's happiness and emotion code asks this helper for the companion.
  -- Keep the upstream all-species behavior instead of narrowing it back to
  -- Pikachu, while spawn/render selection remains fingerprint-based.
  local wrappedStarterInParty = function(save, needHealthy)
    for _, mon in ipairs(save.party or {}) do
      if not needHealthy or healthy(mon) then return mon end
    end
    return nil
  end
  PikachuFollower.starterInParty = wrappedStarterInParty

  -- Preserve the original Yellow story conversion.  Red and Blue never
  -- receive these text or encounter changes.
  if version == "yellow" then
    mod.content.strings:override("PIKACHU", "CHARMANDER")
    mod.content.text:override("_OaksLabPikachuDislikesPokeballsText1",
      "OAK: What?")
    mod.content.text:override("_OaksLabPikachuDislikesPokeballsText2",
      "OAK: It's strange!\nCHARMANDER hates being\nin a POKéBALL!\f"
        .. "You should keep it\nwith you!\fIt should be happy\n"
        .. "if it walks with\nyou!")
    mod.content.text:override("_OaksLabOak1YouShouldTalkToIt",
      "OAK: Look at it!\nCHARMANDER seems to\nlike you!")

    wrappedNewWild = function(game, species, level, ...)
      if species == "PIKACHU" and level == 5 then species = "CHARMANDER" end
      return originalNewWild(game, species, level, ...)
    end
    BattleState.newWild = wrappedNewWild
  end

  local wrappedOnMapEntered
  wrappedOnMapEntered = function(game, ow, opts)
    configureSpriteDef(game, selectedMon(game, true))
    local result = originalOnMapEntered(game, ow, opts)
    syncFollower(game, ow)
    return result
  end

  local wrappedUpdate
  wrappedUpdate = function(game, ow)
    configureSpriteDef(game, selectedMon(game, true))
    local result = originalUpdate(game, ow)
    syncFollower(game, ow)
    return result
  end

  local wrappedTalk
  wrappedTalk = function(game, ow, npc, done)
    if GameVersion.get() ~= "red" and GameVersion.get() ~= "blue" then
      return originalTalk(game, ow, npc, done)
    end

    local mon = selectedMon(game, true)
    if not mon then
      if done then done() end
      return
    end

    -- Land a just-finishing follow step before opening the message, matching
    -- Yellow's own talk path and avoiding a frozen half-tile sprite.
    if npc.moving then
      npc.cellX = npc.targetX or npc.cellX
      npc.cellY = npc.targetY or npc.cellY
      npc.targetX, npc.targetY = nil, nil
      npc.px, npc.py = npc.cellX * 16, npc.cellY * 16
      npc.moving, npc.marching = false, false
      npc.progress, npc.hopStep = 0, nil
    end
    npc.idle, npc.goalX, npc.goalY = nil, nil, nil
    if npc.facePlayer and ow.player then npc:facePlayer(ow.player) end
    if ow.player then
      ow.player.facing = OPPOSITE[npc.facing] or ow.player.facing
    end

    pcall(function()
      require("src.core.Sound").playCry(game.data, mon.species)
    end)
    local def = game.data.pokemon and game.data.pokemon[mon.species]
    local name = mon.nickname or (def and def.name) or mon.species
    local text = Strings("%s is following\nyou!", name)
    local TextBox = require("src.render.TextBox")
    game.stack:push(TextBox.new(game, text, done))
  end

  PikachuFollower.onMapEntered = wrappedOnMapEntered
  PikachuFollower.update = wrappedUpdate
  PikachuFollower.talk = wrappedTalk

  local state = {
    originalUpdate = originalUpdate,
    originalOnMapEntered = originalOnMapEntered,
    originalTalk = originalTalk,
    originalStarterInParty = originalStarterInParty,
    originalNewWild = originalNewWild,
    wrapperNewWild = wrappedNewWild,
    wrapperUpdate = wrappedUpdate,
    wrapperOnMapEntered = wrappedOnMapEntered,
    wrapperTalk = wrappedTalk,
    wrapperStarterInParty = wrappedStarterInParty,
    originalShouldSpawn = vanillaShouldSpawn,
  }
  state.restore = function()
    replaceUpvalue(originalUpdate, "shouldSpawn", vanillaShouldSpawn)
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
    if BattleState and BattleState.newWild == wrappedNewWild then
      BattleState.newWild = originalNewWild
    end
    if rawget(PikachuFollower, STATE_KEY) == state then
      rawset(PikachuFollower, STATE_KEY, nil)
    end
  end
  rawset(PikachuFollower, STATE_KEY, state)

  local function selectFollower(mon, game, quiet)
    if not (mon and game and healthy(mon)) then return false end
    local party = game.save and game.save.party or {}
    local slot
    for i, candidate in ipairs(party) do
      if candidate == mon then slot = i break end
    end
    if not slot then return false end

    mod.save:set("selected_mon", monKey(mon))
    mod.save:set("selected_slot", slot)
    syncFollower(game, game.overworld)

    if not quiet then
      pcall(function()
        require("src.core.Sound").play(game.data, "Swap")
      end)
      local def = game.data.pokemon and game.data.pokemon[mon.species]
      local name = mon.nickname or (def and def.name) or mon.species
      local text = Strings("%s is now your\nfollower!", name)
      local TextBox = require("src.render.TextBox")
      game.stack:push(TextBox.new(game, text))
    end
    return true
  end

  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" or (ctx and ctx.battle) or not healthy(mon) then
      return out
    end
    local active = selectedMon(game, true)
    local label = Strings(active == mon and "FOLLOWING" or "FOLLOWER")
    out[#out + 1] = {
      label = label,
      onSelect = function(selected, selectedGame)
        selectFollower(selected, selectedGame, false)
      end,
    }
    return out
  end)

  -- Small, stable test/debug surface.  It also makes the selection behavior
  -- inspectable from Gen1Recomp's developer console without reaching into
  -- locals or save.modData directly.
  mod.exports.supported = true
  mod.exports.activeMon = function(game) return selectedMon(game, true) end
  mod.exports.assetPath = assetPath
  mod.exports.shouldSpawn = shouldSpawn
  mod.exports.sync = syncFollower
  mod.exports.select = selectFollower
  mod.exports.restore = state.restore

  local labels = { red = "Red", blue = "Blue", yellow = "Yellow" }
  mod.log:info("PokéPC Followers loaded for Pokémon %s", labels[version])
end
