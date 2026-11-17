local stripes = {}

function stripes.draw()
    local line_width = 10*GLOBAL.bump+10

    love.graphics.setLineWidth(line_width)
    local points = {}
    local display_samples = math.min(GLOBAL.sample.buffer_count, GLOBAL.FFT.size)
    local sample_pixels = GLOBAL.screen_width / display_samples

    for i = 1, display_samples do
        local x = (i - 1) * sample_pixels
        local y = -(GLOBAL.sample.buffer[i] or 0) * (GLOBAL.screen_height / 2) * GLOBAL.amplitude/100
        table.insert(points, x)
        table.insert(points, y)
    end

    love.graphics.push()
    love.graphics.translate(GLOBAL.screen_width/2, GLOBAL.screen_height/2)
    love.graphics.rotate(GLOBAL.bump*4-3)
    love.graphics.scale(2)
    love.graphics.translate(-GLOBAL.screen_width/2, -GLOBAL.screen_height/2)
    love.graphics.translate( 0, -line_width*2 )
    if #points >= 1 then
        for i = 1, GLOBAL.screen_height/line_width/2 do
            love.graphics.line(points)
            love.graphics.translate( 0, line_width*2 )
        end
    end
    love.graphics.pop()
end

return stripes