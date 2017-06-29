local redis = require "redis"
local sharedata = require "sharedata"
local social = {}

function social:Init()
    self.name_to_id = {}

    self.union_db = redis.connect(sharedata.query("redis_conf_2"))

    self:Load()
end
---------------------------------------------------------------
--加载数据
---------------------------------------------------------------
function social:Load()
    local name_to_id_key = "social:name_to_id"
    local data = self.union_db:hgetall(name_to_id_key)
    for i = 1, #data, 2 do
        local key,value = data[i],data[i+1]
        self.name_to_id[key] = value
    end
end

---------------------------------------------------------------
--检查是否是已经存在该名称,如果不存在返回nil,存在则返回id
---------------------------------------------------------------
function social:CheckNewName(name,user_id)
    local id = self.name_to_id[name]
    if not id then
        self.name_to_id[name] = user_id
        self.union_db:hmset("social:name_to_id",name,user_id)
    end
    return id
end


local COMMAND = {}


return social,COMMAND