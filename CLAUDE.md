# CLAUDE.md

此文件为 Claude Code (claude.ai/code) 提供本代码库的工作指导。

## 项目概述

这是一个**怪物猎人荒野**的声音调试工具，以**REFramework 模组**形式实现。通过交互式界面实现游戏声音事件的实时监控和操作。

## 架构说明

### 核心组件

- **sound_debugger.lua**: 主模组文件（REFramework 自动运行脚本）
- **JSON 索引映射**: 声音事件数据库（`event_sound_indexmap.json`, `trigger_event_indexmap.json`）
- **统计收集**: 运行时声音容器使用情况跟踪

### 关键数据结构

- **trigger_event_indexmap.json**: 映射声音库 → 触发器ID → 事件ID
- **event_sound_indexmap.json**: 映射声音库 → 事件ID → 详细声音配置（WEM文件、条件、随机标志）
- **g_log_queue**: 运行时触发的声音事件缓冲区（500条限制，滚动窗口）
- **g_sound_banks**: 运行时声音容器缓存

### 函数钩子

模组钩取三个主要声音触发方法：
1. `soundlib.SoundContainer.trigger(System.UInt32, ...)` - 通用声音触发
2. `soundlib.SoundContainer.trigger(System.UInt32, via.vec3, ...)` - 基于位置的触发（如弹壳声）
3. `soundlib.SoundContainer.trigger(soundlib.SoundManager.RequestInfo)` - 高级请求式触发

## 开发命令

### 测试方法
- 安装到 REFramework 的 `autorun` 文件夹
- 启动怪物猎人荒野
- 通过 REFramework 覆盖层 → "声音调试器" 访问
- 在菜单中启用调试模式以记录未知触发器/事件

### 测试文件

使用 data_example 目录下的摘要文件作为样例，以防数据文件过大和误修改数据。

### 数据分析
- 声音日志实时显示在模组界面中
- 调试模式启用时记录未知触发器/事件
- 容器使用统计保存到 `stat_container_info.json`

### 配置管理
- 可在界面中创建/重命名过滤器配置文件
- 声音库过滤支持白名单/黑名单模式
- 调试设置可切换未知触发器/事件记录

## 文件结构

```
reframework/
├── autorun/sound_debugger.lua          # 主模组脚本
├── data/sound_debugger/
│   ├── event_sound_indexmap.json       # 事件到声音映射
│   ├── trigger_event_indexmap.json     # 触发器到事件映射
│   └── stat_container_info.json        # 运行时统计（自动生成）
```

## 技术说明

- 使用 **CatLib** 框架构建模组结构
- 实现已记录声音的**手动重播/停止**功能
- **内存高效**: 500条滚动日志缓冲区
- **声音库过滤**: 支持复杂声音库名称模式
- **条件/随机声音**: 界面中的视觉指示器
- **交叉引用**: 触发器ID ↔ 事件ID ↔ WEM声音文件