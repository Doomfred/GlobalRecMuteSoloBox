--[[
@description Global Rec Mute Solo
@author doomfred, OpenAI
@link https://github.com/Doomfred/GlobalRecMuteSoloBox
@version 1.1.1
@changelog
  Fix startup path detection for ReaPack installations.
@provides
  [main] .
  [nomain] Core.lua
  [main] Global_Rec_Mute_Solo_Reset_Settings.lua
  [main] Global_Rec_Mute_Solo_Enable_Startup.lua
  [main] Global_Rec_Mute_Solo_Disable_Startup.lua
@requires
  js_ReaScriptAPI
@about
  Global Rec Mute Solo provides three global track-state buttons:
  Rec, Mute and Solo.

  Features:
  - compact flat UI composited directly into REAPER;
  - starts in the Main Toolbar when no target is saved;
  - short left click toggles the corresponding global state;
  - long left click enables drag-and-drop to another REAPER UI area;
  - Ctrl + left click opens the configuration menu;
  - button sizes: 75%, 100%, 125%, 150%, 175%, 200%;
  - selected size and host position are remembered;
  - 100% button size = 28 x 28 px;
  - requires js_ReaScriptAPI.

  Core.lua must remain in the same folder as this script.
]]

local NAME = "Global Rec Mute Solo"
local EXT = "GLOBAL_REC_MUTE_SOLO_V5"

if not reaper.JS_Composite or not reaper.JS_Window_FromPoint
    or not reaper.JS_WindowMessage_Intercept
    or not reaper.JS_LICE_CreateBitmap then
    reaper.MB(NAME .. " nécessite js_ReaScriptAPI.", NAME, 0)
    return
end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = script_path .. "?.lua;" .. package.path
local Core = require("Core")

local main_hwnd = reaper.GetMainHwnd()
local transport_title = reaper.JS_Localize("Transport", "common")

-- Flat toolbar-like geometry. V5.1 enlarges the original 24 px buttons by 25%.
-- Buttons are now 30 x 30 px and keep a flat square design.
local BASE_BTN = 28 -- fixed reference: 100% = 28x28 px
local GAP = 1

local SCALE_OPTIONS = {75, 100, 125, 150, 175, 200}
local scale_percent = tonumber(reaper.GetExtState(EXT, "button_scale")) or 100

local BTN = BASE_BTN
local BOX_H = BTN
local BOX_W = BTN * 3 + GAP * 2
local FONT_SIZE = 13

local function apply_scale(percent)
    local valid_scale = false
    for _, v in ipairs(SCALE_OPTIONS) do
        if v == percent then
            valid_scale = true
            break
        end
    end
    if not valid_scale then percent = 100 end

    scale_percent = percent

    -- Fixed pixel sizes. Main Toolbar detection is used ONLY to locate
    -- the host window, never to determine button dimensions.
    local button_sizes = {
        [75]  = 21,
        [100] = 28,
        [125] = 35,
        [150] = 42,
        [175] = 49,
        [200] = 56,
    }

    BTN = button_sizes[percent] or BASE_BTN
    BOX_H = BTN
    BOX_W = BTN * 3 + GAP * 2

    -- Font scales from the fixed 100% reference (Segoe UI Black 13 at 28 px).
    FONT_SIZE = math.max(8, math.floor(13 * percent / 100 + 0.5))
end

apply_scale(scale_percent)

local COLORS = {
    off = 0x555555,
    on = 0xE8E8E8,
    text_off = 0x000000,
    text_on = 0x000000,
    text_hover_active = 0x777777,
    rec = 0xD02020,
    mute = 0xD0A800,
    solo = 0x20A840,
    handle = 0x353535,
}

