local skynet = require "skynet"
local config_manager = require "config_manager"
local cjson = require "cjson"
local resource_center = {}

function resource_center:Init(db,user_info_key)
    self.resource_list = {}
    local config = config_manager.resource_config
    for k,v in pairs(config) do
        self.resource_list[k] = 0
    end
    --加载数据
    local temp = db:hget(user_info_key,"resource_list")
    if temp then
        local data = cjson.decode(temp)
        for type,value in pairs(data) do
            self.resource_list[type] = value
        end
    end
end

function resource_center:Save(db,user_info_key)
    db:hmset(user_info_key,"resource_list", cjson.encode(self.resource_list))
end

function resource_center:Close()
    self.resource_list = nil
end
--[[
    {{type=upvalue,type2=upvalue}}
]]
function resource_center:UpdateResource(arg)
    for type,value in pairs(arg) do
        self.resource_list[type] = self.resource_list[type] + value
    end
end

--检查资源是否足够
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