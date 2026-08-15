local scope = {}

function scope.draw()
    for i = 1, GLOBAL.FFT.size do
        local y = (GLOBAL.FFT.result[i] or 0) * GLOBAL.screen_height * GLOBAL.amplitude
        love.graphics.points(i*(GLOBAL.screen_width/GLOBAL.FFT.size)*2, y)
    end
end

return scope