local host_hwnd
local bitmap, font, gdi_font, gdi_font_mute
local box_x, box_y = 0, 0
local host_w, host_h = 0, 0
local hover = 0
local pressed = 0
local dragging = false
local drag_dx, drag_dy = 0, 0
local drag_prev_host
local redraw = true
local intercepting = false
local last_down = false
local down_button = 0
local down_time = 0
local down_sx, down_sy = 0, 0
local DRAG_HOLD = 0.28
local DRAG_PREVIEW = 0.18
local DRAG_MOVE = 5
local drag_armed = false
local suppress_left_until_release = false

local function extget(k)
    local v = reaper.GetExtState(EXT, k)
    return v ~= "" and v or nil
end

local function extsave(k, v)
    reaper.SetExtState(EXT, k, v and tostring(v) or "", true)
end

local function valid(hwnd)
    return hwnd and reaper.ValidatePtr(hwnd, "HWND*")
end

local function client_size(hwnd)
    if not valid(hwnd) then return 0, 0 end
    local _, w, h = reaper.JS_Window_GetClientSize(hwnd)
    return w or 0, h or 0
end

local function find_main_toolbar()
    if not reaper.JS_Window_ListAllChild then
        return nil
    end

    local count, list = reaper.JS_Window_ListAllChild(main_hwnd)
    if not count or count <= 0 or not list then
        return nil
    end

    local _, ml, mt, mr, mb = reaper.JS_Window_GetRect(main_hwnd)
    if not ml then
        ml, mt, mr, mb = 0, 0, 99999, 99999
    end

    local best, best_score

    for addr in (list .. ","):gmatch("(.-),") do
        local hwnd = reaper.JS_Window_HandleFromAddress(addr)

        if valid(hwnd) and reaper.JS_Window_GetParent(hwnd) == main_hwnd then
            local _, title = reaper.JS_Window_GetTitle(hwnd)
            local _, class = reaper.JS_Window_GetClassName(hwnd)
            local _, w, h = reaper.JS_Window_GetClientSize(hwnd)
            local ok, l, t, r, b = reaper.JS_Window_GetRect(hwnd)

            title = title or ""
            class = class or ""

            if ok and w and h
                and w >= 150
                and h >= 24 and h <= 140
                and title == ""
                and class == "" then

                local rel_x = l - ml
                local rel_y = t - mt

                -- Prefer a compact direct child near the upper-left corner.
                -- The diagnostic on this REAPER setup reported 364x84.
                local score =
                    math.abs(rel_y - 70) * 5 +
                    math.abs(rel_x - 0) * 2 +
                    math.abs(h - 84) * 2 +
                    math.abs(w - 364) * 0.15

                if rel_y >= 0 and rel_y < 240
                    and rel_x >= 0 and rel_x < 900 then
                    if not best_score or score < best_score then
                        best = hwnd
                        best_score = score
                    end
                end
            end
        end
    end

    return best
end

local function find_transport()
    local count, list = reaper.JS_Window_ListFind(transport_title, true)
    if count <= 0 then return nil end
    local first, main_child
    for addr in (list .. ","):gmatch("(.-),") do
        local h = reaper.JS_Window_HandleFromAddress(addr)
        if h then
            first = first or h
            if reaper.JS_Window_IsChild(main_hwnd, h) then
                if main_child then main_child = nil break end
                main_child = h
            end
        end
    end
    return main_child or first
end

local function save_host(hwnd)
    if not valid(hwnd) then return end
    local title = reaper.JS_Window_GetTitle(hwnd) or ""
    local child_id

    if title == "" then
        local parent = reaper.JS_Window_GetParent(hwnd)
        if valid(parent) then
            local id = tonumber(reaper.JS_Window_GetLong(hwnd, "ID"))
            local ptitle = reaper.JS_Window_GetTitle(parent) or ""
            if id and id > 0 and ptitle ~= "" then
                title = ptitle
                child_id = id
            end
        end
    end

    if title == transport_title and not child_id then
        extsave("attach_title", "")
        extsave("attach_child_id", "")
    elseif title ~= "" and not title:find("\n", 1, true) then
        extsave("attach_title", title)
        extsave("attach_child_id", child_id or "")
    end

    extsave("box_x", box_x)
    extsave("box_y", box_y)
