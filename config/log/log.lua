[:01000001] LAUNCH logger ./config/log/log.lua
[:01000002] LAUNCH snlua bootstrap
[:01000003] LAUNCH snlua launcher
[:01000004] LAUNCH snlua cmaster
[:01000004] master listen socket 0.0.0.0:2013
[:01000005] LAUNCH snlua cslave
[:01000005] slave connect to master 127.0.0.1:2013
[:01000006] LAUNCH harbor 1 16777221
[:01000004] connect from 127.0.0.1:59706 4
[:01000004] Harbor 1 (fd=4) report 127.0.0.1:2526
[:01000005] Waiting for 0 harbors
[:01000005] Shakehand ready
[:01000007] LAUNCH snlua datacenterd
[:01000008] LAUNCH snlua service_mgr
[:01000009] LAUNCH snlua main
[:01000009] Server start
[:0100000a] LAUNCH snlua static_data
[:0100000b] LAUNCH snlua sharedatad
[:0100000c] LAUNCH snlua logind
[:0100000d] LAUNCH snlua mysqllog
[:0100000e] LAUNCH snlua debug_console 8000
[:0100000e] Start debug console at 127.0.0.1:8000
[:0100000f] LAUNCH snlua watchdog
[:01000010] LAUNCH snlua gate
[:01000011] LAUNCH snlua agent
[:01000010] Listen on 0.0.0.0:8888
[:01000009] Watchdog listen on 8888
[:01000009] KILL self
[:01000002] KILL self
[:0100000e] 9 connected
[:0100000e] Open log file ./config/logpath//0100000a.log fail
