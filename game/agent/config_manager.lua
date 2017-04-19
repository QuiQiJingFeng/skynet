local sharedata = require "sharedata"

local config_manager = {}

function config_manager:Init()
    self.constant = sharedata.query("constant")
end

return config_manager