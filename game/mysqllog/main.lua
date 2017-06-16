local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register

local mysqllog = require "mysqllog"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
    mysqllog:LoadDefault()

    skynet.register(".mysqllog")
end)