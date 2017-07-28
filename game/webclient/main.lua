local command = require "command"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local func = assert(command[cmd])
        func()
    end)

    skynet.register(".webclient")
end)
