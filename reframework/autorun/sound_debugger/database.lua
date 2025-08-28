--[[
数据库查询模块 - 负责声音事件数据的查询和索引管理
包含触发器映射、事件映射和详细查询功能
]] local M = {}

-- 类型定义和注解
---@class WemInfo
---@field m_bank string @ WEM文件所属的声音库名称
---@field index number @ WEM文件在声音库中的索引

---@class EventDetail
---@field is_random boolean @ 是否为随机声音事件
---@field condition string|nil @ 声音播放条件（可选）
---@field wems WemInfo[] @ WEM文件信息列表
---@field trigger_id number|nil @ 触发器ID（运行时添加）
---@field event_id number|nil @ 事件ID（运行时添加）

---@class EventInfo
---@field event_id number @ 事件ID
---@field bank string @ 声音库名称

---@class TriggerEventIndexMap
---@field [string] table<string, number> @ 声音库名称 -> (触发器ID字符串 -> 事件ID数字)

---@class EventSoundIndexMap  
---@field [string] table<string, EventDetail[]> @ 声音库名称 -> (事件ID字符串 -> 事件详情列表)

-- 数据加载
local trigger_event_indexmap = json.load_file("sound_debugger/trigger_event_indexmap.json") --[[@as TriggerEventIndexMap]]
local event_sound_indexmap = json.load_file("sound_debugger/event_sound_indexmap.json") --[[@as EventSoundIndexMap]]

-- 创建辅助索引映射
-- 触发器ID到声音库的映射（支持一对多关系）
local trigger_to_bank = {} --[[@as table<string, string|string[]>]]

for bank, triggers in pairs(trigger_event_indexmap) do
    for trigger, _ in pairs(triggers) do
        if not trigger_to_bank[trigger] then
            trigger_to_bank[trigger] = bank
        else
            local existing = trigger_to_bank[trigger]
            if type(existing) == "table" then
                table.insert(existing, bank)
            else
                trigger_to_bank[trigger] = {existing, bank}
            end
        end
    end
end

-- 事件ID到声音库的映射（一对一关系）
local event_to_bank = {} --[[@as table<string, string>]]

for bank, event_sounds in pairs(event_sound_indexmap) do
    for event_id, _ in pairs(event_sounds) do
        if not event_to_bank[event_id] then
            event_to_bank[event_id] = bank
        else
            error("冲突的事件ID: " .. tostring(event_id) .. " 在声音库 " .. bank .. " 中")
        end
    end
end

---根据触发器ID获取事件信息
---@param trigger_id number @ 触发器ID
---@return EventInfo[]|nil @ 事件信息列表，如果未找到返回nil
function M.get_event_info_by_trigger_id(trigger_id)
    local bank = trigger_to_bank[tostring(trigger_id)]
    if not bank then
        return nil
    end

    -- 处理一对多的情况
    local banks = type(bank) == "table" and bank or {bank}

    local results = {}
    for _, bank_name in ipairs(banks) do
        local triggers = trigger_event_indexmap[bank_name]
        if triggers then
            local event_id = triggers[tostring(trigger_id)]
            if event_id then
                table.insert(results, {
                    event_id = event_id,
                    bank = bank_name
                })
            end
        end
    end

    return #results > 0 and results or nil
end

---根据声音库名称和事件ID获取事件详细信息
---@param bank string @ 声音库名称
---@param event_id number @ 事件ID
---@return EventDetail[]|nil @ 事件详细信息列表，如果未找到返回nil
function M.get_event_details_by_event_id(bank, event_id)
    local bank_event_sound_data = event_sound_indexmap[bank]
    if not bank_event_sound_data then
        return nil
    end

    local event_infos = bank_event_sound_data[tostring(event_id)]
    return event_infos
end

---根据事件ID获取对应的声音库名称
---@param event_id number @ 事件ID
---@return string|nil @ 声音库名称，如果未找到返回nil
function M.get_bank_by_event_id(event_id)
    return event_to_bank[tostring(event_id)]
end

---查询事件详细信息（综合查询功能）
---@param trigger_id number @ 触发器ID
---@param container_name string @ 容器名称（用于调试输出）
---@param debug_config table @ 调试配置
---@return EventInfo[]|nil, EventDetail[][]|nil @ 返回(事件信息列表, 事件详细信息列表)
function M.query_event_details(trigger_id, container_name, debug_config)
    local event_infos = M.get_event_info_by_trigger_id(trigger_id)
    if not event_infos or #event_infos == 0 then
        if debug_config and not debug_config.unknown_triggers[trigger_id] then
            log.debug("Unknown trigger_id: " .. tostring(trigger_id) .. " container: " .. container_name)
            if debug_config.record_trigger then
                debug_config.unknown_triggers[trigger_id] = true
            end
        end
        return nil, nil
    end

    local results = {}

    for _, event_info in ipairs(event_infos) do
        local event_details = M.get_event_details_by_event_id(event_info.bank, event_info.event_id)
        if not event_details then
            if debug_config and not debug_config.unknown_events[event_info.event_id] then
                log.debug("Unknown event_id: " .. tostring(event_info.event_id) .. " container: " .. container_name)
                if debug_config.record_event then
                    debug_config.unknown_events[event_info.event_id] = true
                end
            end
            goto continue
        end

        -- 过滤出包含WEM文件的事件详情
        local valid_event_details = {}
        for _, event_detail in ipairs(event_details) do
            if #event_detail["wems"] > 0 then
                table.insert(valid_event_details, event_detail)
            end
        end

        if #valid_event_details > 0 then
            table.insert(results, valid_event_details)
        else
            log.debug("Empty wem id for event_id: " .. tostring(event_info.event_id))
        end

        ::continue::
    end

    return event_infos, (#results > 0 and results or nil)
end

---过滤单个事件详情（根据过滤器配置）
---@param event_detail EventDetail[] @ 事件详情列表
---@param filter_profile table @ 过滤器配置
---@return boolean @ 是否通过过滤
local function filter_event_detail_once(event_detail, filter_profile)
    local typical_bank_name = event_detail[1]["wems"][1]["m_bank"]
    local is_match = false

    for _, filter_string in ipairs(filter_profile.banks) do
        if string.find(typical_bank_name, filter_string) then
            is_match = true
            break
        end
    end

    -- return filter_profile.whitelist_mode and is_match or not is_match
    if filter_profile.whitelist_mode then
        return is_match
    else
        return not is_match
    end
end

---过滤事件详情列表
---@param event_details EventDetail[][] @ 事件详情列表的列表
---@param filter_config table @ 过滤器配置
---@return boolean @ 是否通过过滤
function M.filter_event_details(event_details, filter_config)
    if not filter_config.enable then
        return true
    end

    local filter_profile = filter_config.profiles[filter_config.activeProfile]
    if not filter_profile then
        return true
    end

    if #event_details == 1 then
        return filter_event_detail_once(event_details[1], filter_profile)
    else
        -- 多个结果的情况
        local pass = not filter_profile.whitelist_mode -- 黑名单模式默认通过，白名单模式默认不通过

        for _, event_detail in ipairs(event_details) do
            if filter_profile.whitelist_mode then
                -- 白名单模式：任意一个匹配即通过
                if filter_event_detail_once(event_detail, filter_profile) then
                    pass = true
                    break
                end
            else
                -- 黑名单模式：任意一个不通过即拒绝
                if not filter_event_detail_once(event_detail, filter_profile) then
                    pass = false
                    break
                end
            end
        end

        return pass
    end
end

return M
