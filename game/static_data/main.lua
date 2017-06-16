local skynet = require "skynet"
local static_data = require "static_data"

skynet.start(function()
    static_data:LoadDefaultConfig()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
    skynet.register(".static_data")
end)
