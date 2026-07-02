# Git 工作流规范

本文档细化本项目 `AGENTS.md` 中的 Git 提交与推送规则，适用于人工开发和 AI 辅助开发。

## 核心原则

- 默认沿用当前任务所在分支；除非用户明确要求，不额外创建、切换或重命名分支。
- 每轮对话完成一个小逻辑、小功能或小修复后，默认提交并推送当前分支。
- 提交单位不是“消息次数”，而是“最小可解释业务闭环”。
- 提交前只暂存本轮相关文件，禁止默认使用 `git add .`。
- commit 成功后立即 `git push` 到当前分支，避免本地长期堆积未推送工作。

## 每轮任务开始

开始实际改文件前先执行：

```bash
git status --short
```

目的：

- 识别工作区是否已有历史改动。
- 记录哪些文件不是本轮任务产生的。
- 避免后续提交时把用户、其他任务或历史遗留改动混入本轮 commit。

如果工作区已有大量未提交改动，仍可继续开发，但必须遵守：

- 不回滚无关改动。
- 不顺手格式化无关文件。
- 不把无关文件混入本轮提交。
- 如果同一文件里混有本轮改动和旧改动，必须逐段检查并只提交本轮意图。
- 无法安全拆分时，暂不提交该文件，并在最终回复说明原因。

## 每轮完成后的默认提交

用户明确要求实现、修复、调整、完善、联调或继续任务时，视为授权在任务达到稳定可验收状态后提交并推送。

以下泛化回复只表示主线程可继续当前任务，不扩大提交范围：

- “继续”
- “开始吧”
- “可以”
- “按照建议继续”
- “继续处理”

这些回复不授权：

- 把工作区所有未提交改动一起提交。
- 跨任务整理提交。
- 提交未完成或未验证的半成品。
- 提交用户或其他任务留下的无关改动。

## 提交边界

一个 commit 应该能用一句话说明清楚业务目的，并能被单独回滚。

适合单独 commit 的情况：

- 一个 API 接口或服务层 bug 修复。
- 一个 Admin、App、Desktop 页面交互或样式修复。
- 一个独立 Compose、测试框架或性能基线配置治理。
- 一个文档规范补充。
- 一个 SQL migration、SQL baseline 或 migration guard 调整。
- 一个可独立验证的 API、App、Admin、Desktop 模块改动。

可以合并到一个 commit 的情况：

- 同一页面内连续的小样式、小文案、小交互调整。
- 同一模块内为了同一个 bug 必须一起改的测试和实现。
- 同一规范文档和 `AGENTS.md` 中对应的入口说明。

默认需要拆开的情况：

- UI 改动和后端接口改动。
- migration / SQL baseline 和普通业务代码。
- 生成代码和手写逻辑。
- 部署配置和业务功能。
- lockfile 和普通源码。
- 性能测试框架和业务功能。
- 多个端或多个服务模块互不依赖的改动。

## 提交前检查

提交前最低检查：

```bash
git status --short
git diff --check
git diff --cached --check
git diff --cached
```

要求：

- `git diff --check` 和 `git diff --cached --check` 不能有空白错误。
- staged diff 必须逐文件确认，只包含本轮要提交的内容。
- 不使用 `git add .` 作为默认暂存方式。
- 优先使用明确文件路径暂存，例如 `git add AGENTS.md docs/standards/git-workflow.md`。

根据改动范围补充验证：

- API 代码：优先运行 `make api.test`；必要时补充 `make api.test.smoke` 或更小范围的 Compose 内测试。
- SQL migration / `api/sql/base.sql`：必须运行 `make api.migration.guard`，并在提交说明或回复中说明基线来源和兼容风险。
- Docker Compose / 测试入口：运行 `make tests.compose.config`，必要时补充对应 smoke。
- App 代码：运行对应 `flutter test` 或 integration；验收设备顺序遵循 `AGENTS.md`。
- Admin 代码：运行对应单测、构建或 `make admin.test.live`。
- Desktop 代码：运行对应单测、构建或 `make desktop.test.live`。
- 性能测试框架：运行 `make tests.perf.check`，必要时补充 `make api.perf.smoke`。
- 文档-only 改动：最低执行 `git diff --check`。
- 部署 / env / 密钥相关改动：确认没有真实密码、token、证书私钥或其他敏感信息进入 diff。

如果因为外部凭证、真实三方环境、端口占用或耗时无法验证，必须在最终回复中说明。

## 暂存规则

默认使用明确文件路径暂存：

```bash
git add AGENTS.md docs/standards/git-workflow.md
```

对混合改动文件，优先使用交互式暂存或手工拆分 patch：

```bash
git add -p path/to/file
```

禁止：

- 未检查 diff 就 `git add .`。
- 把格式化造成的大面积无关 diff 混入小修复。
- 把用户或其他任务的文件顺手提交。
- 为了“清空工作区”而提交不属于本轮任务的内容。

## 提交信息

提交说明默认使用简体中文，概括业务目的和改动范围。

推荐格式：

```text
docs: 收紧 Git 提交推送规范
fix(api): 修复 WebSocket 订阅回滚
feat(app): 增加邮箱登录联调用例
test(admin): 补充真实后端 smoke 验证
perf(api): 增加 Compose 性能基线
```

要求：

- 前缀使用 Conventional Commits，常用类型包括 `feat:`、`fix:`、`docs:`、`test:`、`chore:`、`refactor:`、`perf:`、`build:`、`ci:`。
- 不为了格式牺牲可读性。
- 不使用空泛描述，例如“update”“fix bug”“调整代码”。
- WIP 只能在用户明确要求保存现场时使用，并写清阻塞点。

## 推送规则

每个 commit 成功后立即推送当前分支：

```bash
git push
```

如果当前分支没有 upstream，先确认目标远端分支；通常使用：

```bash
git push -u origin "$(git branch --show-current)"
```

如果推送失败：

- 不静默跳过。
- 先判断是网络、认证、远端拒绝还是需要拉取。
- 不在未确认情况下执行破坏性合并、rebase 或 reset。
- 在最终回复中说明失败原因和当前本地 commit 状态。

## 不应提交的情况

以下情况默认不提交：

- 用户只要求分析、讨论或制定方案，未产生文件改动。
- 改动尚未完成，明显无法验收。
- 测试或构建失败且不是用户明确要求保存现场。
- 无法区分本轮改动和已有旧改动。
- 发现真实密钥、密码、token、证书私钥进入 diff。
- 用户明确要求“先不要提交”。

## 子代理与 Git

子代理默认不得执行任何 Git stage / commit / push 操作。

即使用户明确授权子代理写文件，子代理产出也只能作为候选 diff / patch，由主线程逐文件 review 后决定是否合入。Git 操作必须由主线程执行。
