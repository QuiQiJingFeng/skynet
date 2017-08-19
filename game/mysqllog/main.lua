local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register

local command = require "command"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(command[cmd])
        if session > 0 then
            skynet.ret(skynet.pack(f(command,...)))
        else
            f(command,...)
        end
    end)
    command:Init()

    skynet.register(".mysqllog")
end)