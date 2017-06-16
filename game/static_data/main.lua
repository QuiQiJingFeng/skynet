local skynet = require "skynet"
local static_data = require "static_data"

skynet.start(function()
    static_data:LoadDefaultConfig()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(static_data.funcs[cmd])
        f(...)
    end)
    skynet.register(".static_data")
end)
