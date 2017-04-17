local skynet = require "skynet"
local protobuf = require "protobuf"

skynet.start(function()
    skynet.error("Server start")
    protobuf.register_file(skynet.getenv("protobuf"))
    --登录校验服务
    skynet.uniqueservice("logind")
    --共享数据服务
    skynet.newservice("static_data")
    --debug服务
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