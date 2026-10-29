/** Bounded GET-324 host/provider evaluation. Does not invoke a model or personal data. */
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, readdirSync, mkdtempSync, rmSync } from "node:fs";
import { dirname, resolve, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { tmpdir } from "node:os";
import { gzipSync, gunzipSync } from "node:zlib";
const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../../../..");
const argv = process.argv.slice(2),
  resume = argv.includes("--resume-public"),
  live = argv.includes("--live") || resume;
const outAt = argv.indexOf("--out");
const out = outAt >= 0 ? resolve(argv[outAt + 1]) : join(here, "results");
mkdirSync(out, { recursive: true });
const freshResult = {
  runAt: new Date().toISOString(),
  scope:
    "Host contract tests plus optional bounded public Tokyo provider smoke. Not iOS, personal-data, model or production acceptance.",
  host: [],
  live: null,
};
const result = resume
  ? JSON.parse(readFileSync(join(out, "tools-eval-results.json"), "utf8"))
  : freshResult;
if (resume) result.continuedAt = new Date().toISOString();
function command(id, cmd, args, options = {}) {
  const started = Date.now();
  const run = spawnSync(cmd, args, {
    cwd: root,
    encoding: "utf8",
    timeout: 120000,
    maxBuffer: 5_000_000,
    ...options,
  });
  const text = (run.stdout || "") + (run.stderr || "");
  writeFileSync(join(out, `${id}.log`), text);
  const item = {
    id,
    command: [cmd, ...args],
    exitCode: run.status,
    error: run.error?.code ?? null,
    elapsedMs: Date.now() - started,
    evidence: `${id}.log`,
  };
  if (id === "node-contracts" || id === "v4-map-flow")
    item.tests = Object.fromEntries(
      [...text.matchAll(/^# (tests|pass|fail|skipped) (\d+)$/gm)].map((m) => [m[1], +m[2]]),
    );
  if (id === "v4-map-flow")
    item.sourceSha256 = /prototype_state_sha256=([a-f0-9]+)/.exec(text)?.[1];
  if (id === "go-harness") {
    const events = text.split("\n").flatMap((line) => {
      try {
        return [JSON.parse(line)];
      } catch {
        return [];
      }
    });
    item.tests = {
      passed: events.filter((e) => e.Action === "pass" && e.Test).length,
      failed: events.filter((e) => e.Action === "fail" && e.Test).length,
      skipped: events.filter((e) => e.Action === "skip" && e.Test).length,
    };
  }
  result.host.push(item);
  console.log(JSON.stringify(item));
}
if (!resume) {
  command("v4-map-flow", process.execPath, [
    "--test",
    "--test-concurrency=1",
    "docs/design/trip-presence-20261029/interaction-v4/evals/map-flow.test.mjs",
  ]);
  command("node-contracts", process.execPath, [
    "--test",
    "--test-concurrency=1",
    ...["camera", "model-schema", "domain-live", "control", "integrity", "score"].map(
      (n) => `docs/design/agent-map-layer-v1/acceptance/${n}.test.mjs`,
    ),
  ]);
  command("provider-security", "python3", [
    "-m",
    "unittest",
    "discover",
    "-s",
    "docs/design/agent-map-layer-v1/acceptance",
    "-p",
    "*_test.py",
    "-v",
  ]);
  if (argv.includes("--go")) {
    command(
      "go-harness",
      process.env.GET324_GO || "go",
      [
        "test",
        "-json",
        "-p",
        "1",
        "./internal/harness",
        "-run",
        "Test(TravelerProfileTool|ToolArguments|GoogleToolsRequire|ModelCallsRequire|CalendarToolWindow|MailToolBounds|MCP|ChatResponse|ChatWithoutConsent|ChatWithConsent|ChatBounds|ChatUntrusted)",
        "-count=1",
      ],
      {
        cwd: join(root, "apps/api"),
        env: {
          ...process.env,
          GOTOOLCHAIN: process.env.GET324_GO ? "local" : "auto",
          GOPROXY: "https://proxy.golang.org",
          GOMAXPROCS: "2",
        },
      },
    );
  } else
    result.host.push({
      id: "go-harness",
      status: "not_requested",
      exitCode: null,
      note: "Pass --go and optionally GET324_GO to run scoped Go tests; never install a toolchain merely for the default fixture run.",
    });
}
if (live) {
  const temp = mkdtempSync(join(tmpdir(), "get324-public-smoke-"));
  try {
    const { createProviders } = await import(
      pathToFileURL(join(root, "docs/design/agent-map-layer-v1/acceptance/providers.mjs"))
    );
    const { createDomain } = await import(
      pathToFileURL(join(root, "docs/design/agent-map-layer-v1/demo/domain.mjs"))
    );
    const { tools, validate } = await import(
      pathToFileURL(join(root, "docs/design/agent-map-layer-v1/demo/contract.mjs"))
    );
    const previousObservations = resume ? (result.live?.observations ?? []) : [];
    const providerDir = join(temp, "providers");
    mkdirSync(providerDir, { recursive: true });
    if (resume) {
      for (const item of result.live?.rawEvidence ?? []) {
        writeFileSync(
          join(providerDir, item.file.split("/").at(-1).replace(/\.gz$/, "")),
          gunzipSync(readFileSync(join(out, item.file))),
        );
      }
    }
    const providers = createProviders(providerDir, {
      maxRequests: 6 - previousObservations.length,
    });
    const receipt = {
      status: "running",
      providerRequestLimit: 6,
      queries: [],
      observations: previousObservations,
      notVerified: [
        "opening hours",
        "correct entrance",
        "native map UI",
        "model autonomous orchestration",
        "personal calendar/mail",
        "transit or driving",
        "payment",
      ],
    };
    result.live = receipt;
    for (const query of ["上野公园", "浅草寺"]) {
      const candidates = await providers.resolvePlace(query);
      receipt.queries.push({
        query,
        status:
          candidates.length === 1 ? "resolved" : candidates.length ? "ambiguous" : "not_found",
        candidates,
      });
    }
    const targets = ["wikidata:Q746216", "wikidata:Q615183"];
    const selected = receipt.queries.map((q, i) =>
      q.candidates.find((p) => p.place_ref === targets[i]),
    );
    if (selected.some((p) => !p)) throw new Error("Predeclared public landmark was not resolved.");
    receipt.testSelection = {
      mode: "explicit_test_oracle",
      placeRefs: targets,
      notModelDisambiguation: true,
      note: "The public query 浅草寺 is ambiguous. A real user must choose; only this provider-routing smoke explicitly selects temple Q615183 rather than the sandal monument.",
    };
    const domain = createDomain(join(temp, "domain"), "http://127.0.0.1:1", {
      catalog: providers.catalog,
      routeLookup: providers.routeLookup,
      mode: "live",
    });
    let response = domain.call(
      "create_map",
      {
        title: "GET-324 public-only smoke",
        city: "Tokyo",
        day_count: 1,
        timezone: "Asia/Tokyo",
        idempotency_key: "create",
      },
      "isolated-public-eval",
    );
    let map = response.data.snapshot;
    response = domain.call(
      "plot_places",
      {
        map_id: map.map_id,
        expected_version: map.version,
        idempotency_key: "plot",
        items: selected.map((p) => ({
          place_ref: p.place_ref,
          day_id: map.days[0].day_id,
          duration_minutes: 30,
        })),
      },
      "isolated-public-eval",
    );
    map = response.data.snapshot;
    const args = {
      map_id: map.map_id,
      expected_version: map.version,
      idempotency_key: "route",
      transport_mode: "walking",
      allow_unknown_travel: false,
      day_plans: [
        {
          day_id: map.days[0].day_id,
          stop_ids: map.days[0].stops.map((s) => s.stop_id),
          start_minute: 540,
          end_minute: 1080,
          order_policy: "preserve",
        },
      ],
    };
    await providers.prepareTool("build_route", args, "isolated-public-eval", domain);
    response = domain.call("build_route", args, "isolated-public-eval");
    validate(tools.find((t) => t.name === "build_route").outputSchema, response);
    const leg = response.data.snapshot.days[0].legs[0];
    if (
      leg.evidence_status !== "resolved" ||
      leg.geometry_status !== "routed" ||
      leg.geometry.coordinates.length < 2
    )
      throw new Error("No resolved provider route geometry.");
    receipt.status = "passed_with_explicit_test_selection";
    receipt.networkRequests = previousObservations.length + providers.network_requests;
    receipt.observations = [...previousObservations, ...providers.observations];
    receipt.snapshot = response.data.snapshot;
    receipt.assertions = [
      "two public Tokyo landmarks carry provider coordinates and revisions; one requires explicit test-oracle disambiguation",
      "bounded actual foot-network matrix and route geometry",
      "strict tool output schema validates",
      "no invented straight-line ETA or fallback fixture",
    ];
  } catch (error) {
    result.live = { ...result.live, status: "unavailable", error: error.message };
    console.log("Public live smoke unavailable:", error.message);
  } finally {
    const rawDir = join(temp, "providers"),
      rawOut = join(out, "public-provider-evidence");
    mkdirSync(rawOut, { recursive: true });
    const raw = [];
    try {
      for (const name of readdirSync(rawDir)) {
        const content = readFileSync(join(rawDir, name));
        const compressed = gzipSync(content);
        writeFileSync(join(rawOut, name + ".gz"), compressed);
        raw.push({
          file: `public-provider-evidence/${name}.gz`,
          sha256: createHash("sha256").update(content).digest("hex"),
          bytes: content.length,
        });
      }
    } catch {}
    if (result.live) result.live.rawEvidence = raw;
    rmSync(temp, { recursive: true, force: true });
  }
}
writeFileSync(join(out, "tools-eval-results.json"), JSON.stringify(result, null, 2) + "\n");
console.log(
  JSON.stringify({
    resultFile: join(out, "tools-eval-results.json"),
    host: result.host.map((x) => ({ id: x.id, exitCode: x.exitCode })),
    live: result.live?.status ?? "not_requested",
  }),
);
