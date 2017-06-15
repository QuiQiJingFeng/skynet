root = "./"
luaservice = root.."service/?.lua;"..root.."game/?.lua;"..root.."game/?/init.lua"
lualoader = root .. "lualib/loader.lua"
lua_path = root.."lualib/?.lua;"..root.."lualib/?/init.lua"
lua_cpath = root .. "luaclib/?.so"
snax = luaservice

-- preload = "./examples/preload.lua"   -- run preload.lua before every lua service run
thread = 8
logger = "./config/log/log.lua" --skynet.error 输出文件
logpath = "."  --只有logfile不存在 同时运行时调用logon命令 logpath才管用  
harbor = 0
address = "127.0.0.1:2526"
master = "127.0.0.1:2013"
start = "main"  -- main script
bootstrap = "snlua bootstrap"   -- The service for bootstrap
standalone = "0.0.0.0:2013"
-- snax_interface_g = "snax_g"
cpath = root.."cservice/?.so"
-- daemon = "./skynet.pid"

profile = true  --统计每个服务使用了多少 cpu 时间

game_port = 8888
maxclient = 8192

--redis config
game_redis_host = "127.0.0.1" 
game_redis_port = 6379
game_redis_auth = "aamm77"

-- mysql config
mysql_ip = "127.0.0.1"
mysql_user = "root"
mysql_pass = ""
mysql_port = 3306

--protobuf
protobuf = "proto/msg.pb"


server_id = 1

time_zone = 8











