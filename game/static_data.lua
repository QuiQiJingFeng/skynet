local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local sharedata = require "sharedata"
local utils = require "utils"
local csv = require "csv"
local constants = require "constants"

local FUNCTION = {}

local function CreateMsgFilesConfig()
    local files = io.popen('ls game/agent/msg') 
    local fileLists = files:read("*all")
    fileLists = utils.replaceStr(fileLists,".lua","")
    local msg_files = utils.split(fileLists,"\n")
    table.remove(msg_files,#msg_files)
    return msg_files
end

local function CreateLogicFilesConfig()
    local files = io.popen('ls game/agent/logic')
    local fileLists = files:read("*all")
    fileLists = utils.replaceStr(fileLists,".lua","")
    local msg_files = utils.split(fileLists,"\n")
    table.remove(msg_files,#msg_files)
    return msg_files    
end

local function CreateResourceConfig()
    local file = csv.load("data/resource.csv")
    local config = {}
    local num = 0
    for ID,data in ipairs(file) do
        local temp = {}
        for k,v in pairs(data) do
            if k == "ID" or k == "key" then
                temp[k] = v
            end
        end
        config[data.key] = temp 
        num = num + 1
    end
    config.length = num

    return config

end

local function CreateConstantConfig()
    local file = io.open("lualib/constants.lua","r")
    local data = file:read("*a")
    file:close()
    return load(data)()
end

local function LoadDefaultConfig()
    --事件中心配置
    sharedata.update("msg_files_config", CreateMsgFilesConfig())
    --逻辑中心配置
    sharedata.update("logic_files_config", CreateLogicFilesConfig())
    
    
    --常量
    sharedata.update("constants_config", CreateConstantConfig())
    --资源
    sharedata.update("resource_config", CreateResourceConfig())
    
end

--热更
function FUNCTION.UpdateConfig(name)
    if name == "constants_config" then
        sharedata.update("constants_config", CreateConstantConfig())
    elseif name == "resource_config" then
        sharedata.update("resource_config", CreateResourceConfig())
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

    LoadDefaultConfig()


    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(FUNCTION[cmd])
        f(...)
    end)
    skynet.register(".static_data")
end)
