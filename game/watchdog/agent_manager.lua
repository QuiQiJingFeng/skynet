local skynet = require "skynet"
local protobuf = require "protobuf"
local agent_pool = require "agent_pool"
local netpack = require "websocketnetpack"
local socket = require "socket"
local sharedata = require "sharedata"
local utils = require "utils"

local AGENT_POLL_TIME = 60  --每60s调度一次  
--当玩家退出后,保留agent 30 分钟
local AGENT_EXPIRE_TIME = skynet.getenv("agent_expire_time") or (30*60);
--玩家数据 每10分钟保存一次
local AGENT_SAVE_TIME = skynet.getenv("agent_save_time") or (10*60);
 

local gateserver
local constants_config

local agent_manager = {}
----------------------------------------------------------------------------
--初始化user_id=>agent的映射  socket=>agent的映射  agent_pool
----------------------------------------------------------------------------
function agent_manager:Init(gate)
    gateserver = gate
    self.userid_to_agent = {}
    self.socket_to_agent = {}
    agent_pool:Init()
    self.online_num = 0

    constants_config = sharedata.query("constants_config")
end
----------------------------------------------------------------------------
--解析接收到的数据
----------------------------------------------------------------------------
function agent_manager:ProcessData(msg)
    local succ, msg_data, pbc_error = pcall(protobuf.decode, "C2GS", msg)
    if not succ then
        skynet.error("ERROR CODE = 1001")
        return false
    elseif not msg_data then
        skynet.error("ERROR CODE = 1002")
        return false
    end

    if not msg_data["login"] and not msg_data["reconnect"] then
        skynet.error("ERROR CODE = 1003")
        return false
    end

    return msg_data
end
----------------------------------------------------------------------------
--客户端消息处理
----------------------------------------------------------------------------
function agent_manager:OnReceiveData(fd,msg,ip)
    local recv_data = self:ProcessData(msg)
    if not recv_data then
        return false
    end
    if recv_data.login then
       return self:ProcessLogin(fd,recv_data.login,ip)
    end

    return true
end
----------------------------------------------------------------------------
--向客户端发送数据
----------------------------------------------------------------------------
function agent_manager:SendToClient(fd,send_msg)
    local buff, sz = netpack.pack(protobuf.encode("GS2C", send_msg))
    socket.write(fd, buff, sz)
end
----------------------------------------------------------------------------
--处理登录
----------------------------------------------------------------------------
function agent_manager:ProcessLogin(fd,data,ip)
    local greater = utils:greaterVersion(data.version,constants_config.LIMIT_VERSION)
    if not greater then
        send_msg = {login_ret = { result = "version_too_low"} }
        self:SendToClient(fd,send_msg)
        return false
    end
    --登录校验
    local ret = skynet.call(".logind","lua","Login",data)
    if ret.result ~= "success" then
        send_msg = {login_ret = ret }
        self:SendToClient(fd,send_msg)
        return true
    end 

    local user_id,is_new = ret.user_id,ret.is_new
    assert(user_id)
    if is_new then
        local register_msg = {  
                                user_id = user_id,
                                server_id = data.server_id,
                                account = data.account,
                                ip = ip,
                                platform = data.platform,
                                channel = data.channel,
                                net_mode = data.net_mode,
                                device_id = data.device_id,
                                device_type = data.device_type,
                                time = "NOW()"
                             }
        --注册日志
        skynet.send(".mysqllog","lua","InsertLog","register_log",register_msg)
    end

    --检测重复登录
    local agent = self.userid_to_agent[user_id]
    if agent then
        agent.lock = true
        if agent.fd >= 0 then 
            --重复登录,踢掉旧的客户端
            self.socket_to_agent[agent.fd] = nil
            skynet.call(agent.service_id, "lua", "Kick", "repeated_login")
            skynet.call(gateserver, "lua", "kick", agent.fd)
        end
    else
        agent = agent_pool:Dequeue()
    end
    skynet.call(agent.service_id, "lua", "Start",gateserver,fd,ip,user_id,data)

    self.userid_to_agent[user_id] = agent
    agent.user_id = user_id

    agent.fd = fd
    agent.lock = false
    
    self.socket_to_agent[fd] = agent

    return true
end

----------------------------------------------------------------------------
--设置失效时间 当socket断开连接的时候,将agent设置失效的时间
----------------------------------------------------------------------------
function agent_manager:SetExpireTime(fd)
    local agent = self.socket_to_agent[fd]
    self.socket_to_agent[fd] = nil

    if agent then
        agent.fd = -1
        agent.expire_time = skynet.time() + AGENT_EXPIRE_TIME
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
--循环检测失效的agent 以及定时存储agent的数据
----------------------------------------------------------------------------
local function SaveTimer()
    skynet.timeout(AGENT_POLL_TIME * 100, SaveTimer)
    if not agent_manager.userid_to_agent then
        return 
    end

    local t_now = skynet.time()
    local tmp_agent_map = {}
    --当前在线人数
    local online_num = 0

    for user_id, agent in pairs(agent_manager.userid_to_agent) do
        if t_now >= agent.save_time then
            if not agent.can_be_reclaim then
                agent.save_time = t_now + AGENT_SAVE_TIME
                --存储
                skynet.send(agent.service_id, "lua", "Save")
                --标记可重用
                if agent.expire_time > 0 then
                    agent.can_be_reclaim = true
                end
            elseif t_now >= agent.expire_time then
                tmp_agent_map[user_id] = agent
            end
        end
        --当前有效连接数量
        if agent.fd >= 0 then
            online_num = online_num + 1
        end
    end
    --对标记过的佣兵加入重用池
    for user_id, agent in pairs(tmp_agent_map) do
        --当agent正在进行某些操作而加锁的时候,不要将其放入回收池
        if not agent.lock then
            agent_manager:ReclaimAgent(agent)
        end
    end
    agent_manager.online_num = online_num
    --TODO:添加online记录
end

do
    skynet.timeout(AGENT_POLL_TIME * 100, SaveTimer)
end

return agent_manager