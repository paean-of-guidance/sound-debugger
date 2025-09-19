--[[
怪物猎人荒野声音调试器 - 主模组文件
通过REFramework模组实现游戏声音事件的实时监控和操作

作者: Eigeen
Github: https://github.com/eigeen
]] -- 引入依赖模块
local Core = require("_CatLib")
local constants = require("sound_debugger.constants")
local database = require("sound_debugger.database")
local ui = require("sound_debugger.ui")
local statistics = require("sound_debugger.statistics")
local utils = require("sound_debugger.utils")

-- 初始化模组
local mod = Core.NewMod("Sound Debugger")

-- 钩取函数定义
local ManualTriggerFn = Core.TypeMethod("soundlib.SoundContainer", "trigger(System.UInt32)")
local RequestInfoTriggerFn = Core.TypeMethod("soundlib.SoundContainer", "trigger(soundlib.SoundManager.RequestInfo)")
local ManualStopTriggeredFn = Core.TypeMethod("soundlib.SoundContainer",
    "stopTriggered(System.UInt32, via.GameObject, System.UInt32)")

-- 全局状态管理
local g_log_queue = {}
local g_is_manual_trigger = false
local g_sound_banks = {}
local g_sound_bank_addrs = {}

-- 防止重复事件记录的状态
local g_recent_trigger_info = {
    caller = nil,
    trigger_id = nil
}

-- 调试配置初始化
local g_debug_config = utils.merge_tables({}, constants.DEFAULT_DEBUG_CONFIG)

-- 统计模块初始化
local initial_stats = json.load_file("sound_debugger/stat_container_info.json")
statistics.init(initial_stats)

---处理声音触发事件的统一处理函数
---@param payload table @ 包含参数和调用类型的载荷
local function on_sound_trigger(payload)
    local args = payload.args
    local call_function_type = payload.call_function_type

    -- 忽略手动触发的事件
    if g_is_manual_trigger then
        g_is_manual_trigger = false
        return
    end

    local trigger_id = sdk.to_int64(args[3]) & 0xFFFFFFFF
    local container_name = sdk.to_managed_object(args[2]):ToString()

    -- 避免重复钩子调用
    if g_recent_trigger_info.caller ~= call_function_type and g_recent_trigger_info.trigger_id == trigger_id then
        return
    end
    g_recent_trigger_info.caller = call_function_type
    g_recent_trigger_info.trigger_id = trigger_id

    -- 查询事件详细信息
    local event_infos, event_details = database.query_event_details(trigger_id, container_name, g_debug_config)
    if not event_details or #event_details == 0 then
        return
    end

    -- 统计信息收集
    if mod.Config.Debug then
        statistics.record_container_info(container_name, trigger_id, event_infos)
    end

    -- 调试信息：检查特殊参数
    local special_arg = sdk.to_int64(args[6]) & 0xFFFFFFFF
    if special_arg ~= 4294967295 then
        utils.log_debug(string.format("special_arg: %d, trigger_id: %d, container: %s", special_arg, trigger_id,
            container_name), "SoundTrigger")
    end

    -- 应用过滤器
    if mod.Config.filter and mod.Config.filter.enable then
        if not database.filter_event_details(event_details, mod.Config.filter) then
            return
        end
    end

    -- 构建原始调用参数
    local raw_call_params
    if call_function_type == constants.CALL_FUNCTION_TYPE.General then
        raw_call_params = {args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11],
                           args[12], args[13]}
    elseif call_function_type == constants.CALL_FUNCTION_TYPE.WithVec3 then
        raw_call_params = {args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]}
    end

    -- 为事件详情添加触发器ID
    for _, event_detail in ipairs(event_details) do
        for _, item in ipairs(event_detail) do
            item["trigger_id"] = trigger_id
            item["event_id"] = nil
        end
    end

    -- 添加到日志队列
    table.insert(g_log_queue, {
        _unique_id = utils.generate_unique_id(),
        data = event_details,
        raw_call_params = raw_call_params,
        call_function_type = call_function_type
    })

    -- 管理队列大小
    g_log_queue = utils.manage_log_queue_size(g_log_queue)
end

