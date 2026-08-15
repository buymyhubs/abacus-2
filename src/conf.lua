function love.conf(t)
    t.audio.mic = true
    t.console = false
    t.window.width = 1280
    t.window.height = 720
    t.window.fullscreen = true
    t.window.title = "FOR RESEARCH PURPOSES ONLY"
    t.window.fullscreentype = "exclusive"
    t.window.msaa = 0
end
love.graphics.setDefaultFilter("nearest", "nearest")