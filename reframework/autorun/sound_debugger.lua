local VERSION = "1.0.0-beta11 (2025-07-05)"

local Core = require("_CatLib")

local mod = Core.NewMod("Sound Debugger")

local trigger_event_indexmap = json.load_file("sound_debugger/trigger_event_indexmap.json")
local event_sound_indexmap = json.load_file("sound_debugger/event_sound_indexmap.json")

local ManualTriggerFn = Core.TypeMethod("soundlib.SoundContainer", "trigger(System.UInt32)")
local RequestInfoTriggerFn = Core.TypeMethod("soundlib.SoundContainer", "trigger(soundlib.SoundManager.RequestInfo)")
local ManualStopTriggeredFn = Core.TypeMethod("soundlib.SoundContainer",
    "stopTriggered(System.UInt32, via.GameObject, System.UInt32)")

local g_log_queue = {}
local g_is_manual_trigger = false

-- bank_name -> SoundContainer.Obj
local g_sound_banks = {}
-- to filter stored bank addr
local g_sound_bank_addrs = {}

local g_stat_container_info = json.load_file("sound_debugger/stat_container_info.json") or {}

local g_dbg = {
    unknown_triggers = {},
    unknown_events = {},
    record_trigger = true,
    record_event = true
}

local CALL_FUNCTION_TYPE = {
    General = 0,
    WithVec3 = 1,
    RequestInfo = 2
}

-- -- create helper indexmaps
-- -- one trigger_id to one or multiple event_ids!
-- local trigger_to_bank = {}
-- for bank, triggers in pairs(trigger_event_indexmap) do
--     for trigger, _ in pairs(triggers) do
--         if not trigger_to_bank[trigger] then
--             trigger_to_bank[trigger] = bank
--         else
--             local exist_elem = trigger_to_bank[trigger]
--             if type(exist_elem) == "table" then
--                 table.insert(exist_elem, bank)
--             else
--                 exist_elem = {exist_elem, bank}
--             end
--             trigger_to_bank[trigger] = exist_elem
--         end
--     end
-- end

local event_to_bank = {}
for bank, event_sounds in pairs(event_sound_indexmap) do
    for event_id, _ in pairs(event_sounds) do
        if not event_to_bank[event_id] then
            event_to_bank[event_id] = bank
        else
            error("conflict event_id: " .. tostring(event_id) .. " in " .. bank)
        end
    end
end

-- ---@param trigger_id number
-- ---@return table | nil
-- local function get_event_info_by_trigger_id(trigger_id)
--     local bank = trigger_to_bank[tostring(trigger_id)]
--     if not bank then
--         return nil
--     end
--     -- one or multiple banks
--     if type(bank) ~= "table" then
--         bank = {bank}
--     end

--     local results = {}
--     for _, bank_name in ipairs(bank) do
--         local triggers = trigger_event_indexmap[bank_name]
--         if not triggers then
--             goto continue
--         end

--         local event_id = triggers[tostring(trigger_id)]
--         if not event_id then
--             goto continue
--         end

--         table.insert(results, {
--             event_id = event_id,
--             bank = bank_name
--         })

--         ::continue::
--     end

--     return results
-- end

---@param bank string
---@param event_id number
local function get_event_details_by_event_id(bank, event_id)
    local bank_event_sound_data = event_sound_indexmap[bank]
    if not bank_event_sound_data then
        return nil
    end

    local event_infos = bank_event_sound_data[tostring(event_id)]
    if not event_infos then
        return nil
    end

    return event_infos
end

-- ---@param trigger_id number
-- ---@return table | nil @ return: (event_info_list, event_details_list)
-- local function query_event_details(trigger_id, container_name)
--     local event_infos = get_event_info_by_trigger_id(trigger_id)
--     if not event_infos or #event_infos == 0 then
--         if not g_dbg.unknown_triggers[trigger_id] then
--             log.debug("Unknown trigger: " .. tostring(trigger_id) .. " caller " .. container_name)
--             if g_dbg.record_trigger then
--                 g_dbg.unknown_triggers[trigger_id] = true
--             end
--         end
--         return
--     end

