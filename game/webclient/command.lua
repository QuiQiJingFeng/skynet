local skynet = require "skynet"
local sharedata = require "sharedata"
local webclientlib = require "webclient"
local webclient = webclientlib.create()
local requests = nil

local constant_config

local function resopnd(request)
    if not request.response then
        return
    end

    local content, errmsg = webclient:get_respond(request.req)  
    if not errmsg then
        request.response(true, true, content)
    else
        local info = webclient:get_info(request.req) 
        if info.response_code == 200 and not info.content_save_failed then
            request.response(true, true, content, errmsg)
        else
            request.response(true, false, errmsg, info)
        end
    end
end

local function query()
    while next(requests) do
        local finish_key = webclient:query()
        if finish_key then
            local request = requests[finish_key];
            assert(request)

            xpcall(resopnd, function() skynet.error(debug.traceback()) end, request)

            webclient:remove_request(request.req)
            requests[finish_key] = nil
        else
            skynet.sleep(1)
        end
    end 
    requests = nil
end

--- 请求某个url
-- @function request
-- @string url url
-- @tab[opt] get get的参数
-- @param[opt] post post参数，table or string类型 
-- @bool[opt] no_reply 使用skynet.call则要设置为nil或false，使用skynet.send则要设置为true
-- @treturn bool 请求是否成功
-- @treturn string 当成功时，返回内容，当失败时，返回出错原因 
-- @usage skynet.call(webclient, "lua", "request", "http://www.dpull.com")
-- @usage skynet.send(webclient, "lua", "request", "http://www.dpull.com", nil, nil, true)
function request(url, get, post, no_reply)
    if get then
        local i = 0
        for k, v in pairs(get) do
            k = webclient:url_encoding(k)
            v = webclient:url_encoding(v)

            url = string.format("%s%s%s=%s", url, i == 0 and "?" or "&", k, v)
            i = i + 1
        end
    end

    if post and type(post) == "table" then
        local data = {}
        for k,v in pairs(post) do
            k = webclient:url_encoding(k)
            v = webclient:url_encoding(v)

            table.insert(data, string.format("%s=%s", k, v))
        end   
        post = table.concat(data , "&")
    end   

    local req, key = webclient:request(url, post)
    if not req then
        return skynet.ret()
    end
    assert(key)

    local response = nil
    if not no_reply then
        --和 skynet.ret 立刻回应消息不同，skynet.response 返回的是一个 closure 。需要回应消息的时候，调用它即可
        response = skynet.response()
    end

    if requests == nil then
        requests = {}
        skynet.fork(query)
    end

    requests[key] = {
        url = url, 
        req = req,
        response = response,
    }
end
-------------------------------------------|||||||||-----------------------------------------------------

-----------------------------------------------------------------
--生成user_id
--@server_id 区服ID
--@return err,user_id
-----------------------------------------------------------------
local function GeneralId(server_id)
    local max_id = account_redis:incrby("user_id_generator", 1)
    if max_id >= constant_config["MAX_USER_ID"] then
        return constant_config["ERROR_CODE"]["PARAMATER_ERROR"]
    end
    local user_id = tonumber(string.format("%d%07d", server_id, max_id))
    return nil,utils:convertTo32(user_id)
end

-----------------------------------------------------------------
--登录远程校验
--@return err
-----------------------------------------------------------------
local function LoginCheck(account,password,logintype)
    local debug = skynet.getenv("debug")
    if debug then
        return nil
    end

    local content = {
        ["action"] = "login",
        ["account"] = account,
        ["password"] = password
    }

    local recvheader = {}
    local check_server = "127.0.0.1:3000"
    local success, status, body = pcall(httpc.post, check_server, "/login", content, recvheader)
    if not success or status ~= 200 then
        return "false"
    end

    body = cjson.decode(body)
    if body.result == "success" then
        return nil
    end

    return false
end

local command = {}
-----------------------------------------------------------------
--登录模块初始化
-----------------------------------------------------------------
function command:init()
    local conf = sharedata.query("redis_conf_0")
    account_redis = redis.connect(conf)

    if not account_redis:exists("user_id_generator") then
        account_redis:set("user_id_generator", 1)
    end

    constant_config = sharedata.query("constants_config")
end

function command:request(...)
    request(...)
end
 
-----------------------------------------------------------------
--登录处理
--@version  客户端版本号
--@account  账户
--@password 密码
--@platform 平台  appstore/google play/360 store/taptap/...
--@logintype  登录方式 gamecenter/facebook/google/...
--@return err,new_user,user_id
-----------------------------------------------------------------
function command.Login(server_id,version,account,password,platform,logintype)

    local ret = {result = "success"}
    local err = LoginCheck(account,password,logintype)
    if err then
        skynet.error("ERROR_CODE:",err)
        return err
    end

    local user_key = string.format("%s:%s",platform,account)
    local user_id = account_redis:hget(user_key, server_id)
    local new_user = false
    if not user_id then
        local err,user_id = GeneralId(server_id)
        if err then
            skynet.error("ERROR_CODE:",err)
            return err
        end
        account_redis:hset(user_key, server_id, user_id)
        new_user = true
    end

    return nil,new_user,user_id
end 



return command