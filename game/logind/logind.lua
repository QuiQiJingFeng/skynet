local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local redis = require "redis"
local sharedata = require "sharedata"
local utils = require "utils"
local httpc = require "http.httpc"
local cjson = require "cjson"

local account_redis
local MAX_USER_ID = 4967000

local logind = {}
-----------------------------------------------------------------
--登录模块初始化
-----------------------------------------------------------------
function logind:Init()
    local conf = sharedata.query("redis_conf_0")
    account_redis = redis.connect(conf)

    if not account_redis:exists("user_id_generator") then
        account_redis:set("user_id_generator", 1)
    end
end
-----------------------------------------------------------------
--登录远程校验
-----------------------------------------------------------------
function logind:Check()
    local debug = skynet.getenv("debug")
    if debug then
        return true
    end

    local content = {
        ["action"] = "login",
        ["account"] = account,
        ["password"] = password
    }
    local recvheader = {}
    local check_server = "127.0.0.1:3000"
    local success, status, body = pcall(httpc.post, check_server, "/login", content, recvheader)
    if not success or status ~= 200 then
        return false
    end

    body = cjson.decode(body)
    if body.result == "success" then
        return true
    end

    return false
end
-----------------------------------------------------------------
--生成user_id
-----------------------------------------------------------------
function logind:CreateUserId()
    local max_id = account_redis:incrby("user_id_generator", 1)
    if max_id >= MAX_USER_ID then
        return nil
    end
    local user_id = tonumber(string.format("%d%07d", server_id, max_id))
    return utils:convertTo32(user_id)
end

local COMMAND = {}
-----------------------------------------------------------------
--登录处理
-----------------------------------------------------------------
function COMMAND.Login(data)
    local ret = {result = "success"}
    local success = logind:Check(data.account,data.password);
    if not success then
        ret.result = "auth_failure"
        return ret
    end

    -----登录校验完毕---------
    local server_id = data.server_id
    local user_key = data.platform .. ":" .. data.account
    local user_id = account_redis:hget(user_key, server_id)
    if not user_id then
        user_id = logind:CreateUserId(server_id)
        if not user_id then
            skynet.error("ERROR CODE = 2001")
            ret.result = "max_user_id"
            return ret
        end
        account_redis:hset(user_key, server_id, user_id)
        ret.is_new = true
        ret.user_id = user_id
    end
    return ret
end 

return {logind = logind,COMMAND = COMMAND}