end

local function find_saved_host()
    local title = extget("attach_title")
    local child_id = tonumber(extget("attach_child_id") or "")
    if not title then return nil end

    local count, list = reaper.JS_Window_ListFind(title, true)
    if count <= 0 then return nil end

    local first, chosen
    for addr in (list .. ","):gmatch("(.-),") do
        local h = reaper.JS_Window_HandleFromAddress(addr)
        if h then
            first = first or h
            if reaper.JS_Window_IsChild(main_hwnd, h) then
                chosen = h
                break
            end
        end
    end
    chosen = chosen or first
    if chosen and child_id then
        chosen = reaper.JS_Window_FindChildByID(chosen, child_id)
    end
    return chosen
end

-- Floating fallback: use a small gfx host only when no saved target exists.
local floating_hwnd
local function create_floating_host()
    gfx.clear = 0x303030
    gfx.init(NAME, BOX_W, BOX_H, 0, 120, 120)
    floating_hwnd = reaper.JS_Window_Find(NAME, true)
    return floating_hwnd
end

local function button_rect(i)
    local x = (i - 1) * (BTN + GAP)
    return x, 0, BTN, BTN
end

local function state(i)
    for n = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, n)
        if tr then
            if i == 1 and reaper.GetMediaTrackInfo_Value(tr, "I_RECARM") == 1 then return true end
            if i == 2 and reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") == 1 then return true end
            if i == 3 and reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") > 0 then return true end
        end
    end
    return false
end

local function accent(i)
    return i == 1 and COLORS.rec or i == 2 and COLORS.mute or COLORS.solo
end

local function point_button(mx, my)
    local lx, ly = mx - box_x, my - box_y
    for i = 1, 3 do
        local x, y, w, h = button_rect(i)
        if lx >= x and lx < x+w and ly >= y and ly < y+h then
            return i
        end
    end
    return 0
end

local function destroy_bitmap()
    if bitmap and valid(host_hwnd) then
        local old_x, old_y = box_x, box_y
        reaper.JS_Composite_Unlink(host_hwnd, bitmap, false)
        reaper.JS_Window_InvalidateRect(
            host_hwnd,
            old_x, old_y,
            old_x + BOX_W, old_y + BOX_H,
            false
        )
    end

    if bitmap then
        reaper.JS_LICE_DestroyBitmap(bitmap)
        bitmap = nil
    end

    if font then
        reaper.JS_LICE_DestroyFont(font)
        font = nil
    end

    if gdi_font then
        reaper.JS_GDI_DeleteObject(gdi_font)
        gdi_font = nil
    end
    if gdi_font_mute then
        reaper.JS_GDI_DeleteObject(gdi_font_mute)
        gdi_font_mute = nil
    end
end

local function make_bitmap()
    destroy_bitmap()
    bitmap = reaper.JS_LICE_CreateBitmap(true, BOX_W, BOX_H)
    font = reaper.JS_LICE_CreateFont()
    local label_font_size = math.max(8, math.floor(FONT_SIZE * 12 / 13 + 0.5))
    gdi_font = reaper.JS_GDI_CreateFont(label_font_size, 800, 0, false, false, false, "Segoe UI Semibold")
    gdi_font_mute = reaper.JS_GDI_CreateFont(label_font_size, 800, 0, false, false, false, "Segoe UI Semibold")
    reaper.JS_LICE_SetFontFromGDI(font, gdi_font, "")
    reaper.JS_Composite_Delay(host_hwnd, 0.02, 0.04, 2)
    reaper.JS_Composite(host_hwnd, box_x, box_y, BOX_W, BOX_H,
        bitmap, 0, 0, BOX_W, BOX_H, true)
    redraw = true
end

