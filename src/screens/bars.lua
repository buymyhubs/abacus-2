local bars = {}

function bars.draw()
    local barWidth = GLOBAL.screen_width / GLOBAL.FFT.size * 8
    for i = 1, GLOBAL.FFT.size/8 do
        local barHeight = (GLOBAL.FFT.result[i] or 0) * GLOBAL.screen_height * GLOBAL.amplitude
        love.graphics.rectangle("fill", (i - 1) * barWidth, GLOBAL.screen_height - barHeight, barWidth, barHeight)
    end
end

return bars