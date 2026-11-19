local squiggle = {}
local points = {}

function squiggle.draw()
    -- love.graphics.print("squiggle")
    local line_width = 100*GLOBAL.sample.low_energy*GLOBAL.amplitude

    if GLOBAL.bump_triggered then
        points = {}
        for i = 1, math.random(GLOBAL.bump*30)*2+10 do
            if i % 2 ~= 0 then
                points[i] = math.random(GLOBAL.screen_width)
            else
                points[i] = math.random(GLOBAL.screen_height)
            end
        end
    end
    love.graphics.setLineWidth(line_width)
    if #points >= 1 then
        love.graphics.line(points)
    end
end

return squiggle