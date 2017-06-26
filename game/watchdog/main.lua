local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local watchdog = require "watchdog"
local SOCKET = watchdog.SOCKET
local CMD = watchdog.CMD

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)

    watchdog:Init()
    
    skynet.register(".watchdog")
end)
