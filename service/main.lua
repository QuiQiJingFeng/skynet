local skynet = require "skynet"
local sprotoloader = require "sprotoloader"

skynet.start(function()
    skynet.error("Server start")
    
    skynet.newservice("debug_console",8000)
    local game_port = skynet.getenv("game_port")
    local max_client = skynet.getenv("max_client")
    --FYD:
    --监控服务，监控8888端口，最大连接数8192
    local watchdog = skynet.newservice("watchdog")
    skynet.call(watchdog, "lua", "start", {
        port = game_port,
        maxclient = max_client,
        nodelay = true,
    })
    skynet.error("Watchdog listen on", game_port)
    skynet.exit()
end)