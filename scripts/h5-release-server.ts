import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { check } from "./h5-release-security";

type Manifest = { assets: Array<{ path: string }> };
type ReleaseServerOptions = { dist: string; hostname?: string; port?: number };

const privateArtifacts = new Set([
  "release-manifest.json",
  "security-headers.json",
]);

function contentType(path: string): string {
  const extension = path.split(".").pop()?.toLowerCase();
  return (
    {
      css: "text/css; charset=utf-8",
      html: "text/html; charset=utf-8",
      js: "text/javascript; charset=utf-8",
      json: "application/json; charset=utf-8",
      mjs: "text/javascript; charset=utf-8",
      png: "image/png",
      svg: "image/svg+xml",
      wasm: "application/wasm",
      webp: "image/webp",
      woff2: "font/woff2",
    }[extension ?? ""] ?? "application/octet-stream"
  );
}

async function serveRelease(options: ReleaseServerOptions) {
  await check(options.dist);
  const dist = resolve(options.dist);
  const manifest = JSON.parse(
    await readFile(resolve(dist, "release-manifest.json"), "utf8"),
  ) as Manifest;
  const securityHeaders = JSON.parse(
    await readFile(resolve(dist, "security-headers.json"), "utf8"),
  ) as Record<string, string>;
  const allowed = new Set(
    manifest.assets
      .map((asset) => asset.path)
      .filter((path) => !privateArtifacts.has(path)),
  );

  return Bun.serve({
    hostname: options.hostname ?? "127.0.0.1",
    port: options.port ?? 8017,
    async fetch(request) {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response(null, { status: 405, headers: securityHeaders });
      }
      let requested: string;
      try {
        requested = decodeURIComponent(new URL(request.url).pathname).replace(
          /^\/+/,
          "",
        );
      } catch {
        return new Response(null, { status: 400, headers: securityHeaders });
      }
      if (privateArtifacts.has(requested)) {
        return new Response(null, { status: 404, headers: securityHeaders });
      }
      const asset = allowed.has(requested) ? requested : "index.html";
      if (!allowed.has(asset))
        return new Response(null, { status: 404, headers: securityHeaders });
      const headers = new Headers(securityHeaders);
      headers.set("content-type", contentType(asset));
      return new Response(
        request.method === "HEAD" ? null : Bun.file(resolve(dist, asset)),
        { headers },
      );
    },
  });
}

if (import.meta.main) {
  const [dist = "dist"] = process.argv.slice(2);
  const server = await serveRelease({
    dist,
    hostname: process.env.H5_RELEASE_HOST ?? "127.0.0.1",
    port: Number(process.env.H5_RELEASE_PORT ?? 8017),
  });
  console.log(`[h5-release] serving ${resolve(dist)} at ${server.url}`);
}

export { serveRelease };
