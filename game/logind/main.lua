local skynet = require "skynet"
local logind = require "logind"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(logind.funcs[cmd])
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
    logind:LoadDefault()
    
    skynet.register(".logind") 
end)
