--[[
统计模块 - 负责声音容器使用情况的统计和管理
包含统计数据收集、存储和查询功能
]]

local M = {}

---@class StatisticsManager
---@field container_info table<string, table<string, table>> @ 容器统计信息
local g_stat_container_info = {}

---初始化统计管理器
---@param initial_data table|nil @ 初始数据（从文件加载）
function M.init(initial_data)
    g_stat_container_info = initial_data or {}
end

---记录容器信息统计
---@param container_name string @ 容器名称
---@param trigger_id number @ 触发器ID
---@param event_infos table @ 事件信息列表
function M.record_container_info(container_name, trigger_id, event_infos)
    local trigger_id_str = tostring(trigger_id)
    local info = g_stat_container_info[container_name] or {}
    
    -- 避免重复记录相同的触发器
    if info[trigger_id_str] then
        return
    end
    
    info[trigger_id_str] = event_infos
    g_stat_container_info[container_name] = info
    
    -- 保存到文件
    json.dump_file("sound_debugger/stat_container_info.json", g_stat_container_info, 2)
end

---获取容器统计信息
---@param container_name string @ 容器名称
---@return table|nil @ 容器的统计信息
function M.get_container_info(container_name)
    return g_stat_container_info[container_name]
end

---获取所有统计信息
---@return table @ 所有统计信息
function M.get_all_stats()
    return g_stat_container_info
end

---清空统计信息
function M.clear_stats()
    g_stat_container_info = {}
    json.dump_file("sound_debugger/stat_container_info.json", g_stat_container_info, 2)
end

---获取统计信息计数
---@return number @ 统计的容器数量
function M.get_container_count()
    local count = 0
    for _ in pairs(g_stat_container_info) do
        count = count + 1
    end
    return count
end

return M