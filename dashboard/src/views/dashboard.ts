export function renderDashboard(): string {
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>RedCode Dev Dashboard</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
  <style>
    [x-cloak] { display: none !important; }
    .terminal { font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; }
    .terminal-output { max-height: 500px; overflow-y: auto; }
    @media (min-width: 1280px) { .terminal-output { max-height: 600px; } }
    @media (min-width: 1536px) { .terminal-output { max-height: 700px; } }
    .status-dot { width: 8px; height: 8px; border-radius: 50%; }
    .status-running { background: #22c55e; box-shadow: 0 0 6px #22c55e; }
    .status-stopped { background: #6b7280; }
  </style>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen" x-data="dashboard()">
  <div class="mx-auto px-6 py-8 max-w-[1800px]">
    <!-- Header -->
    <header class="mb-8">
      <h1 class="text-3xl font-bold text-white mb-2">RedCode Dev Dashboard</h1>
      <p class="text-gray-400">Backend 模块开发管理面板</p>
    </header>

    <!-- Status Bar -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
      <div class="bg-gray-800 rounded-lg p-4">
        <h2 class="text-sm font-semibold text-gray-400 mb-3">服务状态</h2>
        <div class="flex flex-wrap gap-4">
          <template x-for="(status, name) in statuses" :key="name">
            <div class="flex items-center gap-2 bg-gray-700 px-3 py-2 rounded">
              <div class="status-dot" :class="status.running ? 'status-running' : 'status-stopped'"></div>
              <span class="text-sm" x-text="name"></span>
              <span x-show="status.port" class="text-xs text-gray-500" x-text="':' + status.port"></span>
            </div>
          </template>
        </div>
      </div>

      <!-- Coverage Stats -->
      <div class="bg-gray-800 rounded-lg p-4">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-gray-400">API 测试覆盖率</h2>
          <button
            @click="quickAction('coverage:update')"
            class="text-xs text-blue-400 hover:text-blue-300">
            刷新
          </button>
        </div>
        <div x-show="!coverage" class="text-gray-500 text-sm">加载中...</div>
        <div x-show="coverage" class="space-y-2">
          <div class="flex items-center gap-4">
            <div class="flex-1">
              <div class="flex justify-between text-xs mb-1">
                <span class="text-gray-400">覆盖率</span>
                <span class="text-white" x-text="coverage?.summary?.percentage?.toFixed(1) + '%'"></span>
              </div>
              <div class="h-2 bg-gray-700 rounded-full overflow-hidden">
                <div
                  class="h-full bg-green-500 transition-all"
                  :style="'width:' + (coverage?.summary?.percentage || 0) + '%'">
                </div>
              </div>
            </div>
          </div>
          <div class="grid grid-cols-4 gap-2 text-center text-xs">
            <div class="bg-gray-700 rounded p-2">
              <div class="text-white font-medium" x-text="coverage?.summary?.total || 0"></div>
              <div class="text-gray-400">总路由</div>
            </div>
            <div class="bg-gray-700 rounded p-2">
              <div class="text-green-400 font-medium" x-text="coverage?.summary?.goCovered || 0"></div>
              <div class="text-gray-400">Go</div>
            </div>
            <div class="bg-gray-700 rounded p-2">
              <div class="text-blue-400 font-medium" x-text="coverage?.summary?.rustCovered || 0"></div>
              <div class="text-gray-400">Rust</div>
            </div>
            <div class="bg-gray-700 rounded p-2">
              <div class="text-red-400 font-medium" x-text="coverage?.summary?.uncovered || 0"></div>
              <div class="text-gray-400">未覆盖</div>
            </div>
          </div>
          <div class="text-xs text-gray-500" x-show="coverage?.updatedAt">
            更新于: <span x-text="new Date(coverage?.updatedAt).toLocaleString()"></span>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-4 xl:grid-cols-5 gap-6">
      <!-- Command Panel -->
      <div class="lg:col-span-1 xl:col-span-1">
        <div class="bg-gray-800 rounded-lg p-4">
          <h2 class="text-lg font-semibold mb-4">命令面板</h2>

          <!-- Category Tabs -->
          <div class="flex flex-wrap gap-2 mb-4">
            <button
              @click="selectedCategory = 'all'"
              :class="selectedCategory === 'all' ? 'bg-blue-600' : 'bg-gray-700 hover:bg-gray-600'"
              class="px-3 py-1 rounded text-sm transition-colors">
              全部
            </button>
            <template x-for="cat in categories" :key="cat.id">
              <button
                @click="selectedCategory = cat.id"
                :class="selectedCategory === cat.id ? 'bg-blue-600' : 'bg-gray-700 hover:bg-gray-600'"
                class="px-3 py-1 rounded text-sm transition-colors"
                x-text="cat.name">
              </button>
            </template>
          </div>

          <!-- Command List -->
          <div class="space-y-2 max-h-[500px] xl:max-h-[600px] 2xl:max-h-[700px] overflow-y-auto">
            <template x-for="cmd in filteredCommands" :key="cmd.id">
              <div
                class="bg-gray-700 hover:bg-gray-600 rounded p-3 cursor-pointer transition-colors"
                :class="{ 'ring-2 ring-blue-500': selectedCommand?.id === cmd.id }"
                @click="selectCommand(cmd)">
                <div class="flex items-center justify-between">
                  <span class="font-medium text-sm" x-text="cmd.name"></span>
                  <span
                    x-show="runningCommands.includes(cmd.id)"
                    class="text-xs text-green-400 animate-pulse">
                    运行中
                  </span>
                </div>
                <p class="text-xs text-gray-400 mt-1" x-text="cmd.description"></p>
              </div>
            </template>
          </div>
        </div>
      </div>

      <!-- Terminal Panel -->
      <div class="lg:col-span-3 xl:col-span-4">
        <div class="bg-gray-800 rounded-lg p-4 h-full">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">
              <span x-show="!selectedCommand">终端输出</span>
              <span x-show="selectedCommand" x-text="selectedCommand?.name"></span>
            </h2>
            <div class="flex gap-2">
              <button
                x-show="selectedCommand && !runningCommands.includes(selectedCommand?.id)"
                @click="runCommand()"
                class="bg-green-600 hover:bg-green-700 px-4 py-2 rounded text-sm font-medium transition-colors">
                运行
              </button>
              <button
                x-show="selectedCommand && runningCommands.includes(selectedCommand?.id)"
                @click="stopCommand()"
                class="bg-red-600 hover:bg-red-700 px-4 py-2 rounded text-sm font-medium transition-colors">
                停止
              </button>
              <button
                @click="clearOutput()"
                class="bg-gray-700 hover:bg-gray-600 px-4 py-2 rounded text-sm transition-colors">
                清空
              </button>
            </div>
          </div>

          <!-- Terminal Output -->
          <div
            class="terminal bg-black rounded p-4 terminal-output"
            x-ref="terminal">
            <div x-show="!output.length" class="text-gray-500 text-sm">
              选择左侧命令并点击运行...
            </div>
            <template x-for="(line, idx) in output" :key="idx">
              <div
                class="text-sm whitespace-pre-wrap break-all"
                :class="{
                  'text-gray-300': line.type === 'stdout',
                  'text-red-400': line.type === 'stderr',
                  'text-yellow-400': line.type === 'warn',
                  'text-blue-400': line.type === 'start',
                  'text-yellow-400': line.type === 'exit',
                  'text-red-500': line.type === 'error'
                }"
                x-text="line.text">
              </div>
            </template>
          </div>
        </div>
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="mt-6 bg-gray-800 rounded-lg p-4">
      <h2 class="text-lg font-semibold mb-4">快捷操作</h2>
      <div class="flex flex-wrap gap-3">
        <button
          @click="quickAction('docker:up')"
          class="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded text-sm font-medium transition-colors">
          启动开发环境
        </button>
        <button
          @click="quickAction('backend:run')"
          class="bg-green-600 hover:bg-green-700 px-4 py-2 rounded text-sm font-medium transition-colors">
          启动后端
        </button>
        <button
          @click="quickAction('test:unit')"
          class="bg-purple-600 hover:bg-purple-700 px-4 py-2 rounded text-sm font-medium transition-colors">
          运行测试
        </button>
        <button
          @click="quickAction('docker:down')"
          class="bg-gray-600 hover:bg-gray-700 px-4 py-2 rounded text-sm font-medium transition-colors">
          停止服务
        </button>
      </div>
    </div>
  </div>

  <script>
    function dashboard() {
      return {
        commands: [],
        statuses: {},
        coverage: null,
        selectedCategory: 'all',
        selectedCommand: null,
        output: [],
        runningCommands: [],
        eventSource: null,

        categories: [
          { id: 'service', name: '服务' },
          { id: 'database', name: '数据库' },
          { id: 'test', name: '测试' },
          { id: 'build', name: '构建' },
          { id: 'quality', name: '质量' },
        ],

        get filteredCommands() {
          if (this.selectedCategory === 'all') return this.commands;
          return this.commands.filter(c => c.category === this.selectedCategory);
        },

        async init() {
          await this.loadCommands();
          await this.loadStatus();
          await this.loadProcesses();
          await this.loadCoverage();
          // 定时刷新状态
          setInterval(() => this.loadStatus(), 5000);
          setInterval(() => this.loadProcesses(), 3000);
        },

        async loadCommands() {
          const res = await fetch('/api/commands');
          const data = await res.json();
          this.commands = data.commands;
        },

        async loadStatus() {
          const res = await fetch('/api/status');
          const data = await res.json();
          this.statuses = data.statuses;
        },

        async loadProcesses() {
          const res = await fetch('/api/processes');
          const data = await res.json();
          this.runningCommands = data.processes;
        },

        async loadCoverage() {
          try {
            const res = await fetch('/api/coverage');
            if (res.ok) {
              this.coverage = await res.json();
            }
          } catch {
            // ignore
          }
        },

        selectCommand(cmd) {
          this.selectedCommand = cmd;
        },

        async runCommand() {
          if (!this.selectedCommand) return;

          this.output = [];
          const cmdId = this.selectedCommand.id;

          this.eventSource = new EventSource('/api/run/' + cmdId);

          this.eventSource.onmessage = (event) => {
            const data = JSON.parse(event.data);

            if (data.type === 'start') {
              this.output.push({ type: 'start', text: '>>> ' + data.command + ' 开始执行...' });
              this.runningCommands.push(cmdId);
            } else if (data.type === 'stdout' || data.type === 'stderr') {
              if (data.type === 'stderr') {
                const isWarn = /warning|warn|level=warning/i.test(data.text || '');
                this.output.push({ type: isWarn ? 'warn' : 'stderr', text: data.text });
              } else {
                this.output.push({ type: data.type, text: data.text });
              }
            } else if (data.type === 'exit') {
              this.output.push({
                type: 'exit',
                text: '>>> 进程退出，代码: ' + data.code
              });
              this.runningCommands = this.runningCommands.filter(id => id !== cmdId);
              this.eventSource.close();
            } else if (data.type === 'error') {
              this.output.push({ type: 'error', text: '错误: ' + data.message });
              this.eventSource.close();
            }

            // 自动滚动到底部
            this.$nextTick(() => {
              this.$refs.terminal.scrollTop = this.$refs.terminal.scrollHeight;
            });
          };

          this.eventSource.onerror = () => {
            this.runningCommands = this.runningCommands.filter(id => id !== cmdId);
            this.eventSource.close();
          };
        },

        async stopCommand() {
          if (!this.selectedCommand) return;

          await fetch('/api/stop/' + this.selectedCommand.id, { method: 'POST' });
          this.output.push({ type: 'exit', text: '>>> 进程已终止' });

          if (this.eventSource) {
            this.eventSource.close();
          }

          this.runningCommands = this.runningCommands.filter(
            id => id !== this.selectedCommand.id
          );
        },

        clearOutput() {
          this.output = [];
        },

        quickAction(cmdId) {
          const cmd = this.commands.find(c => c.id === cmdId);
          if (cmd) {
            this.selectCommand(cmd);
            this.runCommand();
          }
        }
      };
    }
  </script>
</body>
</html>`;
}
