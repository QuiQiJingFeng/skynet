local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local sharedata = require "sharedata"
local utils = require "utils"
local FUNCTION = {}

local function CreateMsgFilesConfig()
    local files = io.popen('ls game/agent/msg') 
    local fileLists = files:read("*all")
    fileLists = utils.replaceStr(fileLists,".lua","")
    local msg_files = utils.split(fileLists,"\n")
    table.remove(msg_files,#msg_files)
    return msg_files
end


--热更
function FUNCTION.UpdateConfig(name)
    if name == "msg_files" then
        sharedata.update("msg_files", CreateMsgFilesConfig())
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

    sharedata.update("user_redis_conf", {
        host = redis_ip ,
        port = redis_port,
        db = 1,
        auth = redis_auth,
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


    --事件中心配置
    
    sharedata.update("msg_files", CreateMsgFilesConfig())


    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(FUNCTION[cmd])
        f(...)
    end)
    skynet.register(".static_data")
end)
