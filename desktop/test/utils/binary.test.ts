import { describe, expect, it } from 'vitest'

import {
  arrayBufferToBase64,
  base64ToUint8Array,
  uint8ArrayToBase64
} from '@/utils/binary'

describe('binary utils', () => {
  it('converts array buffer to base64 and decodes back', () => {
    const source = new TextEncoder().encode('hello-chatly')
    const base64 = arrayBufferToBase64(source.buffer)
    const decoded = base64ToUint8Array(base64)

    expect(new TextDecoder().decode(decoded)).toBe('hello-chatly')
  })

  it('converts Uint8Array to base64 using exact byte range', () => {
    const source = new Uint8Array([255, 0, 1, 2, 3])
    const subArray = source.subarray(1, 4)
    const base64 = uint8ArrayToBase64(subArray)
    const decoded = base64ToUint8Array(base64)

    expect(Array.from(decoded)).toEqual([0, 1, 2])
  })
})
