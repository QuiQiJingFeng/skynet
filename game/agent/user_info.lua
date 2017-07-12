local socket = require "socket"
local netpack = require "websocketnetpack"
local skynet = require "skynet"
local protobuf = require "protobuf"
local event_dispatcher = require "event_dispatcher"

local user_info = {}

function user_info:Init()
    self.client_fd = -1
    protobuf.register_file(skynet.getenv("protobuf"))
    event_dispatcher:Init()
end

function user_info:SetClientFd(fd)
    self.client_fd = fd
end
 

--向客户端发送数据
function user_info:ResponseClient(msg_name, content)
    if self.client_fd == -1 then
        return 
    end
    local buff, size = netpack.pack(protobuf.encode("GS2C", {[msg_name] = content}))
    socket.write(self.client_fd,buff, size)
end

return user_info