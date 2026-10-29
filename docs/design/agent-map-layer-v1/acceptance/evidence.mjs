import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, realpathSync } from "node:fs";
import { resolve, relative, isAbsolute, join } from "node:path";
export const sha256 = (value) => createHash("sha256").update(value).digest("hex");
export function fileEvidenceReader(root) {
  const base = realpathSync(root);
  return (name) => {
    if (isAbsolute(name)) throw Error("evidence path must be relative");
    const file = realpathSync(resolve(base, name));
    const rel = relative(base, file);
    if (rel.startsWith("..") || isAbsolute(rel)) throw Error("evidence path escapes root");
    return readFileSync(file);
  };
}
export function verifyEvidence(receipt, check, readEvidence) {
  if (typeof readEvidence !== "function")
    throw Error("evidence reader is required; metadata alone is not evidence");
  for (const [name, expected] of Object.entries(receipt.artifacts ?? {})) {
    if (!/^[a-f0-9]{64}$/.test(expected) || sha256(readEvidence(name)) !== expected)
      throw Error("evidence artifact missing or hash mismatch");
  }
  let proof;
  for (const reference of check.evidence) {
    const [name, fragment] = reference.split("#");
    if (!name || !fragment?.startsWith("/"))
      throw Error("evidence requires a JSON pointer assertion");
    const expected = receipt.artifacts?.[name];
    if (!/^[a-f0-9]{64}$/.test(expected ?? "")) throw Error("evidence SHA-256 is required");
    const bytes = readEvidence(name);
    if (sha256(bytes) !== expected) throw Error("evidence hash mismatch");
    const doc = JSON.parse(String(bytes));
    for (const field of [
      "run_id",
      "candidate_digest",
      "rubric_sha256",
      "profile",
      "source_revision",
      "runtime_id",
      "kind",
    ])
      if (doc[field] !== receipt[field]) throw Error(`evidence provenance mismatch: ${field}`);
    let assertion = doc;
    for (const part of fragment.slice(1).split("/"))
      assertion = assertion?.[part.replace(/~1/g, "/").replace(/~0/g, "~")];
    if (!assertion || assertion.case_id !== check.case_id || assertion.status !== check.status)
      throw Error("evidence assertion mismatch");
    proof = doc;
  }
  return proof;
}
export function writeReceipt(
  dir,
  base,
  { kind, checks, trace = {}, meta = {}, prefix = kind, attachments = [] },
) {
  const file = `${prefix}.assertions.json`;
  const document = {
    ...base,
    finished_at: new Date().toISOString(),
    kind,
    trace,
    assertions: Object.fromEntries(
      checks.map((c) => [c.case_id, { case_id: c.case_id, status: c.status, detail: c.detail }]),
    ),
  };
  const bytes = JSON.stringify(document, null, 2) + "\n";
  writeFileSync(join(dir, file), bytes, { mode: 0o600 });
  const receipt = {
    ...base,
    finished_at: document.finished_at,
    kind,
    meta,
    artifacts: {
      [file]: sha256(bytes),
      ...Object.fromEntries(
        attachments.map((name) => [name, sha256(readFileSync(join(dir, name)))]),
      ),
    },
    checks: checks.map((c) => ({ ...c, evidence: [`${file}#/assertions/${c.case_id}`] })),
  };
  writeFileSync(join(dir, `${prefix}.receipt.json`), JSON.stringify(receipt, null, 2) + "\n", {
    mode: 0o600,
  });
  return receipt;
}
