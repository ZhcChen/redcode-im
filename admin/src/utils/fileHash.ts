/**
 * 文件哈希工具（Admin）
 *
 * 使用浏览器内置 Web Crypto 计算 SHA-256，
 * 对应后端的 hash_alg = 2。
 * 若运行环境不支持 Web Crypto，则优雅降级为不带哈希。
 */

export interface FileHashResult {
  hashValue: string | null;
  hashAlg: number | null;
}

/**
 * 计算文件哈希（SHA-256）
 */
export async function computeFileHash(file: Blob): Promise<FileHashResult> {
  try {
    const cryptoObj: Crypto | undefined =
      (window as any).crypto || (window as any).msCrypto;
    if (
      !cryptoObj ||
      !cryptoObj.subtle ||
      typeof cryptoObj.subtle.digest !== 'function'
    ) {
      // 运行环境不支持 Web Crypto，直接降级
      // eslint-disable-next-line no-console
      console.warn('[admin:fileHash] crypto.subtle 不可用，跳过哈希计算');
      return { hashValue: null, hashAlg: null };
    }

    const buffer = await file.arrayBuffer();
    const digest = await cryptoObj.subtle.digest('SHA-256', buffer);
    const hashArray = Array.from(new Uint8Array(digest));
    const hashHex = hashArray
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');

    return {
      hashValue: hashHex,
      hashAlg: 2, // 2 = sha256
    };
  } catch (error) {
    // eslint-disable-next-line no-console
    console.warn('[admin:fileHash] 计算文件哈希失败，将跳过哈希上报', error);
    return { hashValue: null, hashAlg: null };
  }
}
