if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end

GLOBAL = {FFT = {}}
GLOBAL.FFT.size = 512
GLOBAL.FFT.result = {}
GLOBAL.amplitude = 200
local hopSize = GLOBAL.FFT.size / 4
local sample_buffer = {}
local sample_buffer_count = 0

local devices = love.audio.getRecordingDevices()
local recording_device = devices[1]
local success = recording_device:start(GLOBAL.FFT.size)

local loveFFT = require("lovefft")
loveFFT:init(GLOBAL.FFT.size)

local screens = {
    bars = require("screens.bars"),
    spec = require("screens.spec")
}
local current_screen = screens.bars

function love.resize()
    GLOBAL.screen_width, GLOBAL.screen_height = love.graphics.getDimensions()
end
love.resize()

function love.update(dt)
    local newResult, updated = loveFFT:get()
    if updated then
        GLOBAL.FFT.result = newResult
    end

    local streamData = recording_device:getData()
    if streamData == nil then return end

    local count = streamData:getSampleCount()
    local channels = streamData:getChannelCount()

    for i = 0, count - 1 do
        local s = 0
        for c = 1, channels do
            s = s + streamData:getSample(i, c)
        end
        sample_buffer_count = sample_buffer_count + 1
        sample_buffer[sample_buffer_count] = s
    end

    if sample_buffer_count >= GLOBAL.FFT.size then
        local windowData = love.sound.newSoundData(GLOBAL.FFT.size, streamData:getSampleRate(), streamData:getBitDepth(), 1)
        for i = 1, GLOBAL.FFT.size do
            windowData:setSample(i - 1, sample_buffer[i])
        end
        loveFFT:setSoundData(windowData)
        loveFFT:updatePlayTime(0)

        local remaining = sample_buffer_count - hopSize
        for i = 1, remaining do
            sample_buffer[i] = sample_buffer[hopSize + i]
        end
        sample_buffer_count = remaining
    end
end

function love.draw()
    current_screen.draw()
    love.graphics.print(tostring("FOR RESEARCH PURPOSES ONLY: "..recording_device:getName().." "..love.timer.getFPS()), 0, 0)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    if key == "left" then
        current_screen = screens.bars
    end
    if key == "right" then
        current_screen = screens.spec
    end
end