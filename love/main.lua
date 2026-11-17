math.randomseed(os.time())
local debug_mode = false
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
  debug_mode = true
end
local unpack = table.unpack or unpack
math.randomseed(os.time())
GLOBAL = {FFT={},sample={},transient={},beat={}}
GLOBAL.FFT.size = 1024
GLOBAL.FFT.result = {}
GLOBAL.amplitude = 10
GLOBAL.kick_detection_enabled = true
GLOBAL.kick_color_enabled = false
GLOBAL.kick_screen_enabled = false
GLOBAL.kick_bump_enabled = true
GLOBAL.kick_active = false
GLOBAL.bump = 1
local default_kick_sensitivity = 3
GLOBAL.kick_sensitivity = default_kick_sensitivity
GLOBAL.transient.threshold = 1
GLOBAL.transient.triggered = false
GLOBAL.beat.tempo = 120
GLOBAL.beat.division = 4
GLOBAL.beat.triggered = false
GLOBAL.beat.playing = false
local hop_size = GLOBAL.FFT.size/8
GLOBAL.sample.buffer = {}
GLOBAL.sample.buffer_count = 0
GLOBAL.recording = false

local recording_devices = love.audio.getRecordingDevices()
local recording_device_index = 1
local recording_device_count = #recording_devices
local cap_ctl = love.thread.getChannel("cap_ctl")
local viz = love.thread.getChannel("viz")
local capture_thread = love.thread.newThread("capture.lua")
capture_thread:start(44100, 2)

local function set_recording_device(index)
    if index == nil or index < 1 or index > recording_device_count then return end
    recording_device_index = index
    GLOBAL.recording = false
    cap_ctl:push(index)
end
local window_data = love.sound.newSoundData(GLOBAL.FFT.size, 44100, 16, 1)

local loveFFT = require("lovefft-patch")
loveFFT:init(GLOBAL.FFT.size)

local colors = require("colors")

local screens = {
    status = require("screens.status"),
    bars = require("screens.bars"),
    spec = require("screens.spec"),
    osc = require("screens.osc"),
    boxes = require("screens.boxes"),
    stripes = require("screens.stripes"),
    -- kick = require("screens.kick")
}
local current_screen = screens.status

local screen_keys = {}
for k in pairs(screens) do
    table.insert(screen_keys, k)
end


local canvas
function love.resize()
    canvas = love.graphics.newCanvas(GLOBAL.screen_width, GLOBAL.screen_height)
    GLOBAL.screen_width, GLOBAL.screen_height = love.graphics.getDimensions()
end
love.resize()
print(GLOBAL.screen_width)
local color_shader = love.graphics.newShader [[
        uniform vec4 color_A;
        uniform vec4 color_B;
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
        {
            vec4 texturecolor = Texel(texture, texture_coords);
            float lum = texturecolor.r;
            vec4 mapped = mix(color_B, color_A, lum);
            return mapped * color;
        }
    ]]

local color_A = colors.white
local color_B = colors.black
local function update_colors()
    color_shader:sendColor("color_A", color_A)
    color_shader:sendColor("color_B", color_B)
end
update_colors()

local time_since_beat = 0
local time_per_beat = 0
local function set_tempo(new_tempo)
    GLOBAL.beat.triggered = true
    time_since_beat = 0
    time_per_beat = GLOBAL.beat.tempo/60/GLOBAL.beat.division
end
set_tempo()

local kick_release = 0.500
local active_kick = 0
local prev_loudness_low = 0
local kick_lo, kick_hi = 1, 4
local flux_size = 43
local flux_history = {}
local flux_index = 0
local flux_sum = 0
local min_flux = 0.01

