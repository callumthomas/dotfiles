-- Hyprland Lua config.
-- Migrated from hyprland.conf for Hyprland 0.55.0 (Lua-ification).
-- See https://wiki.hypr.land/Configuring/Start/


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- Home: Dell U2415 portrait, far left
hl.monitor({
    output    = "desc:Dell Inc. DELL U2415 7MT0173T0WDS",
    mode      = "1920x1200@59.95",
    position  = "0x0",
    scale     = 1,
    transform = 1,
})
-- Home: LG Ultragear 1440p, to the right of Dell (1200px = Dell width after rotation)
hl.monitor({
    output   = "desc:LG Electronics LG ULTRAGEAR",
    mode     = "2560x1440@59.95",
    position = "1200x240",
    scale    = 1,
})

-- Office: Dell U2415 portrait, far left
hl.monitor({
    output    = "desc:Dell Inc. DELL U2415 7MT0177S4HVL",
    mode      = "1920x1200@59.95",
    position  = "0x0",
    scale     = 1,
    transform = 1,
})
-- Office: Dell U2415 landscape, center
hl.monitor({
    output   = "desc:Dell Inc. DELL U2415 7MT018BE0TDU",
    mode     = "1920x1200@59.95",
    position = "1200x0",
    scale    = 1,
})
-- Office: Dell U2414H (legacy), top-right above laptop; bottom edge meets laptop top at 50% of center monitor (y=600)
hl.monitor({
    output   = "desc:Dell Inc. DELL U2414H 9TG4661BC3ML",
    mode     = "1920x1080@60",
    position = "3120x-480",
    scale    = 1,
})
-- Office: Dell P2419H, current replacement for the U2414H — same top-right slot above the laptop
hl.monitor({
    output   = "desc:Dell Inc. DELL P2419H 61WZFZ2",
    mode     = "1920x1080@60",
    position = "3120x-480",
    scale    = 1,
})

-- Laptop panel — default auto; pinned below the office top monitor (U2414H or P2419H) when present (see callback below).
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })

-- When the office top monitor (U2414H or its P2419H replacement) is connected, pin the
-- laptop directly below it so the split between the two right-stack monitors sits at
-- y=600 (50% of center monitor). When neither is connected, leave the laptop on auto so
-- the home layout works.
local function apply_laptop_position_for_office_top()
    local has_office_top = false
    for _, m in ipairs(hl.get_monitors() or {}) do
        if m.description and (m.description:find("DELL U2414H 9TG4661BC3ML")
                              or m.description:find("DELL P2419H 61WZFZ2")) then
            has_office_top = true
            break
        end
    end
    if has_office_top then
        hl.monitor({
            output   = "desc:Lenovo Group Limited B140UAN02.7",
            mode     = "1920x1200@60",
            position = "3120x600",
            scale    = 1,
        })
    else
        hl.monitor({
            output   = "desc:Lenovo Group Limited B140UAN02.7",
            mode     = "preferred",
            position = "auto",
            scale    = 1,
        })
    end
end

hl.on("hyprland.start",        apply_laptop_position_for_office_top)
hl.on("config.reloaded",       apply_laptop_position_for_office_top)
hl.on("monitor.added",         function(_) apply_laptop_position_for_office_top() end)
hl.on("monitor.removed",       function(_) apply_laptop_position_for_office_top() end)
-- hl.on("monitor.layout_changed", apply_laptop_position_for_office_top)
-- Fallback for any other monitor
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "ghostty"
local fileManager = "thunar"
local menu        = 'ags request "toggle launcher"'


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
    hl.exec_cmd("ags run --directory ~/.config/ags & hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user start xdg-desktop-portal-hyprland")
    hl.exec_cmd("clipse -listen")
    hl.exec_cmd("easyeffects --gapplication-service")
    hl.exec_cmd("~/.config/hypr/scripts/hypr-urgent-border.sh")

    -- Monitoring tools on special workspace
    hl.exec_cmd(terminal .. " --class=com.special.btop -e btop")
    hl.exec_cmd(terminal .. " --class=com.special.dm -e dm")
end)

hl.window_rule({
    name  = "special-apps",
    match = { class = "^(com\\.special\\..*)$" },
    workspace = "special:magic",
})

hl.window_rule({
    name  = "clipse-float",
    match = { class = "com.floating.clipse" },
    float = true,
    size  = "622 652",
})

hl.window_rule({
    name  = "scratch-float",
    match = { class = "com.floating.scratch" },
    float = true,
    size  = "900 600",
})

hl.window_rule({
    name  = "broadcast-float",
    match = { class = "com.floating.broadcast" },
    float = true,
    size  = "900 500",
})


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRLAND_NO_SD_NOTIFY", "1")


-----------------------
----- PERMISSIONS -----
-----------------------

hl.config({
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            active_border   = "rgba(33ccffee)",
            inactive_border = "rgba(33ccff00)",
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 5,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },

    -- Workaround for aquamarine 0.11.0 per-frame modeset + page-flip loop on
    -- multi-monitor laptops. Re-enable once aquamarine > 0.11.0-2 lands the fix.
    -- https://github.com/hyprwm/aquamarine/issues/265
    -- https://github.com/hyprwm/Hyprland/issues/10979
    render = {
        new_render_scheduling = false,
    },
})

