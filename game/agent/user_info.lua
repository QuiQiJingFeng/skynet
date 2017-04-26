local socket = require "socket"
local netpack = require "netpack"
local skynet = require "skynet"
local protobuf = require "protobuf"
local sharedata = require "sharedata"
local redis = require "redis"
local math_ceil = math.ceil

local user_info = {}

function user_info:Init(user_id,data,client_fd, client_ip)
    self.session_id = 0
    self.has_data = false
    --记录本次登录的时间
    self.last_login_time = math_ceil(skynet.time())

    
    --记录本次登录的数据
    self.account = data.account  
    self.platform = data.platform
    self.version = data.version
    self.server_id = data.server_id  
    self.device_id = data.device_id
    self.channel = data.channel
    self.locale = data.locale
    self.net_mode = data.net_mode
    self.device_platform = data.device_platform
    -------
    self.user_id = user_id
    self.client_fd = client_fd
    self.client_ip = client_ip
    
    --加载基础数据
    self:LoadDefaultInfo()
    self:LoadFromDb() 
end

function user_info:LoadDefaultInfo()

end

--加载玩家数据
function user_info:LoadFromDb()
    local user_info_key = "info:" .. self.user_id
    local db_conf = sharedata.query("user_redis_conf")

    local db = redis.connect(db_conf)
    if not db:exists(user_info_key) then
        db:disconnect()
        return false
    end
    ---加载玩家数据

    db:disconnect()
    return true
end

-------------------------
--
--保存到数据库的save 函数
--
--------------------------

function user_info:Save()

end

--玩家登出后设置fd为-1,避免登出后仍向该客户端发送数据
function user_info:Logout()
    self.client_fd = -1
end

--重用agent的时候需要重置lua vm中的用户数据
function user_info:Close()
    for key,var in pairs(self) do
        if type(var) ~= "function" then
            self[key] = nil
        end 
    end
end

--向客户端发送数据
function user_info:ResponseClient(msg_name, content)
    if self.client_fd == -1 then
        return 
    end
    self.session_id = self.session_id + 1
    local send_msg = { session = self.session_id }
    send_msg[msg_name] = content
    local buff, sz = netpack.pack(protobuf.encode("GS2C", send_msg))
    socket.write(self.client_fd, buff, sz)
end

return user_info