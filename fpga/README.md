# Basys 3 FPGA 工程

当前实现为 UART 请求校验与回包，用于验证 Basys 3 和 NUCLEO-F413ZH 的双向连接。VGA 时序、图形绘制和游戏模块尚未实现。

| 项目 | 配置 |
|---|---|
| 开发板 | Digilent Basys 3 |
| FPGA | `xc7a35tcpg236-1` |
| 已验证工具 | Vivado / XSim 2018.3，Windows |
| 综合顶层 | `board_link_top` |
| 时钟 | 板载 100 MHz，`clk100` / W5 |
| 复位 | 中间按键 `btnC` / U18；另有上电复位 |
| UART | 115200 baud，8N1，3.3 V TTL |
| 接收 | JA1，封装脚 J1；接 STM32 PG14 / TX |
| 发送 | JA2，封装脚 L2；接 STM32 PG9 / RX |

完整接线和首次下载流程见 [上手文档](../docs/getting-started.md)，报文格式见 [通信协议](../docs/protocol.md)。两块板必须共地，并各自通过 USB 供电。

## 文件入口

- `rtl/board_link_top.v`：复位、报文解析、回复队列和 LED 指示。
- `rtl/uart_rx.v`：异步输入同步、起始位采样、数据接收和停止位检查。
- `rtl/uart_tx.v`：UART 发送器。
- `constraints/board_link.xdc`：本工程实际使用的引脚和时钟约束。
- `constraints/Basys-3-Master.xdc`：Digilent 官方完整约束参考，保留供以后查 VGA、按键等引脚使用。
- `sim/tb_board_link.sv`：串行链路与报文仿真。
- `prebuilt/board_link_top.bit`：已由当前初开发源码生成的下载文件。

**本工程只启用 `board_link.xdc`。不要同时加入完整 Master XDC。** J1、L2 是 FPGA 封装引脚名，接杜邦线时应找到板上 JA1、JA2。

## 创建图形界面工程

在已经配置好 Vivado 命令环境的终端中，从仓库根目录运行：

```powershell
vivado -mode batch -source fpga/create_project.tcl -tclargs build/fpga-project
```

之后打开 `build/fpga-project/board_link.xpr`。若从 Vivado Tcl Console 使用，在 `fpga` 目录执行 `source create_project.tcl`，默认输出为 `fpga/project/board_link.xpr`。

## 从源码构建 bitstream

从仓库根目录运行：

```powershell
vivado -mode batch -source fpga/build.tcl -tclargs build/fpga
```

主要输出为 `build/fpga/board_link_top.bit`，并产生时序、DRC、资源使用报告及布线检查点。脚本检查内部建立时间裕量，发现负裕量时停止。

`build.tcl` 使用单进程综合、布局布线和 bitstream 生成流程，已在 Vivado 2018.3 中验证；无需依赖 Windows Script Host 启动 `launch_runs` 子任务。不传 `-tclargs` 时，默认输出到 `fpga/build/`。

## 运行仿真

从仓库根目录运行：

```powershell
vivado -mode batch -source fpga/sim.tcl -tclargs build/fpga-sim
```

脚本运行 XSim，并检查日志是否出现 `PASS: UART framing`。仿真使用实际 100 MHz 时钟和 115200 波特率，仅缩短测试中的字节间超时参数来减少运行时间。

覆盖合法收发、A5/5A 数据、错误校验后的恢复、部分包超时、约 ±2% 的发送端波特率偏差、背靠背请求、停止位错误和半包期间复位。

## 下载与观察

在 Vivado Hardware Manager 中连接自己的 Basys 3，选择 `prebuilt/board_link_top.bit` 或自己构建的 `.bit`，再执行 Program Device。上述构建与仿真脚本不会打开硬件目标或自动下载。

| LED | 含义 |
|---|---|
| LD0 | 每 500 ms 翻转，表示 FPGA 程序运行 |
| LD1 | 每收到一帧合法请求翻转 |
| LD2 | 每发生错误校验或 UART 停止位错误翻转 |
| LD15～LD8 | 最近一次合法请求的 `data` |
| LD7～LD3 | 固定为 0 |

按 btnC 清除状态。RAM 下载程序断电后丢失，再次上电需要重新下载。

既有构建与仿真结果见 [验证记录](VERIFICATION.txt)。这些检查尚未包含实体双板接线与回包测试；内部时序报告也不代表外部跳线已验证。
