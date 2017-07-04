local skynet = require "skynet"
local sharedata = require "sharedata"
local utils = require "utils"
local csv = require "csv"
local constants = require "constants"

local static_data = {}

function static_data:Init()

----------------------------------------------------
--redis配置  
----------------------------------------------------  
    local redis_ip = skynet.getenv("game_redis_host")
    local redis_port = skynet.getenv("game_redis_port")
    local redis_auth = skynet.getenv("game_redis_auth")

    local conf = {
        host = redis_ip ,
        port = redis_port,
        db = 0,
        auth = redis_auth
    }
    for i=1,16 do
        local id = i - 1
        conf.db = id
        sharedata.update("redis_conf_"..id, conf)
    end
----------------------------------------------------
--mysql配置  
----------------------------------------------------

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

----------------------------------------------------
--结构配置
----------------------------------------------------
    --事件中心配置
    sharedata.update("msg_files_config", self:CreateMsgFilesConfig())
    --逻辑中心配置
    sharedata.update("data_files_config", self:CreateModuleFilesConfig())
    
----------------------------------------------------
--数据配置
----------------------------------------------------  
    --常量
    sharedata.update("constants_config", self:CreateConstantConfig())
    --资源
    sharedata.update("resource_config", self:CreateResourceConfig())
    --世界
    sharedata.update("world_config", csv.load("data/world.csv"))
end

function static_data:CreateMsgFilesConfig()
    local files = io.popen('ls game/agent/msg') 
    local fileLists = files:read("*all")
    fileLists = utils:replaceStr(fileLists,".lua","")
    local msg_files = utils:split(fileLists,"\n")
    table.remove(msg_files,#msg_files)
    for k,v in pairs(msg_files) do
        msg_files[k] = "msg/"..v
    end
    return msg_files
end

function static_data:CreateModuleFilesConfig()
    local files = io.popen('ls game/agent/data')
    local fileLists = files:read("*all")
    fileLists = utils:replaceStr(fileLists,".lua","")
    local msg_files = utils:split(fileLists,"\n")
    table.remove(msg_files,#msg_files)
    for k,v in pairs(msg_files) do
        msg_files[k] = "data/"..v
    end
    return msg_files    
end

function static_data:CreateResourceConfig()
    local file = csv.load("data/resource.csv")
    local config = {}
    for ID,data in ipairs(file) do
        config[data.key] = data 
    end

    return config
end

function static_data:CreateConstantConfig()
    local file = io.open("lualib/constants.lua","r")
    local data = file:read("*a")
    file:close()
    return load(data)()
end

function static_data:UpdateConfig(name)
    if name == "constants_config" then
        sharedata.update("constants_config", self:CreateConstantConfig())
    elseif name == "resource_config" then
        sharedata.update("resource_config", self:CreateResourceConfig())
    elseif name == "world_config" then
        --世界
        sharedata.update("world_config", csv.load("data/world.csv"))
    end
    return "OK"
end

local COMMAND = {}

function COMMAND.UpdateConfig(name)
    return static_data:UpdateConfig(name)
end



return {static_data = static_data ,COMMAND = COMMAND}