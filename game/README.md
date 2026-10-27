# 共用关卡定义

`level.json` 是 STM32 碰撞逻辑和 FPGA 画面绘制使用的共同关卡来源。修改平台、危险区、出口或出生点后，在仓库根目录执行：

```powershell
python scripts/generate_level.py
python scripts/generate_level.py --check
```

第一条生成 `generated/level.h` 和 `generated/level.vh`；第二条只检查 JSON 是否有效、生成文件是否齐全且与 JSON 一致。检查失败返回非零退出码，不会改文件。不要单独修改生成文件。

## 当前原型约定

| 项目 | 数值 |
|---|---|
| 逻辑画面 | 640 × 480 |
| 玩家碰撞框 | 16 × 24，坐标为左上角 |
| 出生点 | (40, 416) |
| 实心平台 | 5 个，含地板 |
| 危险区 | 1 个，位于地板上 |
| 出口 | (580, 113)，20 × 32 |

坐标、尺寸必须是整数，布尔值不作为整数接受。矩形以 `x, y, w, h` 描述，右边界和下边界不包含在矩形内部；仅贴边不算重叠。

生成器检查矩形尺寸与画面边界、出生点是否与障碍重叠，以及出口处是否有支撑平台和足够的无障碍站立空间。这些静态检查不能证明整条路线一定可通过；跳跃高度、速度、碰撞和实际通关仍由游戏测试验证。

这一版渲染器约定 5 个平台槽位和 1 个危险区槽位，因此生成器明确限制这些数量及玩家大小，避免修改 JSON 后只有一块板接受了变化。扩展数量或角色尺寸时，应同时修改两侧实现和生成器约束。

## 两侧如何使用

- C：包含 `level.h`；尺寸和数量为 `LEVEL_*` 宏，`LEVEL_PLATFORMS` / `LEVEL_HAZARDS` 可直接初始化 `{x, y, w, h}` 结构体数组。
- Verilog：包含 `level.vh`；各矩形分别提供 `` `LEVEL_PLATFORM_0_X ``、`` `LEVEL_PLATFORM_0_Y ``、`` `LEVEL_PLATFORM_0_W ``、`` `LEVEL_PLATFORM_0_H `` 等宏。
- 编译器的 include 搜索路径必须包含 `game/generated/`，两侧构建脚本负责配置。

生成器只依赖 Python 标准库。测试命令：

```powershell
python -m unittest discover -s tests -p test_level_generator.py
```

测试覆盖生成与新鲜度检查、缺失文件、非法尺寸和坐标、数量限制、出生点冲突以及出口站立空间。