--     local results = {}

--     for _, event_info in ipairs(event_infos) do
--         local event_details = get_event_details_by_event_id(event_info.bank, event_info.event_id)
--         if not event_details then
--             if not g_dbg.unknown_triggers[event_info.event_id] then
--                 log.debug("Unknown event_id: " .. tostring(event_info.event_id) .. " caller " .. container_name)
--                 if g_dbg.record_trigger then
--                     g_dbg.unknown_triggers[event_info.event_id] = true
--                 end
--             end
--             goto continue
--         end

--         local retain_event_details = {}
--         for _, event_detail in ipairs(event_details) do
--             -- filter out empty wems
--             if #event_detail["wems"] > 0 then
--                 table.insert(retain_event_details, event_detail)
--             end
--         end
--         event_details = retain_event_details
--         if #event_details == 0 then
--             log.debug("Empty wems for event_id: " .. tostring(event_info.event_id))
--             goto continue
--         end

--         table.insert(results, event_details)
--         ::continue::
--     end

--     return event_infos, results
-- end

---@return boolean @ is_pass
local function _filter_event_detail_once(event_detail, filter_profile)
    local typical_bank_name = event_detail[1]["wems"][1]["m_bank"]
    local is_match = false
    for _, filter_string in ipairs(filter_profile.banks) do
        if string.find(typical_bank_name, filter_string) then
            is_match = true
            break
        end
    end
    if filter_profile.whitelist_mode then
        return is_match
    else
        return not is_match
    end
end

-- --- Filter event details
-- --- for multiple results,
-- --- whitelist: any match | blacklist: all match
-- ---@param event_details table
-- ---@return boolean
-- local function filter_event_details(event_details)
--     if not mod.Config.filter.enable then
--         return true
--     end
--     if #event_details == 1 then
--         local event_detail = event_details[1]
--         local filter_profile = mod.Config.filter.profiles[mod.Config.filter.activeProfile]
--         return _filter_event_detail_once(event_detail, filter_profile)
--     else
--         -- multiple results
--         local filter_profile = mod.Config.filter.profiles[mod.Config.filter.activeProfile]
--         local pass = false
--         if not filter_profile.whitelist_mode then
--             pass = true
--         end
--         for _, event_detail in ipairs(event_details) do
--             if filter_profile.whitelist_mode then
--                 if _filter_event_detail_once(event_detail, filter_profile) then
--                     pass = true
--                     break
--                 end
--             else
--                 if not _filter_event_detail_once(event_detail, filter_profile) then
--                     -- any not pass = drop
--                     pass = false
--                     break
--                 end
--             end
--         end
--         return pass
--     end
-- end

-- local function stat_container_info(container_name, trigger_id, event_infos)
--     local trigger_id = tostring(trigger_id)
--     local info = g_stat_container_info[container_name] or {}
--     if info[trigger_id] then
--         return
--     end
--     info[trigger_id] = event_infos

--     g_stat_container_info[container_name] = info
--     json.dump_file("sound_debugger/stat_container_info.json", g_stat_container_info, 2)
-- end

-- local function on_sound_trigger(payload)
--     local args = payload.args
--     local call_function_type = payload.call_function_type

--     if g_is_manual_trigger then
--         g_is_manual_trigger = false
--         return
--     end

--     local trigger_id = sdk.to_int64(args[3]) & 0xFFFFFFFF
--     local container_name = sdk.to_managed_object(args[2]):ToString()

--     -- -- DEBUG
--     -- if trigger_id == 1367558461 then
--     --     log.debug(string.format("DEBUG trigger_id: %d, container: %s", trigger_id, container_name))
--     -- end

--     local event_infos, event_details = query_event_details(trigger_id, container_name)
--     if not event_details or #event_details == 0 then
--         return
--     end

