export interface DirectUploadSignature {
  url: string;
  method: string;
  headers: Record<string, string>;
  key: string;
}

export async function uploadWithSignature(
  file: File,
  signature: DirectUploadSignature
): Promise<Response> {
  const headers = new Headers(signature.headers || {});
  if (!headers.has('Content-Type')) {
    headers.set('Content-Type', file.type || 'application/octet-stream');
  }

  return fetch(signature.url, {
    method: signature.method || 'PUT',
    headers,
    body: file,
  });
}
