local skynet = require "skynet"
local protobuf = require "protobuf"
local utils = require "utils"
local netpack = require "websocketnetpack"
local socket = require "socket"

local gate
local agent_manager = {}

function agent_manager:Init()
    gate = skynet.newservice("gate")
    protobuf.register_file(skynet.getenv("protobuf"))

    self.userid_to_agent = {}

    return gate
end

--向客户端发送数据
function agent_manager:SendToClient(fd,send_msg)
    local buff, sz = netpack.pack(protobuf.encode("GS2C", send_msg))
    socket.write(fd, buff, sz)
end

--设置失效时间
function agent_manager:OnReceiveData(fd,msg,ip)
    local succ, msg_data, pbc_error = pcall(protobuf.decode, "C2GS", msg)
    if not succ or not msg_data then 
        skynet.error("PBC DECODE ERR:",pbc_error) 
        return 
    end
    if not msg_data.login then 
        skynet.error("FIRST MSG MUST login:") 
        return
    end
    --检查app的版本是否需要强更
    local greater = utils:greaterVersion(data.version,constants_config.LIMIT_VERSION)
    if not greater then
        self:SendToClient(fd,{ login_ret = { result = "version_too_low"} })
        return false
    end
    --登录校验
    local ret = skynet.call(".logind","lua","Login",data)
    if ret.result ~= "success" then
        send_msg = {login_ret = {result = ret.result} }
        self:SendToClient(fd,send_msg)
        return true
    end

    local user_id,is_new = ret.user_id,ret.is_new
    assert(user_id)
    if is_new then
        --TODO register log
    end

    local agent = self.userid_to_agent[user_id]
    if agent then
        agent.lock = true
        if agent.fd >= 0 then 
            --重复登录,踢掉旧的客户端
            self.socket_to_agent[agent.fd] = nil
            --通知旧的客户端退出
            skynet.call(agent.service_id, "lua", "Kick", "repeated_login")
            --断开旧的客户端
            skynet.call(gate, "lua", "kick", agent.fd)
        end
        agent.lock = false
    else
        agent = agent_pool:Dequeue()
    end

    skynet.call(agent.service_id, "lua", "Start",gate,fd,ip,is_new_agent,user_id,data)

    self.userid_to_agent[user_id] = agent
    agent.user_id = user_id

    agent.fd = fd
    agent.lock = false
    
    self.socket_to_agent[fd] = agent

end

--设置失效时间
function agent_manager:SetExpireTime(fd)
    
end

return agent_manager