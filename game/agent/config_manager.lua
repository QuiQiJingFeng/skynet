local sharedata = require "sharedata"

local config_manager = {}

function config_manager:Init()
    self.msg_files_config = sharedata.query("msg_files_config")
    self.constants_config = sharedata.query("constants_config")
end

return config_manager