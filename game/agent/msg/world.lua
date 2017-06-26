local event_dispatcher = require "event_dispatcher"
local config_manager = require "config_manager"
local utils = require "utils"
local world_center = require "module/world_center"
local resource_center = require "module/resource_center"

local world = {}
function world:Init()
    event_dispatcher:RegisterEvent("go_world",utils:handler(self,self.GoWorld)) 
    event_dispatcher:RegisterEvent("out_world",utils:handler(self,self.OutWorld))
end

function world:GoWorld(recv_msg)
    local ret = {result = "success"}
    local world_id = recv_msg.world_id
    local card_id = recv_msg.card_id
    local gold_fingers = recv_msg.gold_fingers
    local data = config_manager.world_config[world_id]
    if not data then
        ret.result = "failer"
        return "go_world_ret",ret
    end
    local args = {}
    local resource_list = data.resource_list
    for k,v in pairs(resource_list) do
        args[k] = -v
    end

    local enough = resource_center:CheckResource(args)
    if not enough then
        ret.result = "resource_not_enough"
        return "go_world_ret",ret
    end
    resource_center:UpdateResource(args)
    world_center:GoWorld(world_id,card_id,gold_fingers)

    return "go_world_ret",ret
end

function world:OutWorld(recv_msg)
    local ret = {result = "success"}
    local card_id = recv_msg.card_id
    local get = world_center:GoWorld(card_id)
end



 

return user