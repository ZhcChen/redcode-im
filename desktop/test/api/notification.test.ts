import { beforeEach, describe, expect, it, vi } from 'vitest'

const {
  invokeMock,
  isPermissionGrantedMock,
  requestPermissionMock,
  sendNotificationMock,
  isFocusedMock,
  isMinimizedMock
} = vi.hoisted(() => ({
  invokeMock: vi.fn(),
  isPermissionGrantedMock: vi.fn(),
  requestPermissionMock: vi.fn(),
  sendNotificationMock: vi.fn(),
  isFocusedMock: vi.fn(),
  isMinimizedMock: vi.fn()
}))

vi.mock('@tauri-apps/api/core', () => ({
  invoke: invokeMock
}))

vi.mock('@tauri-apps/api/webviewWindow', () => ({
  getCurrentWebviewWindow: () => ({
    isFocused: isFocusedMock,
    isMinimized: isMinimizedMock
  })
}))

vi.mock('@tauri-apps/plugin-notification', () => ({
  isPermissionGranted: isPermissionGrantedMock,
  requestPermission: requestPermissionMock,
  sendNotification: sendNotificationMock
}))

import { NotificationApi } from '@/api/notification'

describe('notification api', () => {
  beforeEach(() => {
    isFocusedMock.mockResolvedValue(false)
    isMinimizedMock.mockResolvedValue(false)
    isPermissionGrantedMock.mockResolvedValue(true)
    requestPermissionMock.mockResolvedValue('granted')
  })

  it('sends system notification only when window should not suppress it', async () => {
    await NotificationApi.showSystemNotification({
      title: '  新消息  ',
      body: '  来自测试用户  '
    })

    expect(sendNotificationMock).toHaveBeenCalledWith({
      title: '新消息',
      body: '来自测试用户'
    })
  })

  it('skips system notification when window is focused and not minimized', async () => {
    isFocusedMock.mockResolvedValue(true)
    isMinimizedMock.mockResolvedValue(false)

    await NotificationApi.showSystemNotification({ title: 'a', body: 'b' })

    expect(sendNotificationMock).not.toHaveBeenCalled()
  })

  it('plays sound and requests attention on new message notification', async () => {
    const systemSpy = vi
      .spyOn(NotificationApi, 'showSystemNotification')
      .mockResolvedValue()

    await NotificationApi.showNewMessageNotification({
      title: '新消息',
      body: '请查看'
    })

    expect(invokeMock).toHaveBeenCalledWith('play_notification_sound')
    expect(invokeMock).toHaveBeenCalledWith('request_attention')
    expect(systemSpy).toHaveBeenCalledTimes(1)
  })
})
