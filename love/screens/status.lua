local status = {}
local recording = love.graphics.newImage("screens/assets/abacus2.png")
local standby = love.graphics.newImage("screens/assets/abacus2-alt.png")

function status.draw()
    local scale_factor = 1000
    local energy = GLOBAL.sample.low_energy * GLOBAL.amplitude / scale_factor
    local img = GLOBAL.recording and recording or standby

    local sx = GLOBAL.screen_width / img:getWidth()
    local sy = GLOBAL.screen_height / img:getHeight() + GLOBAL.screen_height * energy

    love.graphics.draw(img, 0, GLOBAL.screen_height, 0, sx, sy, 0, img:getHeight())
end

return status