---处理RequestInfo类型的声音触发
---@param args table @ 函数调用参数
local function on_request_info_trigger(args)
    if g_is_manual_trigger then
        g_is_manual_trigger = false
        return
    end

    local request_info = sdk.to_managed_object(args[3])
    local trigger_id = request_info:get_TriggerId()
    local event_id = request_info:get_EventId()

    -- 避免重复钩子调用
    if g_recent_trigger_info.caller ~= constants.CALL_FUNCTION_TYPE.RequestInfo and g_recent_trigger_info.trigger_id ==
        trigger_id then
        return
    end
    g_recent_trigger_info.caller = constants.CALL_FUNCTION_TYPE.RequestInfo
    g_recent_trigger_info.trigger_id = trigger_id

    -- 查询事件详情
    local banks = database.get_bank_by_event_id(event_id)
    if not banks then
        utils.log_error("unknown event_id: " .. tostring(event_id), "RequestInfoTrigger")
        return
    end

    -- 处理一对多的情况
    local banks_list = type(banks) == "table" and banks or {banks}

    -- 过滤并处理事件详情
    local valid_event_details = {}
    for _, bank_name in ipairs(banks_list) do
        local event_details = database.get_event_details_by_event_id(bank_name, event_id)
        if event_details then
            for _, event_detail in ipairs(event_details) do
                if #event_detail["wems"] > 0 then
                    event_detail["trigger_id"] = trigger_id
                    event_detail["event_id"] = event_id
                    table.insert(valid_event_details, event_detail)
                end
            end
        end
    end

    if #valid_event_details == 0 then
        utils.log_debug("Empty wem id for event_id: " .. tostring(event_id), "RequestInfoTrigger")
        return
    end

    -- 应用过滤器
    if mod.Config.filter and mod.Config.filter.enable then
        if not database.filter_event_details({valid_event_details}, mod.Config.filter) then
            return
        end
    end

    -- 添加到日志队列
    local raw_call_params = {args[2], trigger_id}
    table.insert(g_log_queue, {
        _unique_id = utils.generate_unique_id(),
        data = {valid_event_details},
        raw_call_params = raw_call_params,
        call_function_type = constants.CALL_FUNCTION_TYPE.RequestInfo
    })

    -- 管理队列大小
    g_log_queue = utils.manage_log_queue_size(g_log_queue)
end

-- 钩取声音触发函数
mod.HookFunc("soundlib.SoundContainer",
    "trigger(System.UInt32, via.GameObject, via.GameObject, System.UInt32, System.Boolean, System.UInt32, via.simplewwise.CallbackType, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>)",
    function(args)
        on_sound_trigger({
            args = args,
            call_function_type = constants.CALL_FUNCTION_TYPE.General
        })
    end)

-- 钩取带坐标的声音触发函数（例如弹壳声）
mod.HookFunc("soundlib.SoundContainer",
    "trigger(System.UInt32, via.vec3, via.GameObject, System.UInt32, via.simplewwise.CallbackType, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>)",
    function(args)
        on_sound_trigger({
            args = args,
            call_function_type = constants.CALL_FUNCTION_TYPE.WithVec3
        })
    end)

-- 钩取RequestInfo类型的触发函数
mod.HookFunc("soundlib.SoundContainer", "trigger(soundlib.SoundManager.RequestInfo)", on_request_info_trigger)

-- 手动触发回调函数
local function manual_trigger_callback()
    g_is_manual_trigger = true
end

-- 模组菜单界面
mod.Menu(function()
    imgui.text("Version v" .. constants.VERSION)
    imgui.text("Author: Eigeen")
    imgui.text("Github: https://github.com/eigeen")

    local config_changed = false

    -- 调试面板
    if mod.Config.Debug then
        if ui.draw_debug_panel(g_debug_config, #g_sound_banks, #g_sound_bank_addrs) then
            config_changed = true
        end
    end

    -- 初始化过滤器配置
    if not mod.Config.filter then
        mod.Config.filter = utils.deep_copy(constants.DEFAULT_FILTER_CONFIG)
        config_changed = true
    end

    -- 过滤器面板
    if ui.draw_filter_panel(mod.Config.filter) then
        config_changed = true
    end

    -- Log information display
    imgui.text("Log queue size: " .. tostring(#g_log_queue))

    if imgui.button("Clear Log") then
        g_log_queue = {}
    end

    -- Log display area
    if imgui.tree_node("Log") then
        -- 按逆序显示日志（最新的在前）
        for i = #g_log_queue, 1, -1 do
            local log_data = g_log_queue[i]
            ui.draw_log_node(log_data, manual_trigger_callback, mod.Config.Debug or false)
        end
        imgui.tree_pop()
    end

    return config_changed
end)
