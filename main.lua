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

  -- 1. Register SPRITE_PIKACHU with walker = true and trueColor = true for 3D Voxel compatibility
  mod.content.sprites:patch("SPRITE_PIKACHU", {
    image = mod.path .. "/assets/sprites/follower_CHARMANDER.png",
    frames = 6,
    walker = true,
    trueColor = true,
  })

  -- 2. Dynamic Sprite Cache: Loads and caches follower_<species>.png on demand for all 151 Gen 1 Pokemon
  local followerImgCache = {}
  local function getFollowerImage(species)
    if not species then species = "CHARMANDER" end
    if not followerImgCache[species] then
      local spritePath = mod.path .. "/assets/sprites/follower_" .. tostring(species) .. ".png"
      local ok, img = pcall(Assets.image, spritePath)
      if ok and img then
        followerImgCache[species] = img
      else
        followerImgCache[species] = Assets.image(mod.path .. "/assets/sprites/follower_CHARMANDER.png")
      end
    end
    return followerImgCache[species]
  end

  -- 3. Resolve Active Follower Mon from Save Data (Explicit Selection or Default Party Slot 1)
  local function getActiveFollowerMon(game)
    if not game or not game.save or not game.save.party then return nil end
    local party = game.save.party
    if #party == 0 then return nil end

    -- Check if user explicitly selected a party slot
    local idx = game.save.followerPartyIndex
    if idx and type(idx) == "number" and party[idx] and (party[idx].hp or 0) > 0 then
      return party[idx]
    end

    -- Default to Party Slot 1 if healthy
    if party[1] and (party[1].hp or 0) > 0 then
      return party[1]
    end

    -- Fallback to first healthy mon in party
    for _, mon in ipairs(party) do
      if (mon.hp or 0) > 0 then return mon end
    end

    return party[1]
  end

  -- 4. 3D Voxel compatibility & live texture resolution
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
    local path = mod.path .. "/assets/sprites/follower_" .. tostring(species) .. ".png"
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

  -- 5. Single Post-Zone Redraw: Draws ONE single full-color GBA follower sprite matching active species
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
      local quad = self.frames[frameIdx]
      local flip = (facing == "right") or (stepFlip and (facing == "up" or facing == "down"))

      local drawX = flip and (x + 16) or x
      local flipSx = flip and -1 or 1

      PaletteFX.markSpriteRedraw(followerImg, quad, drawX, y, flipSx, nil, false)
      return
    end

    return origSpriteDraw(self, px, py, camX, camY, facing, walkPhase, stepFlip)
  end

  -- 6. Hook Party Menu Submenu ("FOLLOWER" UI Option)
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

  -- 7. Yellow-only Oak/Pikachu story edits
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

  -- 8. Multi-version follower spawning hook (Red, Blue, Yellow)
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
