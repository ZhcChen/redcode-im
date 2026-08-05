import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { serveRelease } from "./h5-release-server";

const [dist = "dist"] = process.argv.slice(2);
const resolved = resolve(dist);
const expected = JSON.parse(
  await readFile(resolve(resolved, "security-headers.json"), "utf8"),
) as Record<string, string>;
const manifest = JSON.parse(
  await readFile(resolve(resolved, "release-manifest.json"), "utf8"),
) as {
  base_path: string;
  assets: Array<{ path: string }>;
};
const script = manifest.assets.find((asset) => asset.path.endsWith(".js"));
if (!script)
  throw new Error("[h5-release-http] candidate has no JavaScript asset");

const server = await serveRelease({ dist: resolved, port: 0 });
try {
  for (const path of [
    manifest.base_path,
    `${manifest.base_path}${script.path}`,
    `${manifest.base_path}missing-route`,
  ]) {
    const response = await fetch(new URL(path, server.url));
    if (!response.ok)
      throw new Error(
        `[h5-release-http] ${path} returned HTTP ${response.status}`,
      );
    for (const [name, value] of Object.entries(expected)) {
      if (response.headers.get(name) !== value) {
        throw new Error(`[h5-release-http] ${path} has invalid ${name}`);
      }
    }
  }
  for (const path of [
    `${manifest.base_path}release-manifest.json`,
    `${manifest.base_path}security-headers.json`,
  ]) {
    const response = await fetch(new URL(path, server.url));
    if (response.status !== 404)
      throw new Error(`[h5-release-http] private artifact exposed: ${path}`);
  }
  if (manifest.base_path !== "/") {
    const sibling = `${manifest.base_path.slice(0, -1)}-outside/`;
    for (const path of ["/", sibling]) {
      const response = await fetch(new URL(path, server.url));
      if (response.status !== 404) {
        throw new Error(`[h5-release-http] path outside base exposed: ${path}`);
      }
    }
  }
  console.log(
    `[h5-release-http] verified ${Object.keys(expected).length} headers on candidate responses`,
  );
} finally {
  server.stop(true);
}
