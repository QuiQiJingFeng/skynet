local socket = require "socket"
local netpack = require "websocketnetpack"
local skynet = require "skynet"
local protobuf = require "protobuf"
local sharedata = require "sharedata"
local config_manager = require "config_manager"
local redis = require "redis"
local user_info = {}

function user_info:Init(user_id,server_id,channel,locale,client_fd, client_ip)
    self.user_id = user_id
    self.server_id = server_id
    self.channel = channel
    self.locale = locale

    self.client_fd = client_fd
    self.client_ip = client_ip
end

function user_info:LoadFromDb(user_id)
    self.user_id = user_id
    local config = sharedata.query("redis_conf_1")
    local db = redis.connect(config)

    local info_key = "info:"..user_id
    local data_center = {}
    --初始化数据处理模块
    self.data_modules = {}
    for _,file_name in ipairs(config_manager.data_files_config) do
        local mode = require(file_name)
        mode:Init()
        mode:LoadFromDb(data_center,info_key)
        
        self.data_modules[file_name] = mode
    end
    db:disconnect()
end

-------------------------
--保存玩家数据
--------------------------
function user_info:Save()
    local user_info_key = "info:"..self.user_id
    local config = sharedata.query("redis_conf_1")
    local db = redis.connect(config)
    db:multi()
    for _,mode in pairs(self.data_modules) do
        mode:Save(db,self.user_id)
    end
    local ret = db:exec()
    for i, v in ipairs(ret) do
        if not (type(v) == "number" or v == "OK" ) then
            skynet.error("redis save(user_info) index:" .. i .. ",error:" .. v)
            suc = false
        end
    end
    db:disconnect()
end

--重用agent的时候需要重置lua vm中的用户数据
function user_info:Clear()
    for _,module in pairs(self.data_modules) do
        module:Clear()
    end
end

--玩家登出后设置fd为-1,避免登出后仍向该客户端发送数据
function user_info:Logout()
    self.client_fd = -1
    --TODO LogoutLog
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