--     -- data statistics
--     -- store sound container name
--     if mod.Config.Debug then
--         stat_container_info(container_name, trigger_id, event_infos)
--     end
--     -- local container_name = sdk.to_managed_object(args[2]):ToString()
--     -- log.debug("Container name: " .. container_name)
--     -- if not g_sound_bank_addrs[container_name] and #event_details == 1 then
--     --     log.debug("Store sound bank addr: " .. container_name)
--     --     g_sound_bank_addrs[container_name] = true
--     --     log.debug("Store sound bank: " .. key or "nil")
--     --     -- g_sound_banks[key] = args[2]
--     -- end

--     local wtf_arg = sdk.to_int64(args[6]) & 0xFFFFFFFF
--     if wtf_arg ~= 4294967295 then
--         -- if wtf_arg ~= 0 then
--         log.debug(string.format("wtf arg: %d, trigger_id: %d, container: %s", wtf_arg, trigger_id, container_name))
--     end

--     -- use filter
--     if not filter_event_details(event_details) then
--         return
--     end

--     local raw_call_params
--     if call_function_type == CALL_FUNCTION_TYPE.General then
--         raw_call_params = {args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11],
--                            args[12], args[13]}
--     elseif call_function_type == CALL_FUNCTION_TYPE.WithVec3 then
--         raw_call_params = {args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]}
--     end
--     table.insert(g_log_queue, {
--         _unique_id = tostring(math.random(1, 10000000)),
--         data = event_details,
--         raw_call_params = raw_call_params,
--         call_function_type = call_function_type
--     })

--     if #g_log_queue >= 500 then
--         local new_queue = {}
--         for i = 300, 500 do
--             table.insert(new_queue, g_log_queue[i])
--         end
--         g_log_queue = new_queue
--     end
-- end

-- mod.HookFunc("soundlib.SoundContainer",
--     "trigger(System.UInt32, via.GameObject, via.GameObject, System.UInt32, System.Boolean, System.UInt32, via.simplewwise.CallbackType, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>)",
--     function(args)
--         on_sound_trigger({
--             args = args,
--             call_function_type = CALL_FUNCTION_TYPE.General
--         })
--     end)

-- -- 带坐标的，例如铳枪换弹掉落的弹壳声
-- mod.HookFunc("soundlib.SoundContainer",
--     "trigger(System.UInt32, via.vec3, via.GameObject, System.UInt32, via.simplewwise.CallbackType, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>, System.Action`1<soundlib.SoundManager.RequestInfo>)",
--     function(args)
--         on_sound_trigger({
--             args = args,
--             call_function_type = CALL_FUNCTION_TYPE.WithVec3
--         })
--     end)

mod.HookFunc("soundlib.SoundContainer", "trigger(soundlib.SoundManager.RequestInfo)", function(args)
    if g_is_manual_trigger then
        g_is_manual_trigger = false
        return
    end

    local request_info = sdk.to_managed_object(args[3])
    local trigger_id = request_info:get_TriggerId()
    local event_id = request_info:get_EventId()

    local bank = event_to_bank[tostring(event_id)]
    if not bank then
        log.debug("Unknown event_id: " .. tostring(event_id))
        return
    end

    local event_detail = get_event_details_by_event_id(bank, event_id)
    local retain_event_details = {}
    for _, event_detail in ipairs(event_detail) do
        -- filter out empty wems
        if #event_detail["wems"] > 0 then
            table.insert(retain_event_details, event_detail)
        end
    end
    event_detail = retain_event_details
    if #event_detail == 0 then
        log.debug("Empty wems for event_id: " .. tostring(event_id))
        return
    end

    -- use filter
    if mod.Config.filter.enable then
        local filter_profile = mod.Config.filter.profiles[mod.Config.filter.activeProfile]
        if not _filter_event_detail_once(event_detail, filter_profile) then
            return
        end
    end

    local raw_call_params = {args[2], trigger_id}
    table.insert(g_log_queue, {
        _unique_id = tostring(math.random(1, 10000000)),
        data = {event_detail},
        raw_call_params = raw_call_params,
        call_function_type = CALL_FUNCTION_TYPE.RequestInfo
    })

    if #g_log_queue >= 500 then
        local new_queue = {}
        for i = 300, 500 do
            table.insert(new_queue, g_log_queue[i])
        end
        g_log_queue = new_queue
    end
end)

