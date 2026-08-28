-- bcpc -- rules for games played locally, on DP-3 (540Hz) or DP-1 (ultrawide).
--
-- Matched on class rather than on the Wayland content type. The CAVEAT this
-- file used to end with is now settled, and it settled the wrong way: with
-- Overwatch running under Proton,
--
--     hyprctl clients -j | jq '.[] | {class, xwayland, contentType, xdgTag}'
--     { "class": "steam_app_2357570", "xwayland": false,
--       "contentType": "none", "xdgTag": "proton-game" }
--
-- Note `xwayland: false`. That is new, and it is the launch option doing it:
-- PROTON_ENABLE_WAYLAND=1 makes proton-cachyos load winewayland.drv instead of
-- winex11.drv, so Overwatch is now a native Wayland client. An earlier revision
-- of this comment recorded `xwayland: true`, which was true before the option
-- was added and is not any more.
--
-- The conclusion survives the correction, for a different reason than it was
-- first given: `contentType` is *still* "none". Wine does not set the
-- content-type protocol on a game surface whichever driver it uses, so
-- `content = "game"` still matches nothing and every rule here would still be
-- dead config if it were written that way -- which is why a Steam game landed
-- in a tile with rounded corners and dimmed when it lost focus.
--
-- `xdgTag = "proton-game"` is the honest matcher for "a Proton title" and
-- Hyprland supports it as a rule prop, but it covers only Wayland-native Proton
-- clients. Class covers those *and* anything still on XWayland, so the rules
-- below stay on class.
--
-- The tradeoff of matching on class: unlike the content rules, these can reach
-- a game sitting on workspace 11. That overlap with stream.lua is harmless --
-- both files ask for the same fullscreen state and the same pointer confinement,
-- so a streamed game is simply told twice -- but it does mean this file is no
-- longer structurally incapable of touching a stream. The event handler below
-- stays scoped to keep the two from racing each other.

-- Anchored at both ends deliberately. `match.class` is a full match, not a
-- search, so a bare `^steam_app_` prefix silently matches nothing -- which is
-- what left the first pass at this file just as dead as the content rules it
-- replaced. `.*$` is also a valid Lua pattern, so this one constant serves both
-- the rule matcher below and the `w.class:match()` in the backstop.
local GAME_CLASS       = "^steam_app_.*$"  -- Proton/XWayland titles
local STREAM_WORKSPACE = 11               -- stream.lua's, not ours

-- Keep the cursor inside the game. With a 540Hz panel beside a 3440-wide one,
-- a mouselook that runs off the edge onto the other monitor mid-fight is a real
-- hazard, and most games only half-manage the pointer lock themselves.
--
-- Still gated on fullscreen: a windowed game -- or a launcher that maps under
-- the same class before the game proper -- should not trap the pointer in a
-- small window. That gate was inert while the class half never matched; now
-- that the rule below makes fullscreen actually happen, it does something.
hl.window_rule({
    name  = "local-game-pointer",
    match = { class = GAME_CLASS, fullscreen = true },

    confine_pointer = true,
})

-- Launch fullscreen. There was previously no rule for this outside workspace 11,
-- so a locally launched game only ever became fullscreen if the title did it
-- itself -- Overwatch does not, hence the tile.
--
--   fullscreen_state "2 2"   internal and client state both fullscreen, the
--                            same pair stream.lua asks for
--   sync_fullscreen          forces those two to agree; a mismatch is what
--                            leaves a game rendering at the wrong size
--   suppress_event           x11configurerequest stops an XWayland title
--                            resizing its own window back out of fullscreen.
--                            Not fullscreenoutput -- that one exists to pin a
--                            stream to the virtual output, and suppressing it
--                            here would block a legitimate "go fullscreen on
--                            the other monitor" on a two-panel desk.
hl.window_rule({
    name  = "local-game-fullscreen",
    match = { class = GAME_CLASS },

    fullscreen_state = "2 2",
    sync_fullscreen  = true,
    suppress_event   = "x11configurerequest",
})

-- Let the game tear. `general:allow_tearing` in hyprland.lua is only the master
-- switch: with it on but no per-window opt-in, Hyprland still drops the
-- client's tearing commits and says so in `hyprctl rollinglog` --
--
--     Tearing commit requested but the master switch general:allow_tearing is
--     off, ignoring
--
-- Ungated on fullscreen for the same reason the chrome rule below is: rules
-- apply at map time, when the game is not fullscreen yet. It is self-gating in
-- practice -- a torn present needs the window to own the scanout plane, which
-- only a fullscreen one does -- so a windowed game silently gets nothing.
--
-- Two things outside Hyprland have to agree before this shows up as an actual
-- reduction in latency: vsync off inside Overwatch, and `dxvk.tearFree = False`
-- in ~/.config/dxvk.conf, which the DXVK_CONFIG_FILE launch option already
-- points at.
hl.window_rule({
    name  = "local-game-tearing",
    match = { class = GAME_CLASS },

    immediate = true,
})

-- No desktop chrome on a game. Cheaper than it looks: blur in particular is a
-- per-frame cost paid for something almost entirely hidden.
--
-- Deliberately NOT gated on fullscreen, unlike the pointer rule. A window rule
-- is applied when the window maps, and at map time a game is not fullscreen yet
-- -- the rule above is what makes it so, a moment later. Gating this on a state
-- that only arrives afterwards is a good way to reproduce the rounded corners
-- this file exists to remove. Ungated it also covers a game run windowed on
-- purpose, which should not have rounded corners or blur behind it either.
--
-- `decorate = false` rather than the `border_size = 0` / `rounding = 0` this
-- file used to carry. Neither of those is a window property at all --
--
--     hyprctl getprop <regex> no_border    -> prop not found
--     hyprctl getprop <regex> no_rounding  -> prop not found
--
-- and an unrecognised prop is accepted silently, so those two lines had been
-- doing nothing since they were written. `decorate` is in the real property
-- table and reads back false once applied. It takes the border, shadow and
-- glow together, which is the whole intent here anyway.
--
-- Only the display-scoped props live here. no_dim/no_shadow/no_anim are in
-- decoration.lua, because those have to reach a streamed game as well and this
-- file is about the local panels.
hl.window_rule({
    name  = "local-game-chrome",
    match = { class = GAME_CLASS },

    decorate = false,
    no_blur  = true,
})

-- --- fullscreen backstop --------------------------------------------------
-- Same belt-and-braces as stream.lua, and for the same reason: a window rule
-- applies at map time, while a Proton title may map small and only settle into
-- its real surface a moment later. `action = "set"` is idempotent, so this is
-- free when the rule above already did the job -- unlike the bare
-- `fullscreenstate` dispatcher, which toggles and would knock an
-- already-fullscreen game back into a tile.
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

    -- stream.lua has its own handler for workspace 11; two timers racing to
    -- fullscreen the same window is how a game ends up flickering between
    -- states on a cold start.
    if w.workspace ~= nil and w.workspace.id == STREAM_WORKSPACE then return end

    -- A timer, never a sleep: these callbacks run on the compositor event loop
    -- and blocking one freezes the desktop.
    hl.timer(function() go_fullscreen(w) end, { timeout = 400, type = "oneshot" })
end)
