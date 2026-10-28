import test from "node:test";
import assert from "node:assert/strict";
import { allCases } from "./criteria.mjs";
import { scoreReceipts, meetsThreshold } from "./score.mjs";
import { sha256 } from "./evidence.mjs";
const candidate = "a".repeat(64),
  rubric = "b".repeat(64),
  docs = new Map();
function receipts(overrides = {}) {
  return allCases.map((c) => {
    const base = {
      schema_version: 1,
      run_id: "run-real-001",
      candidate_digest: candidate,
      rubric_sha256: rubric,
      profile: "grok-public",
      evidence_type: "live",
      kind: c.kinds[0],
      started_at: new Date().toISOString(),
      finished_at: new Date().toISOString(),
      source_revision: "test-revision",
      runtime_id: "unit-runtime",
      ...overrides,
    };
    const trace = {
      server_url: "https://acceptance.example/mcp/maps",
      exchange: {
        url: "https://api.x.ai/v1/responses",
        status: 200,
        response: { id: "unit-response", output: [{ type: "mcp_call" }] },
      },
      scenarios: Array.from({ length: 10 }, (_, i) => ({
        id: `s-${i}`,
        passed: true,
        events: [{ type: "model_response" }, { type: "mcp_call" }, { type: "browser_assertion" }],
      })),
      samples: {
        snapshot_ms: Array(20).fill(10),
        update_ms: Array(20).fill(100),
        feedback_ms: Array(20).fill(5),
      },
    };
    const name = `proof-${c.id}.json`,
      bytes = JSON.stringify({
        ...base,
        trace,
        assertions: { [c.id]: { case_id: c.id, status: "pass" } },
      });
    docs.set(name, bytes);
    return {
      ...base,
      artifacts: { [name]: sha256(bytes) },
      checks: [
        {
          case_id: c.id,
          status: "pass",
          detail: "unit synthetic assertion",
          evidence: [`${name}#/assertions/${c.id}`],
        },
      ],
    };
  });
}
const read = (name) => {
  if (!docs.has(name)) throw Error("evidence file missing");
  return docs.get(name);
};
const run = (r) =>
  scoreReceipts({
    candidateDigest: candidate,
    rubricHash: rubric,
    profile: "grok-public",
    receipts: r,
    readEvidence: read,
  });
test("strictly greater than 98", () => {
  assert.equal(meetsThreshold(98), false);
  assert.equal(meetsThreshold(98.01), true);
});
test("all verified proof fixtures produce expected scoring in this unit only", () => {
  assert.equal(run(receipts()).total_score, 100);
  assert.equal(run(receipts()).accepted, true);
});
test("minor missing point has verified lower bound 99", () => {
  const out = run(receipts().filter((r) => r.checks[0].case_id !== "G3"));
  assert.equal(out.verified_points, 99);
  assert.equal(out.accepted, true);
  assert.equal(out.total_score, null);
});
test("critical missing cannot pass", () => {
  assert.equal(run(receipts().filter((r) => r.checks[0].case_id !== "A1")).accepted, false);
});
test("fixture never gets live credit", () => {
  assert.equal(run(receipts({ evidence_type: "fixture" })).verified_points, 0);
});
test("old candidate and rubric excluded", () => {
  assert.equal(run(receipts({ candidate_digest: "c".repeat(64) })).verified_points, 0);
  assert.equal(run(receipts({ rubric_sha256: "c".repeat(64) })).verified_points, 0);
});
test("DeepSeek local cannot satisfy Grok-public", () => {
  assert.equal(run(receipts({ profile: "deepseek-local" })).verified_points, 0);
});
test("cannot stitch different runs", () => {
  const r = receipts();
  r[0].run_id = "other";
  assert.throws(() => run(r), /provenance mismatch/);
});
test("cannot stitch revisions even with consistent per-file proofs", () => {
  const r = receipts(),
    saved = new Map(docs);
  const other = receipts({ source_revision: "other" })[0],
    bytes = docs.get("proof-A1.json");
  docs.clear();
  for (const [k, v] of saved) docs.set(k, v);
  docs.set("other-A1.json", bytes);
  other.artifacts = { "other-A1.json": sha256(bytes) };
  other.checks[0].evidence = ["other-A1.json#/assertions/A1"];
  r[0] = other;
  const out = run(r);
  assert.equal(out.accepted, false);
  assert.equal(out.mixed_revisions, true);
});
test("stale evidence rejected", () => {
  assert.equal(run(receipts({ finished_at: "2020-01-01T00:00:01Z" })).verified_points, 0);
});
test("pass without assertion evidence rejected", () => {
  const r = receipts();
  r[0].checks[0].evidence = [];
  assert.throws(() => run(r), /evidence/);
});
test("missing evidence file rejected", () => {
  const r = receipts();
  r[0].checks[0].evidence = ["absent.json#/assertions/A1"];
  r[0].artifacts["absent.json"] = "f".repeat(64);
  assert.throws(() => run(r), /missing/);
});
test("changed proof bytes rejected by sha256", () => {
  const r = receipts();
  docs.set("proof-A1.json", "{}");
  assert.throws(() => run(r), /hash mismatch/);
});
test("wrong assertion anchor rejected", () => {
  const r = receipts();
  r[0].checks[0].evidence = ["proof-A1.json#/assertions/A2"];
  assert.throws(() => run(r), /assertion mismatch/);
});
test("metadata-only fake xAI response cannot earn A1", () => {
  const r = receipts();
  const doc = JSON.parse(docs.get("proof-A1.json"));
  doc.trace = {};
  const bytes = JSON.stringify(doc);
  docs.set("proof-A1.json", bytes);
  r[0].artifacts["proof-A1.json"] = sha256(bytes);
  assert.equal(run(r).accepted, false);
  assert.equal(run(r).verified_points, 95);
});
test("unknown case fails closed", () => {
  const r = receipts();
  r[0].checks[0].case_id = "invented";
  assert.throws(() => run(r), /unknown case/);
});
test("failed replay cannot hide under previous pass", () => {
  const r = receipts();
  r.push({ ...r[0], checks: [{ ...r[0].checks[0], status: "fail" }] });
  assert.equal(run(r).accepted, false);
});
