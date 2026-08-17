local bars = {}

function bars.draw()
    local bar_width = GLOBAL.screen_width / GLOBAL.FFT.size * 8
    for i = 1, GLOBAL.FFT.size/8 do
        local bar_height = (GLOBAL.FFT.result[i] or 0) * GLOBAL.screen_height * GLOBAL.amplitude
        love.graphics.rectangle("fill", (i - 1) * bar_width, GLOBAL.screen_height - bar_height, bar_width, bar_height)
    end
end

return bars