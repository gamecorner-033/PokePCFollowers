return {
  {
    key = "color_mode",
    label = "Sprite Colors",
    type = "choice",
    default = "color",
    choices = {
      { "Full Color", "color" },
      { "GBC Palette", "gbc" },
    },
    description = "Full Color uses the original PNG colors. GBC Palette uses the game's color system.",
  },
}