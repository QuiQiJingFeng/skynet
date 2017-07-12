local skynet = require "skynet"
local utils = require "utils"
local user_info = require "user_info"
local event_dispatcher = require "event_dispatcher"

local AGENT_OP = {}

setmetatable(AGENT_OP, {
    __call = function(t, func_name, ...)
        while _G["SEASSION_PROCESS"] do
            skynet.yield()
        end
        _G["SEASSION_PROCESS"] = true
        local func = AGENT_OP[func_name]
        local succ, ret = pcall(func,...)
        _G["SEASSION_PROCESS"] = false
        --执行错误在此结束协程, 阻止ret返回
        if not succ then
            assert(false)
        end

        return ret
    end
})

--------------------CUSTOM-------------
function AGENT_OP.DebugProto(msg_name, data)
    -- body
    
    local table_data = load("return " .. data)
    local recv_msg = table_data()

    print("-------receive client msg-------",msg_name)
    utils:dump(recv_msg,"-------",10)
    print("\n\n")

    local succ, proto, send_msg = xpcall(event_dispatcher.DispatchEvent, debug.traceback, event_dispatcher, msg_name, recv_msg)
    print("-------response client msg-------",proto)
    utils:dump(send_msg,"---------",10)

    return "OK"
end
 


return AGENT_OP