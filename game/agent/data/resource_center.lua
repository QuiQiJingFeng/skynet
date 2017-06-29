local skynet = require "skynet"
local config_manager = require "config_manager"
local cjson = require "cjson"
local resource_center = {}
-------------------------------------------------------------
--初始化资源模块
-------------------------------------------------------------
function resource_center:Init(db,user_id)
    self.resource_list = {}
    local config = config_manager.resource_config
    for k,v in pairs(config) do
        self.resource_list[k] = 0
    end
end
-------------------------------------------------------------
--从数据库加载数据
-------------------------------------------------------------
function resource_center:LoadFromDb(db,user_id)
    local resource_key = user_id .. ":resource_list"
    local data = db:hgetall(resource_key) or {}
    for i = 1, #data, 2 do
        local key,value = data[i],data[i+1]
        self.resource_list[key] = tonumber(value)
    end
end
-------------------------------------------------------------
--向数据库保存数据
-------------------------------------------------------------
function resource_center:Save(db,user_id)
    local resource_key = user_id .. ":resource_list"
    local temp = {}
    for key,value in pairs(self.resource_list) do
        table.insert(temp,key)
        table.insert(temp,value)
    end
    db:hmset(resource_key,unpack(temp))
end

function resource_center:Clear()
    self.resource_list = nil
end

-------------------------------------------------------------
--更新资源  {reskey1=upvalue,reskey2=upvalue}
-------------------------------------------------------------
function resource_center:UpdateResource(arg)
    for key,value in pairs(arg) do
        self.resource_list[key] = self.resource_list[key] + value
    end
end
-------------------------------------------------------------
--检查资源是否足够  {reskey1=upvalue,reskey2=upvalue}
-------------------------------------------------------------
function resource_center:CheckResource(arg)
    for type,value in pairs(arg) do
        local new_value = self.resource_list[type] + value
        if new_value < 0 then
            return false
        end
    end
    return true
end

return resource_center