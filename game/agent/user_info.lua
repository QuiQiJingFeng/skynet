local socket = require "socket"
local netpack = require "netpack"
local skynet = require "skynet"
local protobuf = require "protobuf"
local math_ceil = math.ceil
local user_info = {}

function user_info:Init(server_id,user_id)
    self.has_data = nil
    self.session_id = 0
    self.server_id = server_id
    self.user_id = user_id

    self.db_conf = sharedata.query("user_redis_conf")
    self.user_info_key = "info:" .. self.user_id
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
--重用agent的时候需要重置lua vm中的用户数据
function user_info:ClearData()
    for key,var in pairs(self) do
        if type(var) ~= "function" then
            self[key] = nil
        end 
    end
end
--加载玩家数据
function user_info:LoadFromDb()
    local db = redis.connect(self.db_conf)
    if not db:exists(user_info_key) then
        db:disconnect()
        return false
    end
    ---加载玩家数据
    return true
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