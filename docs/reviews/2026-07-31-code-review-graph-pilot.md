# Code Review Graph 受控接入试点评估

## 结论

**保留受控接入。** 五次真实 review 中，3 次发现了主线程首轮候选外、且经当前源码复核有效的依赖或测试文件，达到计划要求的 `3/5` 保留阈值。三次无业务改动的增量更新耗时为 `0.92s`、`0.56s`、`0.57s`，中位数 `0.57s`，低于 `5s` 阈值。MCP 移除演练没有阻塞 CE review，也没有产生 Codex/Git hooks。

保留不代表扩大使用范围。文件级 impact 对大型 handler/service 噪声很高，静态 CSS 的 token savings 指标具有误导性；因此继续执行“符合触发矩阵时手工调用、符号级查询优先、失败立即降级”的边界。

## 方法

- 试点基于仓库中的真实提交，图数据库构建于 `main@b6297b83f240`，CRG 版本为 `2.3.7`。
- 每次查询前先用提交目标、`git show --name-status` 和源码入口冻结首轮候选，不用 CRG 反向改写首轮清单。
- 历史提交用于复演审查范围；测试证据来自提交内测试 diff 与当前源码关系抽查，本次没有重新检出历史版本执行完整业务测试。
- “有效发现”必须位于首轮候选外，并能由当前源码中的 import、call 或测试调用复核。
- 首轮读取文件数不以图结果回填。是否保留主要依据额外有效发现次数，不使用 CRG 自报 token savings 作为判定依据。

## 汇总

| # | 样本 | 类型 | 首轮候选数 | CRG 候选外文件 | 有效新增 | 结果 |
|---|------|------|------------|-----------------|----------|------|
| 1 | `a5b78324` 附件提交校验 | Rust API + Flutter | 4 | 6 | 1 | 有帮助，噪声高 |
| 2 | `d8790654` 账号认证切换 | API + Flutter + H5 + Desktop + iOS | 60 | 20（截断） | 2 | 有帮助，需按契约筛选 |
| 3 | `7ff99d9c` 消息运行模式 | Rust 公共模块 | 10 | 6 个 importers | 2 | 有帮助，符号/模块查询准确 |
| 4 | `167e6d21` 朋友圈样式 | 静态 UI/CSS | 1 | 0 | 0 | 应跳过，指标误导 |
| 5 | `b6297b83` 工作流文档 | MCP 故障降级 | 5 | 不适用 | 不适用 | 降级成功，CE 未阻塞 |

## 试点记录

### 1. 附件提交校验：Rust API + Flutter

- **提交与 changed files：** `a5b78324`；`api/src/handlers/message.rs`、`api/tests/websocket_integration.rs`、`app/lib/core/services/message_service.dart`、`app/test/core/message_service_attachment_retry_test.dart`。
- **冻结的首轮候选：** 上述 4 个文件。审查入口是服务端附件提交校验和客户端失败重试，测试文件已由提交 diff 明确给出。
- **CRG 查询：** 对两个生产文件执行 depth 1 impact，并查询 `ensure_message_attachment_keys_are_committed` callers。impact 报告 6 个额外文件；caller 查询准确返回同文件内的 relay-only 包装函数与 `send_message`。
- **有效新增：** `api/src/database/file_upload_store.rs`。源码确认 handler 在 `api/src/handlers/message.rs:755` 调用其 `has_completed_by_key`，这是附件是否完成提交的决定性存储边界。
- **误报/漏报：** 其余数据库 store 主要由大型 `message.rs` 的文件级关系扩散产生，不应全部读取。跨 Rust/Dart 的业务契约没有形成直接图边，仍需人工对照请求与错误处理。
- **CE 实际读取：** 4 个首轮文件加 1 个有效新增文件，共 5 个；没有因 CRG 候选扩大到全部 store。
- **测试证据：** 提交包含 WebSocket 持久化模式附件测试和 Flutter 附件重试测试；本次只抽查关系，没有重跑历史版本测试。

### 2. 默认账号认证：多端公共契约

- **提交与 changed files：** `d8790654`，共 60 个文件，覆盖 API、Admin、Flutter、H5、Desktop、iOS、性能脚本和文档。
- **冻结的首轮候选：** 以 API `auth.rs`/settings、各端 auth API/repository/login view、对应 auth tests 和契约文档为首轮；迁移和测试矩阵因提交 diff 直接纳入。
- **CRG 查询：** 对 `api/src/handlers/auth.rs`、Flutter `auth_repository.dart`、H5 `auth.ts` 和 Desktop `system.ts` 执行 depth 1 impact，返回 20 个截断候选。
- **有效新增：** `app/integration_test/api_contract_flow_test.dart` 当前直接构造 `AuthRepository` 并调用 `login(account:, password:)`；`app/lib/features/auth/models/auth_session.dart` 是 repository 返回契约。两者都值得在账号字段变化时纳入复核。
- **误报/漏报：** upload、push、avatar cache 等候选只是共享认证状态的宽泛消费者，不是本次账号字段切换的首轮重点。图不能可靠证明 Rust、Dart、Vue、Swift 间 JSON 字段语义一致，必须继续对照 API 文档和各端序列化代码。
- **CE 实际读取：** 首轮按 changed files 和契约分层审查，额外读取 2 个有效文件；未使用 CRG 的 20 文件列表替代 60 文件 diff 审查。
- **测试证据：** 原提交包含 API auth/users/WS 集成测试、Flutter/H5/Desktop/iOS auth 测试和 live smoke 更新；本次未重跑历史版本测试。

