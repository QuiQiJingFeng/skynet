#!/bin/bash
MODE=$1

#检查config.lua文件是否存在
if [ ! -f "config/conf/config.lua" ]; then
    echo "[ERROR] NO config.lua"
    exit 1
fi

#创建数据文件夹
DATA_DIR_PATH="config/data/"
if [ ! -d "$DATA_DIR_PATH" ]; then
    mkdir "$DATA_DIR_PATH"
fi

#创建日志文件夹
LOG_DIR_PATH="config/log/" 
if [ ! -d "$LOG_DIR_PATH" ]; then
    mkdir "$LOG_DIR_PATH"
fi

ulimit -n 20
#对生成的 core 文件的大小不进行限制。
ulimit -c unlimited

##########更新协议#########
cd proto/
./gen.sh
cd ../

if [ ! -n "$MODE" ]; then
    nohup ./skynet config/conf/config.lua > ./config/log/output.log 2>&1 &
elif [ "$MODE" = "debug" ]; then
    ./skynet config/conf/config.lua
else
    echo "[ERROR] UNKNOW PARAM2 $1"
    exit 1
fi