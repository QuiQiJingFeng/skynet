local skynet = require "skynet"
local protobuf = require "protobuf"
local netpack = require "websocketnetpack"
local socket = require "socket"
local user_info = require "user_info"
local config_manager = require "config_manager"
local event_dispatcher = require "event_dispatcher"

local config = require "invoke"
local AGENT_OP = config.AGENT_OP
local CMD = config.CMD

skynet.start(function()
    skynet.dispatch("lua", function(session, service_address, cmd, ...)
        local ret
        
        if AGENT_OP[cmd] then
            ret = AGENT_OP(cmd, ...)
        else
            local f = assert(CMD[cmd])
            ret = f(...)
        end

        if session > 0 then
            skynet.ret(skynet.pack(ret))
        end
    end)
    config_manager:Init()
    
    

    user_info:Init()
end)
