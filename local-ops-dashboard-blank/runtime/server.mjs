import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const runtimeDir = fileURLToPath(new URL(".", import.meta.url));
const appRoot = resolve(runtimeDir, "..", "app");
const host = "127.0.0.1";
const requestedPort = Number(process.argv[2] || 4173);
const port = Number.isInteger(requestedPort) && requestedPort > 0 ? requestedPort : 4173;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
};

function safeFilePath(urlPath) {
  const cleanPath = decodeURIComponent(urlPath.split("?")[0]);
  const relativePath = cleanPath === "/" ? "index.html" : cleanPath.replace(/^\/+/, "");
  const candidate = resolve(appRoot, normalize(relativePath));
  if (candidate !== appRoot && !candidate.startsWith(`${appRoot}${sep}`)) return null;
  return candidate;
}

const server = createServer((request, response) => {
  if (request.url?.startsWith("/__dashboard_health")) {
    response.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
    response.end(JSON.stringify({ app: "noise-lab-local-dashboard", ok: true }));
    return;
  }

  let filePath = safeFilePath(request.url || "/");
  if (!filePath || !existsSync(filePath)) {
    filePath = join(appRoot, "index.html");
  }

  if (statSync(filePath).isDirectory()) filePath = join(filePath, "index.html");
  const isDataFile = filePath.endsWith(`${sep}data${sep}current-data.js`);
  response.writeHead(200, {
    "Content-Type": MIME[extname(filePath).toLowerCase()] || "application/octet-stream",
    "Cache-Control": isDataFile ? "no-store, max-age=0" : "public, max-age=3600",
  });
  createReadStream(filePath).pipe(response);
});

server.on("error", (error) => {
  console.error(error.code === "EADDRINUSE" ? `PORT_IN_USE:${port}` : error.message);
  process.exit(2);
});

server.listen(port, host, () => {
  console.log(`http://${host}:${port}/`);
});

