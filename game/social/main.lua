local skynet = require "skynet"
require "skynet.manager"
local config = require "social"
local social = config.social
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
    social:Init()
    skynet.register(".social")
end)
