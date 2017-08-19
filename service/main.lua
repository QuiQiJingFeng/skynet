local skynet = require "skynet"

skynet.start(function()
    -- --登录校验服务
    skynet.newservice("reptile_manager")
    skynet.exit()
end)