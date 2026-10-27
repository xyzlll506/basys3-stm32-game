# Basys 3 + NUCLEO-F413ZH：第一次双板通信

[返回项目首页](../README.md) · [接线示意](images/wiring.svg) · [通信协议](protocol.md)

这一版只做 UART 双向回包。先把接线、下载和通信跑通；暂不需要显示屏、蜂鸣器或额外串口模块。

## 1. 接线：三根线

先断开两块板的供电，再接下面三根线。NUCLEO 的 ST Zio 和 Basys 3 Pmod 都是插孔，使用公对公杜邦线，长度尽量不超过 20 cm。

| NUCLEO-F413ZH 实际接线处 | 方向 | Basys 3 实际接线处 | 含义 |
|---|---|---|---|
| D1 / PG14，CN10 第 14 脚 | → | JA 第 1 脚：JA1 | STM32 TX → FPGA RX |
| D0 / PG9，CN10 第 16 脚 | ← | JA 第 2 脚：JA2 | STM32 RX ← FPGA TX |
| GND，CN10 第 22 脚 | — | JA 第 5 脚：JA5（GND） | 共地 |

Basys 3 JA 第 11 脚也为 GND，可替代第 5 脚。

**只连这三根线，不互连两块板的 3.3V / 5V 电源脚。**JA 第 6、12 脚是 3.3V，不能误当作地线。根据板上 JA、1 和 GND 标记定位，不能按插头照片的方向猜位置。

`J1`、`L2` 是 FPGA 芯片封装脚号，供 XDC 使用；手工接线请找 JA1、JA2，并非去找一个叫 J1 的连接器。

接好后，各自连接电脑 USB：

- Basys 3：标为 PROG 的 Micro-USB 接口，电源选择为 USB，板上电源开关打开。
- NUCLEO-F413ZH：ST-LINK 部分的 CN1 Micro-USB 接口，使用出厂 USB 供电跳线位置。
- 这是 3.3V TTL UART，不需要 RS-232、RS-485 或 USB 转 TTL 模块。

## 2. 软件和工程入口

- FPGA：Vivado 2018.3，器件 `xc7a35tcpg236-1`。
- STM32：Keil MDK + STM32 HAL，器件 `STM32F413ZHT6`。
- STM32 主工程：`stm32/MDK-ARM/nucleo_f413zh_uart.uvprojx`。
- FPGA 一键建工程：`fpga/create_project.tcl`。

建议先直接打开随包工程跑通，再用下节 CubeMX 配置自己重建学习。

## 3. CubeMX 配置对照

若自己新建工程，在 MCU Selector 选择 `STM32F413ZHTx`，LQFP144 封装。使用 Board Selector 选择 NUCLEO-F413ZH 也可以，但需要核对自动启用的外设与下面一致。

| 配置项 | 本次设置 |
|---|---|
| SYS → Debug | Serial Wire，保留 ST-LINK 下载调试 |
| 主时钟 | 内部 HSI 16 MHz；不依赖外部晶振，不使用 PLL |
| Clock Configuration | SYSCLK / HCLK / PCLK1 / PCLK2 均为 16 MHz |
| USART6 模式 | Asynchronous；TX = PG14，RX = PG9，AF8 |
| USART6 参数 | 115200，8 Data Bits，None Parity，1 Stop Bit，TX/RX，None Flow Control，Oversampling 16 |
| USART3 模式 | Asynchronous；TX = PD8，RX = PD9，AF7；用于 ST-LINK 虚拟串口日志 |
| USART3 参数 | 同上，115200 / 8N1 / None Flow Control |
| PB0 | GPIO Output，初始低电平：绿灯 LD1 |
| PB7 | GPIO Output，初始低电平：蓝灯 LD2 |
| PB14 | GPIO Output，初始低电平：红灯 LD3 |
| UART 中断 / DMA | 第一版不启用；使用 HAL 轮询收发 |
| Project Manager → Toolchain / IDE | MDK-ARM V5 |
| Code Generator | 可启用外设各自生成 .c/.h 文件，便于检查 GPIO、USART 配置 |

HSI 时钟选择无需改板上晶振或焊桥。绿灯 PB0 适用于默认焊桥状态；如果板子曾被改为 PA5，优先根据蓝灯、红灯和电脑日志判断结果。

重建工程后，应用层需要包含 `board_link.h`，将 `board_link.c` 加入 Keil 工程及相应头文件搜索路径。在外设初始化完成后调用一次 `BoardLink_Init()`，在 `while (1)` 内持续调用 `BoardLink_Task()`。请与随包 `main.c` 的具体调用一致，不要重复初始化同一串口。CubeMX 重新生成时，应把自己的调用放在 USER CODE 区内。

## 4. Vivado 配置与下载

第一次验证接线时，也可以直接在 Hardware Manager 中下载随包的 `fpga/prebuilt/board_link_top.bit`，这份文件已由本包源码在 Vivado 2018.3 中生成。下面的建工程流程用于查看、修改和重新编译源码。

打开 Vivado，在 Tcl Console 切换到解压后的 `fpga` 文件夹，例如：

```tcl
cd {E:/your_folder/basys3-stm32-game/fpga}
source create_project.tcl
```

之后依次运行 Synthesis、Implementation、Generate Bitstream；也可以按 `fpga` 目录下脚本说明运行批处理构建。

约束只添加 `fpga/constraints/board_link.xdc`。**不要再把 `Basys-3-Master.xdc` 同时加入本工程**；完整版作为以后查开关、按钮、VGA 等接口的参考。

