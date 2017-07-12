local event_dispatcher = {}
function event_dispatcher:Init()
    self.handlers = {} 

    require "msg.user"
end

function event_dispatcher:RegisterEvent(event_name,handle) 
    self.handlers[event_name] = handle
end

function event_dispatcher:DispatchEvent(event_name,...) 
    local handle = self.handlers[event_name]
    return handle(...)
end

return event_dispatcher