local function draw()
    if not bitmap then return end
    reaper.JS_LICE_Clear(bitmap, 0x00000000)

    local labels = {"Rec", "Mute", "Solo"}

    for i = 1, 3 do
        local x, y, w, h = button_rect(i)
        local active = state(i)

        local fill = active and accent(i) or COLORS.off

        -- DRAG feedback only.
        if dragging or drag_armed then
            if active then
                if i == 1 then fill = 0xB92626
                elseif i == 2 then fill = 0xB89700
                else fill = 0x238E3E end
            else
                fill = 0x777777
            end
        end

        reaper.JS_LICE_FillRect(
            bitmap, x, y, w, h,
            fill, 1, "COPY"
        )

        if i > 1 then
            reaper.JS_LICE_FillRect(
                bitmap, x - 1, y, 1, h,
                0x202020, 1, "COPY"
            )
        end

        if dragging or drag_armed then
            reaper.JS_LICE_FillRect(
                bitmap, x, y, w, 1,
                0xD8D8D8, 1, "COPY"
            )
            reaper.JS_LICE_FillRect(
                bitmap, x, y + h - 1, w, 1,
                0x101010, 1, "COPY"
            )
        end
    end

    -- Draw all labels through GDI directly onto the system LICE bitmap.
    -- JS_GDI_DrawText supports HCENTER + VCENTER, so there are no more
    -- hand-tuned x/y offsets and all labels are centered in their 30x30 box.
    local dc = reaper.JS_LICE_GetDC(bitmap)

    if dc and gdi_font then
        local previous_font = reaper.JS_GDI_SelectObject(dc, gdi_font)

        -- 1 = TRANSPARENT background mode in GDI.
        reaper.JS_GDI_SetTextBkMode(dc, 1)
        reaper.JS_GDI_SetTextColor(dc, 0x000000)

        for i = 1, 3 do
            local x, y, w, h = button_rect(i)
            local label = labels[i]

            if i == 2 and gdi_font_mute then
                reaper.JS_GDI_SelectObject(dc, gdi_font_mute)
            else
                reaper.JS_GDI_SelectObject(dc, gdi_font)
            end

            reaper.JS_GDI_DrawText(
                dc,
                label,
                #label,
                x, y,
                x + w, y + h,
                "HCENTER|VCENTER|SINGLELINE|NOPREFIX"
            )
        end

        if previous_font then
            reaper.JS_GDI_SelectObject(dc, previous_font)
        end
    end

    if valid(host_hwnd) then
        reaper.JS_Window_InvalidateRect(
            host_hwnd,
            box_x, box_y,
            box_x + BOX_W, box_y + BOX_H,
            false
        )
    end

    redraw = false
end

local function stop_intercepts()
    if intercepting and valid(host_hwnd) then
        reaper.JS_WindowMessage_Release(host_hwnd, "WM_LBUTTONDOWN")
        reaper.JS_WindowMessage_Release(host_hwnd, "WM_LBUTTONUP")
    end
    intercepting = false
end

local function start_intercepts()
    if intercepting or not valid(host_hwnd) then return end
    reaper.JS_WindowMessage_Intercept(host_hwnd, "WM_LBUTTONDOWN", false)
    reaper.JS_WindowMessage_Intercept(host_hwnd, "WM_LBUTTONUP", false)
    intercepting = true
end

local function choose_drop_host(mx, my)
    local h = reaper.JS_Window_FromPoint(mx, my)
    local cur = h
    while valid(cur) and cur ~= main_hwnd do
        local w, hh = client_size(cur)
        if w >= BOX_W and hh >= BOX_H and hh <= 180
            and reaper.JS_Window_IsChild(main_hwnd, cur) then
            return cur
        end
        cur = reaper.JS_Window_GetParent(cur)
    end
    return h
end

