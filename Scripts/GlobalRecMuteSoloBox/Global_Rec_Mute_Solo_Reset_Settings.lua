--[[
@description Global Rec Mute Solo - Reset Settings
@author doomfred, OpenAI
@link https://github.com/Doomfred/GlobalRecMuteSoloBox
@version 1.1.4
@noindex
@about
  Clears the saved host window, position and button size for Global Rec Mute Solo.
]]
local EXT = "GLOBAL_REC_MUTE_SOLO_V5"

for _, key in ipairs({
  "attach_title",
  "attach_child_id",
  "box_x",
  "box_y",
  "button_scale"
}) do
  reaper.DeleteExtState(EXT, key, true)
end

reaper.MB(
  "Global Rec Mute Solo settings have been reset.\n\n" ..
  "The next launch will use the Main Toolbar and the default 100% size.",
  "Global Rec Mute Solo",
  0
)
