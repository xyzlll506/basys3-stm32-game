# 第三方来源与许可

本文件提供来源索引，实际条款以各文件版权头及随附原始许可为准。未将整个仓库统一声明为某种开源许可。

## STM32CubeF4 1.28.3

以下文件来自 STM32CubeF4 1.28.3，本仓库只包含当前 Keil 工程所需部分。

| 范围 | 来源 / 说明 | 随附许可 |
|---|---|---|
| `stm32/Drivers/STM32F4xx_HAL_Driver/` | ST STM32F4 HAL，保留原始头部和目录许可 | [组件许可](stm32/Drivers/STM32F4xx_HAL_Driver/LICENSE.txt)、[包级条款](stm32/Package_license.md) |
| `stm32/Drivers/CMSIS/Include/` | Arm CMSIS 核心头文件 | [CMSIS 许可](stm32/Drivers/CMSIS/LICENSE.txt)及文件版权头 |
| `stm32/Drivers/CMSIS/Device/ST/STM32F4xx/` | ST 器件头和 F413 启动文件 | [器件许可](stm32/Drivers/CMSIS/Device/ST/STM32F4xx/LICENSE.txt)、[包级条款](stm32/Package_license.md) |
| `stm32/Core/Src/system_stm32f4xx.c` 等带 ST 声明的模板 | 按文件头原有声明处理，保留模板许可 | [模板许可](stm32/LICENSE_ST_TEMPLATE.txt)、[包级条款](stm32/Package_license.md) |

上游：[STMicroelectronics/STM32CubeF4](https://github.com/STMicroelectronics/STM32CubeF4)。包级许可涉及的其他组件不表示全部包含在本仓库中。

## Digilent Master XDC

- 文件：`fpga/constraints/Basys-3-Master.xdc`。
- 来源：[Digilent/digilent-xdc](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc)。
- 上游采用 MIT License，Copyright (c) 2017 Digilent；原文保存在 [Digilent-LICENSE.txt](fpga/constraints/Digilent-LICENSE.txt)。
- 当前精简 `board_link.xdc` 使用相同板级引脚资料，保留上述来源和许可。

完整 XDC 作为引脚参考，当前构建脚本只加入精简 XDC。

## 构建工具

Vivado、Keil、设备包及其安装程序不包含在本仓库中，使用者自行安装。预编译 BIT / HEX 的工具版本及校验值记录于各侧验证文件和根 `SHA256SUMS.txt`。
