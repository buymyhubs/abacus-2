local loveFFT = require("lovefft")
function loveFFT:get()
    local latest
    while self.channelFFT:getCount() > 0 do latest = self.channelFFT:pop() end
    if latest then self.fftArray = latest end
    return self.fftArray, latest ~= nil
end

return loveFFT