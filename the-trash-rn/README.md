# The Trash RN

Expo SDK 51 + Expo Router + Supabase 的 React Native 客户端。

## 已补齐的关键能力

- 本地知识库向量匹配（`assets/trash_knowledge.json` + 余弦相似度）
- 启动预热（AI engine warmup）与全局状态（ready/loading/error）
- Duel 实时状态机（`player_ready / answer_submitted / player_finished / presence`）
- 社区页显式定位交互（`使用当前位置` / `选择城市`）
- 手机号统一规范化（输入 `6505551234` 自动归一化为 `+16505551234`）

## 环境要求

- Node.js 20+
- pnpm 10+
- Xcode（iOS 真机/模拟器）
- CocoaPods

## 1) 安装依赖

```bash
pnpm install
```

说明：项目路径包含空格时，`postinstall` 会自动修复 RN iOS 脚本的路径引用。

## 2) 配置环境变量

在 `the-trash-rn/.env` 中至少配置：

- `EXPO_PUBLIC_SUPABASE_URL`
- `EXPO_PUBLIC_SUPABASE_ANON_KEY`
- `EXPO_PUBLIC_SUPABASE_EDGE_FUNCTION_URL`
- `EXPO_PUBLIC_RECORDER_BUCKET`

## 3) iOS 真机安装开发构建（无 99 美元账号）

```bash
pnpm pods:install
pnpm expo run:ios --device
```

首次安装或原生依赖变化后需要重新执行。只做本地调试时不需要 Apple Developer 付费账号。

## 4) 启动开发服务器

```bash
pnpm expo start --dev-client --tunnel --clear
```

推荐 `--tunnel`，可避免 ATS 对明文 HTTP 的限制。

## 5) 数据库迁移

在仓库根目录执行：

```bash
supabase db push --project-ref <your-project-ref>
```

迁移规范：仅提交 `supabase/migrations/`，该目录是唯一真相源。

## 常见问题

1. `There was a problem loading the project ... ATS requires secure connection`

- 使用 `--tunnel` 启动，不要直连 `http://<ip>:8081`。

2. `path name contains null byte`（CocoaPods 间歇错误）

- 用 `pnpm pods:install`（内置重试）。

3. `with-environment.sh: /Users/.../The: No such file or directory`

- 重新执行 `pnpm install`，确认补丁脚本已运行。

4. 社区定位弹窗没有城市可选

- 先执行迁移并确保 `communities` 有数据；客户端也会回退到内置城市列表。

5. 好友榜同步通讯录会上传什么

- 仅上传去重后的邮箱和手机号，不上传联系人姓名。
- 默认需要你在好友榜里显式同意后才会同步。
- 单次同步最多上传 300 个邮箱 + 300 个手机号。

## 自动化测试

```bash
pnpm test
```

当前已覆盖：错误模型、认证状态管理、竞技场 store 拆分后的关键路径、好友榜通讯录最小化同步。

## 常用命令

```bash
pnpm lint
pnpm format
pnpm test
pnpm expo run:ios --device
pnpm expo start --dev-client --tunnel --clear
```