local function move_to_host(new_host, screen_x, screen_y)
    if not valid(new_host) or new_host == host_hwnd then
        return
    end

    local old_host = host_hwnd
    local old_x, old_y = box_x, box_y

    stop_intercepts()

    if bitmap and valid(old_host) then
        reaper.JS_Composite_Unlink(
            old_host, bitmap, false
        )
        reaper.JS_Window_InvalidateRect(
            old_host,
            old_x, old_y,
            old_x + BOX_W, old_y + BOX_H,
            true
        )
    end

    -- Destroy only graphics objects; old host has already been cleaned.
    if bitmap then
        reaper.JS_LICE_DestroyBitmap(bitmap)
        bitmap = nil
    end
    if font then
        reaper.JS_LICE_DestroyFont(font)
        font = nil
    end
    if gdi_font then
        reaper.JS_GDI_DeleteObject(gdi_font)
        gdi_font = nil
    end
    if gdi_font_mute then
        reaper.JS_GDI_DeleteObject(gdi_font_mute)
        gdi_font_mute = nil
    end

    host_hwnd = new_host
    host_w, host_h = client_size(host_hwnd)

    local cx, cy = reaper.JS_Window_ScreenToClient(
        host_hwnd, screen_x, screen_y
    )

    box_x = math.max(
        0,
        math.min(host_w - BOX_W, cx - drag_dx)
    )
    box_y = math.max(
        0,
        math.min(host_h - BOX_H, cy - drag_dy)
    )

    make_bitmap()
    start_intercepts()
end


local function rebuild_for_scale(new_scale)
    if new_scale == scale_percent then return end

    local old_w, old_h = BOX_W, BOX_H
    local old_x, old_y = box_x, box_y

    if bitmap and valid(host_hwnd) then
        reaper.JS_Composite_Unlink(host_hwnd, bitmap, false)
        reaper.JS_Window_InvalidateRect(
            host_hwnd,
            old_x, old_y,
            old_x + old_w, old_y + old_h,
            true
        )
    end

    if bitmap then
        reaper.JS_LICE_DestroyBitmap(bitmap)
        bitmap = nil
    end
    if font then
        reaper.JS_LICE_DestroyFont(font)
        font = nil
    end
    if gdi_font then
        reaper.JS_GDI_DeleteObject(gdi_font)
        gdi_font = nil
    end
    if gdi_font_mute then
        reaper.JS_GDI_DeleteObject(gdi_font_mute)
        gdi_font_mute = nil
    end

    apply_scale(new_scale)
    extsave("button_scale", scale_percent)

    host_w, host_h = client_size(host_hwnd)
    box_x = math.max(0, math.min(box_x, math.max(0, host_w - BOX_W)))
    box_y = math.max(0, math.min(box_y, math.max(0, host_h - BOX_H)))

    make_bitmap()
    save_host(host_hwnd)
    redraw = true
end

local function show_context_menu()
    local menu =
        "#Global Rec Mute Solo|" ..
        "Taille 100%|" ..
        "Taille 125%|" ..
        "Taille 150%|" ..
        "Taille 200%|" ..
        "||Réinitialiser l'emplacement|" ..
        "Quitter"

    -- Mark the current size.
    local current_index =
        scale_percent == 75 and 1 or
        scale_percent == 100 and 2 or
        scale_percent == 125 and 3 or
        scale_percent == 150 and 4 or
        scale_percent == 175 and 5 or 6

    local entries = {
        "Taille 75%",
        "Taille 100% (Main Toolbar)",
        "Taille 125%",
        "Taille 150%",
        "Taille 175%",
        "Taille 200%"
    }

    entries[current_index] = "!" .. entries[current_index]

    menu =
        "#Global Rec Mute Solo|" ..
        table.concat(entries, "|") ..
        "||Réinitialiser l'emplacement|" ..
        "Quitter"

    local title = "GRMS_Menu_" .. reaper.genGuid()

    gfx.init(title, 0, 0, 0, 0, 0)
    local menu_hwnd = reaper.JS_Window_Find(title, true)
    if menu_hwnd then
        reaper.JS_Window_Show(menu_hwnd, "HIDE")
    end

    gfx.x, gfx.y = 0, 0
    local choice = gfx.showmenu(menu)
    gfx.quit()

    -- gfx.showmenu counts the disabled title "#Global Rec Mute Solo"
    -- as item #1. Remove that offset so our logical menu indices start
    -- at 1 = 75%, 2 = 100%, etc.
    if choice > 0 then
        choice = choice - 1
    end

    if choice == 1 then
        rebuild_for_scale(75)
    elseif choice == 2 then
        rebuild_for_scale(100)
    elseif choice == 3 then
        rebuild_for_scale(125)
    elseif choice == 4 then
        rebuild_for_scale(150)
    elseif choice == 5 then
        rebuild_for_scale(175)
    elseif choice == 6 then
        rebuild_for_scale(200)
    elseif choice == 7 then
        -- Clear remembered target/position. Current run stays where it is;
        -- next launch falls back to floating mode.
        for _, k in ipairs({
            "attach_title",
            "attach_child_id",
            "box_x",
            "box_y"
        }) do
            reaper.DeleteExtState(EXT, k, true)
        end
    elseif choice == 8 then
        -- Ask the main loop to stop cleanly.
        reaper.SetExtState(EXT, "request_quit", "1", false)
    end
