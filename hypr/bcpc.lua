-- bcpc -- host-specific input and environment.
--
-- required() from hyprland.lua near the bottom, so anything set here wins over
-- the defaults above it -- the same ordering the old `source =` lines had.
--
-- Env vars belong here rather than in ~/.zshrc.bcpc: zshrc runs only for
-- interactive shells, so anything exported there is invisible to GUI apps
-- launched from the Noctalia launcher. hl.env applies to the whole session.

-- --- Keyboard -------------------------------------------------------------
-- Replaces the setxkbmap call in zshrc, which cannot work under Wayland.
-- lv3:ralt_switch makes Right Alt a distinct modifier (ISO_Level3_Shift = Mod5)
-- so it can serve as the Hyprland mod key without capturing Left Alt, which
-- applications still need. See `mod` in keybinds.lua.
-- Cost: Right Alt no longer types AltGr third-level characters.
hl.config({
    input = {
        kb_layout  = "us",
        kb_options = "ctrl:nocaps,lv3:ralt_switch",
    },
})

-- --- Mouse ----------------------------------------------------------------
-- Flat, unscaled pointer deltas. This is not a desktop-comfort preference:
-- Hyprland runs pointer motion through libinput's acceleration curve before it
-- reaches *any* client, and that includes the relative-pointer stream a game
-- reads for mouselook. Left on libinput's default "adaptive" profile, a slow
-- drag and a fast flick of the same physical distance turn into different
-- in-game distances -- which is exactly what a raw-input mode exists to avoid,
-- and why a Windows sensitivity number does not carry across untouched.
--
--   accel_profile "flat"   no curve; output scales linearly with input
--   sensitivity 0          the neutral point of Hyprland's -1.0..1.0 range.
--                          NOT "off" -- 0 means 1:1. It is also the default,
--                          so this line documents the intent rather than
--                          changing anything; accel_profile is the one doing
--                          the work.
--
-- Deliberately NOT force_no_accel. That bypasses the pointer pipeline instead
-- of flattening it, and the wiki's own warning about cursor desynchronisation
-- is the failure you would then be chasing. Flat is the supported way to ask
-- for the same thing.
--
-- Global rather than per-device (hl.device), because the desk mouse is not the
-- only pointer on this seat -- the Wooting's HID mouse endpoints show up in
-- `hyprctl devices` as mice too -- and a per-device block only covers a name
-- that happens to be plugged in at the time.
hl.config({
    input = {
        accel_profile = "flat",
        sensitivity   = 0,
    },
})

-- --- Mouse DPI ------------------------------------------------------------
-- Starts the Solaar daemon, which is the only thing on this host that puts the
-- PRO X 2 DEX on the 1200 DPI it is configured for.
--
-- The mouse powers on with its onboard profile active, and that profile is 800
-- DPI. ~/.config/solaar/config.yaml already asks for the opposite --
-- `onboard_profiles: 0` with `dpi_extended: 1200` -- but nothing on this host
-- ever applied that file. Solaar ships no systemd unit, there is no
-- ~/.config/autostart, and no exec_cmd here launched it, so it had only ever
-- been running when it was started by hand. That is why the DPI was wrong after
-- every reboot, and why it kept looking like a symptom of whatever else had
-- been changed that week.
--
-- Measured, not assumed. `solaar show` reports the saved and the live value as
-- separate lines, and on a fresh boot with no daemon they disagree:
--
--     Sensitivity (DPI) (saved): {X:1200, Y:1200, LOD:HIGH}
--     Sensitivity (DPI)        : {X:800,  Y:800,  LOD:HIGH}
--
-- Starting the daemon flips the live value to 1200 with nothing else touched.
--
-- A resident daemon rather than a one-shot `solaar config ... dpi 1200`: this
-- is a wireless mouse that sleeps and re-pairs, and re-applying settings when
-- the device comes back is the job solaar stays resident for. A one-shot would
-- hold only until the first sleep.
--
-- `--window=hide` keeps it out of the tray. Here it is a settings applier that
-- runs at login, not something meant to be clicked.
--
-- A second handler for this event, which is fine: hyprland.lua already has one
-- for the desktop-wide daemons, and window.open is registered in both
-- gaming.lua and stream.lua. Host hardware belongs in this file rather than in
-- that generic list.
hl.on("hyprland.start", function()
    hl.exec_cmd("solaar --window=hide")
end)

-- --- RGB ------------------------------------------------------------------
-- The terminal-palette gradient across the GPU, the board and the DIMMs
-- (openrgb/iceberg-rgb.py). Started here rather than enabled: the OpenRGB
-- server reaches the I2C and hidraw nodes through `uaccess` ACLs, which only
-- exist once the login session is active, and this is the first point on
-- this host that is guaranteed -- see openrgb/openrgb-server.service.
-- BindsTo in iceberg-rgb.service pulls the server in, so one unit is enough.
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start iceberg-rgb.service")
end)

-- --- NVIDIA ---------------------------------------------------------------
-- 4070 Ti (Ada) on the open kernel modules. Deliberately NOT setting
-- WLR_NO_HARDWARE_CURSORS or GBM_BACKEND: those are pre-explicit-sync advice
-- and cause problems on current drivers.
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-- --- Toolkits -------------------------------------------------------------
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- Stops Electron/Chromium flicker by forcing native Wayland.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
