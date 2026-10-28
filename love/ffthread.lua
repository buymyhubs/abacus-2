local fftSize = ...
local fft = require("libs.luafft")
local inChannel = love.thread.getChannel("toFFT")

local fftSizeInv = 1 / fftSize
local function postprocess(x)
    return x * fftSizeInv * 0.5
end

while true do
    local toFFT = inChannel:demand()
    while inChannel:getCount() > 0 do
        toFFT = inChannel:pop()
    end

    local res = fft.fft(toFFT, false)
    local fftArray = {}
    for i = 1, fftSize / 2 do
        fftArray[i] = postprocess(res[i]:abs() + res[#res-i+1]:abs())
    end
    love.thread.getChannel("fft"):push(fftArray)
end