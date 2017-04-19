root = "./"
luaservice = root.."service/?.lua;"..root.."game/?.lua;"..root.."game/?/init.lua"
lualoader = root .. "lualib/loader.lua"
lua_path = root.."lualib/?.lua;"..root.."lualib/?/init.lua"
lua_cpath = root .. "luaclib/?.so"
snax = luaservice

-- preload = "./examples/preload.lua"   -- run preload.lua before every lua service run
thread = 8
logger = nil
logpath = "."
harbor = 1
address = "127.0.0.1:2526"
master = "127.0.0.1:2013"
start = "main"  -- main script
bootstrap = "snlua bootstrap"   -- The service for bootstrap
standalone = "0.0.0.0:2013"
-- snax_interface_g = "snax_g"
cpath = root.."cservice/?.so"
-- daemon = "./skynet.pid"

game_port = 8888
maxclient = 8192

--redis config
game_redis_host = "127.0.0.1" 
game_redis_port = 6379
-- game_redis_auth = ""

-- mysql config
mysql_ip = "127.0.0.1"
mysql_user = "root"
mysql_pass = ""
mysql_port = 3306

--protobuf
protobuf = "proto/msg.pb"


server_id = 1

time_zone = 8











