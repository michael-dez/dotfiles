-- bcpc -- everything that exists only while Moonlight is connected: game/desktop session modes,
-- stream workspace rules, crop mitigation. set_mode() is called by hooks/stream-mode.sh via `hyprctl eval`.
-- Why each rule: docs/streaming.md#hyprstreamlua
local SUNSHINE_OUTPUT  = "sunshine"
local STREAM_WORKSPACE = 11

local function log(msg)
    print("[stream.lua] " .. msg)
end

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

function M.streaming()
    return hl.get_monitor(SUNSHINE_OUTPUT) ~= nil
end

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

local ws_game = hl.workspace_rule({
    workspace   = tostring(STREAM_WORKSPACE),
    monitor     = SUNSHINE_OUTPUT,
    gaps_in     = 0,
    gaps_out    = 0,
    no_border   = true,
    no_rounding = true,
    decorate    = false,
})

local ws_desktop = hl.workspace_rule({
    workspace = tostring(STREAM_WORKSPACE),
    monitor   = SUNSHINE_OUTPUT,
})

local game_rule = hl.window_rule({
    name  = "stream-game",
    match = { workspace = STREAM_WORKSPACE },

    fullscreen_state = "2 2",
    sync_fullscreen  = true,
    suppress_event   = "fullscreenoutput x11configurerequest",
    confine_pointer  = true,
})

local capture = hl.window_rule({
    name      = "stream-capture",
    match     = { class = "^steam$" },
    workspace = tostring(STREAM_WORKSPACE) .. " silent",
})

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

local function go_fullscreen(w)
    if w == nil then return end

    log(("fullscreen %s size=%s fs=%s client=%s"):format(
        tostring(w.class), tostring(w.size),
        tostring(w.fullscreen), tostring(w.fullscreen_client)))

    hl.dispatch(hl.dsp.window.fullscreen_state({
        internal = 2, client = 2, action = "set", window = w,
    }))
end

hl.on("window.open", function(w)
    if w == nil or M.mode ~= "game" or not M.streaming() then return end
    if w.workspace == nil or w.workspace.id ~= STREAM_WORKSPACE then return end

    hl.timer(function() go_fullscreen(w) end, { timeout = 400, type = "oneshot" })
end)

hl.on("window.close", function()
    if M.mode ~= "game" or not M.streaming() then return end

    hl.timer(function()
        local windows = hl.get_workspace_windows(STREAM_WORKSPACE) or {}
        if #windows == 0 then return end

        for _, w in ipairs(windows) do
            if w.fullscreen == 2 then return end   -- something already covers it
        end

        table.sort(windows, function(a, b)
            return (a.focus_history_id or math.huge) < (b.focus_history_id or math.huge)
        end)
        go_fullscreen(windows[1])
    end, { timeout = 400, type = "oneshot" })
end)

M.set_mode(read_line(SESSION_FILE) or "game")

return M
