-- bcpc -- host-specific input and environment (required last from hyprland.lua).
-- Why flat accel, solaar, RGB start: docs/hyprland.md#bcpclua
hl.config({
    input = {
        kb_layout  = "us",
        kb_options = "ctrl:nocaps,lv3:ralt_switch",
    },
})

hl.config({
    input = {
        accel_profile = "flat",
        sensitivity   = 0,
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("solaar --window=hide")
end)

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start iceberg-rgb.service")
end)

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
