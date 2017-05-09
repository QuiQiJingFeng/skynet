local skynet = require "skynet"
local config_manager = require "config_manager"
local sharedata = require "sharedata"
local redis = require "redis"

local resource_center = {}

function resource_center:Init()
    self.resource_list = {}
    for i=1,config_manager.resource_config.length do
        self.resource_list[i] = 0
    end
end

function resource_center:Save()
    local config = sharedata.query("user_redis_conf")
    local db = redis.connect(config)
    db:multi()

    local ret = db:exec()
    for i, v in ipairs(ret) do
        if not (type(v) == "number" or v == "OK" ) then
            skynet.error("redis save(user_info) index:" .. i .. ",error:" .. v)
            suc = false
        end
    end

    db:disconnect()
end

function resource_center:Close()
    
end


return resource_center