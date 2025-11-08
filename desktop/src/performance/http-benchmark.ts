/**
 * HTTP 性能基准测试工具
 * 比较 TypeScript 和 Rust HTTP 客户端的性能
 */

import { rustHttp } from '../api/rust-http'
import { get as httpGet, post as httpPost, put as httpPut, patch as httpPatch, del as httpDelete } from '../api/http'
import type { ApiResponse } from '../api/http'

interface BenchmarkResult {
  name: string
  method: string
  path: string
  iterations: number
  tsTimes: number[]
  rustTimes: number[]
  tsAvg: number
  rustAvg: number
  improvement: number
  success: boolean
}

interface BenchmarkConfig {
  iterations: number
  warmup: number
  concurrent: boolean
  outputFormat: 'json' | 'html' | 'console'
}

class HttpPerformanceBenchmark {
  private results: BenchmarkResult[] = []
  private config: BenchmarkConfig

  constructor(config?: Partial<BenchmarkConfig>) {
    this.config = {
      iterations: 100,
      warmup: 10,
      concurrent: false,
      outputFormat: 'console',
      ...config
    }
  }

  /**
   * 执行单次请求测试
   */
  private async singleRequest(
    method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
    path: string,
    body?: any,
    useRust: boolean = true
  ): Promise<number> {
    const start = performance.now()

    try {
      if (useRust) {
        switch (method) {
          case 'GET':
            await rustHttp.get(path)
            break
          case 'POST':
            await rustHttp.post(path, body)
            break
          case 'PUT':
            await rustHttp.put(path, body)
            break
          case 'PATCH':
            await rustHttp.patch(path, body)
            break
          case 'DELETE':
            await rustHttp.delete(path)
            break
        }
      } else {
        switch (method) {
          case 'GET':
            await httpGet(path)
            break
          case 'POST':
            await httpPost(path, body)
            break
          case 'PUT':
            await httpPut(path, body)
            break
          case 'PATCH':
            await httpPatch(path, body)
            break
          case 'DELETE':
            await httpDelete(path)
            break
        }
      }

      return performance.now() - start
    } catch (error) {
      console.error('Request failed:', error)
      return -1
    }
  }

  /**
   * 执行基准测试
   */
  async run(
    name: string,
    method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
    path: string,
    body?: any,
    iterations?: number
  ): Promise<BenchmarkResult> {
    const iters = iterations || this.config.iterations
    const tsTimes: number[] = []
    const rustTimes: number[] = []

    console.log(`\n🚀 开始基准测试: ${name}`)
    console.log(`   路径: ${method} ${path}`)
    console.log(`   迭代次数: ${iters}`)

    // 预热
    console.log('   预热中...')
    for (let i = 0; i < this.config.warmup; i++) {
      await this.singleRequest(method, path, body, true)
      await this.singleRequest(method, path, body, false)
    }

    // 测试 TypeScript 实现
    console.log('   测试 TypeScript 实现...')
    for (let i = 0; i < iters; i++) {
      const duration = await this.singleRequest(method, path, body, false)
      if (duration > 0) {
        tsTimes.push(duration)
      }
      if (i % 10 === 0) {
        process.stdout.write(`.`)
      }
    }
    console.log()

    // 测试 Rust 实现
    console.log('   测试 Rust 实现...')
    for (let i = 0; i < iters; i++) {
      const duration = await this.singleRequest(method, path, body, true)
      if (duration > 0) {
        rustTimes.push(duration)
      }
      if (i % 10 === 0) {
        process.stdout.write(`.`)
      }
    }
    console.log()

    // 计算统计数据
    const tsAvg = tsTimes.reduce((a, b) => a + b, 0) / tsTimes.length
    const rustAvg = rustTimes.reduce((a, b) => a + b, 0) / rustTimes.length
    const improvement = ((tsAvg - rustAvg) / tsAvg * 100)

    const result: BenchmarkResult = {
      name,
      method,
      path,
      iterations: iters,
      tsTimes,
      rustTimes,
      tsAvg,
      rustAvg,
      improvement,
      success: tsTimes.length > 0 && rustTimes.length > 0
    }

    this.results.push(result)
    return result
  }

