local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local command = require "command"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(command[cmd])
        f(command,...)
    end)
    command:Init()
end)
