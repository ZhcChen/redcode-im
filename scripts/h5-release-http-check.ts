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
  assets: Array<{ path: string }>;
};
const script = manifest.assets.find((asset) => asset.path.endsWith(".js"));
if (!script)
  throw new Error("[h5-release-http] candidate has no JavaScript asset");

const server = await serveRelease({ dist: resolved, port: 0 });
try {
  for (const path of ["/", `/${script.path}`, "/missing-route"]) {
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
  for (const path of ["/release-manifest.json", "/security-headers.json"]) {
    const response = await fetch(new URL(path, server.url));
    if (response.status !== 404)
      throw new Error(`[h5-release-http] private artifact exposed: ${path}`);
  }
  console.log(
    `[h5-release-http] verified ${Object.keys(expected).length} headers on candidate responses`,
  );
} finally {
  server.stop(true);
}
