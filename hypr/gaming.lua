-- bcpc -- rules for games played locally on DP-3 / DP-1. Matched on class (steam_app_.*), not content type.
-- Why each rule: docs/hyprland.md#gaminglua
local GAME_CLASS       = "^steam_app_.*$"  -- Proton/XWayland titles
local STREAM_WORKSPACE = 11               -- stream.lua's, not ours

hl.window_rule({
    name  = "local-game-pointer",
    match = { class = GAME_CLASS, fullscreen = true },

    confine_pointer = true,
})

hl.window_rule({
    name  = "local-game-fullscreen",
    match = { class = GAME_CLASS },

    fullscreen_state = "2 2",
    sync_fullscreen  = true,
    suppress_event   = "x11configurerequest",
})

hl.window_rule({
    name  = "local-game-tearing",
    match = { class = GAME_CLASS },

    immediate = true,
})

hl.window_rule({
    name  = "local-game-chrome",
    match = { class = GAME_CLASS },

    decorate = false,
    no_blur  = true,
})

local function go_fullscreen(w)
    if w == nil then return end

    print(("[gaming.lua] fullscreen %s size=%s fs=%s"):format(
        tostring(w.class), tostring(w.size), tostring(w.fullscreen)))

    hl.dispatch(hl.dsp.window.fullscreen_state({
        internal = 2, client = 2, action = "set", window = w,
    }))
end

hl.on("window.open", function(w)
    if w == nil or w.class == nil then return end
    if not w.class:match(GAME_CLASS) then return end

    if w.workspace ~= nil and w.workspace.id == STREAM_WORKSPACE then return end

    hl.timer(function() go_fullscreen(w) end, { timeout = 400, type = "oneshot" })
end)
