local skynet = require "skynet"
require "skynet.manager"
local static_data,COMMAND = require "static_data"

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
