local rate, channels = ...
require("love.audio"); require("love.sound"); require("love.timer"); require("love.data")
local ffi = require("ffi")

local ctl = love.thread.getChannel("cap_ctl")
local viz = love.thread.getChannel("viz")
local devices = love.audio.getRecordingDevices()
local dev, file, bytes
local mono = false
local file_n = 0

local function u32(n) return love.data.pack("string", "<I4", n) end

local function open_device(i)
    if dev then dev:stop() end
    dev = devices[i]
    if not dev:start(rate, rate, 16, channels) then dev:start(rate, rate, 16, 1) end
end

local function downmix(d)
    local n = d:getSampleCount()
    local out = love.sound.newSoundData(n, rate, 16, 1)
    local src = ffi.cast("int16_t*", d:getFFIPointer())
    local dst = ffi.cast("int16_t*", out:getFFIPointer())
    for i = 0, n - 1 do
        dst[i] = math.floor((src[2 * i] + src[2 * i + 1]) / 2)
    end
    d:release()
    return out
end

local function start_recording()
    local ch = mono and 1 or dev:getChannelCount()
    file_n = file_n + 1
    file = assert(io.open(os.date("lovis-%Y%m%d-%H%M%S-") .. file_n .. ".wav", "wb"))
    file:write("RIFF", u32(0), "WAVE", "fmt ", u32(16),
        love.data.pack("string", "<I2I2I4I4I2I2", 1, ch, rate, rate * ch * 2, ch * 2, 16),
        "data", u32(0))
    bytes = 0
end

local function stop_recording()
    if not file then return end
    file:seek("set", 4);  file:write(u32(36 + bytes))
    file:seek("set", 40); file:write(u32(bytes))
    file:close()
    file = nil
end

open_device(1)
while true do
    local msg = ctl:pop()
    if msg == "quit" then break
    elseif msg == "rec" then if file then stop_recording() else start_recording() end
    elseif msg == "mono" then
        mono = not mono
        if file then stop_recording(); start_recording() end -- channel count changed: new file
    elseif type(msg) == "number" then stop_recording(); open_device(msg)
    end

    local d = dev:getData()
    if d then
        if mono and d:getChannelCount() == 2 then d = downmix(d) end
        if file then
            local s = d:getString()
            file:write(s)
            bytes = bytes + #s
        end
        viz:push(d)
    else
        love.timer.sleep(0.01)
    end
end
stop_recording()
dev:stop()