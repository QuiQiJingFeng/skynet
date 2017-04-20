local sharedata = require "sharedata"

local config_manager = {}

function config_manager:Init()
    self.msg_files = sharedata.query("msg_files")
end

return config_manager