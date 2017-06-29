local skynet = require "skynet"
local logind,COMMAND = require "logind"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(COMMAND[cmd])
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
    logind:Init()
    
    skynet.register(".logind") 
end)