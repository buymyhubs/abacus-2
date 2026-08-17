local osc = {}

function osc.draw()
    love.graphics.setLineWidth(30)
    love.graphics.push()
    love.graphics.translate(0, GLOBAL.screen_height / 2)

    local points = {}
    local display_samples = math.min(GLOBAL.sample.buffer_count, GLOBAL.FFT.size)
    local sample_pixels = GLOBAL.screen_width / display_samples

    for i = 1, display_samples do
        local x = (i - 1) * sample_pixels
        local y = -(GLOBAL.sample.buffer[i] or 0) * (GLOBAL.screen_height / 2) * GLOBAL.amplitude/100
        table.insert(points, x)
        table.insert(points, y)
    end

    if #points >= 4 then
        love.graphics.line(points)
    end

    love.graphics.pop()
end

return osc