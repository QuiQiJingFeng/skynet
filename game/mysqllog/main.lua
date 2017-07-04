local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register

local config = require "mysqllog"
local manager = config.manager
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
    manager:LoadDefault()

    skynet.register(".mysqllog")
end)