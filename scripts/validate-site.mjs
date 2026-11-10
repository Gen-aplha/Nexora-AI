import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const htmlFiles = fs.readdirSync(root).filter(name => name.endsWith(".html"));
const failures = [];

for (const file of htmlFiles) {
  const source = fs.readFileSync(path.join(root, file), "utf8");
  const ids = new Set();
  for (const match of source.matchAll(/\bid\s*=\s*["']([^"']+)["']/gi)) {
    const id = match[1];
    if (ids.has(id)) failures.push(file + ": duplicate id \"" + id + "\"");
    ids.add(id);
  }

  for (const match of source.matchAll(/\b(?:href|src)\s*=\s*["']([^"']+)["']/gi)) {
    const value = match[1].trim();
    if (!value || /^(?:https?:|mailto:|tel:|data:|javascript:|blob:|#)/i.test(value)) continue;
    const pathname = decodeURIComponent(value.split("#")[0].split("?")[0]);
    if (!pathname) continue;
    const target = path.resolve(root, pathname.startsWith("/") ? "." + pathname : pathname);
    if (target !== root && !target.startsWith(root + path.sep)) {
      failures.push(file + ": link escapes repository root: " + value);
      continue;
    }
    const resolved = fs.existsSync(target) && fs.statSync(target).isDirectory()
      ? path.join(target, "index.html")
      : target;
    if (!fs.existsSync(resolved)) failures.push(file + ": missing local target " + value);
  }
}

const sitemapPath = path.join(root, "sitemap.xml");
if (!fs.existsSync(sitemapPath)) failures.push("sitemap.xml is missing");
else {
  const sitemap = fs.readFileSync(sitemapPath, "utf8");
  for (const match of sitemap.matchAll(/<loc>([^<]+)<\/loc>/gi)) {
    const url = new URL(match[1]);
    const relative = url.pathname.replace(/^\/Nexora-AI\/?/, "");
    const target = path.join(root, relative || "index.html");
    if (!fs.existsSync(target)) failures.push("sitemap target does not exist: " + match[1]);
  }
}

if (failures.length) {
  console.error("NEXORA site validation failed:");
  for (const failure of failures) console.error(" - " + failure);
  process.exitCode = 1;
} else {
  console.log("NEXORA site validation passed (" + htmlFiles.length + " HTML pages checked).");
}
