local socket = require "socket"
local netpack = require "websocketnetpack"
local skynet = require "skynet"
local protobuf = require "protobuf"
local sharedata = require "sharedata"
local redis = require "redis"
local config_manager = require "config_manager"
local math_ceil = math.ceil

local user_info = {}

function user_info:Init(user_id,server_id,channel,locale,client_fd, client_ip)

    self.client_fd = client_fd
    self.client_ip = client_ip

    --初始化逻辑处理模块
    self.logic_modules = {}
    for _,file_name in ipairs(config_manager.logic_files_config) do
        local module = require("msg/"..file_name)
        module:Init()
        local key = string.sub(file_name,1,-5)  
        self.logic_modouls[key] = module
    end

    self.logic_modouls["user_center"]:SetLoginInfo(user_id,server_id,channel,locale)
end

-------------------------
--
--保存到数据库的save 函数
--
--------------------------
function user_info:Save()
    for _,module in pairs(self.logic_modules) do
        module:Save()
    end
    return true
end

--重用agent的时候需要重置lua vm中的用户数据
function user_info:Close()
    for _,module in pairs(self.logic_modules) do
        module:Close()
    end
end

--玩家登出后设置fd为-1,避免登出后仍向该客户端发送数据
function user_info:Logout()
    self.client_fd = -1
end

--向客户端发送数据
function user_info:ResponseClient(msg_name, content)
    if self.client_fd == -1 then
        return 
    end
    local send_msg = {}
    send_msg[msg_name] = content
    local buff, size = netpack.pack(protobuf.encode("GS2C", send_msg))
    socket.write(self.client_fd,buff, size)
end

return user_info