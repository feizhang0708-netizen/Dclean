# Dclean

macOS 系统清理与网络诊断工具。

## 功能

- **垃圾扫描** — 扫描并清理系统垃圾文件
- **网络诊断** — 检测网络连接状态、DNS、路由
- **ISP 测速** — 测试网络上传/下载速度
- **进程监控** — 查看系统资源占用

## 安装

下载最新版 [Dclean.dmg](https://github.com/feizhang0708-netizen/Dclean/releases/latest) 安装。

或手动构建：

```bash
git clone https://github.com/feizhang0708-netizen/Dclean.git
cd Dclean
bash Scripts/build.sh
cp -R Dclean.app /Applications/
```

## 系统要求

- macOS 13.0+
- Apple Silicon (M1/M2/M3/M4)

## 技术栈

- Swift 5.9
- WebView UI (HTML/JS)
- CoreWLAN / ServiceManagement
