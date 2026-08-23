--[[
@description Global Rec Mute Solo - Disable at REAPER startup
@author doomfred, OpenAI
@version 1.1.3
@link https://github.com/Doomfred/GlobalRecMuteSoloBox
@noindex
]]

local NAME = "Global Rec Mute Solo"
local START_MARK = "-- BEGIN GlobalRecMuteSoloBox startup"
local END_MARK   = "-- END GlobalRecMuteSoloBox startup"

local path = reaper.GetResourcePath() .. "/Scripts/__startup.lua"

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
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

local function remove_block(text)
    local a = text:find(START_MARK, 1, true)
    if not a then return text, false end

    local b = text:find(END_MARK, a, true)
    if not b then
        return text:sub(1, a - 1), true
    end

    b = b + #END_MARK
    local suffix = text:sub(b + 1)
    suffix = suffix:gsub("^\r?\n", "", 1)

    return text:sub(1, a - 1) .. suffix, true
end

local existing = read_file(path)

if existing == nil then
    reaper.MB(
        "No __startup.lua file was found.\n\nAutomatic startup is already disabled.",
        NAME,
        0
    )
    return
end

local cleaned, changed = remove_block(existing)

if not changed then
    reaper.MB(
        "Global Rec Mute Solo was not configured to start automatically.",
        NAME,
        0
    )
    return
end

local ok, err = write_file(path, cleaned)

if not ok then
    reaper.MB(
        "Unable to modify:\n" .. path .. "\n\n" .. tostring(err),
        NAME,
        0
    )
    return
end

reaper.MB(
    "Automatic startup disabled.\n\n" ..
    "Any other commands in __startup.lua have been preserved.",
    NAME,
    0
)
