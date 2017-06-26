local skynet = require "skynet"
require "skynet.manager"

local battle = require "battle"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(COMMAND[cmd])
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
    battle:LoadDefault()
    
    skynet.register(".battle") 
end)
