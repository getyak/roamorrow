const assert = require("node:assert/strict");
const fs = require("node:fs");
const { createRequire } = require("node:module");
const { tmpdir } = require("node:os");
const { join, resolve } = require("node:path");
const { setTimeout: delay } = require("node:timers/promises");
const { test } = require("node:test");

const root = createRequire(resolve(__dirname, "../../package.json"));

test("aborting a glob stops filesystem traversal after rejection", async () => {
  // https://github.com/advisories/GHSA-3g3m-2fjr-6pw4
  const { glob } = root("glob");
  const directory = fs.mkdtempSync(join(tmpdir(), "roamorrow-glob-abort-"));
  try {
    for (let i = 0; i < 12; i++) {
      const child = join(directory, String(i), "nested");
      fs.mkdirSync(child, { recursive: true });
      fs.writeFileSync(join(child, "item.txt"), "fixture");
    }
    const controller = new AbortController();
    let reads = 0;
    const instrumentedFS = {
      ...fs,
      readdir(...args) {
        reads++;
        if (reads === 1) controller.abort(new Error("fixture-abort"));
        return fs.readdir(...args);
      },
    };
    await assert.rejects(
      glob("**/*", { cwd: directory, signal: controller.signal, fs: instrumentedFS }),
      /fixture-abort/,
    );
    const readsAtRejection = reads;
    await delay(100);
    assert.equal(reads, readsAtRejection, "rejected walks must not keep opening directories");
    assert.deepEqual(
      glob.sync("**/*.txt", { cwd: directory }).sort(),
      Array.from({ length: 12 }, (_, i) => `${i}/nested/item.txt`).sort(),
    );
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test("the actual ts-morph matcher preserves public matching behavior", () => {
  const tsMorph = createRequire(root.resolve("ts-morph"));
  const common = createRequire(tsMorph.resolve("@ts-morph/common"));
  const { minimatch, Minimatch } = common("minimatch");
  assert.equal(minimatch("apps/ios/Example.swift", "**/*.swift"), true);
  assert.equal(new Minimatch("**/*.{ts,tsx}").match("apps/web/page.tsx"), true);
  assert.equal(minimatch("apps/web/page.tsx", "**/*.swift"), false);
});
