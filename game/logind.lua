local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local redis = require "redis"
local sharedata = require "sharedata"
local utils = require "utils"
local account_redis

local MAX_USER_ID = 4967000

local CMD = {}

local function CreateUserId(server_id)
    local max_id = account_redis:incrby("user_id_generator", 1)
    if max_id >= MAX_USER_ID then
        return nil
    end
    local user_id = tonumber(string.format("%d%07d", server_id, max_id))
    return utils:convertTo32(user_id)
end

--登录，如果账户不存在则新建一个
function CMD.Login(msg)
    local err = nil
    local server_id = msg.server_id
    local user_key = msg.platform .. ":" .. msg.user
    --检查用户名和密码是否符合规则
    local user_id = account_redis:hget(user_key, server_id)

    if not user_id then
        user_id = CreateUserId()
        if not user_id then
            return user_id
        end
        account_redis:hset(user_key, server_id, user_id)
    end
    return err,user_id
end 

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd])
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)

    local conf = sharedata.query("account_redis_conf")
    account_redis = redis.connect(conf)

    if not account_redis:exists("user_id_generator") then
        account_redis:set("user_id_generator", 1)
    end

    skynet.register(".logind") 
end)
