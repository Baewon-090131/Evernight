# Evernight

一个自制自用的相册整理工具。当前版本为 `v0.1-Fall Asleep Beta`，目标是先完成一套可以在真机相册上实际使用的核心流程。

## v0.1 已实现

- 通过 PhotoKit 请求相册读写权限。
- 按拍摄月份读取照片和视频。
- 在滑动整理页切换 `全部媒体 / 照片 / 视频`。
- 左滑下一张、右滑撤回、上滑加入待删除、下滑放入目标相簿。
- 创建用户相簿并设置默认归档相簿。
- 待删除区二次复核。
- 使用滑轨确认删除，未到终点自动回弹，满轨后交给 iOS 系统再次确认。
- iOS 26 上使用 Liquid Glass；较低系统版本使用系统材质回退。

首版暂不包含相似照片识别、相簿合并、整理统计和持久化整理进度。

## 技术栈

- Swift 6 语言模式
- SwiftUI
- PhotoKit
- iOS 18 最低部署版本
- iOS 26 SDK 与 Liquid Glass 原生 API
- XcodeGen 生成 Xcode 工程

## 本地构建

需要 macOS、Xcode 26 和 XcodeGen。

```bash
brew install xcodegen
xcodegen generate
open Evernight.xcodeproj
```

也可以直接构建产物：

```bash
bash scripts/build-ipa.sh
```

未签名 IPA 输出到 `artifacts/Evernight-v0.1-Fall-Asleep-Beta-unsigned.ipa`。

## GitHub Actions 构建 IPA

仓库只保留 `Build unsigned IPA` 工作流：

- 手动运行或推送 `v*` 标签时触发。
- 生成未签名 IPA。
- 适合通过 AltStore、Sideloadly 或其他自签名工具安装。
- 未签名 IPA 不能直接在未经处理的真机上安装。

## 测试

`EvernightTests` 使用 Swift Testing 覆盖滑卡状态和撤回逻辑。CI 会执行 `build-for-testing`，确认 App 与测试目标能够编译。

## 权限与数据

- 照片读取、缩略图回调和整理索引均在本机完成。
- v0.1 不上传相册内容。
- 待删除项目只保存在内存中。
- 点击删除后仍会经过 iOS 系统删除确认，并可在系统“最近删除”中恢复。

## 角色素材

当前图标仅使用项目提供的参考图案作为内部测试素材。正式发布前需要替换为已获得授权的品牌资产。
