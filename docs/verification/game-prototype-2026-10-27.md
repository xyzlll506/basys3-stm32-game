# 游戏原型软件验证

日期：2026-10-27（Asia/Shanghai）。代码位于 `feature/vga-game-prototype` 开发分支；实体板与显示器尚未连接、下载或实测。

## FPGA

工具为 Vivado / XSim 2018.3，目标 `xc7a35tcpg236-1`。

- 25.2 MHz 纯逻辑行为仿真通过：真实 UART 请求 / 回复、合法帧、XOR / 序号 / 保留字段 / 坐标 / flags 检查、半包超时、停止位错误、复位、帧边界提交、链路失效和按键去抖。
- VGA 每帧 800×525=420000 时钟，有效像素 307200；同步窗口和消隐 RGB 检查通过。
- 实际 renderer 导出 640×480 预览，已检查平台、角色、出口、危险区及 HUD。
- 综合、布局布线、BIT 生成通过，DRC 0 项；内部 setup WNS +30.868 ns，hold WHS +0.122 ns。
- 资源：541 LUT、565 FF、0 BRAM、1 MMCM。时钟报告中像素周期 39.683 ns，约 25.2 MHz；MMCM 参数经完整实现验证。

详细结果见 [FPGA 记录](../../fpga/game/VERIFICATION.md)。

## STM32

- Keil ARM Compiler 5.06 update 7 完整重建：0 错误、0 警告。
- Code 7614 B、RO-data 586 B、RW-data 32 B、ZI-data 1224 B。
- 独立游戏 Keil 工程引用 21 个源文件，均为仓库内相对路径。
- 主机 Clang 使用实际纯 C 游戏与协议源码测试：移动、跳跃边沿、禁止空中二跳、屏幕边界、平台顶 / 底 / 侧碰撞、重生、死亡计数饱和、重开及通关。
- 协议测试覆盖数据中的 A5 / 5A、错误 XOR、非法按键位、重复序号、部分帧超时、HAL tick 溢出、序号复位恢复及 255 回绕。
- 从初始化开始只发送按键，179 帧、零死亡通关，未通过直接改坐标绕过路线。

详细结果见 [STM32 记录](../../stm32/GAME_VERIFICATION.txt)。

## 共享关卡与固件

- 关卡生成器的 8 项单元测试通过；JSON 与 C / Verilog 生成头的一致性检查通过。
- 原 UART 的 RTL、C 应用、工程与预编译文件保持不变，供当前实物连接测试使用。
- 游戏 BIT / HEX 已保存并加入根 [SHA256SUMS.txt](../../SHA256SUMS.txt)，和验证构建的校验值一致。

## 边界

主机测试不包含 HAL 驱动和实体 UART 的电气行为；XSim 纯逻辑仿真不实例化 MMCM。MMCM 与内部路径使用 Vivado 实现结果核对，外部连线、显示器兼容性、按键手感和真实时钟偏差仍待实测。

本机没有 Icarus Verilog；`scripts/run_game_hdl_sim.py` 为远端 CI 提供同一游戏测试平台的入口，当前已通过的本地 HDL 仿真来自 XSim。新的 GitHub Actions 执行状态须以对应提交为准。
