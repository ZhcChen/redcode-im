import { describe, expect, it } from 'vitest'

const liveBackendEnabled = process.env.DESKTOP_LIVE_BACKEND_ENABLED === 'true'
const apiBaseUrl = (process.env.DESKTOP_API_BASE_URL || 'http://127.0.0.1:8010').replace(/\/+$/, '')
const wsUrl =
  process.env.DESKTOP_WS_URL ||
  apiBaseUrl.replace(/^http:\/\//, 'ws://').replace(/^https:\/\//, 'wss://') + '/ws'

const liveIt = liveBackendEnabled ? it : it.skip

async function postJson<T>(path: string, body: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body)
  })

  if (!response.ok) {
    expect.fail(`${path} returned HTTP ${response.status}: ${await response.text()}`)
  }

  return (await response.json()) as T
}

describe('desktop live backend smoke', () => {
  liveIt('reaches healthz, performs email auth, and opens websocket', async () => {
    const healthResponse = await fetch(`${apiBaseUrl}/healthz`)
    expect(healthResponse.status).toBe(200)
    expect((await healthResponse.text()).trim()).toBe('ok')

    const email = `desktop-live-${Date.now()}-${Math.random().toString(16).slice(2)}@example.test`
    const password = 'pass123456'

    const registered = await postJson<{ email: string; username: string; status: string }>(
      '/auth/register',
      {
        email,
        password,
        nickname: 'Desktop Live'
      }
    )
    expect(registered.email).toBe(email)
    expect(registered.username).toMatch(/^u_/)
    expect(registered.username.length).toBeLessThanOrEqual(50)
    expect(registered.status).toBe('active')

    const login = await postJson<{
      token: string
      refresh_token: string
      user: { email: string; username: string }
    }>('/auth/login', {
      email,
      password
    })
    expect(login.token).toBeTruthy()
    expect(login.refresh_token).toBeTruthy()
    expect(login.user.email).toBe(email)
    expect(login.user.username).toBe(registered.username)

    const socket = new WebSocket(wsUrl)
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('websocket open timeout')), 10_000)
      socket.addEventListener('open', () => {
        clearTimeout(timeout)
        resolve()
      })
      socket.addEventListener('error', () => {
        clearTimeout(timeout)
        reject(new Error('websocket open failed'))
      })
    })
    socket.close()
  })
})
