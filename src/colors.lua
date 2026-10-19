---@alias value number

local colors = {
    red = {1, 0, 0, 1},
    green = {0, 1, 0, 1},
    blue = {0, 0, 1, 1},
    cyan = {0, 1,1,1},
    yellow = {1,1,0,1},
    purple = {1,0,1,1}
}

local color_keys = {}
for key in pairs(colors) do
    table.insert(color_keys, key)
end

colors.black = {0, 0, 0, 1}
colors.white = {1, 1, 1, 1}

function colors.random_color_preset()
    local key = color_keys[math.random(#color_keys)]
    return colors[key]
end

function colors.random_color()
    return {math.random(), math.random(), math.random(), 1}
end

function colors.get_invert(color)
    return {1-color[1], 1-color[2], 1-color[3], 1}
end


return colors