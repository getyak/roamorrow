import http from "node:http";
import { readFileSync, mkdirSync, writeFileSync, existsSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import { randomBytes, createHash } from "node:crypto";
import { tools, validate } from "./contract.mjs";
import { createDomain, DomainError } from "./domain.mjs";
const root = dirname(fileURLToPath(import.meta.url));
const mime = { ".mjs": "text/javascript", ".css": "text/css", ".html": "text/html" };
export async function startServer({
  port = 0,
  dir = join(tmpdir(), "roamorrow-map-layer-get294"),
  bearer = randomBytes(24).toString("hex"),
  domainFactory = createDomain,
  prepareTool = null,
  scoped = false,
  publicBaseURL = null,
  extraBearers = {},
  runtimeMetadata = null,
} = {}) {
  mkdirSync(dir, { recursive: true });
  const secretPath = join(dir, "session-secret");
  const secret = existsSync(secretPath)
    ? readFileSync(secretPath, "utf8")
    : randomBytes(24).toString("hex");
  if (!existsSync(secretPath)) writeFileSync(secretPath, secret, { mode: 0o600 });
  const sign = (s) =>
    createHash("sha256")
      .update(secret + s)
      .digest("hex");
  let domain, baseURL, listenURL;
  const quotas = new Map();
  const trace = [];
  const server = http.createServer(async (req, res) => {
    res.setHeader("Cache-Control", "no-store");
    if (runtimeMetadata) {
      res.setHeader("X-Map-Candidate", runtimeMetadata.candidate_digest);
      res.setHeader("X-Map-Revision", runtimeMetadata.source_revision);
      res.setHeader("X-Map-Runtime", runtimeMetadata.runtime_id);
    }
    res.setHeader("Referrer-Policy", "no-referrer");
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("X-Robots-Tag", "noindex, nofollow");
    const json = (status, value) => {
      res.writeHead(status, { "Content-Type": "application/json" });
      res.end(JSON.stringify(value));
    };
    const host = req.headers.host;
    if (
      ![
        new URL(baseURL).host,
        new URL(listenURL).host,
        `localhost:${new URL(listenURL).port}`,
      ].includes(host)
    ) {
      json(403, { error: "invalid host" });
      return;
    }
    const u = new URL(req.url, baseURL);
    const origin = req.headers.origin;
    if (origin && origin !== baseURL && origin !== baseURL.replace("127.0.0.1", "localhost")) {
      json(403, { error: "invalid origin" });
      return;
    }
    let subject = null;
    const session = req.headers.cookie?.match(/(?:^|; )map_demo=([^;]+)/)?.[1];
    if (session) {
      const [sub, sig] = session.split(".");
      if (sig === sign(sub)) subject = sub;
    }
    if (req.headers.authorization === `Bearer ${bearer}`) subject = "fixture-api-owner";
    for (const [token, sub] of Object.entries(extraBearers))
      if (req.headers.authorization === `Bearer ${token}`) subject = sub;
    const ensureSession = () => {
      if (!subject) {
        subject = randomBytes(12).toString("hex");
        res.setHeader(
          "Set-Cookie",
          `map_demo=${subject}.${sign(subject)}; HttpOnly; SameSite=Strict; Path=/`,
        );
      }
      return subject;
    };
    try {
      if (req.method === "GET" && u.pathname === "/favicon.ico") {
        res.writeHead(204);
        res.end();
        return;
      }
      if (req.method === "GET" && u.pathname === "/healthz") {
        json(200, { ok: true, demo: !scoped, protocol: "2025-11-25" });
        return;
      }
      if (req.method === "POST" && u.pathname === "/api/session") {
        if (!subject) {
          json(401, { error: "scoped token required" });
          return;
        }
        res.setHeader(
          "Set-Cookie",
          `map_demo=${subject}.${sign(subject)}; HttpOnly; SameSite=Strict; Path=/${publicBaseURL ? "; Secure" : ""}`,
        );
        json(200, { ok: true });
        return;
      }
      if (req.method === "GET" && u.pathname === "/contract.json") {
        json(200, { tools });
        return;
      }
      if (req.method === "GET" && u.pathname === "/api/trace") {
        json(200, {
          trace: trace.filter((x) => x.subject === subject).map(({ subject, ...x }) => x),
        });
        return;
      }
      if (req.method === "GET" && u.pathname.startsWith("/api/maps/")) {
        json(200, { snapshot: domain.get(u.pathname.split("/").at(-1), subject), can_edit: true });
        return;
      }
      if (req.method === "GET" && u.pathname.startsWith("/api/share/")) {
        json(200, domain.share(u.pathname.split("/").at(-1), subject));
        return;
      }
      if (req.method === "POST" && u.pathname.startsWith("/api/fork/")) {
        if (scoped && !subject) {
          json(401, { error: "login required to fork" });
          return;
        }
        const result = domain.fork(u.pathname.split("/").at(-1), ensureSession());
        json(200, { ...result, can_edit: true });
        return;
      }
      if (u.pathname === "/mcp/maps") {
        if (req.method !== "POST") {
          res.setHeader("Allow", "POST");
          json(405, { error: "POST only; JSON response stream" });
          return;
        }
        if (!subject) {
          json(401, { error: "demo owner session required" });
          return;
        }
        if (!req.headers["content-type"]?.startsWith("application/json")) {
          json(415, { error: "application/json required" });
          return;
        }
        const parts = [];
        let size = 0;
        for await (const chunk of req) {
          size += chunk.length;
          if (size > 256 * 1024) {
            json(413, { error: "body too large" });
            return;
          }
          parts.push(chunk);
        }
        let rpc;
        try {
          rpc = JSON.parse(Buffer.concat(parts).toString());
        } catch {
          json(200, { jsonrpc: "2.0", id: null, error: { code: -32700, message: "parse error" } });
          return;
        }
        if (
          !rpc ||
          Array.isArray(rpc) ||
          rpc.jsonrpc !== "2.0" ||
          typeof rpc.method !== "string" ||
          ("id" in rpc && !["string", "number"].includes(typeof rpc.id))
        ) {
          json(200, {
            jsonrpc: "2.0",
            id: null,
            error: { code: -32600, message: "invalid request" },
          });
          return;
        }
        const protocol = req.headers["mcp-protocol-version"];
        if (protocol && protocol !== "2025-11-25") {
          json(400, { error: "unsupported protocol version" });
          return;
        }
        if (!("id" in rpc)) {
          res.writeHead(202);
          res.end();
          return;
        }
        const reply = (result) => json(200, { jsonrpc: "2.0", id: rpc.id, result });
        if (rpc.method === "initialize") {
          reply({
            protocolVersion: "2025-11-25",
            capabilities: { tools: { listChanged: false }, resources: {} },
            serverInfo: { name: "roamorrow-map-boundary-demo", version: "0.1.0" },
          });
          return;
        }
        if (rpc.method === "ping") {
          reply({});
          return;
        }
        if (rpc.method === "tools/list") {
          reply({ tools });
          return;
        }
        if (rpc.method === "resources/read") {
          const uri = rpc.params?.uri;
          const mid =
            typeof uri === "string" && uri.match(/^roamorrow:\/\/maps\/(map_[\w-]+)$/)?.[1];
          if (!mid) throw new DomainError("VALIDATION_ERROR", "invalid resource URI");
          const snapshot = domain.get(mid, subject);
          reply({
            contents: [{ uri, mimeType: "application/json", text: JSON.stringify(snapshot) }],
          });
          return;
        }
        if (rpc.method !== "tools/call") {
          json(200, {
            jsonrpc: "2.0",
            id: rpc.id,
            error: { code: -32601, message: "method not found" },
          });
          return;
        }
        const name = rpc.params?.name,
          args = rpc.params?.arguments;
        const tool = tools.find((t) => t.name === name);
        if (!tool) {
          json(200, {
            jsonrpc: "2.0",
            id: rpc.id,
            error: { code: -32602, message: "unknown tool" },
          });
          return;
        }
        if (scoped) {
          const count = quotas.get(subject) ?? 0;
          if (count >= 150) {
            json(429, { error: "acceptance tool budget exhausted" });
            return;
          }
          quotas.set(subject, count + 1);
        }
        let result;
        const started = Date.now();
        try {
          try {
            validate(tool.inputSchema, args);
          } catch (e) {
            throw new DomainError("VALIDATION_ERROR", e.message);
          }
          if (scoped && req.headers["x-demo-fault"])
            throw new DomainError("VALIDATION_ERROR", "public fault injection disabled");
          if (args.map_id) domain.get(args.map_id, subject);
          if (prepareTool) await prepareTool(name, args, subject, domain);
          result = await domain.call(name, args, subject, { fault: req.headers["x-demo-fault"] });
        } catch (e) {
          if (!(e instanceof DomainError)) throw e;
          result = {
            ok: false,
            error: { code: e.code, message: e.message, retryable: e.retryable, details: e.details },
          };
        }
        validate(tool.outputSchema, result);
        trace.push({
          subject,
          name,
          input: args,
          output: result,
          elapsed_ms: Date.now() - started,
        });
        if (trace.length > 150) trace.shift();
        reply({
          isError: !result.ok,
          content: [{ type: "text", text: JSON.stringify(result) }],
          structuredContent: result,
        });
        return;
      }
      const staticFiles = { "/app.mjs": "app.mjs", "/style.css": "style.css" };
      let filename = staticFiles[u.pathname];
      if (
        req.method === "GET" &&
        (u.pathname === "/" ||
          u.pathname === "/interaction" ||
          /^\/(s|m)\/[\w-]+$/.test(u.pathname))
      ) {
        filename = "index.html";
        if (!scoped && (u.pathname === "/" || u.pathname === "/interaction")) ensureSession();
      }
      if (req.method === "GET" && filename) {
        const ext = filename.slice(filename.lastIndexOf("."));
        res.writeHead(200, { "Content-Type": `${mime[ext]}; charset=utf-8` });
        res.end(readFileSync(join(root, filename)));
        return;
      }
      json(404, { error: "not found" });
    } catch (e) {
      if (e instanceof DomainError)
        json(e.code === "NOT_FOUND" ? 404 : 409, {
          ok: false,
          error: { code: e.code, message: e.message, retryable: e.retryable, details: e.details },
        });
      else {
        console.error("demo error:", e.message);
        json(500, { error: "demo internal error" });
      }
    }
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", resolve);
  });
  listenURL = `http://127.0.0.1:${server.address().port}`;
  baseURL = publicBaseURL ?? listenURL;
  domain = domainFactory(dir, baseURL);
  return {
    server,
    baseURL,
    listenURL,
    bearer,
    dir,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const runtime = await startServer({
    port: Number(process.env.MAP_DEMO_PORT ?? 4649),
    dir: process.env.MAP_DEMO_DATA_DIR,
  });
  console.log(
    `Map Layer boundary demo: ${runtime.baseURL}\nInteraction sheet: ${runtime.baseURL}/interaction\nData: ${runtime.dir}\nFixture places + estimated transit. Grok conversation is scripted; MCP calls are real HTTP.`,
  );
  for (const signal of ["SIGINT", "SIGTERM"])
    process.on(signal, () => {
      runtime.server.close(() => process.exit(0));
    });
}