end

local function update_mouse()
    local sx, sy = reaper.GetMousePosition()
    local cx, cy = reaper.JS_Window_ScreenToClient(host_hwnd, sx, sy)
    local hit = point_button(cx, cy)

    if hit ~= hover then
        hover = hit
        redraw = true
    end

    -- JS_Mouse_GetState uses the same bitfield as gfx.mouse_cap:
    -- bit 1 = left mouse, bit 4 = Ctrl on Windows.
    local mouse_state = reaper.JS_Mouse_GetState(1 | 4)
    local down = (mouse_state & 1) == 1
    local ctrl_down = (mouse_state & 4) == 4

    -- Ctrl + left click opens the configuration menu.
    -- Suppress the entire left-click gesture so it cannot toggle or drag.
    if down and not last_down then
        if hit > 0 and ctrl_down then
            suppress_left_until_release = true
            down_button = 0
            pressed = 0
            drag_armed = false
            dragging = false
            redraw = true

            show_context_menu()
        else
            down_button = hit
            drag_armed = false
            down_time = reaper.time_precise()
            down_sx, down_sy = sx, sy

            if hit > 0 then
                pressed = hit
                redraw = true
            end
        end
    end

    -- Timing fallback: Ctrl can become visible one defer cycle later.
    if down and last_down and not suppress_left_until_release
        and not dragging and down_button > 0 and ctrl_down then

        suppress_left_until_release = true
        down_button = 0
        pressed = 0
        drag_armed = false
        dragging = false
        redraw = true

        show_context_menu()
    end

    if suppress_left_until_release then
        if not down and last_down then
            suppress_left_until_release = false
            down_button = 0
            pressed = 0
            drag_armed = false
            dragging = false
            redraw = true
        end

        last_down = down
        return
    end

    -- Normal click / drag behavior.
    if down and down_button > 0 and not dragging then
        local held = reaper.time_precise() - down_time
        local moved = math.max(
            math.abs(sx - down_sx),
            math.abs(sy - down_sy)
        )

        if held >= DRAG_PREVIEW and not drag_armed then
            drag_armed = true
            redraw = true
        end

        if held >= DRAG_HOLD or moved >= DRAG_MOVE then
            dragging = true
            drag_armed = false
            pressed = 0
            redraw = true
            drag_dx = cx - box_x
            drag_dy = cy - box_y
        end
    end

    if dragging and down then
        local drop = choose_drop_host(sx, sy)

        if valid(drop) and drop ~= host_hwnd then
            move_to_host(drop, sx, sy)
            cx, cy = reaper.JS_Window_ScreenToClient(
                host_hwnd, sx, sy
            )
        end

        local old_x, old_y = box_x, box_y
        local new_x = math.max(
            0,
            math.min(host_w - BOX_W, cx - drag_dx)
        )
        local new_y = math.max(
            0,
            math.min(host_h - BOX_H, cy - drag_dy)
        )

        if new_x ~= old_x or new_y ~= old_y then
            reaper.JS_Composite_Unlink(
                host_hwnd, bitmap, false
            )

            reaper.JS_Window_InvalidateRect(
                host_hwnd,
                old_x, old_y,
                old_x + BOX_W, old_y + BOX_H,
                true
            )

            box_x, box_y = new_x, new_y

            reaper.JS_Composite(
                host_hwnd,
                box_x, box_y, BOX_W, BOX_H,
                bitmap, 0, 0, BOX_W, BOX_H,
                true
            )

            reaper.JS_Window_InvalidateRect(
                host_hwnd,
                box_x, box_y,
                box_x + BOX_W, box_y + BOX_H,
                false
            )
        end

        redraw = true
    end

    if not down and last_down then
        if dragging then
            dragging = false
            drag_armed = false
            pressed = 0
            down_button = 0
            save_host(host_hwnd)
            extsave("box_x", box_x)
            extsave("box_y", box_y)
            redraw = true

        elseif down_button > 0 then
            local release_hit = point_button(cx, cy)

            if release_hit == down_button then
                if down_button == 1 then
                    Core.toggle_arm()
                elseif down_button == 2 then
                    Core.toggle_mute()
                elseif down_button == 3 then
                    Core.toggle_solo()
                end
                reaper.UpdateArrange()
            end

            pressed = 0
            drag_armed = false
            down_button = 0
            redraw = true
        end
    end

    last_down = down