local function _draw_replay_buttons(call_context, unique_id)
    local raw_call_params = call_context.raw_call_params
    local call_function_type = call_context.call_function_type
    if raw_call_params then
        if imgui.button("Replay##" .. unique_id) then
            g_is_manual_trigger = true
            ManualTriggerFn:call(raw_call_params[1], raw_call_params[2])
        end
        imgui.same_line()
        if imgui.button("Stop##" .. unique_id) then
            ManualStopTriggeredFn:call(raw_call_params[1], raw_call_params[2], 0, 0)
        end
        if mod.Config.Debug then
            local container_name = sdk.to_managed_object(raw_call_params[1]):ToString()
            imgui.text(container_name)
        end
    end
end

local function _draw_event_detail_node(event_details, unique_id, call_context)
    local typical_bank_name = event_details[1]["wems"][1]["m_bank"]
    local typical_indexes = {}
    for _, wem_info in ipairs(event_details[1]["wems"]) do
        table.insert(typical_indexes, wem_info["index"])
    end

    local conditional = false
    if #event_details > 1 then
        conditional = true
    end

    local node_title = typical_bank_name .. " "
    for _, index in ipairs(typical_indexes) do
        node_title = node_title .. string.format("[%d]", index)
    end
    if conditional then
        node_title = node_title .. " {C?}"
    end
    if event_details[1]["is_random"] then
        node_title = node_title .. " {R}"
    end
    -- unique id
    node_title = node_title .. "##" .. unique_id

    -- node start
    if not imgui.tree_node(node_title) then
        return
    end

    if call_context then
        _draw_replay_buttons(call_context, unique_id)
    end

    for _, event_detail in ipairs(event_details) do
        if conditional then
            imgui.text("Condition " .. (event_detail["condition"] or "nil"))
        end
        if event_detail["is_random"] then
            imgui.text("Random")
        end
        for _, wem_info in ipairs(event_detail["wems"]) do
            imgui.text("  - " .. string.format("%s[%d]", wem_info["m_bank"], wem_info["index"]))
        end
    end

    imgui.tree_pop()
end

local function draw_log_node(log_data)
    local unique_id = log_data["_unique_id"]
    local event_details = log_data["data"]
    local call_context = {
        raw_call_params = log_data["raw_call_params"],
        call_function_type = log_data["call_function_type"]
    }

    if #event_details > 1 then
        -- multiple results
        local event = event_details[1]
        local typical_bank_name = event[1]["wems"][1]["m_bank"]
        local typical_indexes = {}
        for _, wem_info in ipairs(event[1]["wems"]) do
            table.insert(typical_indexes, wem_info["index"])
        end

        local node_title = "{M} "
        node_title = node_title .. typical_bank_name
        for _, index in ipairs(typical_indexes) do
            node_title = node_title .. string.format("[%d]", index)
        end
        node_title = node_title .. "..." .. "##" .. unique_id
        if imgui.tree_node(node_title) then
            _draw_replay_buttons(call_context, unique_id)
            for _, event_detail in ipairs(event_details) do
                _draw_event_detail_node(event_detail, unique_id, nil)
            end
            imgui.tree_pop()
        end
    elseif #event_details == 1 then
        _draw_event_detail_node(event_details[1], unique_id, call_context)
    end
end

