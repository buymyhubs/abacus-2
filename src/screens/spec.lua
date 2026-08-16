local scope = {}

function scope.draw()
    love.graphics.setLineWidth(3)
    local points = {}
    love.graphics.push()
    love.graphics.scale(2,2)
    for i = 1, GLOBAL.FFT.size do
        local y = (GLOBAL.FFT.result[i] or 0) * GLOBAL.screen_height * GLOBAL.amplitude
        table.insert(points, i*(GLOBAL.screen_width/GLOBAL.FFT.size))
        table.insert(points, y)
    end
    love.graphics.line(points)
    love.graphics.pop()
end

return scope