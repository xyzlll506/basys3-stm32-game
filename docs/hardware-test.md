# 第一次实物测试：接线与 UART 回包

本步骤验证两块实体板能否可靠收发数据。使用原 UART 测试程序；游戏原型使用另一组工程，等本步骤通过后再切换。

## 1. 断电接三根线

准备三根 2.54 mm 公对公杜邦线，尽量短于 20 cm。先拔掉两块板的 USB 和其他电源，再接：

| STM32 NUCLEO-F413ZH | 方向 | Basys 3 |
|---|---|---|
| D1 / PG14，CN10 第 14 脚，USART6_TX | → | JA1，JA 第 1 脚，FPGA RX |
| D0 / PG9，CN10 第 16 脚，USART6_RX | ← | JA2，JA 第 2 脚，FPGA TX |
| GND，CN10 第 22 脚 | — | JA5，JA 第 5 脚，GND |

NUCLEO 端优先按 D1、D0、GND 丝印核对。Basys 3 端根据 JA、引脚 1 标记和板卡资料确认编号；示意图不是实物朝向，不能按照片左边或右边猜。

JA11 也是 GND，可以替代 JA5。JA6、JA12 是 3.3 V 电源，不能当作 GND。两块板只互连信号和地，不互连 3.3 V / 5 V。

![接线示意，非实物朝向](images/wiring.svg)

`J1`、`L2` 是 XDC 中的 FPGA 封装脚名称，实际插线位置分别是 JA1、JA2。

## 2. 各自接 USB 供电

- Basys 3：连接标为 PROG 的 Micro-USB，确认 USB 供电选择和板上电源开关。
- NUCLEO-F413ZH：连接 ST-LINK 部分 CN1 的 Micro-USB，保留出厂 USB 供电跳线配置。
- 两根 USB 都使用可传数据的线，分别接电脑；板间 UART 是 3.3 V TTL，不需要额外 USB 转 TTL 模块。

本步骤只需要两块板、USB 和三根杜邦线。

## 3. 下载原 UART 测试程序

| 部分 | 本步骤使用的文件 |
|---|---|
| Basys 3 | [`fpga/prebuilt/board_link_top.bit`](../fpga/prebuilt/board_link_top.bit) |
| STM32 Keil 工程 | [`stm32/MDK-ARM/nucleo_f413zh_uart.uvprojx`](../stm32/MDK-ARM/nucleo_f413zh_uart.uvprojx) |
| STM32 对应预编译 HEX | [`stm32/firmware/nucleo_f413zh_uart.hex`](../stm32/firmware/nucleo_f413zh_uart.hex) |

Vivado 打开 Hardware Manager → Auto Connect → Program Device，选择上述 UART BIT。Keil 打开 UART 工程，Rebuild 后选择 ST-Link Debugger、SW / SWD，再下载并运行。完整软件步骤见 [上手文档](getting-started.md)。

这两份是配对的 UART 测试程序，不要一边下载 UART、一边下载游戏工程。

## 4. 查看结果

打开 STM32 ST-LINK 对应的虚拟 COM 口，设置 115200 / 8N1、无流控、文本显示。

```text
PASS seq=0 data=0x00
PASS seq=1 data=0x01
PASS seq=2 data=0x02
```

约每 500 ms 一条。STM32 蓝灯显示请求尝试，绿灯显示有效回包，红灯正常时熄灭；Basys 3 LD0 为心跳，LD1 随有效请求翻转。

如果 STM32 已运行而 FPGA 尚未下载，先出现 TIMEOUT 属于预期现象。两边都运行后仍持续 TIMEOUT，则检查 TX/RX 是否交叉、GND 是否接通、是否插错 JA 引脚。

建议先连续观察一分钟。通过后可单独按两块板的复位键，检查随后能否重新出现 PASS。每次调整跳线前先断电。

## 5. 通信通过后再切换游戏

游戏工程沿用这三根连接线，另接兼容 640×480@60 Hz 的 VGA 显示器。下一步见 [游戏原型说明](game-prototype.md)。

编译和仿真记录已经存在，但实体接线是否通过，必须根据本步骤的实际输出记录；本仓库不会把尚未观察到的实物结果写成通过。
