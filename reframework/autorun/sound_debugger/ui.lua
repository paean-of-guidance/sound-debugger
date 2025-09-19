--[[
UI模块 - 负责声音调试器的界面绘制和交互
包含日志显示、过滤器面板、重播按钮等UI组件
]]

local M = {}

---@class LogData
---@field _unique_id string @ 日志项的唯一标识符
---@field data table @ 事件详情数据
---@field raw_call_params table|nil @ 原始调用参数（用于重播）
---@field call_function_type number @ 调用函数类型

---@class FilterProfile
---@field whitelist_mode boolean @ 是否为白名单模式
---@field banks string[] @ 声音库过滤列表

---@class FilterConfig
---@field enable boolean @ 是否启用过滤
---@field activeProfile string @ 当前激活的过滤配置名称
---@field profiles table<string, FilterProfile> @ 过滤配置列表

-- 引入Core模块用于工具函数
local Core = require("_CatLib")

-- 重播和停止函数的引用
local ManualTriggerFn = Core.TypeMethod("soundlib.SoundContainer", "trigger(System.UInt32)")
local ManualStopTriggeredFn = Core.TypeMethod("soundlib.SoundContainer", "stopTriggered(System.UInt32, via.GameObject, System.UInt32)")

---绘制重播按钮组
---@param call_context table @ 调用上下文信息
---@param unique_id string @ 唯一标识符
---@param manual_trigger_callback function @ 手动触发回调函数
---@param debug_mode boolean @ 是否显示调试信息
function M.draw_replay_buttons(call_context, unique_id, manual_trigger_callback, debug_mode)
    local raw_call_params = call_context.raw_call_params
    if not raw_call_params then
        return
    end
    
    if imgui.button("Replay##" .. unique_id) then
        manual_trigger_callback()
        ManualTriggerFn:call(raw_call_params[1], raw_call_params[2])
    end
    
    imgui.same_line()
    if imgui.button("Stop##" .. unique_id) then
        ManualStopTriggeredFn:call(raw_call_params[1], raw_call_params[2], 0, 0)
    end
    
    if debug_mode then
        local container_name = sdk.to_managed_object(raw_call_params[1]):ToString()
        imgui.text("Container: " .. container_name)
    end
end

---绘制事件详情节点
---@param event_details table @ 事件详情列表
---@param unique_id string @ 唯一标识符
---@param call_context table|nil @ 调用上下文（可选）
---@param manual_trigger_callback function|nil @ 手动触发回调函数
---@param debug_mode boolean @ 是否显示调试信息
function M.draw_event_detail_node(event_details, unique_id, call_context, manual_trigger_callback, debug_mode)
    local typical_bank_name = event_details[1]["wems"][1]["m_bank"]
    local typical_indexes = {}
    
    for _, wem_info in ipairs(event_details[1]["wems"]) do
        table.insert(typical_indexes, wem_info["index"])
    end
    
    -- 检查是否为条件性或随机声音
    local is_conditional = #event_details > 1
    local is_random = event_details[1]["is_random"]
    
    -- 构建节点标题
    local node_title = typical_bank_name .. " "
    for _, index in ipairs(typical_indexes) do
        node_title = node_title .. string.format("[%d]", index)
    end
    
    if is_conditional then
        node_title = node_title .. " {Conditional}"
    end
    if is_random then
        node_title = node_title .. " {Random}"
    end
    node_title = node_title .. "##" .. unique_id
    
    -- 绘制节点
    if imgui.tree_node(node_title) then
        -- 显示触发器ID和事件ID
        local trigger_id = event_details[1]["trigger_id"] or 0
        local event_id = event_details[1]["event_id"] or 0
        
        if imgui.button(string.format("Trigger ID: %d##%s", trigger_id, unique_id)) then
            sdk.copy_to_clipboard(tostring(trigger_id))
        end
        imgui.same_line()
        if imgui.button(string.format("Event ID: %d##%s", event_id, unique_id)) then
            sdk.copy_to_clipboard(tostring(event_id))
        end
        
        -- 显示重播按钮
        if call_context and manual_trigger_callback then
            imgui.text(string.format("Call Type: %s", call_context.call_function_type))
            M.draw_replay_buttons(call_context, unique_id, manual_trigger_callback, debug_mode)
        end
        
        -- 显示详细信息
        for _, event_detail in ipairs(event_details) do
            if is_conditional and event_detail["condition"] then
                imgui.text("Condition: " .. event_detail["condition"])
            end
            if event_detail["is_random"] then
                imgui.text("Random Play")
            end
            
            -- 显示音频列表，包含顺序id和唯一id
            for _, wem_info in ipairs(event_detail["wems"]) do
                imgui.text(string.format("  - %d  %s[%d]", wem_info["wem_id"], wem_info["m_bank"], wem_info["index"]))
            end
        end
        
        imgui.tree_pop()
    end
end

