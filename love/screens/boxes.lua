local boxes = {}

local box_count = 8

function boxes.draw()
    local box_width = GLOBAL.screen_width / box_count
    for i = 1, box_count do
        local level = 0
        for j = GLOBAL.FFT.size/(box_count*4)*i-GLOBAL.FFT.size/(box_count*4)+1, GLOBAL.FFT.size/(box_count*4)*i do
            if GLOBAL.FFT.result[j] == nil then
                print("nil")
            end
            level = level + GLOBAL.FFT.result[j]*j
        end
        level = level*GLOBAL.amplitude/100
        love.graphics.setColor(level,level,level)
        love.graphics.rectangle("fill", (i - 1) * box_width, 0, box_width, GLOBAL.screen_height)
        love.graphics.setColor(1,1,1,1)
        -- print(i.." "..level)
    end
end

return boxes