| 顶层信号 | FPGA 封装脚 | 实际硬件 |
|---|---|---|
| 100 MHz 时钟 | W5 | 板载晶振 |
| 中间按键复位 | U18 | btnC |
| UART 接收 | J1 | JA1 |
| UART 发送 | L2 | JA2 |
| LED | U16 等 | 板载 LD0～LD15，详见精简 XDC |

打开 Hardware Manager → Open Target → Auto Connect，选择板上的 FPGA，然后 Program Device，选择本工程生成的 `.bit`。RAM 下载的程序断电会丢失，重新上电需要再次下载；初次实验先使用这种方式。

## 5. Keil 编译与下载

1. 打开 `stm32/MDK-ARM/nucleo_f413zh_uart.uvprojx`。
2. 确认目标器件为 STM32F413ZH，选择本机实际安装的 ARM 编译器版本。
3. Rebuild，确认没有错误。
4. Options for Target → Debug，选择 ST-Link Debugger；Settings 中使用 SW / SWD。
5. Utilities 使用 ST-LINK 下载，下载后 Reset and Run；必要时手动按板上黑色 RESET 键启动。

本次程序烧录由你在确认接线后操作。随包的编译检查不会替你连接或烧录实体板。

## 6. 怎么确认成功

电脑打开 NUCLEO 的 ST-LINK Virtual COM Port，设置 115200 / 8N1、无流控、文本显示。两块板可能各自出现一个 COM 口；日志来自 ST-LINK 对应的端口。

每 500 ms，STM32 发送：

```text
A5  seq  data  checksum
checksum = A5 XOR seq XOR data
```

FPGA 校验成功后回复：

```text
5A  seq  data  checksum
checksum = 5A XOR seq XOR data
```

`seq` 为递增序号，`data` 为本次测试数值；数值到 255 后自然回到 0。

| 位置 | 正常现象 |
|---|---|
| STM32 蓝灯 LD2 / PB7 | 持续闪烁，表示主循环运行 |
| STM32 绿灯 LD1 / PB0 | 收到有效回包后翻转 |
| STM32 红灯 LD3 / PB14 | 正常通信时熄灭；失败时亮 |
| Basys 3 LD0 | 持续闪烁，表示 FPGA 程序运行 |
| Basys 3 LD1 | 每次收到合法请求后翻转 |
| Basys 3 LD2 | 校验错误指示，正常不应变化 |
| Basys 3 LD15～LD8 | 二进制显示最近一次接收的 data |
| 电脑串口 | 周期性输出 PASS 及对应序号、数据 |

FPGA 尚未下载时，STM32 显示 TIMEOUT 是预期现象；下载完成后应在随后几轮请求中恢复。

## 7. 遇到问题时按这个顺序检查

1. **两边没有心跳灯：**分别确认 USB 数据线、供电开关和程序是否下载并运行。
2. **STM32 有日志，FPGA 只有 LD0：**检查 STM32 D1/PG14 → JA1，以及 GND。
3. **FPGA LD1 有变化，STM32 TIMEOUT：**重点检查 JA2 → STM32 D0/PG9 的回程线。
4. **校验错误或偶发异常：**核对两边 115200/8N1，缩短线材、避免松动；不要插到 JA6/JA12。
5. **灯工作但没有电脑日志：**确认使用 ST-LINK CN1、选对 COM 口；检查 USART3 是否配置 PD8/PD9。曾改过焊桥的板子还需要核对 VCP 连接。
6. **Vivado 提示端口不存在：**确认顶层为 `board_link_top`，只加入配套精简 XDC，并使用同一套 Verilog 文件。

通过这个测试后，就可以在此协议基础上增加坐标、按键、人物状态，再把 VGA 绘图模块接入。

## 官方资料

- Digilent Basys 3 Master XDC：https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
- Digilent Basys 3 Reference Manual：https://reference.digilentinc.com/_media/reference/programmable-logic/basys-3/basys3_rm.pdf
- ST UM1974（NUCLEO-F413ZH 接头见 Table 16，印刷页 51～52；LED 见 25 页；VCP 见 27 页）：https://www.st.com.cn/resource/en/user_manual/dm00244518-stm32-nucleo144-boards-mb1137-stmicroelectronics.pdf
- STM32F413ZH 数据手册（USART6 AF8 见复用功能表）：https://www.st.com/resource/en/datasheet/stm32f413zh.pdf

## 验证边界

已实际完成：

- Keil ARM Compiler 5.06 update 7 重建：0 错误、0 警告，生成 HEX。
- Vivado / XSim 2018.3：100 MHz / 115200 baud 串行仿真通过，覆盖合法包、错误校验、A5/5A 数据、部分包超时、波特率偏差、停止位错误、背靠背请求及复位恢复。仿真仅缩短了字节间超时参数以减少运行时间。
- FPGA 综合、布局布线和 bitstream 生成通过，DRC 0 项违规，内部建立时间最差裕量 +4.410 ns、保持时间最差裕量 +0.131 ns。
- 接线表、XDC、STM32 USART6 配置和两侧协议已交叉核对一致。

尚未在你的实体开发板上验证接线和回包，首次下载后请按照第 6 节核对。内部 FPGA 时序检查不替代实际板间连线测试。

本机 Windows CScript 环境限制了 Vivado `launch_runs` 的子任务启动。因此 `build.tcl` 采用已验证的单进程构建方式，不依赖这个机制。如果 GUI 的 Generate Bitstream 在你的电脑上卡住，可在 PowerShell 中从 `fpga` 目录执行：

```powershell
vivado -mode batch -source build.tcl
```

输出在 `fpga/build/board_link_top.bit`。此脚本只编译，不会打开硬件目标或烧录开发板。
