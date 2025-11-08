/**
 * 二进制与 Base64 转换工具
 */
const hasBuffer = typeof globalThis !== 'undefined' && typeof (globalThis as any).Buffer !== 'undefined';

const encodeBinaryToBase64 = (binary: string): string => {
  if (typeof btoa === 'function') {
    return btoa(binary);
  }
  if (hasBuffer) {
    return (globalThis as any).Buffer.from(binary, 'binary').toString('base64');
  }
  throw new Error('当前环境不支持 Base64 编码');
};

const decodeBase64ToBinary = (base64: string): string => {
  if (typeof atob === 'function') {
    return atob(base64);
  }
  if (hasBuffer) {
    return (globalThis as any).Buffer.from(base64, 'base64').toString('binary');
  }
  throw new Error('当前环境不支持 Base64 解码');
};

export const arrayBufferToBase64 = (buffer: ArrayBuffer): string => {
  const bytes = new Uint8Array(buffer);
  const chunk = 0x8000;
  let binary = '';
  for (let i = 0; i < bytes.length; i += chunk) {
    const slice = bytes.subarray(i, i + chunk);
    binary += String.fromCharCode(...slice);
  }
  return encodeBinaryToBase64(binary);
};

export const uint8ArrayToBase64 = (bytes: Uint8Array): string => {
  return arrayBufferToBase64(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
};

export const base64ToUint8Array = (base64: string): Uint8Array => {
  const binary = decodeBase64ToBinary(base64);
  const len = binary.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
};

export const blobToBase64 = async (blob: Blob): Promise<string> => {
  const buffer = await blob.arrayBuffer();
  return arrayBufferToBase64(buffer);
};
