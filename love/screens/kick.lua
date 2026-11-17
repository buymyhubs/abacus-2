local kick = {}
local unpack = table.unpack or unpack

function kick.draw()
    local lowbands = {unpack(GLOBAL.FFT.result, 1, GLOBAL.FFT.size/5)}
    local loudest_low = 0
    if lowbands and #lowbands > 0 then
    for i = 1, #lowbands do
            if lowbands[i] > loudest_low then
                loudest_low = lowbands[i]
            end
        end
    end
    local bar_height = loudest_low*GLOBAL.screen_height
    local kick_sensitivity_y = GLOBAL.screen_height-(GLOBAL.kick_sensitivity*GLOBAL.screen_height)
    love.graphics.rectangle("fill", 0, GLOBAL.screen_height-bar_height, GLOBAL.screen_width, bar_height)
    love.graphics.line(0, kick_sensitivity_y, GLOBAL.screen_width, kick_sensitivity_y)
    love.graphics.print(loudest_low, GLOBAL.screen_width/2, GLOBAL.screen_height/2,0,4)
end

return kick