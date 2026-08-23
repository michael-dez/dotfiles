-- bcpc -- everything that exists only while Moonlight is connected.
--
-- Replaces two things at once: the workspace-11 block that used to live in
-- hyprland.conf, and sunshine/hooks/stream-focus.py, which was a standalone
-- Python daemon parsing Hyprland's socket2 event stream.
--
-- That daemon existed because hyprlang could not express "fullscreen whatever
-- lands on workspace 11": `windowrule = fullscreen true, match:workspace 11`
-- parsed without error but never applied. Lua documents `match.workspace` as a
-- real window-rule prop, so the rule below is the primary mechanism and the
-- event handlers are a backstop. See the comment on WS_RULE_VERIFIED.

local SUNSHINE_OUTPUT    = "sunshine"
local STREAM_WORKSPACE   = 11

-- print() lands in Hyprland's own log, readable with `hyprctl rollinglog`, so
-- this side of the stream needs no equivalent of the shell hooks' log file.
local function log(msg)
    print("[stream.lua] " .. msg)
end

-- The headless output's existence *is* the stream. Derived rather than tracked
-- so there is no flag to get out of sync with reality -- stream-start.sh
-- creates the output, stream-end.sh removes it, and nothing else makes one.
local function streaming()
    return hl.get_monitor(SUNSHINE_OUTPUT) ~= nil
end

-- --- the virtual output ---------------------------------------------------
-- A default mode for the output stream-start.sh creates on demand. That hook
-- overrides this with the client's negotiated mode, but `hyprctl reload`
-- re-applies the config, and without a rule naming this output the catch-all
-- in hyprland.lua would reclaim it at its preferred size -- resizing a live
-- stream mid-session. Naming it here keeps a reload harmless.
hl.monitor({
    output   = SUNSHINE_OUTPUT,
    mode     = "1280x800@90",   -- Steam Deck OLED, which is what streams here
    position = "auto",
    scale    = 1,
})

-- --- the reserved workspace -----------------------------------------------
-- The stream should look like a dedicated game display, not a tiled desktop
-- with chrome around the edges. Note the polarity flip from hyprlang: what was
-- `border:false, rounding:false` is `no_border`/`no_rounding` here.
hl.workspace_rule({
    workspace   = tostring(STREAM_WORKSPACE),
    monitor     = SUNSHINE_OUTPUT,
    gaps_in     = 0,
    gaps_out    = 0,
    no_border   = true,
    no_rounding = true,
    decorate    = false,
})

-- --- the crop mitigation --------------------------------------------------
-- Matched on the workspace, so nothing here can reach local play on DP-3/DP-1.
--
-- The failure being addressed: a game asks X how big the display is, gets a
-- physical monitor's size rather than the virtual output's, renders at that,
-- and what reaches the encoder is the top-left crop of a larger image.
--
--   suppress_event fullscreenoutput   drops a client's request to fullscreen
--                                     onto a *different* output than the one
--                                     it is on -- the request behind the crop.
--   suppress_event x11configurerequest stops an XWayland game resizing its own
--                                     window out from under the frame.
--   sync_fullscreen                   forces Hyprland's internal fullscreen
--                                     state and the state sent to the client to
--                                     agree; a mismatch is the crop.
--   confine_pointer                   host and stream share one seat, so
--                                     without this the desk mouse wanders off
--                                     the virtual output mid-game. Keybinds are
--                                     handled by the compositor and still fire,
--                                     so MOD5+SHIFT+s remains an escape hatch.
hl.window_rule({
    name  = "stream-game",
    match = { workspace = STREAM_WORKSPACE },

    fullscreen_state = "2 2",
    sync_fullscreen  = true,
    suppress_event   = "fullscreenoutput x11configurerequest",
    confine_pointer  = true,
})

-- --- pulling Steam onto the stream ----------------------------------------
-- Steam maps its windows onto whatever workspace holds focus at that moment,
-- and focus drifts: the desk mouse moves, or a cold Steam start takes long
-- enough that stream-start.sh's focus call is ancient history. Placement cannot
-- be pinned at launch either -- the steam:// URL is handled by the already
-- running Steam process, so the window is not a child of anything we spawn.
--
-- Enabled only while a client is connected. Left on permanently it would yank
-- Steam off the desk during local play, which is the whole reason the Python
-- version only ran for the life of a stream.
local capture = hl.window_rule({
    name      = "stream-capture",
    match     = { class = "^steam$" },
    workspace = tostring(STREAM_WORKSPACE) .. " silent",
})
capture:set_enabled(false)

hl.on("monitor.added", function(m)
    if m ~= nil and m.name == SUNSHINE_OUTPUT then
        capture:set_enabled(true)
        log("stream up: capture rule enabled")
    end
end)

hl.on("monitor.removed", function(m)
    if m ~= nil and m.name == SUNSHINE_OUTPUT then
        capture:set_enabled(false)
        log("stream down: capture rule disabled")
    end
end)

-- --- fullscreen enforcement -----------------------------------------------
-- `action = "set"` is an idempotent setter. The old Python had to read the
-- window's state first and bail if it was already fullscreen, because the bare
-- `fullscreenstate` dispatcher toggles -- asking for the state a window is
-- already in turned it back off, which knocked games that map already-
-- fullscreen straight back into a tile.
local function go_fullscreen(w)
    if w == nil then return end

    log(("fullscreen %s size=%s fs=%s client=%s"):format(
        tostring(w.class), tostring(w.size),
        tostring(w.fullscreen), tostring(w.fullscreen_client)))

    hl.dispatch(hl.dsp.window.fullscreen_state({
        internal = 2, client = 2, action = "set", window = w,
    }))
end

-- Backstop for the window rule above. Harmless if the rule already did the job,
-- because the dispatcher is idempotent -- so this stays in place whether or not
-- `match.workspace` turns out to apply, rather than depending on it.
hl.on("window.open", function(w)
    if w == nil or not streaming() then return end
    if w.workspace == nil or w.workspace.id ~= STREAM_WORKSPACE then return end

    -- Some games map and then request fullscreen themselves a moment later;
    -- acting first would race that. A timer, never a sleep: these callbacks run
    -- on the compositor event loop and blocking one freezes the desktop.
    hl.timer(function() go_fullscreen(w) end, { timeout = 400, type = "oneshot" })
end)

-- Hyprland allows one fullscreen window per workspace, so the game going
-- fullscreen dropped Big Picture back to a tile. When the game exits, nothing
-- restores it -- that is what this is for.
hl.on("window.close", function()
    if not streaming() then return end

    hl.timer(function()
        local windows = hl.get_workspace_windows(STREAM_WORKSPACE) or {}
        if #windows == 0 then return end

        for _, w in ipairs(windows) do
            if w.fullscreen == 2 then return end   -- something already covers it
        end

        -- Lowest focus_history_id is the most recently focused window, which is
        -- what the user was looking at before whatever was on top went away.
        table.sort(windows, function(a, b)
            return (a.focus_history_id or math.huge) < (b.focus_history_id or math.huge)
        end)
        go_fullscreen(windows[1])
    end, { timeout = 400, type = "oneshot" })
end)

-- Focus is deliberately left on the streamed window. Host and stream share one
-- Hyprland seat, so the game only receives input while it holds focus --
-- handing focus back to the desk would send the client's keystrokes to a
-- desktop window.
