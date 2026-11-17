local spec = {}

function spec.draw()
    love.graphics.setLineWidth(3)
    local points = {}
    for i = 1, GLOBAL.FFT.size do
        local y = (GLOBAL.FFT.result[i] or 0) * GLOBAL.screen_height * GLOBAL.amplitude/2 * i
        table.insert(points, i*(GLOBAL.screen_width/GLOBAL.FFT.size))
        table.insert(points, y)
    end
    love.graphics.push()
    love.graphics.scale(2,2)
    love.graphics.translate(-GLOBAL.screen_width/4,-GLOBAL.screen_height/4)
    love.graphics.push()
    love.graphics.translate(GLOBAL.screen_width/2,GLOBAL.screen_height/2)
    love.graphics.scale(1,-1)    
    love.graphics.line(points)
    love.graphics.pop()
    love.graphics.push()
    love.graphics.translate(GLOBAL.screen_width/2,GLOBAL.screen_height/2)
    love.graphics.line(points)
    love.graphics.pop()
    love.graphics.push()
    love.graphics.translate(GLOBAL.screen_width/2,GLOBAL.screen_height/2)
    love.graphics.scale(-1,-1)    
    love.graphics.line(points)
    love.graphics.pop()
    love.graphics.push()
    love.graphics.translate(GLOBAL.screen_width/2,GLOBAL.screen_height/2)
    love.graphics.scale(-1,1)    
    love.graphics.line(points)
    love.graphics.pop()
    love.graphics.pop()
end

return spec