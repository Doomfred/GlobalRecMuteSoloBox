--[[
@description Global Rec Mute Solo - Enable at REAPER startup
@author doomfred, OpenAI
@version 1.1.1
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
    if not b then return text:sub(1, a - 1) end

    b = b + #END_MARK
    local suffix = text:sub(b + 1)
    suffix = suffix:gsub("^\r?\n", "", 1)
    return text:sub(1, a - 1) .. suffix
end

local function dirname(path)
    return path:match("^(.*[\\/])") or ""
end

local function lua_quote(path)
    -- %q safely escapes Windows backslashes and any special characters.
    return string.format("%q", path)
end

-- IMPORTANT: derive the real installation directory from THIS action.
local _, this_script = reaper.get_action_context()
local install_dir = dirname(this_script)
local main_script = install_dir .. "Global_Rec_Mute_Solo.lua"

-- Validate before modifying __startup.lua.
local test = io.open(main_script, "rb")
if not test then
    reaper.MB(
        "Impossible de trouver le script principal :\n\n" ..
        main_script ..
        "\n\nRéinstalle ou synchronise le package ReaPack puis réessaie.",
        NAME, 0
    )
    return
end
test:close()

local block =
    START_MARK .. "\n" ..
    "do\n" ..
    "  local started = reaper.time_precise()\n" ..
    "  local script = " .. lua_quote(main_script) .. "\n\n" ..
    "  local function launch_GlobalRecMuteSoloBox()\n" ..
    "    if reaper.time_precise() - started < 1.0 then\n" ..
    "      reaper.defer(launch_GlobalRecMuteSoloBox)\n" ..
    "      return\n" ..
    "    end\n\n" ..
    "    local ok, err = pcall(dofile, script)\n" ..
    "    if not ok then\n" ..
    "      reaper.ShowConsoleMsg(\"GlobalRecMuteSoloBox startup error:\\n\" .. tostring(err) .. \"\\n\")\n" ..
    "    end\n" ..
    "  end\n\n" ..
    "  launch_GlobalRecMuteSoloBox()\n" ..
    "end\n" ..
    END_MARK .. "\n"

local path = startup_path()
local existing = remove_existing_block(read_file(path))

if existing ~= "" and not existing:match("\n$") then
    existing = existing .. "\n"
end

local ok, err = write_file(path, existing .. block)
if not ok then
    reaper.MB(
        "Impossible de modifier :\n" .. path .. "\n\n" .. tostring(err),
        NAME, 0
    )
    return
end

reaper.MB(
    "Démarrage automatique activé.\n\n" ..
    "Chemin détecté :\n" .. main_script .. "\n\n" ..
    "Global Rec Mute Solo sera lancé au prochain démarrage de REAPER.",
    NAME, 0
)
