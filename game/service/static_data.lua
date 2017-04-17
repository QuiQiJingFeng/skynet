local skynet = require "skynet"
local sharedata = require "sharedata"
local constants = require "constants"


local FUNCTION = {}
--热更
function FUNCTION.UpdateConfig(name)
    if name == "constants" then
        sharedata.update("constants", constants)
    end
end 

skynet.start(function()
    --redis配置    
    local redis_ip = skynet.getenv("game_redis_host")
    local redis_port = skynet.getenv("game_redis_port")
    local redis_auth = skynet.getenv("game_redis_auth")
    
    sharedata.update("account_redis_conf", {
        host = redis_ip ,
        port = redis_port,
        db = 0,
        auth = redis_auth
    })
    --mysql配置
    local mysql_ip = skynet.getenv("mysql_ip")
    local mysql_port = skynet.getenv("mysql_port")
    local mysql_user = skynet.getenv("mysql_user")
    local mysql_pass = skynet.getenv("mysql_pass")
    
    sharedata.update("mysql_conf", {
        host = mysql_ip,
        port = mysql_port,
        user = mysql_user,
        password = mysql_pass,
        max_packet_size = 1024 * 1024
    })

    --数据配置
    sharedata.update("constants", constants)

    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(FUNCTION[cmd])
        f(...)
    end)
    skynet.register(".static_data")
end)
