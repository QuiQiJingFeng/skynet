local skynet = require "skynet"

skynet.start(function()
    -- --共享数据服务
    skynet.newservice("static_data")
    -- --登录校验服务
    skynet.uniqueservice("logind")
    -- --mysqllog服务
    skynet.newservice("mysqllog")
    -- --好友服务
    -- skynet.newservice("social")
    -- --控制台服务
    -- skynet.newservice("debug_console",8000)
    
    -- local game_port = skynet.getenv("game_port")
    -- local max_client = skynet.getenv("max_client")
    
    -- --监控服务，监控8888端口，最大连接数8192
    -- local watchdog = skynet.newservice("watchdog")
    -- skynet.call(watchdog, "lua", "start", {
    --     port = game_port,
    --     maxclient = max_client,
    --     nodelay = true,
    -- })
    skynet.newservice("reptile_manager")
    skynet.error("Watchdog listen on", game_port)
    skynet.exit()
end)