local skynet = require "skynet"
local event_dispatcher = require "event_dispatcher"
local utils = require "utils"
local user_info = require "user_info"
local config_manager = require "config_manager"

---------------------------------------------------------------
--查询支付项
---------------------------------------------------------------
event_dispatcher:RegisterEvent("query_product_list",function(recv_msg)
    local ret = {reason = "success"}
    local send_msg = { reason = "success" }
    return "query_product_list_ret",ret
end)