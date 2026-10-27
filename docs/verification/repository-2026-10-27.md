# Git 仓库整理验证

日期：2026-10-27（Asia/Shanghai）。

本次将 UART 初开发包整理为独立仓库，保留原 RTL、应用逻辑、精简约束及预编译固件。新增 README、协议、开发路线、上传指南、Git 忽略规则和自动检查。

## 检查结果

- Keil 工程的 19 个源文件、头文件目录及 scatter 文件均使用有效的仓库内相对路径。
- 修正 `.uvprojx` 中遗留的 RTE 目标名称，改为与当前 `NUCLEO_F413ZH_UART` 一致。
- 修正后，在临时副本用 ARM Compiler 5.06 update 7 完整重建：0 错误、0 警告；Code 7248 B、RO-data 528 B、RW-data 24 B、ZI-data 1168 B。
- `python scripts/check_repo.py` 检查通过：工程引用、预编译 BIT / HEX 校验值、Intel HEX 记录、本项目文档本地链接、SVG XML 及第三方许可文件。
- 已核对 `.gitignore` 排除 Vivado / Keil 构建缓存，并保留明确提供的预编译 BIT / HEX。
- 检查了项目源码和预编译 BIT：未发现本机用户目录、登录令牌或私钥。

第三方导入文件保留原始排版，包括部分行尾空格；Git 的空白检查对这些文件单独关闭，原创文件继续检查。

## 验证边界

原 FPGA 的 XSim、实现和时序结果见 [初开发记录](uart-starter-2026-10-27.txt) 和 [FPGA 记录](../../fpga/VERIFICATION.txt)。本次没有修改 RTL，也没有重复运行 FPGA 构建。

GitHub Actions 的仓库检查和 Icarus 仿真已配置；远端执行须等首次推送。当前 Windows 没有安装 Icarus，因此本地尚未运行 Icarus；已通过的 HDL 仿真来自 XSim。

本次未连接、下载或测试实体开发板，也未创建或推送远端 GitHub 仓库。
