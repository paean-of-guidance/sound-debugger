--[[
工具函数模块 - 包含通用的工具函数和辅助方法
]]

local M = {}

local constants = require("sound_debugger.constants")

---生成唯一ID
---@return string @ 随机生成的唯一标识符
function M.generate_unique_id()
    return tostring(math.random(1, 10000000))
end

---管理日志队列大小
---@param log_queue table @ 日志队列
---@return table @ 清理后的日志队列
function M.manage_log_queue_size(log_queue)
    if #log_queue >= constants.LOG_QUEUE_CONFIG.MAX_SIZE then
        local new_queue = {}
        local start_index = constants.LOG_QUEUE_CONFIG.MAX_SIZE - constants.LOG_QUEUE_CONFIG.TRIM_SIZE
        
        for i = start_index, constants.LOG_QUEUE_CONFIG.MAX_SIZE do
            if log_queue[i] then
                table.insert(new_queue, log_queue[i])
            end
        end
        
        return new_queue
    end
    
    return log_queue
end

---深拷贝表
---@param original table @ 原始表
---@return table @ 拷贝后的表
function M.deep_copy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = M.deep_copy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

---合并表（浅拷贝）
---@param target table @ 目标表
---@param source table @ 源表
---@return table @ 合并后的目标表
function M.merge_tables(target, source)
    for key, value in pairs(source) do
        target[key] = value
    end
    return target
end

---检查表中是否包含指定值
---@param tbl table @ 要检查的表
---@param value any @ 要查找的值
---@return boolean @ 是否包含该值
function M.table_contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

---从表中移除指定值
---@param tbl table @ 要操作的表
---@param value any @ 要移除的值
---@return boolean @ 是否成功移除
function M.table_remove_value(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

---格式化触发器ID和事件ID的显示文本
---@param trigger_id number|nil @ 触发器ID
---@param event_id number|nil @ 事件ID
---@return string, string @ 格式化后的触发器ID文本和事件ID文本
function M.format_ids_for_display(trigger_id, event_id)
    local trigger_text = trigger_id and string.format("trigger_id: %d", trigger_id) or "trigger_id: Unknown"
    local event_text = event_id and string.format("event_id: %d", event_id) or "event_id: Unknown"
    return trigger_text, event_text
end

---验证过滤器配置的有效性
---@param filter_config table @ 过滤器配置
---@return boolean @ 配置是否有效
function M.validate_filter_config(filter_config)
    if type(filter_config) ~= "table" then
        return false
    end
    
    if type(filter_config.enable) ~= "boolean" then
        return false
    end
    
    if type(filter_config.activeProfile) ~= "string" then
        return false
    end
    
    if type(filter_config.profiles) ~= "table" then
        return false
    end
    
    for profile_name, profile in pairs(filter_config.profiles) do
        if type(profile) ~= "table" then
            return false
        end
        
        if type(profile.whitelist_mode) ~= "boolean" then
            return false
        end
        
        if type(profile.banks) ~= "table" then
            return false
        end
    end
    
    return true
end

---安全地获取嵌套表中的值
---@param tbl table @ 源表
---@param ... string @ 键的路径
---@return any @ 找到的值，如果路径不存在则返回nil
function M.safe_get(tbl, ...)
    local current = tbl
    local keys = {...}
    
    for _, key in ipairs(keys) do
        if type(current) ~= "table" or current[key] == nil then
            return nil
        end
        current = current[key]
    end
    
    return current
end

---记录错误信息到调试日志
---@param message string @ 错误信息
---@param context string|nil @ 上下文信息
function M.log_error(message, context)
    local full_message = context and string.format("[%s] %s", context, message) or message
    log.debug("Error: " .. full_message)
end

---记录调试信息
---@param message string @ 调试信息
---@param context string|nil @ 上下文信息
function M.log_debug(message, context)
    local full_message = context and string.format("[%s] %s", context, message) or message
    log.debug(full_message)
end

return M