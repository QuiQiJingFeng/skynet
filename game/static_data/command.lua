local sharedata = require "sharedata"
local skynet = require "skynet"
local utils = require "utils"
local csv = require "csv"
local command = {}

local function CreateMsgFilesConfig()
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

local function CreateConstantConfig()
    local file = io.open("lualib/constants.lua","r")
    local data = file:read("*a")
    file:close()
    return load(data)()
end

local function CreatePaymentConfig()
    local file = csv.load("data/products.csv")
    local config = {}
    for _,cell in pairs(file) do
        config[cell.good_id] = cell
    end
    return config
end

function command.Init()
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

    sharedata.update("msg_files_config", CreateMsgFilesConfig())
    
    sharedata.update("constants_config", CreateConstantConfig())

    sharedata.update("products_config", CreatePaymentConfig())

end

function command.UpdateConfig(name)
    if name == "constants_config" then
        sharedata.update("constants_config", CreateConstantConfig())
    elseif name == "products_config" then
        sharedata.update("products_config",CreatePaymentConfig())
    end

    return "OK"
end

return command