---@param filter table
---@return boolean @ changed
local function draw_filter_panel(filter)
    local configChanged = false

    if not imgui.tree_node("Filter") then
        return configChanged
    end

    local changed, value = imgui.checkbox("Enable Filter", filter.enable)
    if changed then
        configChanged = true
        filter.enable = value
    end

    local profile_names = {}
    for profile_name, _ in pairs(filter.profiles) do
        table.insert(profile_names, profile_name)
    end

    if imgui.button("New Profile") then
        local new_name = filter.activeProfile .. "_new"
        while Core.IsInTable(profile_names, new_name) do
            new_name = new_name .. "_new"
        end
        -- TODO: fix shallow copy
        filter.profiles[new_name] = filter.profiles[filter.activeProfile]
        filter.activeProfile = new_name
        configChanged = true
    end

    local changed, value, _, _ = imgui.input_text("Profile Name", filter.activeProfile, 256)
    if changed then
        -- update profile name
        if not Core.IsInTable(profile_names, value) then
            local curr_profile = filter.profiles[filter.activeProfile]
            filter.profiles[filter.activeProfile] = nil
            filter.activeProfile = value
            filter.profiles[value] = curr_profile
            configChanged = true
        end
    end

    local p_index = 1
    for i, profile_name in ipairs(profile_names) do
        if profile_name == filter.activeProfile then
            p_index = i
            break
        end
    end
    local changed, p_index = imgui.combo("Profile", p_index, profile_names)
    if changed then
        filter.activeProfile = profile_names[p_index]
        configChanged = true
    end

    local profile = filter.profiles[filter.activeProfile]
    if not profile then
        profile = {
            whitelist_mode = false,
            banks = {}
        }
        filter.profiles[filter.activeProfile] = profile
        configChanged = true
    end

    local changed, value = imgui.checkbox("Whitelist Mode", profile.whitelist_mode)
    if changed then
        configChanged = true
        profile.whitelist_mode = value
    end
    imgui.text("Filter by Bank")
    if not profile.banks then
        profile.banks = {}
    end
    for i, bank_name in ipairs(profile.banks) do
        local changed, value, _, _ = imgui.input_text("##bank_filter" .. tostring(i), bank_name, 256)
        if changed then
            configChanged = true
            profile.banks[i] = value
        end
        imgui.same_line()
        if imgui.button("X##bank_filter_remove" .. tostring(i)) then
            configChanged = true
            table.remove(profile.banks, i)
        end
    end
    if imgui.button("Add Filter") then
        table.insert(profile.banks, "")
    end

    imgui.tree_pop()

    if configChanged then
        filter.profiles[filter.activeProfile] = profile
    end

    return configChanged
end

mod.Menu(function()
    imgui.text("Version v" .. VERSION)
    imgui.text("Author: Eigeen")
    imgui.text("Github: https://github.com/eigeen")

    local configChanged = false

    if mod.Config.Debug then
        imgui.text("Debug mode")
        local changed, value = imgui.checkbox("Record unknown triggers", g_dbg.record_trigger)
        if changed then
            g_dbg.record_trigger = value
        end
        local changed, value = imgui.checkbox("Record unknown events", g_dbg.record_event)
        if changed then
            g_dbg.record_event = value
        end
        if imgui.button("Clear unknowns") then
            g_dbg.unknown_triggers = {}
            g_dbg.unknown_events = {}
        end
        imgui.text("g_sound_banks size: " .. tostring(#g_sound_banks))
        imgui.text("g_sound_bank_addrs size: " .. tostring(#g_sound_bank_addrs))
    end

    -- if imgui.button("Remove") then
    if not mod.Config.filter then
        mod.Config.filter = {
            enable = false,
            activeProfile = "default",
            profiles = {
                default = {
                    whitelist_mode = false,
                    banks = {}
                }
            }
        }
        configChanged = true
    end
    if draw_filter_panel(mod.Config.filter) then
        configChanged = true
    end
    -- end

    imgui.text("g_log_queue size: " .. tostring(#g_log_queue))

    if imgui.button("Clear Logs") then
        g_log_queue = {}
    end

    if imgui.tree_node("Logs") then
        -- draw logs, reverse order
        for i = #g_log_queue, 1, -1 do
            local log_data = g_log_queue[i]
            draw_log_node(log_data)
        end
        imgui.tree_pop()
    end

    return configChanged
end)