end

local last_states = {}
local function main()
    if reaper.GetExtState(EXT, "request_quit") == "1" then
        reaper.DeleteExtState(EXT, "request_quit", false)
        return
    end

    if not valid(host_hwnd) then
        host_hwnd = find_saved_host()
        if not host_hwnd then
            -- No valid remembered target: prefer the Main Toolbar.
            host_hwnd = find_main_toolbar()
            if host_hwnd then
                host_w, host_h = client_size(host_hwnd)
                box_x = math.max(0, host_w - BOX_W - 4)
                box_y = math.max(0, math.floor((host_h - BOX_H) / 2))
                save_host(host_hwnd)
            else
                -- Safety fallback only if Main Toolbar detection fails.
                host_hwnd = create_floating_host()
                box_x, box_y = 0, 0
            end
        end
        host_w, host_h = client_size(host_hwnd)
        make_bitmap()
        start_intercepts()
    end

    host_w, host_h = client_size(host_hwnd)
    update_mouse()

    for i=1,3 do
        local v = state(i)
        if last_states[i] ~= v then
            last_states[i] = v
            redraw = true
        end
    end

    if redraw then draw() end
    reaper.defer(main)
end

local function cleanup()
    stop_intercepts()
    destroy_bitmap()
    if floating_hwnd then gfx.quit() end
end

reaper.atexit(cleanup)
reaper.DeleteExtState(EXT, "request_quit", false)

-- If no target is remembered, V5.9.1 first tries to attach to the Main Toolbar.
host_hwnd = find_saved_host()

if host_hwnd then
    box_x = tonumber(extget("box_x")) or 0
    box_y = tonumber(extget("box_y")) or 0
else
    -- First launch: attach directly to the Main Toolbar.
    host_hwnd = find_main_toolbar()

    if host_hwnd then
        host_w, host_h = client_size(host_hwnd)
        box_x = math.max(0, host_w - BOX_W - 4)
        box_y = math.max(0, math.floor((host_h - BOX_H) / 2))
        save_host(host_hwnd)
    else
        -- Only fall back to floating if automatic detection fails.
        host_hwnd = create_floating_host()
        box_x, box_y = 0, 0
    end
end

host_w, host_h = client_size(host_hwnd)
make_bitmap()
start_intercepts()
main()
