/**
 * Tauri 工具函数测试
 */
import { generateWindowTitle } from '../tauri'

describe('Tauri Utils', () => {
  describe('generateWindowTitle', () => {
    it('应该生成默认标题当没有用户信息时', () => {
      expect(generateWindowTitle()).toBe('Chatly')
      expect(generateWindowTitle({})).toBe('Chatly')
      expect(generateWindowTitle({ mobile: '' })).toBe('Chatly')
    })

    it('应该完整显示手机号', () => {
      const userInfo = { mobile: '13800138000' }
      expect(generateWindowTitle(userInfo)).toBe('Chatly - 13800138000')
    })

    it('应该完整显示不同的手机号', () => {
      expect(generateWindowTitle({ mobile: '15312345678' })).toBe('Chatly - 15312345678')
      expect(generateWindowTitle({ mobile: '18888888888' })).toBe('Chatly - 18888888888')
    })

    it('应该处理短号码', () => {
      expect(generateWindowTitle({ mobile: '12345' })).toBe('Chatly - 12345')
      expect(generateWindowTitle({ mobile: '123456' })).toBe('Chatly - 123456')
    })

    it('应该处理各种长度的号码', () => {
      expect(generateWindowTitle({ mobile: '1234567' })).toBe('Chatly - 1234567')
      expect(generateWindowTitle({ mobile: '12345678' })).toBe('Chatly - 12345678')
      expect(generateWindowTitle({ mobile: '123456789' })).toBe('Chatly - 123456789')
    })

    it('应该忽略其他用户信息字段', () => {
      const userInfo = {
        mobile: '13800138000',
        nickname: '测试用户',
        username: 'testuser'
      }
      expect(generateWindowTitle(userInfo)).toBe('Chatly - 13800138000')
    })
  })
})
