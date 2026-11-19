local bars = {}

function bars.draw()
    local bandwidth = 8
    local bar_width = GLOBAL.screen_width / GLOBAL.FFT.size * bandwidth
    for i = 1, GLOBAL.FFT.size/bandwidth do
        local bar_height = (GLOBAL.FFT.result[i] or 0) * GLOBAL.screen_height * GLOBAL.amplitude *i
        love.graphics.rectangle("fill", (i - 1) * bar_width, (GLOBAL.screen_height - bar_height)/2, bar_width, bar_height)
    end
end

return bars