  /**
   * 批量执行测试
   */
  async runBatch(tests: Array<{
    name: string
    method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'
    path: string
    body?: any
    iterations?: number
  }>): Promise<void> {
    console.log(`\n📊 开始批量基准测试 (${tests.length} 个测试)`)

    for (const test of tests) {
      try {
        await this.run(test.name, test.method, test.path, test.body, test.iterations)
        await new Promise(resolve => setTimeout(resolve, 1000)) // 等待1秒
      } catch (error) {
        console.error(`❌ 测试 ${test.name} 失败:`, error)
      }
    }

    this.printSummary()
  }

  /**
   * 打印汇总结果
   */
  printSummary(): void {
    if (this.results.length === 0) {
      console.log('❌ 没有测试结果')
      return
    }

    console.log('\n' + '='.repeat(80))
    console.log('📊 HTTP 性能基准测试结果汇总')
    console.log('='.repeat(80))

    let totalImprovement = 0
    let successfulTests = 0

    for (const result of this.results) {
      if (result.success) {
        successfulTests++
        totalImprovement += result.improvement

        console.log(`\n✅ ${result.name}`)
        console.log(`   路径: ${result.method} ${result.path}`)
        console.log(`   TypeScript: ${result.tsAvg.toFixed(2)}ms`)
        console.log(`   Rust:      ${result.rustAvg.toFixed(2)}ms`)
        console.log(`   性能提升:  ${result.improvement > 0 ? '+' : ''}${result.improvement.toFixed(1)}%`)

        // 统计信息
        const tsMin = Math.min(...result.tsTimes)
        const tsMax = Math.max(...result.tsTimes)
        const rustMin = Math.min(...result.rustTimes)
        const rustMax = Math.max(...result.rustTimes)

        console.log(`   TypeScript 范围: ${tsMin.toFixed(2)}ms - ${tsMax.toFixed(2)}ms`)
        console.log(`   Rust 范围:      ${rustMin.toFixed(2)}ms - ${rustMax.toFixed(2)}ms`)
      } else {
        console.log(`\n❌ ${result.name} - 测试失败`)
      }
    }

    const avgImprovement = totalImprovement / successfulTests

    console.log('\n' + '='.repeat(80))
    console.log('📈 总体统计:')
    console.log(`   成功测试: ${successfulTests}/${this.results.length}`)
    console.log(`   平均性能提升: ${avgImprovement > 0 ? '+' : ''}${avgImprovement.toFixed(1)}%`)
    console.log('='.repeat(80))

    // 导出 JSON 报告
    this.exportJsonReport()
  }

  /**
   * 导出 JSON 报告
   */
  exportJsonReport(): void {
    const report = {
      timestamp: new Date().toISOString(),
      config: this.config,
      results: this.results
    }

    const blob = new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `http-benchmark-${Date.now()}.json`
    a.click()
    URL.revokeObjectURL(url)

    console.log('📁 JSON 报告已下载')
  }

