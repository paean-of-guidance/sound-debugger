# Sound Debugger for Monster Hunter Wilds

A REFramework mod for real-time sound event monitoring and debugging in Monster Hunter Wilds.

## Prerequisites

- [REFramework](https://github.com/praydog/REFramework)
- [CatLib](https://www.nexusmods.com/monsterhunterwilds/mods/65)

## Installation

1. Copy `reframework` folder to game's root directory.
2. Launch Monster Hunter Wilds
3. Access the tool via REFramework overlay => "Script Generated UI" => "Sound Debugger"

## Important Notes

- **Database Dependency**: This mod relies on sound databases extracted from game resources ([data/sound_debugger](data/sound_debugger))
- **Version Compatibility**: Database must be updated with game patches - using outdated versions may result in inaccurate sound mapping

## Features

- Real-time sound event monitoring
- Interactive sound playback/stopping
- Simple sound bank filtering (whitelist/blacklist)
- Trigger ID ↔ Event ID ↔ WEM file cross-referencing

> [!WARNING]  
> Playback some effect audio may crash your game.

---

# 怪物猎人荒野声音调试器

怪物猎人荒野的REFramework模组，用于实时声音事件监控和调试。

## 前置依赖

- [REFramework](https://github.com/praydog/REFramework)
- [CatLib](https://www.nexusmods.com/monsterhunterwilds/mods/65)

## 安装方法

1. 将 `reframework` 复制到游戏根目录
2. 启动怪物猎人荒野
3. 通过 REFramework 覆盖层 => "Script Generated UI" => "Sound Debugger" 访问界面

## 重要说明

- **数据库依赖**: 本模组依赖从游戏资源提取的声音数据库 ([data/sound_debugger](data/sound_debugger))
- **版本兼容性**: 数据库需要随游戏更新而更新 - 使用旧版本可能导致声音映射不准确

## 功能特性

- 实时声音事件监控
- 交互式声音播放/停止
- 声音库过滤（白名单/黑名单）
- 触发器ID ↔ 事件ID ↔ WEM文件交叉引用
