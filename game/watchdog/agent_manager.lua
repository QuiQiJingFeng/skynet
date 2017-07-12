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

----------------------------------------------------------------------------
--设置失效时间 当socket断开连接的时候,将agent设置失效的时间
----------------------------------------------------------------------------
function agent_manager:SetExpireTime(fd)
    local agent = self.socket_to_agent[fd]
    self.socket_to_agent[fd] = nil

    if agent then
        agent.fd = -1
        agent.expire_time = skynet.time() + 30*60
        skynet.send(agent.service_id, "lua", "Logout")
    end
end

----------------------------------------------------------------------------
--将失效的agent加入重用池中
----------------------------------------------------------------------------
function agent_manager:ReclaimAgent(agent)
    if self.userid_to_agent[agent.user_id] then
        self.userid_to_agent[agent.user_id] = nil
    end
    skynet.call(agent.service_id, "lua", "Close")
    agent_pool:Push(agent)
end

----------------------------------------------------------------------------
--获取玩家的agent服务id
----------------------------------------------------------------------------
function agent_manager:GetAgentByUserId(user_id)
    local agent = self.userid_to_agent[user_id]
    if agent then
        return agent.service_id
    end
    return 
end

----------------------------------------------------------------------------
--循环检测失效的agent
----------------------------------------------------------------------------
local function ExpireTimer()
    skynet.timeout(60 * 100, ExpireTimer)
    if not agent_manager.userid_to_agent then
        return 
    end

    local t_now = skynet.time()
    local tmp_agent_map = {}
    --当前在线人数
    local online_num = 0

    for user_id, agent in pairs(agent_manager.userid_to_agent) do
        if agent.expire_time > 0 and t_now >= agent.expire_time then
            tmp_agent_map[user_id] = agent
        else
            --当前有效连接数量
            if agent.fd >= 0 then
                online_num = online_num + 1
            end 
        end
    end
    --对标记过的佣兵加入重用池
    for user_id, agent in pairs(tmp_agent_map) do
        if not agent.lock then
            agent_manager:ReclaimAgent(agent)
        end
    end
    agent_manager.online_num = online_num
    --TODO:添加online记录
end
----------------------------------------------------------------------------
--整点调度
----------------------------------------------------------------------------
local function ClockTimer()
    local t_now = math.floor(skynet.time())
    local date_now = os.date("*t", t_now)
    local timer = 360000
    skynet.timeout(math.ceil(timer), ClockTimer)
    --0点时刻
    if date_now.hour == 0 then
    end 
end

do
    skynet.timeout(AGENT_POLL_TIME * 100, ExpireTimer)
end

do
    local t_now = math.floor(skynet.time())
    --下一个整点的格林威治时间 多5s是怕时间调度不精准
    local next_time = os.date("*t", t_now)
    next_time.min = 0
    next_time.sec = 5
    next_time.hour = next_time.hour + 1

    local clock_time = os.time(next_time)
    local timer = (clock_time-t_now)*100
    skynet.timeout(math.ceil(timer), ClockTimer)
end

return agent_manager