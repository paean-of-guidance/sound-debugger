#!/usr/bin/env python3
"""
创建 reframework 目录内容到游戏根目录的硬链接脚本
用于怪物猎人荒野声音调试器模组的部署

使用方法:
    python create_hardlinks.py <游戏根目录路径>
"""

import os
import sys
import argparse
from pathlib import Path


def create_hardlinks(source_dir, target_dir, override=False):
    """
    递归创建源目录到目标目录的硬链接，保持目录结构
    
    Args:
        source_dir (Path): 源目录路径 (reframework)
        target_dir (Path): 目标目录路径 (游戏根目录/reframework)
    """
    created_count = 0
    skipped_count = 0
    error_count = 0
    
    # 确保目标目录存在
    target_dir.mkdir(parents=True, exist_ok=True)
    
    for root, dirs, files in os.walk(source_dir):
        root_path = Path(root)
        
        # 计算相对于源目录的相对路径
        rel_path = root_path.relative_to(source_dir)
        target_root = target_dir / rel_path
        
        # 创建目标目录结构
        target_root.mkdir(parents=True, exist_ok=True)
        
        # 处理当前目录中的所有文件
        for file in files:
            source_file = root_path / file
            target_file = target_root / file
            
            try:
                # 如果目标文件已存在，跳过
                if target_file.exists():
                    if override:
                        print(f"将覆盖已存在的文件: {target_file}")
                        target_file.unlink()
                    else:
                        print(f"跳过已存在的文件: {target_file}")
                        skipped_count += 1
                        continue
                
                # 创建硬链接
                os.link(source_file, target_file)
                print(f"创建硬链接: {source_file} -> {target_file}")
                created_count += 1
                
            except OSError as e:
                print(f"创建硬链接失败 {source_file} -> {target_file}: {e}")
                error_count += 1
    
    return created_count, skipped_count, error_count


def main():
    parser = argparse.ArgumentParser(
        description="创建 reframework 目录内容到游戏根目录的硬链接",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
    python create_hardlinks.py "C:\\Games\\Monster Hunter Wilds"
    python create_hardlinks.py "/home/user/games/mhw"
        """
    )
    parser.add_argument(
        "game_root", 
        help="游戏根目录路径"
    )
    parser.add_argument(
        "-f", 
        action="store_true", 
        help="如果目标文件已存在，覆盖它"
    )
    parser.add_argument(
        "--dry-run", 
        action="store_true", 
        help="仅显示将要执行的操作，不实际创建硬链接"
    )
    
    args = parser.parse_args()
    
    # 验证路径
    game_root = Path(args.game_root).resolve()
    if not game_root.exists():
        print(f"错误: 游戏根目录不存在: {game_root}")
        sys.exit(1)
    
    if not game_root.is_dir():
        print(f"错误: 指定路径不是目录: {game_root}")
        sys.exit(1)
    
    # 获取当前脚本所在目录的 reframework 目录
    script_dir = Path(__file__).parent.resolve()
    reframework_source = script_dir / "reframework"
    
    if not reframework_source.exists():
        print(f"错误: 源 reframework 目录不存在: {reframework_source}")
        print("请确保脚本位于包含 reframework 目录的文件夹中")
        sys.exit(1)
    
    # 目标 reframework 目录
    reframework_target = game_root / "reframework"
    
    print(f"源目录: {reframework_source}")
    print(f"目标目录: {reframework_target}")
    print()
    
    if args.dry_run:
        print("=== 预览模式 (--dry-run) ===")
        print("将要创建的硬链接:")
        
        for root, dirs, files in os.walk(reframework_source):
            root_path = Path(root)
            rel_path = root_path.relative_to(reframework_source)
            target_root = reframework_target / rel_path
            
            for file in files:
                source_file = root_path / file
                target_file = target_root / file
                print(f"  {source_file} -> {target_file}")
        
        print("\n使用不带 --dry-run 参数重新运行以实际创建硬链接")
        return
    
    # 执行硬链接创建
    print("开始创建硬链接...")
    try:
        created, skipped, errors = create_hardlinks(reframework_source, reframework_target, args.f or False)
        
        print(f"\n操作完成!")
        print(f"创建硬链接: {created} 个文件")
        print(f"跳过文件: {skipped} 个文件")
        print(f"错误: {errors} 个文件")
        
        if errors > 0:
            print(f"\n警告: 有 {errors} 个文件创建硬链接时出错，请检查上方错误信息")
            sys.exit(1)
        else:
            print("\n所有文件硬链接创建成功!")
            
    except KeyboardInterrupt:
        print("\n操作被用户中断")
        sys.exit(1)
    except Exception as e:
        print(f"\n发生未预期的错误: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()