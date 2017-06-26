local skynet = require "skynet"
local config_manager = require "config_manager"

local world = {}

function world:Init(db,user_info_key)
    self.worlds = {}
end

function world:Save(db,user_info_key)
 
end

function world:Close()
 
end

function world:GoWorld(world_id,card_id,gold_fingers)
    if not self.worlds[tostring(world_id)] then
        self.worlds[tostring(world_id)] = {}
    end

    table.insert(self.worlds[tostring(world_id)],{world_id = world_id,card_id = card_id,gold_fingers = gold_fingers,get = {}})
end

function world:OutWorld(card_id)

    for key,var in pairs(self.worlds) do
        for idx,data in ipairs(var) do
            if data.card_id == card_id then
                table.remove(var,idx)
                return data.get
            end
        end
    end
    return {}
end
 
return world