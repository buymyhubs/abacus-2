local debug_mode = false
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
  debug_mode = true
end
math.randomseed(os.time())
GLOBAL = {FFT={},sample={},transient={},beat={}}
GLOBAL.FFT.size = 1024
GLOBAL.FFT.result = {}
GLOBAL.amplitude = 100
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
    boxes = require("screens.boxes")
}
local current_screen = screens.status

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
local sure = false
local keys_pressed = {}
function love.update(dt)
    sure = false
    keys_pressed = {}
    if GLOBAL.beat.triggered then
        GLOBAL.beat.triggered = false
    end
    if GLOBAL.transient.triggered then
        GLOBAL.beat.triggered = false
    end
    time_since_beat = time_since_beat + dt
    if time_since_beat >= time_per_beat then
        GLOBAL.beat.triggered = true
        time_since_beat = time_since_beat - time_per_beat
    end
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
    love.graphics.print(tostring("FOR RESEARCH PURPOSES ONLY. DEVICE: "..recording_devices[recording_device_index]:getName()..(GLOBAL.sample.channels == 2 and " STEREO" or " MONO")..(GLOBAL.recording and " REC" or "").." AMPLITUDE: "..GLOBAL.amplitude.." BEAT TRIGGERED: "..bool_to_string(GLOBAL.beat.triggered).." TEMPO: "..GLOBAL.beat.tempo.." FPS: "..love.timer.getFPS()), 0, 0)
end

local keymap = {
    ["shift"] = function ()
        sure = true
    end,
    ["escape"] = function ()
        love.event.quit()
    end,
    ["up"] = function ()
        GLOBAL.amplitude = GLOBAL.amplitude*2
    end,
    ["down"] = function ()
        GLOBAL.amplitude = GLOBAL.amplitude/2
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
        local old_color_A = color_A
        local old_color_B = color_B
        color_A = old_color_B
        color_B = old_color_A
        update_colors()
    end,
    ["i"] = function ()
        color_A = colors.get_invert(color_A)
        color_B = colors.get_invert(color_B)
        update_colors()
    end,
    ["b"] = function ()
        color_A = colors.black
        color_B = colors.white
        update_colors()
    end,
    ["w"] = function ()
        color_A = colors.white
        color_B = colors.black
        update_colors()
    end,
    ["space"] = function ()
        color_A = colors.random_color()
        color_B = colors.get_invert(color_A)
        update_colors()
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