-- Curves
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "gb",
        kb_variant = "",
        kb_model   = "pc105",
        kb_options = "caps:escape_shifted_capslock",
        kb_rules   = "",

        follow_mouse  = 1,
        sensitivity   = 0,
        scroll_factor = 0.75,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Apps
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("env MOZ_ENABLE_WAYLAND=0 firefox -P default-release"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("env MOZ_ENABLE_WAYLAND=0 firefox -P minimal"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("datagrip"))

-- Lock
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("~/.config/hypr/scripts/hyprlock-themed.sh"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprlock --config ~/.config/hypr/hyprlock-screenshot.conf"))

-- Tmux sessions
hl.bind("CONTROL + ALT + 1", hl.dsp.exec_cmd(terminal .. " --confirm-close-surface=false -e tmux new -A -s delio-demo"))
hl.bind("CONTROL + ALT + 2", hl.dsp.exec_cmd(terminal .. " --confirm-close-surface=false -e tmux new -A -s delio-prod"))
hl.bind("CONTROL + ALT + 3", hl.dsp.exec_cmd(terminal .. " --confirm-close-surface=false -e tmux new -A -s fe-build"))
hl.bind("CONTROL + ALT + 4", hl.dsp.exec_cmd(terminal .. " --confirm-close-surface=false -e tmux new -A -s devenv"))

-- Home Assistant office lamp
hl.bind("CONTROL + ALT + L", hl.dsp.exec_cmd("~/dev/dotfiles/homeassistant/toggle_office_lamp.sh"))
hl.bind(mainMod .. " + F1",  hl.dsp.exec_cmd("~/dev/dotfiles/homeassistant/set_office_lamp.sh -50"))
hl.bind(mainMod .. " + F2",  hl.dsp.exec_cmd("~/dev/dotfiles/homeassistant/set_office_lamp.sh +50"))

-- Workspace / shell utilities
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.focus({ workspace = "emptym" }))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("killall gjs || ags run --directory ~/.config/ags &"))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("rfkill toggle bluetooth"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-dark-mode.sh"))

-- Broadcast input: SUPER+SHIFT+LMB toggles a window's membership, SUPER+SHIFT+Return sends
hl.bind(mainMod .. " + SHIFT + mouse:272", hl.dsp.exec_cmd("~/.config/hypr/scripts/broadcast-select.sh"), { mouse = true })
hl.bind(mainMod .. " + SHIFT + Return",    hl.dsp.exec_cmd("~/.config/hypr/scripts/broadcast-send.sh"))

-- Floating scratch terminals
-- closewindow always returns "ok" async, so we check for the window's existence
-- first via `hyprctl clients` and toggle accordingly.
hl.bind(mainMod .. " + V",         hl.dsp.exec_cmd('hyprctl clients | grep -q "class: com.floating.clipse" && hyprctl dispatch closewindow class:com.floating.clipse || ' .. terminal .. ' --class=com.floating.clipse --confirm-close-surface=false -e clipse'))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd('hyprctl clients | grep -q "class: com.floating.scratch" && hyprctl dispatch closewindow class:com.floating.scratch || ' .. terminal .. ' --class=com.floating.scratch --confirm-close-surface=false -e tmux new -A -s scratch'))

-- Screenshot
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("hyprcap shot region -z -n -A -r | wl-copy --type image/png"))

-- Window / session control
hl.bind(mainMod .. " + SHIFT + CONTROL + Q", hl.dsp.exit())
hl.bind(mainMod .. " + Q",                   hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + F",           hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + G",           hl.dsp.window.fullscreen_state({ internal = 0, client = 2 }))
hl.bind(mainMod .. " + P",                   hl.dsp.exec_cmd("GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb Plex"))
hl.bind(mainMod .. " + J",                   hl.dsp.layout("togglesplit"))    -- dwindle only

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Resize with mainMod + Control + arrow keys
hl.bind(mainMod .. " + CONTROL + left",  hl.dsp.window.resize({ x = -100, y = 0,    relative = true }))
hl.bind(mainMod .. " + CONTROL + down",  hl.dsp.window.resize({ x = 0,    y = 100,  relative = true }))
hl.bind(mainMod .. " + CONTROL + up",    hl.dsp.window.resize({ x = 0,    y = -100, relative = true }))
hl.bind(mainMod .. " + CONTROL + right", hl.dsp.window.resize({ x = 100,  y = 0,    relative = true }))

-- Move window with mainMod + Shift + arrow keys
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Workspace switch + move-to-workspace with mainMod + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Media keys (requires playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Lid close: suspend-then-hibernate (hypridle handles locking via before_sleep_cmd)
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("systemctl suspend-then-hibernate"), { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Bind default workspaces to monitors
-- Home: Dell portrait | LG Ultragear | Laptop
-- Office: Dell portrait | Dell landscape | Laptop
hl.workspace_rule({ workspace = "1", monitor = "desc:Dell Inc. DELL U2415 7MT0173T0WDS", default = true })
hl.workspace_rule({ workspace = "1", monitor = "desc:Dell Inc. DELL U2415 7MT0177S4HVL", default = true })
hl.workspace_rule({ workspace = "2", monitor = "desc:LG Electronics LG ULTRAGEAR",       default = true })
hl.workspace_rule({ workspace = "2", monitor = "desc:Dell Inc. DELL U2415 7MT018BE0TDU", default = true })
hl.workspace_rule({ workspace = "3", monitor = "eDP-1",                                  default = true })
