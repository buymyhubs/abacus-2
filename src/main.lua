if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end

local fftSize = 512
local hopSize = fftSize / 4
local fftArray = {}
local sampleBuffer = {}
local sampleBufferCount = 0

local devices = love.audio.getRecordingDevices()
local recordingDevice = devices[1]
local success = recordingDevice:start(fftSize)

local loveFFT = require("lovefft")
loveFFT:init(fftSize)

local amplitude = 50

function love.resize()
    W, H = love.graphics.getDimensions()
end
love.resize()

function love.update(dt)
    local newArray, updated = loveFFT:get()
    if updated then
        fftArray = newArray
    end

    local streamData = recordingDevice:getData()
    if streamData == nil then return end

    local count = streamData:getSampleCount()
    local channels = streamData:getChannelCount()

    for i = 0, count - 1 do
        local s = 0
        for c = 1, channels do
            s = s + streamData:getSample(i, c)
        end
        sampleBufferCount = sampleBufferCount + 1
        sampleBuffer[sampleBufferCount] = s
    end

    if sampleBufferCount >= fftSize then
        local windowData = love.sound.newSoundData(fftSize, streamData:getSampleRate(), streamData:getBitDepth(), 1)
        for i = 1, fftSize do
            windowData:setSample(i - 1, sampleBuffer[i])
        end
        loveFFT:setSoundData(windowData)
        loveFFT:updatePlayTime(0)

        local remaining = sampleBufferCount - hopSize
        for i = 1, remaining do
            sampleBuffer[i] = sampleBuffer[hopSize + i]
        end
        sampleBufferCount = remaining
    end
end

function love.draw()
    local barWidth = W / fftSize * 8
    for i = 1, fftSize/8 do
        local barHeight = (fftArray[i] or 0) * H * amplitude
        love.graphics.rectangle("fill", (i - 1) * barWidth, H - barHeight, barWidth, barHeight)
    end
    love.graphics.print(tostring("FOR RESEARCH PURPOSES ONLY: "..recordingDevice:getName().." "..love.timer.getFPS()), 0, 0)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end