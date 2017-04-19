local sharedata = require "sharedata"

local config_manager = {}

function config_manager:Init()
    self.constant = sharedata.query("constant")
    -- local utils = require "utils"
    -- utils:dump(self.constant,"FYD======",10)
end

return config_manager