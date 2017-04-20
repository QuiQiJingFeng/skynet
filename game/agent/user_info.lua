local socket = require "socket"
local netpack = require "netpack"
local skynet = require "skynet"
local protobuf = require "protobuf"
local sharedata = require "sharedata"
local redis = require "redis"
local math_ceil = math.ceil
local user_info = {}

function user_info:Init(server_id,user_id)
    self.session_id = 0
    self.server_id = server_id
    self.user_id = user_id

    self.db_conf = sharedata.query("user_redis_conf")
    self.user_info_key = "info:" .. self.user_id

    self.last_login_time = nil
    self.has_data = false
end

--登录成功后记录数据
function user_info:InitData(data,client_fd, client_ip)
    self.client_fd = client_fd
    self.client_ip = client_ip
    self.device_id = data.device_id
    self.locale = data.locale
    self.platform_uid = data.user
    self.platform = data.platform
    self.last_login_time = math_ceil(skynet.time())
end
--玩家登出后就直接断开连接
function user_info:Logout()
    skynet.call(gate, "lua", "kick", fd)
    self.user_id = ""
    self.client_fd = -1
end

--重用agent的时候需要重置lua vm中的用户数据
function user_info:ClearData()
    for key,var in pairs(self) do
        if type(var) ~= "function" then
            self[key] = nil
        end 
    end
end

function user_info:LoadDefaultInfo()

end

function user_info:CreateLeader(leader_name, channel)
    self.leader_name = leader_name
end

--加载玩家数据
function user_info:LoadFromDb()
    local db = redis.connect(self.db_conf)
    if not db:exists(user_info_key) then
        db:disconnect()
        return false
    end
    ---加载玩家数据

    db:disconnect()
    self.has_data = true
    return true
end

-------------------------
--
--保存到数据库的save 函数
--
--------------------------

function user_info:Save()
    --如果没有数据,或者user_id不存在则不用存储
    if not self.has_data or self.user_id == "" then
        return true
    end

    local suc = true

    user_info_key = "info:" .. self.user_id
    local db = redis.connect(self.db_conf)

    db:multi()

    self:SaveBaseInfoToDb()
    --保存资源列表信息

    local ret = db:exec()

    for i, v in ipairs(ret) do
        if not (type(v) == "number" or v == "OK" ) then
            shield.error("redis save(user_info) index:" .. i .. ",error:" .. v)
            suc = false
        end
    end

    db:disconnect()

    local formation_info = self:CalcTroopInfo(self.troop.cur_formation_id)
    shield.call(".arena", "lua", "UpdateTroopInfo", self.user_id, formation_info, self.base_info.leader_name)

    --保存合战信息
    shield.call(".campaign", "lua", "SaveUserCampaign", self.user_id, self.campaign)

    self:SyncGuildFormation()

    return suc
end

--向客户端发送数据
function user_info:ResponseClient(msg_name, content)
    self.session_id = self.session_id + 1
    local send_msg = { session = self.session_id }
    send_msg[msg_name] = content
    local buff, sz = netpack.pack(protobuf.encode("GS2C", send_msg))
    socket.write(self.client_fd, buff, sz)
end

return user_info