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
