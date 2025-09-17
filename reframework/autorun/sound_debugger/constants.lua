--[[
常量和类型定义模块 - 包含声音调试器的所有常量定义和类型注解
]]

local M = {}

-- 版本信息
M.VERSION = "1.0.0-beta11 (2025-09-17)"

-- 调用函数类型枚举
M.CALL_FUNCTION_TYPE = {
    General = 0,        -- 通用触发
    WithVec3 = 1,       -- 带坐标触发（如弹壳声）
    RequestInfo = 2     -- 请求信息触发
}

-- 日志队列配置
M.LOG_QUEUE_CONFIG = {
    MAX_SIZE = 500,     -- 最大队列长度
    TRIM_SIZE = 200     -- 队列清理后保留的数量（从第300项开始保留200项）
}

-- 默认过滤器配置
M.DEFAULT_FILTER_CONFIG = {
    enable = false,
    activeProfile = "default",
    profiles = {
        default = {
            whitelist_mode = false,
            banks = {}
        }
    }
}

-- 默认调试配置
M.DEFAULT_DEBUG_CONFIG = {
    unknown_triggers = {},
    unknown_events = {},
    record_trigger = true,
    record_event = true
}

return M