local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local redis = require "redis"
local FUNCTION = {}
--热更
function FUNCTION.Login(data)
    
end 

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd])
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)



    skynet.register(".logind") 
end)
