local skynet = require "skynet"
local agent_manager = {}

function agent_manager:dequeue_agent()
    local service_id = skynet.newservice("agent")
    local agent = {}
    agent.service_id = service_id
    agent.fd = -1
    agent.user_id = ""

    return agent
end


return agent_manager