-- @noindex
-- Reaper_Toggle_R_M / Core.lua
-- Module central contenant la logique commune aux actions Arm, Mute et Solo.

local M = {}

M.section = "REAPER_TOGGLE_R_M"

-- ============================================================
-- Utilitaires généraux
-- ============================================================

local function count_tracks()
    return reaper.CountTracks(0)
end

local function get_track(index)
    return reaper.GetTrack(0, index)
end

-- ============================================================
-- ARM
-- ============================================================

function M.is_any_track_armed()
    for i = 0, count_tracks() - 1 do
        local tr = get_track(i)
        if tr and reaper.GetMediaTrackInfo_Value(tr, "I_RECARM") == 1 then
            return true
        end
    end
    return false
end

function M.toggle_arm()
    local num_tracks = count_tracks()
    if num_tracks == 0 then return end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    if M.is_any_track_armed() then
        local indices = {}

        for i = 0, num_tracks - 1 do
            local tr = get_track(i)
            if tr and reaper.GetMediaTrackInfo_Value(tr, "I_RECARM") == 1 then
                indices[#indices + 1] = tostring(i)
                reaper.SetMediaTrackInfo_Value(tr, "I_RECARM", 0)
            end
        end

        reaper.SetExtState(
            M.section,
            "SAVED_ARMED_TRACKS",
            table.concat(indices, ","),
            false
        )
    else
        local saved = reaper.GetExtState(M.section, "SAVED_ARMED_TRACKS")

        if saved ~= "" then
            for idx_str in string.gmatch(saved, "([^,]+)") do
                local idx = tonumber(idx_str)

                if idx and idx < num_tracks then
                    local tr = get_track(idx)
                    if tr then
                        reaper.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
                    end
                end
            end
        end
    end

    reaper.Undo_EndBlock("Toggle Unarm/Rearm All Tracks", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

-- ============================================================
-- MUTE
-- ============================================================

function M.is_any_track_muted()
    for i = 0, count_tracks() - 1 do
        local tr = get_track(i)
        if tr and reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") == 1 then
            return true
        end
    end
    return false
end

function M.toggle_mute()
    local num_tracks = count_tracks()
    if num_tracks == 0 then return end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    if M.is_any_track_muted() then
        local indices = {}

        for i = 0, num_tracks - 1 do
            local tr = get_track(i)
            if tr and reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") == 1 then
                indices[#indices + 1] = tostring(i)
                reaper.SetMediaTrackInfo_Value(tr, "B_MUTE", 0)
            end
        end

        reaper.SetExtState(
            M.section,
            "SAVED_MUTED_TRACKS",
            table.concat(indices, ","),
            false
        )
    else
        local saved = reaper.GetExtState(M.section, "SAVED_MUTED_TRACKS")

        if saved ~= "" then
            for idx_str in string.gmatch(saved, "([^,]+)") do
                local idx = tonumber(idx_str)

                if idx and idx < num_tracks then
                    local tr = get_track(idx)
                    if tr then
                        reaper.SetMediaTrackInfo_Value(tr, "B_MUTE", 1)
                    end
                end
            end
        end
    end

    reaper.Undo_EndBlock("Toggle Unmute/Remute All Tracks", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

-- ============================================================
-- SOLO
-- ============================================================

function M.is_any_track_soloed()
    for i = 0, count_tracks() - 1 do
        local tr = get_track(i)
        if tr and reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") > 0 then
            return true
        end
    end
    return false
end

function M.toggle_solo()
    local num_tracks = count_tracks()
    if num_tracks == 0 then return end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    if M.is_any_track_soloed() then
        local indices = {}

        for i = 0, num_tracks - 1 do
            local tr = get_track(i)
            if tr then
                local solo_state =
                    reaper.GetMediaTrackInfo_Value(tr, "I_SOLO")

                if solo_state > 0 then
                    -- On conserve l'index et le type de solo (1 ou 2).
                    indices[#indices + 1] =
                        tostring(i) .. ":" .. tostring(solo_state)

                    reaper.SetMediaTrackInfo_Value(tr, "I_SOLO", 0)
                end
            end
        end

        reaper.SetExtState(
            M.section,
            "SAVED_SOLOED_TRACKS",
            table.concat(indices, ","),
            false
        )
    else
        local saved =
            reaper.GetExtState(M.section, "SAVED_SOLOED_TRACKS")

        if saved ~= "" then
            for pair_str in string.gmatch(saved, "([^,]+)") do
                local idx_str, state_str =
                    string.match(pair_str, "(%d+):(%d+)")

                local idx = tonumber(idx_str)
                local state = tonumber(state_str) or 1

                if idx and idx < num_tracks then
                    local tr = get_track(idx)
                    if tr then
                        reaper.SetMediaTrackInfo_Value(
                            tr,
                            "I_SOLO",
                            state
                        )
                    end
                end
            end
        end
    end

    reaper.Undo_EndBlock("Toggle Unsolo/Resolo All Tracks", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

return M