### 3. 消息运行模式：公共模块调用者

- **提交与 changed files：** `7ff99d9c`，10 个 Rust 源码/测试文件，核心为 `api/src/services/message_runtime.rs` 及 message、room、search handlers。
- **冻结的首轮候选：** 提交中的 10 个文件，重点查看 runtime settings 的读取、更新、消息持久化和 relay-only 行为。
- **CRG 查询：** 对 `api/src/services/message_runtime.rs` 执行 `importers_of`。返回 6 个高置信度 importers。
- **有效新增：** `api/src/handlers/chat_history.rs` 调用 `is_relay_only_runtime`；`api/src/handlers/settings.rs` 同时调用 runtime settings 的 load/update。两者不在该提交 changed files 中，但分别约束历史读取与管理设置入口。
- **误报/漏报：** 6 个 importers 都是静态 import 事实，但是否受某个具体函数变更影响仍需逐符号判断。图未替代 relay-only 的 Redis、存储和 WebSocket 运行时验证。
- **CE 实际读取：** 10 个首轮文件加 2 个候选外文件，共 12 个。
- **测试证据：** 原提交包含 admin 与 WebSocket 集成测试；当前 runtime 模块还有模式解析/default 单元测试。本次只抽查源码关系。

### 4. 朋友圈详情样式：静态 UI

- **提交与 changed files：** `167e6d21`，仅 `im-ui-html/assets/styles.css`。
- **冻结的首轮候选：** 样式文件，以及视觉验收时对应的朋友圈列表/详情渲染入口；按触发矩阵本应跳过 CRG。
- **CRG 查询：** 为验证边界，仍对 CSS 文件执行一次 depth 1 impact。
- **结果：** 0 changed nodes、0 impacted nodes、0 additional files，但 `context_savings` 同时报告 `59032` tokens / `100%`，无法反映视觉审查工作量。
- **误报/漏报：** token savings 是误导性指标；CSS selector、DOM 状态、响应式布局和截图差异均未被图覆盖。
- **CE 实际读取：** CRG 没有减少读取；仍需源码、页面和截图验收。该类任务继续默认跳过。
- **测试证据：** 原提交是纯样式调整，本次未启动浏览器复演历史页面。

### 5. MCP 移除：失败降级

- **样本：** `b6297b83` 的工作流规则文档 review，共 5 个 changed files。
- **冻结的首轮候选：** `AGENTS.md`、`docs/index.md`、plan/review prompts 和 CRG 工具参考文档。
- **故障注入：** 执行 `codex mcp remove code-review-graph-redcode-im`，随后 `codex mcp get` 明确返回 server 不存在。
- **降级路径：** 使用 `git show --stat`、`rg` 检查五阶段、证据顺序和不得阻塞规则，并运行 `make tests.tooling`；测试通过，Git 尾部未被阻塞。
- **恢复：** 使用固定的 `uvx --from code-review-graph==2.3.7 ... serve` 命令重新注册同名 MCP。`~/.codex/hooks.json` 前后均不存在，Husky hook SHA-256 保持不变。
- **CE 实际读取：** 5 个首轮文件，无额外图文件；CRG 故障没有改变 review 结论或提交能力。

## 性能与隔离证据

- 完整构建：1,108 个解析文件，13,138 个构建节点，98,803 条边，约 5.6 秒；本地图约 112MB。
- 当前状态：12,898 个查询节点、97,020 条查询边、1,098 个文件。
- 增量更新：`0.92s`、`0.56s`、`0.57s`，中位数 `0.57s`。
- Git：`.code-review-graph/graph.db` 被 `.gitignore` 命中，工作区不显示图数据。
- 自动化：`test.all`、`test.live`、Husky `pre-commit` / `commit-msg` 均无 CRG 调用。
- 运行方式：没有 daemon、watch、embeddings、GitHub Action 或 CRG install 产物。

## 长期规则

1. 保留四个显式 Make 入口和项目专属 Codex MCP。
2. review 优先使用符号级 `callers_of`、`importers_of`、`tests_for`；大型文件的 file impact 仅用于产生少量待验证线索。
3. 跨语言契约仍以请求、序列化源码、测试和运行时行为为准，不能把同名搜索当作契约边。
4. 小型文档、CSS 和局部 UI 任务跳过 CRG；静态 UI 不引用 token savings 作为收益证据。
5. MCP 或图更新失败时立即降级，不重试到阻塞 CE；恢复操作不得引入 hooks 或后台进程。

当前证据支持“受控保留”，不支持自动 hooks、默认门禁或每次 execute 自动更新。若后续连续试点只产生宽泛候选而没有有效新增，应降级为完全手工、按需 CLI 查询；若出现 CE 阻塞或隐藏自动触发，则移除接入。
