local skynet = require "skynet"
--由于 Lua 的math.random函数是直接使用 libc 的随机函数接口，内部的算法基本上就是线性同余，
--这样的随机数生成的特点是性能比较高，但是随机序列的分布不会很均匀。
--在游戏里面的表现很可能就是一个人脸很黑，一直抽不到，或是一直都能抽到很好的卡。
skynet.start(function()
    skynet.error("Server start")

    --共享数据服务
    skynet.newservice("static_data")
    --登录校验服务
    skynet.uniqueservice("logind")
    --mysqllog服务
    skynet.newservice("mysqllog")

    skynet.newservice("social")

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