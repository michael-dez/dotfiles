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
