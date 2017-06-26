local event_dispatcher = {}
function event_dispatcher:Init(msg_files)
    self.handlers = {} 

    for _,file_name in ipairs(msg_files) do
        require(file_name):Init()
    end
end

function event_dispatcher:RegisterEvent(event_name,handle,order)   
    local event_pool = self.handlers[event_name] 
    if not event_pool then
        event_pool = {} 
        self.handlers[event_name] = event_pool
    end
    if order then
        table.insert(event_pool,order,handle) 
    else
        table.insert(event_pool,handle)
    end
    
end

function event_dispatcher:DispatchEvent(event_name,...) 
    local event_pool = self.handlers[event_name]
    if not event_pool then
        return 
    end
    --如果只有一个方法,返回方法的返回值
    if #event_pool == 1 then
        return event_pool[1](...)
    end
    for _,handle in ipairs(event_pool) do 
        local stop = handle(...)
        if stop then
            break;
        end
    end
end

function event_dispatcher:RemoveEventListener(event_name)
    self.handlers[event_name] = nil 
end

function event_dispatcher:RemoveAllEventListeners()
    self.handlers = {} 
end

return event_dispatcher