local socket = require "socket"
local netpack = require "netpack"
local skynet = require "skynet"
local protobuf = require "protobuf"
local math_ceil = math.ceil
local user_info = {}

function user_info:Init(server_id)
    self.has_data = nil
    self.session_id = 0
    self.server_id = server_id
end

function user_info:LoadFromDb()
    --判断redis中是否有数据
    --如果有则加载数据，同时self.has_data = true
end

function user_info:IsNeedCreateRole()
    return self.has_data
end

function user_info:InitData(data,client_fd, client_ip)

    self.client_fd = client_fd
    self.client_ip = client_ip
    self.device_id = data.device_id
    self.locale = data.locale
    self.platform_uid = data.user
    self.platform = data.platform
    self.last_login_time = math_ceil(skynet.time())
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