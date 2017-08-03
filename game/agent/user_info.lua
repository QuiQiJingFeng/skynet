local socket = require "socket"
local netpack = require "websocketnetpack"
local skynet = require "skynet"
local protobuf = require "protobuf"
local sharedata = require "sharedata"
local config_manager = require "config_manager"
local redis = require "redis"
local cjson = require "cjson"
local user_info = {}

function user_info:Init(fd,ip,user_id,server_id,platform,logintype,locale)
    self.client_fd = fd
    self.client_ip = ip
    self.user_id = user_id
    self.server_id = server_id
    self.platform = platform
    self.logintype = logintype
    self.locale = locale
end

function user_info:LoadDefault()
    self.data_center = {}
    self.data_center.base_info = {
        user_id=self.user_id,
        card_num = 0,
        user_name = "",
        role_id = nil,
    }
end

-------------------------
--加载玩家数据
--------------------------
function user_info:LoadFromDb(user_id)
    self.user_id = user_id
    local config = sharedata.query("redis_conf_1")
    local db = redis.connect(config)

    local info_key = "info:" .. self.user_id
    if not db:exists(info_key) then
        db:disconnect()
        return false
    end

    local content = db:hgetall(info_key)
    for i = 1, #content, 2 do
      local key = content[i]
      local value = content[i+1]
      self.data_center[key] = cjson.decode(value)
    end
    db:disconnect()
    return true
end

-------------------------
--保存玩家数据
--------------------------
function user_info:Save()
    local config = sharedata.query("redis_conf_1")
    local db = redis.connect(config)
    db:multi()
    local info_key = "info:" .. self.user_id
    for key,value in pairs(self.data_center) do
        local content = cjson.encode(value)
        db:hmset(info_key,key,content)
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