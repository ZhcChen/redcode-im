/**
 * 测试窗口标题功能
 */
import { updateWindowTitle, generateWindowTitle } from './tauri'

// 测试生成标题功能
export function testGenerateTitle() {
  console.log('=== 测试生成窗口标题功能 ===')
  
  const testCases = [
    { userInfo: undefined, expected: 'Chatly' },
    { userInfo: {}, expected: 'Chatly' },
    { userInfo: { mobile: '' }, expected: 'Chatly' },
    { userInfo: { mobile: '13800138000' }, expected: 'Chatly - 13800138000' },
    { userInfo: { mobile: '15888888888' }, expected: 'Chatly - 15888888888' },
  ]
  
  testCases.forEach(({ userInfo, expected }, index) => {
    const result = generateWindowTitle(userInfo)
    const passed = result === expected
    console.log(`测试 ${index + 1}: ${passed ? '✅' : '❌'}`)
    console.log(`  输入: ${JSON.stringify(userInfo)}`)
    console.log(`  期望: ${expected}`)
    console.log(`  实际: ${result}`)
    console.log('')
  })
}

// 测试更新窗口标题功能
export async function testUpdateTitle() {
  console.log('=== 测试更新窗口标题功能 ===')
  
  try {
    console.log('测试1: 设置默认标题')
    await updateWindowTitle()
    console.log('✅ 默认标题设置完成')
    
    await new Promise(resolve => setTimeout(resolve, 1000))
    
    console.log('测试2: 设置带手机号的标题')
    await updateWindowTitle({ mobile: '13800138000' })
    console.log('✅ 手机号标题设置完成')
    
    await new Promise(resolve => setTimeout(resolve, 1000))
    
    console.log('测试3: 重置为默认标题')
    await updateWindowTitle()
    console.log('✅ 重置标题完成')
    
  } catch (error) {
    console.error('❌ 测试失败:', error)
  }
}

// 在控制台运行测试
if (typeof window !== 'undefined') {
  // @ts-ignore
  window.testTitle = {
    testGenerateTitle,
    testUpdateTitle
  }
  
  console.log('窗口标题测试功能已加载到 window.testTitle')
  console.log('可以在控制台运行:')
  console.log('- window.testTitle.testGenerateTitle()')
  console.log('- window.testTitle.testUpdateTitle()')
}