---绘制日志节点
---@param log_data LogData @ 日志数据
---@param manual_trigger_callback function @ 手动触发回调函数
---@param debug_mode boolean @ 是否显示调试信息
function M.draw_log_node(log_data, manual_trigger_callback, debug_mode)
    local unique_id = log_data["_unique_id"]
    local event_details = log_data["data"]
    local call_context = {
        raw_call_params = log_data["raw_call_params"],
        call_function_type = log_data["call_function_type"]
    }
    
    if #event_details > 1 then
        -- 多个结果的情况
        local first_event = event_details[1]
        local typical_bank_name = first_event[1]["wems"][1]["m_bank"]
        local typical_indexes = {}
        
        for _, wem_info in ipairs(first_event[1]["wems"]) do
            table.insert(typical_indexes, wem_info["index"])
        end
        
        local node_title = "{Multiple Results} " .. typical_bank_name
        for _, index in ipairs(typical_indexes) do
            node_title = node_title .. string.format("[%d]", index)
        end
        node_title = node_title .. "..." .. "##" .. unique_id
        
        if imgui.tree_node(node_title) then
            M.draw_replay_buttons(call_context, unique_id, manual_trigger_callback, debug_mode)
            
            for _, event_detail in ipairs(event_details) do
                M.draw_event_detail_node(event_detail, unique_id, nil, nil, debug_mode)
            end
            
            imgui.tree_pop()
        end
    else
        -- 单个结果
        M.draw_event_detail_node(event_details[1], unique_id, call_context, manual_trigger_callback, debug_mode)
    end
end

---绘制过滤器面板
---@param filter FilterConfig @ 过滤器配置
---@return boolean @ 配置是否已更改
function M.draw_filter_panel(filter)
    local config_changed = false
    
    if not imgui.tree_node("Filter") then
        return config_changed
    end
    
    -- Enable filter checkbox
    local changed, value = imgui.checkbox("Enable Filter", filter.enable)
    if changed then
        config_changed = true
        filter.enable = value
    end
    
    -- 获取所有配置文件名称
    local profile_names = {}
    for profile_name, _ in pairs(filter.profiles) do
        table.insert(profile_names, profile_name)
    end
    
    -- New profile button
    if imgui.button("New Profile") then
        local new_name = filter.activeProfile .. "_new"
        while Core.IsInTable(profile_names, new_name) do
            new_name = new_name .. "_new"
        end
        
        -- 深拷贝当前配置
        local current_profile = filter.profiles[filter.activeProfile]
        filter.profiles[new_name] = {
            whitelist_mode = current_profile.whitelist_mode,
            banks = {}
        }
        for i, bank in ipairs(current_profile.banks) do
            filter.profiles[new_name].banks[i] = bank
        end
        
        filter.activeProfile = new_name
        config_changed = true
    end
    
    -- Profile name input box
    local changed, value = imgui.input_text("Profile Name", filter.activeProfile, 256)
    if changed then
        if not Core.IsInTable(profile_names, value) then
            local curr_profile = filter.profiles[filter.activeProfile]
            filter.profiles[filter.activeProfile] = nil
            filter.activeProfile = value
            filter.profiles[value] = curr_profile
            config_changed = true
        end
    end
    
    -- Profile selection dropdown
    local selected_index = 1
    for i, profile_name in ipairs(profile_names) do
        if profile_name == filter.activeProfile then
            selected_index = i
            break
        end
    end
    
    local changed, new_index = imgui.combo("Profile", selected_index, profile_names)
    if changed then
        filter.activeProfile = profile_names[new_index]
        config_changed = true
    end
    
    -- Get current profile
    local profile = filter.profiles[filter.activeProfile]
    if not profile then
        profile = {
            whitelist_mode = false,
            banks = {}
        }
        filter.profiles[filter.activeProfile] = profile
        config_changed = true
    end
    
    -- Whitelist mode checkbox
    local changed, value = imgui.checkbox("Whitelist Mode", profile.whitelist_mode)
    if changed then
        config_changed = true
        profile.whitelist_mode = value
    end
    
    -- Sound bank filter
    imgui.text("Filter by Sound Bank")
    if not profile.banks then
        profile.banks = {}
    end
    
    -- Display existing filters
    for i, bank_name in ipairs(profile.banks) do
        local changed, value = imgui.input_text("##bank_filter" .. tostring(i), bank_name, 256)
        if changed then
            config_changed = true
            profile.banks[i] = value
        end
        
        imgui.same_line()
        if imgui.button("Remove##bank_filter_remove" .. tostring(i)) then
            config_changed = true
            table.remove(profile.banks, i)
            break  -- Avoid modifying table during iteration
        end
    end
    
    -- Add filter button
    if imgui.button("Add Filter") then
        table.insert(profile.banks, "")
        config_changed = true
    end
    
    imgui.tree_pop()
    
    if config_changed then
        filter.profiles[filter.activeProfile] = profile
    end
    
    return config_changed
end

---绘制调试面板
---@param debug_config table @ 调试配置
---@param sound_banks_count number @ 声音库数量
---@param sound_bank_addrs_count number @ 声音库地址数量
---@return boolean @ 配置是否已更改
function M.draw_debug_panel(debug_config, sound_banks_count, sound_bank_addrs_count)
    local config_changed = false
    
    imgui.text("Debug Mode")
    
    local changed, value = imgui.checkbox("Record Unknown Triggers", debug_config.record_trigger)
    if changed then
        debug_config.record_trigger = value
        config_changed = true
    end
    
    local changed, value = imgui.checkbox("Record Unknown Events", debug_config.record_event)
    if changed then
        debug_config.record_event = value
        config_changed = true
    end
    
    if imgui.button("Clear Unknown Items") then
        debug_config.unknown_triggers = {}
        debug_config.unknown_events = {}
        config_changed = true
    end
    
    imgui.text("Sound Banks Count: " .. tostring(sound_banks_count))
    imgui.text("Sound Bank Addresses Count: " .. tostring(sound_bank_addrs_count))
    
    return config_changed
end

return M