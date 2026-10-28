import { createHash } from "node:crypto";
import { readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve, relative } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { segments, allCases, rubricVersion } from "./criteria.mjs";
import { verifyEvidence, fileEvidenceReader } from "./evidence.mjs";
const here = dirname(fileURLToPath(import.meta.url));
export const rubricHash = () =>
  createHash("sha256")
    .update(readFileSync(join(here, "criteria.mjs")))
    .digest("hex");
export function candidateDigest() {
  const files = [];
  function walk(dir) {
    for (const entry of readdirSync(dir)) {
      const p = join(dir, entry);
      if (statSync(p).isDirectory()) walk(p);
      else if (/\.(mjs|py|html|css)$/.test(p) && !p.endsWith(".test.mjs")) files.push(p);
    }
  }
  walk(join(here, "../demo"));
  walk(here);
  const hash = createHash("sha256");
  for (const p of files.sort()) {
    hash.update(relative(here, p));
    hash.update(readFileSync(p));
  }
  return hash.digest("hex");
}
export const meetsThreshold = (points) => Number.isFinite(points) && points > 98;
const percentile95 = (values) =>
  [...values].sort((a, b) => a - b)[Math.ceil(values.length * 0.95) - 1];
export function scoreReceipts({
  candidateDigest: candidate,
  rubricHash: rubric,
  profile,
  receipts,
  readEvidence,
  expectedRevision,
  now = Date.now(),
  maxAgeMs = 86400000,
}) {
  if (!/^[a-f0-9]{64}$/.test(candidate) || !/^[a-f0-9]{64}$/.test(rubric))
    throw Error("candidate and rubric hashes are required");
  const definitions = new Map(allCases.map((c) => [c.id, c]));
  const verdicts = new Map(),
    excluded = [];
  const runIds = new Set(),
    revisions = new Set();
  for (const receipt of receipts) {
    let reason = null;
    if (receipt.schema_version !== 1) throw Error("unsupported receipt schema_version");
    if (receipt.evidence_type !== "live") reason = "fixture_or_non_live";
    else if (receipt.candidate_digest !== candidate) reason = "different_candidate";
    else if (receipt.rubric_sha256 !== rubric) reason = "different_rubric";
    else if (receipt.profile !== profile) reason = "different_target_profile";
    else if (expectedRevision && receipt.source_revision !== expectedRevision)
      reason = "different_revision";
    else if (
      !Number.isFinite(Date.parse(receipt.finished_at)) ||
      now - Date.parse(receipt.finished_at) > maxAgeMs ||
      Date.parse(receipt.finished_at) > now + 300000
    )
      reason = "stale_or_invalid_time";
    if (reason) {
      excluded.push({ run_id: receipt.run_id, kind: receipt.kind, reason });
      continue;
    }
    if (
      !receipt.run_id ||
      !receipt.source_revision ||
      !receipt.runtime_id ||
      !Array.isArray(receipt.checks)
    )
      throw Error("receipt provenance fields are required");
    runIds.add(receipt.run_id);
    revisions.add(receipt.source_revision);
    for (const check of receipt.checks) {
      const definition = definitions.get(check.case_id);
      if (!definition) throw Error(`unknown case ${check.case_id}`);
      if (!["pass", "fail", "unverified"].includes(check.status))
        throw Error("invalid check status");
      if (
        check.status === "pass" &&
        (!Array.isArray(check.evidence) ||
          !check.evidence.length ||
          check.evidence.some((x) => typeof x !== "string" || !x.trim()))
      )
        throw Error(`${check.case_id}: pass requires concrete assertion evidence`);
      if (!definition.kinds.includes(receipt.kind)) {
        excluded.push({ case_id: check.case_id, reason: "wrong_evidence_kind" });
        continue;
      }
      const proof = check.status === "pass" ? verifyEvidence(receipt, check, readEvidence) : null;
      let status = check.status,
        detail = check.detail ?? "";
      if (
        status === "pass" &&
        check.case_id === "A1" &&
        (proof?.trace?.exchange?.url !== "https://api.x.ai/v1/responses" ||
          proof.trace.exchange.status !== 200 ||
          !proof.trace.exchange.response?.id ||
          !proof.trace.server_url?.startsWith("https://") ||
          !proof.trace.exchange.response.output?.some((x) => x.type === "mcp_call"))
      ) {
        status = "unverified";
        detail = "missing real xAI response + HTTPS remote MCP provenance";
      }
      if (
        status === "pass" &&
        check.case_id === "G1" &&
        (!Array.isArray(proof?.trace?.scenarios) ||
          new Set(proof.trace.scenarios.map((x) => x.id)).size < 10 ||
          proof.trace.scenarios.some(
            (x) =>
              x.passed !== true ||
              !x.events?.some((e) => e.type === "model_response") ||
              !x.events?.some((e) => e.type === "mcp_call") ||
              !x.events?.some((e) => e.type === "browser_assertion"),
          ))
      ) {
        status = "unverified";
        detail = "ten distinct completed passing scenarios required";
      }
      if (status === "pass" && check.case_id === "G2") {
        const metrics = proof?.trace?.samples;
        const limits = { snapshot_ms: 500, update_ms: 2000, feedback_ms: 100 };
        if (
          Object.keys(limits).some(
            (k) =>
              !Array.isArray(metrics?.[k]) ||
              metrics[k].length < 20 ||
              metrics[k].some((x) => typeof x !== "number" || !Number.isFinite(x) || x < 0),
          )
        ) {
          status = "unverified";
          detail = "at least 20 measured samples per latency metric required";
        } else if (Object.entries(limits).some(([k, limit]) => percentile95(metrics[k]) > limit)) {
          status = "fail";
          detail = "measured p95 exceeds pinned latency budget";
        }
      }
      const previous = verdicts.get(check.case_id);
      // Fail is sticky; verified pass outranks missing coverage. Directory order is irrelevant.
      const rank = { unverified: 0, pass: 1, fail: 2 };
      if (!previous || rank[status] > rank[previous.status])
        verdicts.set(check.case_id, {
          status,
          detail,
          run_id: receipt.run_id,
          evidence: check.evidence ?? [],
        });
    }
  }
  const stageReports = segments.map((segment) => {
    const cases = segment.cases.map((c) => ({
      ...c,
      ...(verdicts.get(c.id) ?? {
        status: "unverified",
        detail: "no eligible evidence",
        evidence: [],
      }),
    }));
    const verified = cases.filter((c) => c.status === "pass").reduce((n, c) => n + c.points, 0),
      failed = cases.filter((c) => c.status === "fail").reduce((n, c) => n + c.points, 0),
      unknown = segment.points - verified - failed;
    return {
      id: segment.id,
      title: segment.title,
      weight: segment.points,
      verified_points: verified,
      failed_points: failed,
      unverified_points: unknown,
      score: unknown === 0 ? (verified / segment.points) * 100 : null,
      cases,
    };
  });
  const verified = stageReports.reduce((n, s) => n + s.verified_points, 0),
    failed = stageReports.reduce((n, s) => n + s.failed_points, 0),
    unknown = 100 - verified - failed;
  const criticalMissing = allCases
      .filter((c) => c.critical && (verdicts.get(c.id)?.status ?? "unverified") === "unverified")
      .map((c) => c.id),
    criticalFailed = allCases
      .filter((c) => c.critical && verdicts.get(c.id)?.status === "fail")
      .map((c) => c.id);
  return {
    rubric_version: rubricVersion,
    rubric_sha256: rubric,
    candidate_digest: candidate,
    profile,
    run_ids: [...runIds],
    mixed_runs: runIds.size > 1,
    mixed_revisions: revisions.size > 1,
    source_revisions: [...revisions],
    verified_points: verified,
    failed_points: failed,
    unverified_points: unknown,
    total_score: unknown === 0 ? verified : null,
    score_interval: [verified, verified + unknown],
    coverage_percent: 100 - unknown,
    critical_unverified: criticalMissing,
    critical_failed: criticalFailed,
    accepted:
      runIds.size === 1 &&
      revisions.size === 1 &&
      meetsThreshold(verified) &&
      !criticalMissing.length &&
      !criticalFailed.length,
    segments: stageReports,
    excluded,
  };
}
export function markdown(report) {
  const lines = [
    "# 真实链路验收评分",
    `目标：严格大于 98 分；profile=${report.profile}；规则 ${report.rubric_version}。`,
    `当前已实证得点 **${report.verified_points}/100**，未验证 ${report.unverified_points}，失败 ${report.failed_points}。${report.accepted ? "已达到本 profile 验收门槛。" : "尚未达到验收门槛；未验证不等于质量为零，也不作通过。"}`,
    "",
    "| 分段 | 权重 | 已实证得点 | 未验证 | 失败 |",
    "| --- | ---: | ---: | ---: | ---: |",
  ];
  for (const s of report.segments)
    lines.push(
      `| ${s.title} | ${s.weight} | ${s.verified_points} | ${s.unverified_points} | ${s.failed_points} |`,
    );
  lines.push(
    "",
    "评分是测试证据点数，不是生产可用率。不同候选、profile、run ID、过期和 fixture 结果不能拼成一次成功。",
    "",
    `候选 digest：${report.candidate_digest}`,
    `规则 hash：${report.rubric_sha256}`,
  );
  for (const s of report.segments) {
    const pending = s.cases.filter((c) => c.status !== "pass");
    if (pending.length)
      lines.push(
        "",
        `## ${s.title} 的缺口`,
        ...pending.map((c) => `- ${c.id} [${c.status}] ${c.title}：${c.detail}`),
      );
  }
  return lines.join("\n") + "\n";
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2),
    readOpt = (name, def) => {
      const i = args.indexOf(name);
      return i < 0 ? def : args[i + 1];
    };
  const dir = resolve(readOpt("--receipts", ".")),
    out = resolve(readOpt("--out", join(dir, "score.json"))),
    profile = readOpt("--profile", "grok-public");
  const files = readdirSync(dir).filter((x) => x.endsWith(".receipt.json"));
  const receipts = files.map((x) => JSON.parse(readFileSync(join(dir, x), "utf8")));
  const report = scoreReceipts({
    candidateDigest: candidateDigest(),
    rubricHash: rubricHash(),
    profile,
    receipts,
    readEvidence: fileEvidenceReader(dir),
  });
  writeFileSync(out, JSON.stringify(report, null, 2) + "\n");
  writeFileSync(out.replace(/\.json$/, ".md"), markdown(report));
  console.log(
    JSON.stringify({
      verified_points: report.verified_points,
      unverified_points: report.unverified_points,
      accepted: report.accepted,
      out,
    }),
  );
}
