# 上传到 GitHub

仓库名称建议使用 `basys3-stm32-game`。本地项目已有 `main` 分支；首次提交包含当前 UART 初开发代码及文档。显示与游戏开发进度见 [路线](roadmap.md)。

## 1. 在 GitHub 创建空仓库

登录你的账号，在 GitHub 新建仓库，选择名称和公开 / 私有可见性。**不要勾选自动创建 README、.gitignore 或 LICENSE**，因为本地已有对应说明和历史，避免出现两份独立的首次提交。

项目原创代码的许可证尚未选定，见 [许可状态](../LICENSE_STATUS.md)。第三方许可已随源码保留。

## 2. 连接本地仓库并推送

在本地 `basys3-stm32-game` 文件夹中打开 PowerShell。将下面的地址替换为你刚创建仓库的 HTTPS 地址：

```powershell
git status
git remote add origin https://github.com/xyzlll506/basys3-stm32-game.git
git push -u origin main
```

如果使用了其他仓库名，必须改成对应地址。若 `origin` 已存在，先运行 `git remote -v` 核对；需要修改时使用 `git remote set-url origin 新地址`，不要重复添加。

首次推送时按 Git 凭据管理器的提示登录 GitHub。不要把访问令牌写进文件或远端 URL；本仓库不附带任何上传凭据。Git 的提交作者和 GitHub 登录认证是两项独立设置。

## 3. 上传后检查

- 首页显示本项目 README，目录里有 `fpga/`、`stm32/` 和 `docs/`。
- `Actions` 页面可以看到仓库自检与 UART 仿真结果；首次远端执行前不要标记为通过。
- 可在另一目录克隆后，运行 `python scripts/check_repo.py`，确认工程引用和固件校验。

GitHub Actions 使用公开 Ubuntu runner 和 Icarus，只检查仓库完整性及 HDL 行为；不运行 Vivado 布局布线、Keil 链接，也不连接实体开发板。

## 后续日常提交

```powershell
python scripts/check_repo.py
git diff --check
git status
git add README.md docs fpga stm32 scripts .github
git commit -m "Describe the concrete change"
git push
```

新增其他根目录文件时，按实际文件名加入暂存区。修改 RTL 或 STM32 应用后，完成对应仿真或编译，再提交结果。缓存和个人调试设置已经通过 `.gitignore` 排除。

## 以后修改提交身份

作者配置仅作用于这个仓库，可在仓库内查看：

```powershell
git config --local user.name
git config --local user.email
```

若使用 GitHub 隐私邮箱，格式按账号设置中的 Emails 页面显示为准。[GitHub 提交邮箱说明](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address)。
