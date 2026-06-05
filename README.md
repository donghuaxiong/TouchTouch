# TouchTouch

TouchTouch 是一个 macOS 菜单栏应用，用触控板边缘滑动快速调节屏幕亮度和系统音量。应用常驻菜单栏，不占用 Dock，提供可视化 HUD、触觉反馈、灵敏度调节和触发方式设置。

## 功能特性

- 菜单栏常驻控制面板
- 触控板滚动手势调节亮度和音量
- 增强边缘识别：按住 `Option` 后，左边缘控制亮度，右边缘控制音量
- 兼容触发方式：`Option` 控制亮度，`Command` 控制音量
- 可调节边缘宽度、滚动阈值、变化步长和防抖时间
- 支持反转滑动方向
- 支持 HUD 屏幕提示和亮/暗玻璃背景
- 支持触觉反馈和强度设置
- 亮度控制优先使用系统 DisplayServices，必要时回退到 `brightness` CLI
- 音量控制使用 AppleScript，并带 Core Audio 回退逻辑

## 系统要求

- macOS 13.0 或更高版本
- Swift 6.0 工具链
- Xcode Command Line Tools

可选依赖：

- [`brightness`](https://github.com/nriley/brightness)：当系统亮度接口不可用时作为回退方案使用
- `create-dmg`：用于生成更完整的 DMG 安装包布局；没有该工具时脚本会回退到 `hdiutil`

## 权限说明

TouchTouch 需要读取修饰键和触控板滚动事件，因此首次使用时需要授权：

1. 打开应用菜单栏面板。
2. 点击 `请求权限`。
3. 在系统设置中允许 TouchTouch 使用：
   - 辅助功能
   - 输入监控
4. 授权后重启应用，或关闭再重新运行。

如果应用没有响应触控板手势，优先检查以上两个权限是否已经授予当前构建出的 `TouchTouch.app`。

## 使用方式

默认启用增强边缘识别：

| 操作 | 效果 |
| --- | --- |
| 按住 `Option`，在触控板左边缘上下滑动 | 调节屏幕亮度 |
| 按住 `Option`，在触控板右边缘上下滑动 | 调节系统音量 |

关闭增强边缘识别后：

| 操作 | 效果 |
| --- | --- |
| 按住 `Option` 并滚动 | 调节屏幕亮度 |
| 按住 `Command` 并滚动 | 调节系统音量 |

可以在菜单栏面板中调整：

- 是否启用监听
- 是否启用增强左右边缘识别
- 边缘宽度
- 滑动阈值
- 亮度/音量步长
- 是否反转滑动方向
- HUD 和触觉反馈

## 开发运行

克隆项目后在根目录执行：

```bash
swift build
```

直接运行 SwiftPM 可执行文件：

```bash
swift run TouchTouch
```

更推荐使用项目脚本构建 `.app` 并启动：

```bash
./script/build_and_run.sh
```

脚本会：

1. 编译应用
2. 生成 `dist/TouchTouch.app`
3. 写入基础 `Info.plist`
4. 进行 ad-hoc 签名
5. 打开应用

其他调试模式：

```bash
./script/build_and_run.sh --debug
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --verify
```

## 测试

运行单元测试：

```bash
swift test
```

当前测试位于 `Tests/TouchTouchTests`。

## 打包

生成发布用 `.app` 和 `.dmg`：

```bash
./script/package_dmg.sh
```

产物会输出到：

```text
dist/TouchTouch.app
dist/TouchTouch.dmg
```

该脚本会构建通用架构 release 版本、生成应用图标、创建 app bundle、执行 ad-hoc 签名，并生成 DMG。

## 项目结构

```text
.
├── Package.swift
├── Sources/TouchTouch
│   ├── App
│   │   └── TouchTouchApp.swift
│   ├── Services
│   │   ├── BrightnessManager.swift
│   │   ├── HapticManager.swift
│   │   ├── HUDManager.swift
│   │   ├── MultiTouchSupportManager.swift
│   │   ├── PermissionManager.swift
│   │   ├── TrackpadEventMonitor.swift
│   │   └── VolumeManager.swift
│   ├── Stores
│   │   └── AppState.swift
│   ├── Support
│   │   └── ProcessRunner.swift
│   └── Views
│       └── SettingsView.swift
├── Tests/TouchTouchTests
└── script
    ├── build_and_run.sh
    ├── generate_icon.swift
    └── package_dmg.sh
```

## 实现概览

- `TouchTouchApp`：应用入口，创建菜单栏窗口并隐藏 Dock 图标
- `AppState`：集中管理用户设置、持久化和控制动作分发
- `TrackpadEventMonitor`：监听滚动事件，判断触发目标和调节方向
- `MultiTouchSupportManager`：读取触控板触点位置，用于左右边缘识别
- `BrightnessManager`：调节亮度，支持系统接口和 CLI 回退
- `VolumeManager`：调节系统音量，支持 AppleScript 和 Core Audio 回退
- `HUDManager`：显示亮度/音量反馈浮层
- `PermissionManager`：请求辅助功能和输入监控权限

## 注意事项

- 项目使用了 macOS 私有框架 `DisplayServices` 和 `MultiTouchSupport`，适合本地工具或个人使用；如果要正式分发，需要评估兼容性、签名、公证和审核风险。
- ad-hoc 签名的本地构建可能会导致权限授权和 app 路径绑定。如果重新生成 app 后权限失效，请在系统设置中移除旧条目后重新授权。
- 外接显示器或不支持系统亮度接口的设备可能无法调节亮度，可以安装 `brightness` CLI 作为回退。
