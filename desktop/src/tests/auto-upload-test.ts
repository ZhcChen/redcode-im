import { invoke } from '@tauri-apps/api/core'
import { UserApi } from '../api/user'
import { SystemApi } from '../api/system'
import { store } from '../store'

const AUTO_UPLOAD_ENABLED = import.meta.env.VITE_AUTO_UPLOAD_TEST === 'true'
const TEST_ACCOUNT = import.meta.env.VITE_AUTO_UPLOAD_ACCOUNT || 'admin@example.com'
const TEST_PASSWORD = import.meta.env.VITE_AUTO_UPLOAD_PASSWORD || 'password123'
const TEST_IMAGE_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAD0lEQVR4nGP4z4APMOGVHAgAEGkCBusZT6YAAAAASUVORK5CYII='

const toUint8Array = (base64: string): Uint8Array => {
  const binary = atob(base64)
  const len = binary.length
  const bytes = new Uint8Array(len)
  for (let i = 0; i < len; i += 1) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes
}

const createTestFile = (): File => {
  const bytes = toUint8Array(TEST_IMAGE_BASE64)
  return new File([bytes], `auto_avatar_${Date.now()}.png`, { type: 'image/png' })
}

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

export const setupAutoUploadTest = () => {
  if (!AUTO_UPLOAD_ENABLED) {
    return
  }

  console.info('[AutoUploadTest] 自动头像上传测试已启用')

  setTimeout(() => {
    runAutoUploadTest().catch((error) => {
      console.error('[AutoUploadTest] 测试失败:', error)
      quitApp()
    })
  }, 1200)
}

const quitApp = async () => {
  try {
    await invoke('quit_app')
  } catch (error) {
    console.warn('[AutoUploadTest] 退出应用失败:', error)
  }
}

const runAutoUploadTest = async () => {
  const timeoutId = window.setTimeout(() => {
    console.error('[AutoUploadTest] 超过30秒未完成，强制退出')
    quitApp()
  }, 30000)

  try {
    console.info('[AutoUploadTest] 开始登录流程', { account: TEST_ACCOUNT })
    const loginResp = await SystemApi.loginWithSMS({ phone: TEST_ACCOUNT, code: TEST_PASSWORD })
    if (!loginResp.success || !loginResp.data) {
      throw new Error(loginResp.message || '登录接口返回失败')
    }

    await store.dispatch('login', {
      token: loginResp.data.token,
      userInfo: loginResp.data.userInfo
    })

    console.info('[AutoUploadTest] 登录成功，开始头像上传流程')

    const file = createTestFile()
    const uploadResp = await UserApi.uploadAvatar(file)

    if (uploadResp.success) {
      console.info('[AutoUploadTest] 头像上传成功')
    } else {
      console.error('[AutoUploadTest] 头像上传失败', uploadResp)
    }

    await sleep(1000)
  } catch (error) {
    console.error('[AutoUploadTest] 执行过程中出现错误:', error)
  } finally {
    window.clearTimeout(timeoutId)
    console.info('[AutoUploadTest] 测试结束，准备退出应用')
    await sleep(500)
    quitApp()
  }
}