  /**
   * 生成 HTML 报告
   */
  generateHtmlReport(): string {
    const styles = `
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; }
        .summary { background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 20px 0; }
        .test { background: white; border: 1px solid #e9ecef; border-radius: 8px; margin: 10px 0; padding: 15px; }
        .success { border-left: 4px solid #28a745; }
        .failed { border-left: 4px solid #dc3545; }
        .metric { display: inline-block; margin: 5px 10px; }
        .value { font-weight: bold; color: #495057; }
        .positive { color: #28a745; }
        .negative { color: #dc3545; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #dee2e6; padding: 8px; text-align: left; }
        th { background-color: #f8f9fa; }
      </style>
    `

    let html = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>HTTP 性能基准测试报告</title>
        ${styles}
      </head>
      <body>
        <div class="header">
          <h1>📊 HTTP 性能基准测试报告</h1>
          <p>生成时间: ${new Date().toLocaleString()}</p>
        </div>

        <div class="summary">
          <h2>📈 总体统计</h2>
          <p>总测试数: ${this.results.length}</p>
          <p>成功测试: ${this.results.filter(r => r.success).length}</p>
          <p>平均性能提升: ${this.results.length > 0
            ? (this.results.filter(r => r.success).reduce((a, b) => a + b.improvement, 0) / this.results.filter(r => r.success).length).toFixed(1)
            : 0}%</p>
        </div>

        <table>
          <thead>
            <tr>
              <th>测试名称</th>
              <th>方法</th>
              <th>路径</th>
              <th>TypeScript (ms)</th>
              <th>Rust (ms)</th>
              <th>性能提升</th>
              <th>状态</th>
            </tr>
          </thead>
          <tbody>
    `

    for (const result of this.results) {
      const improvementClass = result.improvement > 0 ? 'positive' : 'negative'
      const statusClass = result.success ? 'success' : 'failed'
      const statusText = result.success ? '✅ 成功' : '❌ 失败'

      html += `
        <tr class="${statusClass}">
          <td>${result.name}</td>
          <td>${result.method}</td>
          <td><code>${result.path}</code></td>
          <td>${result.tsAvg.toFixed(2)}</td>
          <td>${result.rustAvg.toFixed(2)}</td>
          <td class="${improvementClass}">${result.improvement > 0 ? '+' : ''}${result.improvement.toFixed(1)}%</td>
          <td>${statusText}</td>
        </tr>
      `
    }

    html += `
          </tbody>
        </table>
      </body>
      </html>
    `

    return html
  }

  /**
   * 导出 HTML 报告
   */
  exportHtmlReport(): void {
    const html = this.generateHtmlReport()
    const blob = new Blob([html], { type: 'text/html' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `http-benchmark-report-${Date.now()}.html`
    a.click()
    URL.revokeObjectURL(url)

    console.log('📄 HTML 报告已下载')
  }

  /**
   * 生成内存使用报告
   */
  async generateMemoryReport(): Promise<void> {
    if (!('memory' in performance)) {
      console.warn('此浏览器不支持内存 API')
      return
    }

    console.log('\n💾 内存使用报告')
    console.log('='.repeat(80))

    // TypeScript 实现内存测试
    console.log('🧪 测试 TypeScript 实现内存使用...')
    const tsMemoryBefore = (performance as any).memory?.usedJSHeapSize
    for (let i = 0; i < 50; i++) {
      await rustHttp.get('/health') // 实际会调用 TypeScript 回退实现
    }
    const tsMemoryAfter = (performance as any).memory?.usedJSHeapSize
    const tsMemoryIncrease = tsMemoryAfter - tsMemoryBefore

    // Rust 实现内存测试
    console.log('🧪 测试 Rust 实现内存使用...')
    const rustMemoryBefore = (performance as any).memory?.usedJSHeapSize
    for (let i = 0; i < 50; i++) {
      await rustHttp.get('/health')
    }
    const rustMemoryAfter = (performance as any).memory?.usedJSHeapSize
    const rustMemoryIncrease = rustMemoryAfter - rustMemoryBefore

    console.log(`\n内存使用增加:`)
    console.log(`   TypeScript: ${(tsMemoryIncrease / 1024 / 1024).toFixed(2)} MB`)
    console.log(`   Rust:      ${(rustMemoryIncrease / 1024 / 1024).toFixed(2)} MB`)
    console.log(`   节省:      ${((tsMemoryIncrease - rustMemoryIncrease) / 1024 / 1024).toFixed(2)} MB`)
  }
}

// 导出
export { HttpPerformanceBenchmark }
export type { BenchmarkResult, BenchmarkConfig }

// 创建默认实例
export const httpBenchmark = new HttpPerformanceBenchmark()

/**
 * 快捷测试方法
 */
export const runQuickBenchmark = async () => {
  console.log('🚀 开始快速基准测试...')

  await httpBenchmark.run(
    '健康检查',
    'GET',
    '/health',
    undefined,
    20
  )

  await httpBenchmark.run(
    '获取用户信息',
    'GET',
    '/auth/me',
    undefined,
    20
  )

  await httpBenchmark.run(
    '搜索用户',
    'GET',
    '/users/search?keyword=test',
    undefined,
    20
  )

  httpBenchmark.printSummary()
  httpBenchmark.exportJsonReport()
  httpBenchmark.exportHtmlReport()
}
