--[[
@description Global Rec Mute Solo - Enable at REAPER startup
@author doomfred, OpenAI
@version 1.1.6
@link https://github.com/Doomfred/GlobalRecMuteSoloBox
@noindex
]]

local NAME = "Global Rec Mute Solo"
local START_MARK = "-- BEGIN GlobalRecMuteSoloBox startup"
local END_MARK   = "-- END GlobalRecMuteSoloBox startup"

local function startup_path()
    return reaper.GetResourcePath() .. "/Scripts/__startup.lua"
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return "" end
    local data = f:read("*a") or ""
    f:close()
    return data
end

local function write_file(path, data)
    local f, err = io.open(path, "wb")
    if not f then return false, err end
    f:write(data)
    f:close()
    return true
end

local function remove_existing_block(text)
    local a = text:find(START_MARK, 1, true)
    if not a then return text end

    local b = text:find(END_MARK, a, true)
    if not b then
        return text:sub(1, a - 1)
    end

    b = b + #END_MARK
    local suffix = text:sub(b + 1)
    suffix = suffix:gsub("^\r?\n", "", 1)

    return text:sub(1, a - 1) .. suffix
end

local block = [[
-- BEGIN GlobalRecMuteSoloBox startup
do
  local started = reaper.time_precise()

  local function launch_GlobalRecMuteSoloBox()
    if reaper.time_precise() - started < 1.0 then
      reaper.defer(launch_GlobalRecMuteSoloBox)
      return
    end

    local script =
      reaper.GetResourcePath() ..
      "/Scripts/GlobalRecMuteSoloBox/Scripts/Global_Rec_Mute_Solo.lua"

    local ok, err = pcall(dofile, script)
    if not ok then
      reaper.ShowConsoleMsg(
        "GlobalRecMuteSoloBox startup error:\n" ..
        tostring(err) .. "\n"
      )
    end
  end

  launch_GlobalRecMuteSoloBox()
end
-- END GlobalRecMuteSoloBox startup
]]

local path = startup_path()
local existing = remove_existing_block(read_file(path))

if existing ~= "" and not existing:match("\n$") then
    existing = existing .. "\n"
end

local ok, err = write_file(path, existing .. block)

if not ok then
    reaper.MB(
        "Unable to modify:\n" .. path .. "\n\n" .. tostring(err),
        NAME,
        0
    )
    return
end

reaper.MB(
    "Automatic startup enabled.\n\n" ..
    "Global Rec Mute Solo will use REAPER's resource path dynamically and " ..
    "will launch the next time REAPER starts.",
    NAME,
    0
)
