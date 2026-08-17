if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end

GLOBAL = {FFT={},sample={},transient={},beat={}}
GLOBAL.FFT.size = 256
GLOBAL.FFT.result = {}
GLOBAL.amplitude = 100
GLOBAL.transient.threshold = 1
GLOBAL.transient.triggered = false
GLOBAL.beat.tempo = 120
GLOBAL.beat.division = 4
GLOBAL.beat.triggered = false
GLOBAL.beat.playing = false
local hop_size = GLOBAL.FFT.size
GLOBAL.sample.buffer = {}
GLOBAL.sample.buffer_count = 0

local recording_devices = love.audio.getRecordingDevices()
local recording_device_index = 1
local recording_device_count = #recording_devices
local recording_device = recording_devices[recording_device_index]
local function set_recording_device(index)
    if index == nil or index < 1 or index > recording_device_count then return end
    recording_device_index = index
    recording_device:stop()
    recording_device = recording_devices[recording_device_index]
    local success = recording_device:start(GLOBAL.FFT.size)
end
set_recording_device(recording_device_index)
local window_data = love.sound.newSoundData(GLOBAL.FFT.size, 44100, 16, 1)

local loveFFT = require("lovefft")
loveFFT:init(GLOBAL.FFT.size)

local screens = {
    bars = require("screens.bars"),
    spec = require("screens.spec"),
    osc = require("screens.osc")
}
local current_screen = screens.bars

local canvas
function love.resize()
    canvas = love.graphics.newCanvas(GLOBAL.screen_width, GLOBAL.screen_height)
    GLOBAL.screen_width, GLOBAL.screen_height = love.graphics.getDimensions()
end
love.resize()
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
color_shader:sendColor("color_A", {1, 0.5, 1, 1})
color_shader:sendColor("color_B", {0, 0, 1, 1})
local time_since_beat = 0
local time_per_beat = 0
local function set_tempo(new_tempo)
    GLOBAL.beat.triggered = true
    time_since_beat = 0
    time_per_beat = GLOBAL.beat.tempo/60/GLOBAL.beat.division
end
set_tempo()
function love.update(dt)
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

    local stream_data = recording_device:getData()
    if stream_data == nil then return end

    local count = stream_data:getSampleCount()
    local channels = stream_data:getChannelCount()

    for i = 0, count - 1 do
        local s = 0
        for c = 1, channels do
            s = s + stream_data:getSample(i, c)
        end
        GLOBAL.sample.buffer_count = GLOBAL.sample.buffer_count + 1
        GLOBAL.sample.buffer[GLOBAL.sample.buffer_count] = s
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
    love.graphics.print(tostring("FOR RESEARCH PURPOSES ONLY. DEVICE: "..recording_device:getName().." AMPLITUDE: "..GLOBAL.amplitude.." BEAT TRIGGERED: "..bool_to_string(GLOBAL.beat.triggered).." TEMPO: "..GLOBAL.beat.tempo.." FPS: "..love.timer.getFPS()), 0, 0)
end

function love.keypressed(key)
    local shift_held = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    local tempo_held = love.keyboard.isDown("t") 
    if key == "escape" then
        love.event.quit()
    end

    if key == "up" then
        if shift_held then
            GLOBAL.transient.threshold = GLOBAL.transient.threshold+0.1
        elseif tempo_held then
            GLOBAL.beat.tempo = GLOBAL.beat.tempo+5
        else
            GLOBAL.amplitude = GLOBAL.amplitude*2
        end
    end
    if key == "down" then
        if shift_held then
            GLOBAL.transient.threshold = GLOBAL.transient.threshold-0.1
        elseif tempo_held then
            GLOBAL.beat.tempo = GLOBAL.beat.tempo-5
        else
            GLOBAL.amplitude = GLOBAL.amplitude/2
        end
    end
    if key == "left" then
        current_screen = screens.osc
    end
    if key == "right" then
        current_screen = screens.spec
    end

    if key == "space" then
        GLOBAL.beat.playing = not GLOBAL.beat.playing
    end

    if key == "[" then
        set_recording_device(recording_device_index-1)
    end
    if key == "]" then
        set_recording_device(recording_device_index+1)
    end
end

function love.keyreleased(key)
    local tempo_released = key == "t"
    if tempo_released then 
        set_tempo()
    end
end