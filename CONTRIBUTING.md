# 开发与提交

当前工作重点是先在实体板上确认 UART 回包，再接入 VGA。阶段安排见 [开发路线](docs/roadmap.md)。

## 修改范围

- FPGA 逻辑放在 `fpga/rtl/`，板级端口变化同时更新精简 XDC 和接线文档。
- STM32 应用放在 `stm32/Core/`。CubeMX 重建时，保留 USER CODE 区并核对 USART6 PG14 / PG9。
- 保持协议两侧一致；变更字段、校验或超时后，更新 [协议说明](docs/protocol.md) 和仿真。
- `stm32/Drivers/` 为随附第三方代码；如确需修改，记录来源、版本和变更，并保留原始版权声明。

## 提交前

1. 运行 `python scripts/check_repo.py`，检查工程引用、文档链接和预编译文件。
2. 修改 RTL 后运行 UART 仿真；涉及时钟、引脚或资源后重新运行 Vivado 实现，记录 timing 和 DRC。
3. 修改 C 或 Keil 配置后在 MDK 重建。不要把 GNU 编译或静态检查写成 Keil 链接已通过。
4. 涉及硬件行为时写清开发板型号、接线、软件版本及实际现象，区分仿真与实测。
5. 查看 `git diff --check` 和 `git status`，不要提交缓存、调试器个人设置或凭据。

## 预编译文件

`fpga/prebuilt/board_link_top.bit` 与 `stm32/firmware/nucleo_f413zh_uart.hex` 是初次上板用的已验证快照，不会随源码自动更新。更新它们时，必须同时更新 `SHA256SUMS.txt` 和对应的构建验证记录，说明使用的工具及源码提交。普通开发产物保存到被忽略的构建目录。

提交说明写清具体变更和验证结果。PR 可使用仓库模板。
