export interface FileHashResult {
  hashValue: string | null;
  hashAlg: number | null;
}

export async function computeFileHash(file: Blob): Promise<FileHashResult> {
  try {
    const cryptoObj: Crypto | undefined = window.crypto;
    if (!cryptoObj?.subtle || typeof cryptoObj.subtle.digest !== "function") {
      console.warn("[desktop-el-renderer] crypto.subtle unavailable, skip file hash");
      return { hashValue: null, hashAlg: null };
    }

    const buffer = await file.arrayBuffer();
    const digest = await cryptoObj.subtle.digest("SHA-256", buffer);
    const hashHex = Array.from(new Uint8Array(digest))
      .map((item) => item.toString(16).padStart(2, "0"))
      .join("");

    return {
      hashValue: hashHex,
      hashAlg: 2
    };
  } catch (error) {
    console.warn("[desktop-el-renderer] compute file hash failed", error);
    return { hashValue: null, hashAlg: null };
  }
}
