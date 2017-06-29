local skynet = require "skynet"
local config_manager = require "config_manager"

local user_center = {}

function user_center:Init(db,user_id)
    self.base_info = {user_id = user_id}
end

-------------------------------------------------------------
--从数据库加载数据
-------------------------------------------------------------
function user_center:LoadFromDb(db,user_id)
    local base_info_key = user_id .. ":base_info"
    local data = db:hgetall(base_info_key) or {}
    for i = 1, #data, 2 do
        local key,value = data[i],data[i+1]
        self.base_info[key] = value
    end
end

function user_center:Save(db,user_id)
    local base_info_key = user_id .. ":base_info"
    local temp = {}
    for key,value in pairs(self.base_info) do
        table.insert(temp,key)
        table.insert(temp,value)
    end
    db:hmset(base_info_key,unpack(temp))
end

function user_center:Close()
    self.base_info = nil
end

return user_center