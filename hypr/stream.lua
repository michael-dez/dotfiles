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
-- event handlers are a backstop. See the comment on the window.open handler.
--
-- --- two session modes ----------------------------------------------------
--
-- One stream config cannot serve both clients this host streams to:
--
--   game     the Steam Deck. Workspace 11 is a dedicated game display: every
--            window on it is forced fullscreen, the pointer is confined to it,
--            and stray Steam windows are pulled onto it.
--   desktop  BCLT, using Moonlight's "Desktop" app instead of RDP. Same
--            virtual output, but an ordinary workspace -- tiling, borders, a
--            pointer that can reach every window. The game rules are not a
--            harmless extra here: they would fullscreen every terminal you
--            open and trap the cursor in it, which is the opposite of a
--            remote desktop.
--
-- The hooks choose the mode from SUNSHINE_APP_NAME and call set_mode() through
-- `hyprctl eval`, which shares this Lua state. See sunshine/hooks/stream-mode.sh.

local SUNSHINE_OUTPUT  = "sunshine"
local STREAM_WORKSPACE = 11

-- print() lands in Hyprland's own log, readable with `hyprctl rollinglog`, so
-- this side of the stream needs no equivalent of the shell hooks' log file.
local function log(msg)
    print("[stream.lua] " .. msg)
end

-- --- per-stream state written by the hooks --------------------------------
-- Both files live in XDG_RUNTIME_DIR and are removed by stream-end.sh, so
-- "no file" means "no stream" and a reboot cannot leave a stale one behind.
--
-- They exist for exactly one situation: `hyprctl reload` (MOD5+SHIFT+c, or any
-- tool that triggers one) re-runs this file from scratch mid-stream. Without
-- somewhere to read the live stream's state from, that reload would re-apply
-- whatever is hardcoded here -- which is how a 1080p stream to a docked Deck
-- used to get snapped back to 1280x800.
local RUNTIME      = os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000"
local MODE_FILE    = RUNTIME .. "/sunshine-video-mode"     -- e.g. 1920x1080@60
local SESSION_FILE = RUNTIME .. "/sunshine-session-mode"   -- "game" | "desktop"

local function read_line(path)
    local f = io.open(path, "r")
    if f == nil then return nil end
    local line = f:read("*l")
    f:close()
    if line == nil or line == "" then return nil end
    return line
end

local M = { mode = "game" }

-- The headless output's existence *is* the stream. Derived rather than tracked
-- so there is no flag to get out of sync with reality -- stream-start.sh
-- creates the output, stream-end.sh removes it, and nothing else makes one.
function M.streaming()
    return hl.get_monitor(SUNSHINE_OUTPUT) ~= nil
end

-- --- the virtual output ---------------------------------------------------
-- The mode is the CLIENT's, never this host's idea of one. stream-start.sh
-- sizes the output from SUNSHINE_CLIENT_WIDTH/HEIGHT/FPS on connect and writes
-- the result to MODE_FILE; this line only has to survive a reload without
-- undoing that. A Deck docked to a television asks for the television's mode,
-- and nothing here may second-guess it.
--
-- The fallbacks, in order, and never a hardcoded resolution -- a hardcoded one
-- here is exactly the bug this rule used to be:
--
--   1. the mode file, which is the client's negotiated mode;
--   2. the mode the output is ALREADY running at, if it exists. A reload that
--      finds a live stream but no mode file -- a stream that predates this
--      file, or one whose state was lost -- must not resize what someone is
--      watching, and "preferred" would do exactly that. Observed rather than
--      theorised: writing this file auto-reloaded Hyprland mid-stream and took
--      a 1280x720 session to 1920x1080 with no hook involved;
--   3. "preferred", which is only reached when there is no stream at all and
--      so no client to have an opinion.
--
-- The rule still has to name this output, whichever branch wins -- without it
-- the catch-all in hyprland.lua would reclaim the output on reload.
local function live_mode()
    local m = hl.get_monitor(SUNSHINE_OUTPUT)
    if m == nil or m.width == nil or m.height == nil then return nil end
    return ("%dx%d@%g"):format(m.width, m.height, m.refresh_rate or 60)
end

local video_mode = read_line(MODE_FILE) or live_mode() or "preferred"
hl.monitor({
    output   = SUNSHINE_OUTPUT,
    mode     = video_mode,
    position = "auto",
    scale    = 1,
})

