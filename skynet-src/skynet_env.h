#ifndef SKYNET_ENV_H
#define SKYNET_ENV_H

const char * skynet_getenv(const char *key);
void skynet_setenv(const char *key, const char *value);

void skynet_env_init();

#endif
/*
    说明:
        这是一个专门用来存储环境变量的模块
        本模块会创建一个lua虚拟机用来存储环境变量
        只允许添加环境变量,不允许对环境变量进行修改
*/