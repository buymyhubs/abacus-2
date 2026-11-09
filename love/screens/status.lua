local status = {}
local recording = love.graphics.newImage("screens/assets/abacus2.png")
local standby = love.graphics.newImage("screens/assets/abacus2-alt.png")

function status.draw()
    if GLOBAL.recording then
        love.graphics.draw(recording, 0, 0, 0, GLOBAL.screen_width/recording:getWidth(), GLOBAL.screen_height/recording:getHeight())
    else
        love.graphics.draw(standby, 0, 0, 0, GLOBAL.screen_width/standby:getWidth(), GLOBAL.screen_height/standby:getHeight())
    end
end

return status