-- --- the reserved workspace -----------------------------------------------
-- Two rules for the same workspace, of which exactly one is ever enabled --
-- set_mode() below owns that. Written as a pair rather than as one rule that
-- gets edited because a workspace rule's props cannot be changed after it is
-- created; `enabled` is the only thing that can be toggled at runtime
-- (`hyprctl workspacerules` prints it, which is how this was verified).
--
-- Game: the stream should look like a dedicated game display, not a tiled
-- desktop with chrome around the edges. Note the polarity flip from hyprlang:
-- what was `border:false, rounding:false` is `no_border`/`no_rounding` here.
local ws_game = hl.workspace_rule({
    workspace   = tostring(STREAM_WORKSPACE),
    monitor     = SUNSHINE_OUTPUT,
    gaps_in     = 0,
    gaps_out    = 0,
    no_border   = true,
    no_rounding = true,
    decorate    = false,
})

-- Desktop: the same binding to the virtual output, and nothing else. Gaps and
-- borders are how you tell which window has focus, and a remote desktop needs
-- that at least as much as the desk does.
local ws_desktop = hl.workspace_rule({
    workspace = tostring(STREAM_WORKSPACE),
    monitor   = SUNSHINE_OUTPUT,
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
--
-- Game mode only. In a desktop session every one of these is wrong: a confined
-- pointer cannot reach a second window, and forced fullscreen turns every
-- terminal into the whole screen.
local game_rule = hl.window_rule({
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
-- Enabled only while a client is connected, and only in game mode. Left on
-- permanently it would yank Steam off the desk during local play, which is the
-- whole reason the Python version only ran for the life of a stream; left on
-- in desktop mode it would yank Steam onto the stream from the desk, which is
-- just as unwanted when the stream is a remote desktop.
local capture = hl.window_rule({
    name      = "stream-capture",
    match     = { class = "^steam$" },
    workspace = tostring(STREAM_WORKSPACE) .. " silent",
})

-- --- mode switching -------------------------------------------------------
-- Called from the hooks via `hyprctl eval package.loaded.stream.set_mode(...)`.
-- That reach works because eval runs in the same Lua state the config was
-- loaded into, so require()'s cache is the shared surface between the shell
-- hooks and this file -- no socket, no daemon, no global to collide with
-- another fragment's names.
--
-- Anything other than "desktop" means game, deliberately: an unset or
-- misspelled SUNSHINE_APP_NAME then lands on the behaviour this host has
-- always had rather than on a half-configured desktop.
function M.set_mode(requested)
    local mode = (requested == "desktop") and "desktop" or "game"
    M.mode = mode

    local game = (mode == "game")
    ws_game:set_enabled(game)
    ws_desktop:set_enabled(not game)
    game_rule:set_enabled(game)
    capture:set_enabled(game and M.streaming())

    log("mode -> " .. mode .. " (streaming: " .. tostring(M.streaming()) .. ")")
end

-- --- bringing a workspace to the stream -----------------------------------
-- The one thing a desktop stream cannot do without help. Focusing a workspace
-- that lives on another monitor moves FOCUS to that monitor -- Hyprland has no
-- other reading of it -- so from the client, MOD5+2 sends your keystrokes to a
-- window on the desk that you cannot see. This moves the workspace to the
-- virtual output first, so it arrives where it can be watched.
--
-- Bound to MOD5+CTRL+<number> in keybinds.lua. Off-stream it degrades to a
-- plain focus, which is what those keys would otherwise have done.
function M.pull_workspace(id)
    if not M.streaming() then
        hl.dispatch(hl.dsp.focus({ workspace = id }))
        return
    end

    log("pulling workspace " .. tostring(id) .. " onto " .. SUNSHINE_OUTPUT)
    hl.dispatch(hl.dsp.workspace.move({ workspace = id, monitor = SUNSHINE_OUTPUT }))
    hl.dispatch(hl.dsp.focus({ workspace = id }))
end

hl.on("monitor.added", function(m)
    if m ~= nil and m.name == SUNSHINE_OUTPUT then
        capture:set_enabled(M.mode == "game")
        log("stream up in " .. M.mode .. " mode")
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
--
-- Gated on game mode for the same reason the rule is. A desktop session that
-- fullscreened every window it opened would be unusable, and the gate has to be
-- here as well as on the rule: this handler does not consult the rule at all.
hl.on("window.open", function(w)
    if w == nil or M.mode ~= "game" or not M.streaming() then return end
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
    if M.mode ~= "game" or not M.streaming() then return end

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

-- Last, not first: set_mode() reads M.streaming() and touches every rule above,
-- so all of them have to exist by now. SESSION_FILE is what makes a reload
-- mid-stream keep the mode the running stream asked for instead of reverting to
-- game -- the same argument as MODE_FILE, one layer up.
M.set_mode(read_line(SESSION_FILE) or "game")

return M
