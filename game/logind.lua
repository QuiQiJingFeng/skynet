local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local redis = require "redis"
local sharedata = require "sharedata"
local utils = require "utils"
local server_id
local account_redis

local MAX_USER_ID = 4967000

local FUNCTION = {}

local function CreateUserId()
    local max_id = account_redis:incrby("user_id_generator", 1)
    if max_id >= MAX_USER_ID then
        return nil
    end
    local user_id = tonumber(string.format("%d%07d", server_id, max_id))
    return utils:convertTo32(user_id)
end

--热更
function FUNCTION.Login(msg)
    local user_key = msg.platform .. ":" .. msg.user
    local user_id = account_redis:hget(user, server_id)
    if not user_id then
        user_id = CreateUserid()
        if not user_id then
            return 
        end
        account_redis:hset(user_key, server_id, user_id)
    end

    return user_id
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

    server_id = tonumber(skynet.getenv("server_id"))
    if not server_id then
        print("server_id error")
        skynet.abort()
    end


    skynet.register(".logind") 
end)