local function kick()
    -- print("kick!")
    GLOBAL.kick_active = true
    active_kick = kick_release

    if GLOBAL.kick_color_enabled then
        color_A = colors.random_color()
        color_B = colors.get_invert(color_A)
        update_colors()
    end

    if GLOBAL.kick_bump_enabled then
        GLOBAL.bump = math.random()
    end
    if GLOBAL.kick_screen_enabled then
        local randomIndex = math.random(1, #screen_keys)
        current_screen = screens[screen_keys[randomIndex]]
    end
end


local function low_energy()
    local sum = 0
    local result = GLOBAL.FFT.result
    for i = kick_lo, kick_hi do
        sum = sum + (result[i] or 0)
    end
    return sum / (kick_hi - kick_lo + 1)
end

local function detect_kick(dt)
    local low = low_energy()
    local flux = math.max(0, low - prev_loudness_low)
    prev_loudness_low = low

    local count = #flux_history
    local mean = count > 0 and flux_sum / count or 0

    if active_kick > 0 then
        active_kick = active_kick - dt
    elseif flux > min_flux and flux > mean * GLOBAL.kick_sensitivity then
        kick()
    end

    flux_index = flux_index % flux_size + 1
    flux_sum = flux_sum - (flux_history[flux_index] or 0) + flux
    flux_history[flux_index] = flux
end


local sure = false
local keys_pressed = {}
function love.update(dt)
    sure = false
    keys_pressed = {}
    -- if GLOBAL.beat.triggered then
    --     GLOBAL.beat.triggered = false
    -- end
    -- if GLOBAL.transient.triggered then
    --     GLOBAL.beat.triggered = false
    -- end
    -- time_since_beat = time_since_beat + dt
    -- if time_since_beat >= time_per_beat then
    --     GLOBAL.beat.triggered = true
    --     time_since_beat = time_since_beat - time_per_beat
    -- end
    local newResult, updated = loveFFT:get()
    if updated then
        GLOBAL.FFT.result = newResult
    end

    local err = capture_thread:getError()
    if err then error(err) end

    local stream_data = viz:pop()
    while stream_data do
        local count = stream_data:getSampleCount()
        local channels = stream_data:getChannelCount()
        GLOBAL.sample.channels = channels

        for i = 0, count - 1 do
            local s = 0
            for c = 1, channels do
                s = s + stream_data:getSample(i, c)
            end
            GLOBAL.sample.buffer_count = GLOBAL.sample.buffer_count + 1
            GLOBAL.sample.buffer[GLOBAL.sample.buffer_count] = s / channels
        end
        stream_data = viz:pop()
    end

    if GLOBAL.sample.buffer_count > GLOBAL.FFT.size then
        local excess = GLOBAL.sample.buffer_count - GLOBAL.FFT.size
        for i = 1, GLOBAL.FFT.size do
            GLOBAL.sample.buffer[i] = GLOBAL.sample.buffer[excess + i]
        end
        GLOBAL.sample.buffer_count = GLOBAL.FFT.size
        if debug_mode then
            print("audio buffer overflow at "..love.timer.getTime()..". discarding "..excess.." samples.")
        end
    end

    while GLOBAL.sample.buffer_count >= GLOBAL.FFT.size do
        for i = 1, GLOBAL.FFT.size do
            window_data:setSample(i - 1, GLOBAL.sample.buffer[i])
        end
        loveFFT:setSoundData(window_data)
        loveFFT:updatePlayTime(0)

        local remaining = GLOBAL.sample.buffer_count - hop_size
        for i = 1, remaining do
            GLOBAL.sample.buffer[i] = GLOBAL.sample.buffer[hop_size + i]
        end
        GLOBAL.sample.buffer_count = remaining
    end

    GLOBAL.kick_active = false
    -- testing out kick detection
    if GLOBAL.kick_detection_enabled then
        detect_kick(dt)
    end

    if love.timer.getTime() % 5 < dt then
        local gc_count = collectgarbage()
        if debug_mode then print("collecting garbage:", gc_count) end
    end
end

local function bool_to_string(bool)
    if bool then
        return "true"
    else
        return "false"
    end
end

function love.draw()
    love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        current_screen.draw()
    love.graphics.setCanvas()
    love.graphics.setShader(color_shader)
    love.graphics.draw(canvas)
    love.graphics.setShader()
    if debug_mode then
        love.graphics.print(tostring("FOR RESEARCH PURPOSES ONLY. DEVICE: "..recording_devices[recording_device_index]:getName()..(GLOBAL.sample.channels == 2 and " STEREO" or " MONO")..(GLOBAL.recording and " REC" or "").." AMPLITUDE: "..GLOBAL.amplitude.." BEAT TRIGGERED: "..bool_to_string(GLOBAL.beat.triggered).." KICK SENSITITVITY: "..GLOBAL.kick_sensitivity.." FPS: "..love.timer.getFPS()), 0, 0)
    end
end

local keymap = {
    ["shift"] = function ()
        sure = true
    end,
    ["escape"] = function ()
        love.event.quit()
    end,
    ["up"] = function ()
        GLOBAL.kick_sensitivity = GLOBAL.kick_sensitivity*2
    end,
    ["down"] = function ()
        GLOBAL.kick_sensitivity = GLOBAL.kick_sensitivity/2
    end,
    ["."] = function ()
        GLOBAL.amplitude = GLOBAL.amplitude*2
    end,
    [","] = function ()
        GLOBAL.amplitude = GLOBAL.amplitude/2
    end,
    ["0"] = function ()
        current_screen = screens.status
    end,
    ["1"] = function ()
        current_screen = screens.osc
    end,
    ["2"] = function ()
        current_screen = screens.spec
    end,
    ["3"] = function ()
        current_screen = screens.bars
    end,
    ["4"] = function ()
        current_screen = screens.boxes
    end,
    ["5"] = function ()
        current_screen = screens.stripes
    end,
    ["m"] = function ()
        cap_ctl:push("mono")
    end,
    ["r"] = function ()
        GLOBAL.recording = not GLOBAL.recording
        cap_ctl:push("rec")
    end,
    ["["] = function ()
        set_recording_device(recording_device_index-1)
    end,
    ["]"] = function ()
        set_recording_device(recording_device_index+1)
    end,
    ["s"] = function ()
        GLOBAL.kick_screen_enabled = not GLOBAL.kick_screen_enabled
    end,
    ["c"] = function ()
        GLOBAL.kick_color_enabled = not GLOBAL.kick_color_enabled
    end,
    ["b"] = function ()
        GLOBAL.kick_bump_enabled = not GLOBAL.kick_bump_enabled
    end,
    ["a"] = function ()
        GLOBAL.kick_bump_enabled = true
        GLOBAL.kick_color_enabled = true
        GLOBAL.kick_screen_enabled = true
    end,
    ["o"] = function ()
        GLOBAL.kick_bump_enabled = false
        GLOBAL.kick_color_enabled = false
        GLOBAL.kick_screen_enabled = false
    end,       
    ["i"] = function ()
        color_A = colors.get_invert(color_A)
        color_B = colors.get_invert(color_B)
        update_colors()
    end,
    ["w"] = function ()
        color_A = colors.white
        color_B = colors.black
        update_colors()
    end,
    ["k"] = function ()
        GLOBAL.kick_detection_enabled = not GLOBAL.kick_detection_enabled
    end,
    ["space"] = function ()
        kick()
    end,
    ["/"] = function ()
        GLOBAL.kick_sensitivity = default_kick_sensitivity
    end
}

function love.keypressed( key, scancode, isrepeat )
    if keymap[key] == nil then
        return
    end
    keymap[key]()
end

function love.quit()
    cap_ctl:push("quit")
    capture_thread:wait()
end
