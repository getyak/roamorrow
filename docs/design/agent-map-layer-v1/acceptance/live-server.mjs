// An isolated real-data acceptance runtime. This is not the production Go backend.
import { randomBytes, randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { candidateDigest, rubricHash } from "./score.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { startServer } from "../demo/server.mjs";
import { createDomain } from "../demo/domain.mjs";
import { createProviders } from "./providers.mjs";
export async function startLiveServer({
  dir,
  port = 4650,
  publicBaseURL = null,
  envFile,
  cacheDir,
} = {}) {
  if (!dir) throw Error("isolated data directory is required");
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const metadata = {
    candidate_digest: candidateDigest(),
    rubric_sha256: rubricHash(),
    source_revision: execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim(),
    runtime_id: randomUUID(),
    started_at: new Date().toISOString(),
  };
  const providers = createProviders(cacheDir ?? join(dir, "provider-cache"), { envFile });
  const bearer = randomBytes(24).toString("hex"),
    guestBearer = randomBytes(24).toString("hex");
  const runtime = await startServer({
    port,
    dir: join(dir, "state"),
    bearer,
    runtimeMetadata: metadata,
    scoped: true,
    publicBaseURL,
    extraBearers: { [guestBearer]: "acceptance-other-user" },
    domainFactory: (storage, base) =>
      createDomain(storage, base, {
        catalog: providers.catalog,
        routeLookup: providers.routeLookup,
        mode: "live",
      }),
    prepareTool: providers.prepareTool,
  });
  writeFileSync(
    join(dir, "runtime.private.json"),
    JSON.stringify(
      {
        ...metadata,
        url: runtime.baseURL,
        listen_url: runtime.listenURL,
        bearer,
        guest_bearer: guestBearer,
        scope: "isolated-acceptance-only",
        transport: "walking",
      },
      null,
      2,
    ),
    { mode: 0o600 },
  );
  return { ...runtime, providers };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const argv = process.argv.slice(2),
    get = (flag, fallback) => {
      const i = argv.indexOf(flag);
      return i < 0 ? fallback : argv[i + 1];
    };
  const runtime = await startLiveServer({
    dir: resolve(get("--dir", "./map-live-acceptance-state")),
    port: Number(get("--port", "4650")),
    publicBaseURL: get("--public-url", null),
    envFile: get("--env-file", undefined),
    cacheDir: get("--cache-dir", undefined),
  });
  console.log(
    `Real-data acceptance runtime: ${runtime.listenURL}\nTransport: walking; scoped authentication required; tokens stored only in runtime.private.json`,
  );
  for (const signal of ["SIGINT", "SIGTERM"])
    process.on(signal, () => runtime.server.close(() => process.exit(0)));
}
