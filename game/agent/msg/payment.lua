local skynet = require "skynet"
local event_dispatcher = require "event_dispatcher"
local utils = require "utils"
local user_info = require "user_info"
local config_manager = require "config_manager"
---------------------------------------------------------------
--查询支付项
---------------------------------------------------------------
event_dispatcher:RegisterEvent("query_product_list",function(recv_msg)
    local ret = {result = "success"}
    local products_config = config_manager.products_config
    local ptype = recv_msg.type
    if not ptype then
        ret.result = "ptype_is_nil"
        return "query_product_list_ret",ret
    end
    local product_type = config_manager.constants_config["PRODUCTS_TYPE"][ptype]
    ret.good_list = {}
    for i,data in pairs(products_config) do
        local item = {}
        item.good_id = data.good_id
        local product_key = product_type.."_product_id"
        item.product_id = data[product_key]
        item.name = data.name
        item.price = data.price
        item.num = data.num
        item.first_pay_gift = data.first_pay_gift
        item.gift = data.gift
    end

    return "query_product_list_ret",ret
end)