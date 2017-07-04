local skynet = require "skynet"
require "skynet.manager"
local config = require "static_data"
local static_data = config.static_data
local COMMAND = config.COMMAND

skynet.start(function() 
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(COMMAND[cmd])
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
    static_data:Init()
    skynet.register(".static_data")
end)
