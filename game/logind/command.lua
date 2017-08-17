local skynet = require "skynet"
local redis = require "redis"
local utils = require "utils"
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
-- @usage skynet.call(webclient, "lua", "Request", "http://www.dpull.com")
-- @usage skynet.send(webclient, "lua", "Request", "http://www.dpull.com", nil, nil, true)
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

--登录校验配置
local LOGIN_OPTION = {
    ["FYDGAMES"] = {
        method = "POST",
        url = "127.0.0.1:3000/login",
        post = '{"action":"login","account":"%s","password"="%s"}',
        check = {result = true}
    }
}

-----------------------------------------------------------------
--生成user_id
--@server_id 区服ID
--@return err,user_id
-----------------------------------------------------------------
local function GeneralId(server_id)
    local max_id = account_redis:incrby("user_id_generator", 1)
    if max_id >= constant_config["MAX_USER_ID"] then
        return constant_config["ERROR_CODE"]["OVER_MAX_ID"]
    end
    local user_id = tonumber(string.format("%d%07d", server_id, max_id))
    return nil,utils:convertTo32(user_id)
end

--检查tb2中是否存在和tb1一样的key
local function compare(tb1,tb2)
    for k,v in pairs(tb1) do
        if type(v) == "table" and type(tb2[k]) == "table" then
            return compare(v,tb2[k])
        elseif v == tb2[k] then
            return true
        end
    end
end

-----------------------------------------------------------------
--登录远程校验
--@return err
-----------------------------------------------------------------
local function LoginCheck(account,password,logintype)
    local check_error = nil
    local debug = skynet.getenv("debug")
    if debug then
        return check_error
    end

    local option = LOGIN_OPTION[logintype]
    if not option then
        check_error = constant_config["ERROR_CODE"]["ERROR_LOGIN_TYPE"]
        return check_error
    end
    local get,post,url
    if option.method == "POST" then
        local post_str = string.format(option.post,account,password)
        local content = cjson.decode(post_str)
        post = content
        url = option.url
    elseif option.method == "GET" then
        local get_str = string.format(option.get,account,password)
        local content = cjson.decode(get_str)
        get = content
        url = option.url
    end
 
    local success,content = request(url,get,post)
    if not success then
        skynet.error("ERROR: ",content)
        check_error = constant_config["ERROR_CODE"]["HTTP_ERROR"]
        return check_error
    end

    body = cjson.decode(content)
    local check = compare(option.check,body)

    if check then
        check_error = nil
        return check_error
    else
        check_error = constant_config["ERROR_CODE"]["LOGIN_CHECK_ERROR"]
        return check_error
    end
end

local command = {}
-----------------------------------------------------------------
--登录模块初始化
-----------------------------------------------------------------
function command.Init()
    local conf = sharedata.query("redis_conf_0")
    account_redis = redis.connect(conf)

    if not account_redis:exists("user_id_generator") then
        account_redis:set("user_id_generator", 1)
    end

    constant_config = sharedata.query("constants_config")
end

function command.Request(...)
    request(...)
end
 
-----------------------------------------------------------------
--登录处理
--@account  账户
--@password 密码
--@platform 平台  appstore/google play/360 store/taptap/...
--@logintype  登录方式 gamecenter/facebook/google/...
--@return err,new_user,user_id
-----------------------------------------------------------------
function command.Login(server_id,account,password,platform,logintype)
    local response = skynet.response()

    local err = LoginCheck(account,password,logintype)
    if err then
        skynet.error("ERROR_CODE:",err)
        response(true,err)
        return 
    end
    local user_key = string.format("%s:%s",platform,account)
    local user_id = account_redis:hget(user_key, server_id)
    local new_user = false
    if not user_id then
        err,user_id = GeneralId(server_id)
        if err then
            skynet.error("ERROR_CODE:",err)
            response(true,err)
            return
        end
        account_redis:hset(user_key, server_id, user_id)
        new_user = true
    end

    response(true,nil,new_user,user_id)
end 

return command