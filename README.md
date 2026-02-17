# The Trash

The Trash 是一个垃圾分类与环保互动产品仓库，包含两个客户端实现：

- `The Trash/`：SwiftUI 原生 iOS 版本（主工程）
- `the-trash-rn/`：Expo + React Native 版本（跨平台）

## 仓库结构

```text
.
├── The Trash/                     # SwiftUI iOS 代码
├── The Trash.xcodeproj            # Xcode 工程
├── the-trash-rn/                  # Expo / RN 代码
├── supabase/migrations/           # Supabase 迁移源
├── The Trash/migrations/          # App 侧 SQL 镜像
├── scripts/                       # 契约检查与迁移同步脚本
├── Makefile
└── docs/
```

## 1) Swift iOS 开发

### 环境

- Xcode 16+
- iOS Simulator 或真机
- `MobileCLIPImage.mlpackage` 放在 `The Trash/` 下
- 本地私密配置 `The Trash/Secrets.swift`（不要提交）

### 常用命令

```bash
make open
make build
make build-device
make test
```

也可直接打开工程：

```bash
open "The Trash.xcodeproj"
```

## 2) React Native 开发（推荐先走这条）

详细说明见 `the-trash-rn/README.md`。

快速启动：

```bash
cd the-trash-rn
pnpm install
pnpm expo start --dev-client --tunnel --clear
```

### RN iOS 真机最短路径

```bash
cd the-trash-rn
pnpm install
pnpm pods:install
pnpm expo run:ios --device
pnpm expo start --dev-client --tunnel --clear
```

## 3) 数据库迁移（Supabase）

### 迁移执行

```bash
supabase db push --project-ref <your-project-ref>
```

`project-ref` 就是 Supabase 项目短 ID（Dashboard URL 里 `project/<ref>` 这段）。

### 镜像同步与契约检查

```bash
make migrations-sync
make migrations-check
make contracts
make doctor
```

建议流程：

1. 新增 `supabase/migrations/*.sql`
2. `supabase db push --project-ref <ref>`
3. `make migrations-sync`
4. `make doctor`
5. 提交 `supabase/migrations` 和 `The Trash/migrations`

## 4) 常见问题

- `Could not find table ... in schema cache`：
  - 说明远端 schema 还没应用完整迁移，先执行 `supabase db push`。
- Expo iOS 出现 ATS 明文连接报错：
  - 使用 `pnpm expo start --dev-client --tunnel --clear`。
- `Authentication with Apple Developer Portal failed / no team`：
  - 不能走 EAS iOS 云构建；可用本地 Xcode 真机安装，或先用 Android 开发机。
