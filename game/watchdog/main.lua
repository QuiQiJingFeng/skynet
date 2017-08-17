local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local command = require "command"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = command[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(command[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)

    command.Init()

    








    
    skynet.register(".watchdog")
end)
