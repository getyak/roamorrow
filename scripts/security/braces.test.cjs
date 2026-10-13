const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const { readFileSync } = require("node:fs");
const { createRequire } = require("node:module");
const { resolve } = require("node:path");
const { test } = require("node:test");

const repoRoot = resolve(__dirname, "../..");

function consumers() {
  // A four-package fixture permits local verification without installing the
  // whole web workspace. CI leaves this unset and checks both real consumers.
  if (process.env.SC_BRACES_FIXTURE_PACKAGE) {
    const fixture = createRequire(resolve(process.env.SC_BRACES_FIXTURE_PACKAGE));
    return [{ name: "isolated fixture", require: fixture }];
  }
  const web = createRequire(resolve(repoRoot, "apps/web/package.json"));
  const tailwind = createRequire(web.resolve("tailwindcss/package.json"));
  return ["micromatch", "chokidar"].map((name) => ({
    name,
    require: createRequire(tailwind.resolve(`${name}/package.json`)),
  }));
}

const nested = (open, close, depth) => open.repeat(depth) + "x" + close.repeat(depth);
const depthError = (error) =>
  error instanceof SyntaxError && /maximum nesting depth \(100\)/.test(error.message);

test("rejects excessive brace and parenthesis nesting before recursive walkers", () => {
  for (const consumer of consumers()) {
    const braces = consumer.require("braces");
    assert.equal(consumer.require("braces/package.json").version, "3.0.3", consumer.name);
    for (const [open, close, depth] of [
      ["{", "}", 101],
      ["(", ")", 101],
      ["{(", ")}", 51],
    ]) {
      assert.throws(() => braces.parse(nested(open, close, depth)), depthError, consumer.name);
    }
    const attack = nested("{", "}", 4000); // 8001 chars: below the existing length limit.
    for (const operation of [braces, braces.compile, braces.expand]) {
      assert.throws(() => operation(attack), depthError, consumer.name);
    }
  }
});

test("keeps the depth boundary and normal glob behavior", () => {
  for (const consumer of consumers()) {
    const braces = consumer.require("braces");
    assert.doesNotThrow(() => braces.parse(nested("{", "}", 100)), consumer.name);
    assert.doesNotThrow(() => braces.parse(nested("(", ")", 100)), consumer.name);
    assert.deepEqual(braces.expand("a{b,{c,d}}z"), ["abz", "acz", "adz"]);
    assert.doesNotThrow(() => braces.parse("\\{".repeat(150)));
    assert.doesNotThrow(() => braces.parse("[" + "{".repeat(150) + "]"));
    assert.doesNotThrow(() => braces.parse('"' + "{".repeat(150) + '"'));
    assert.throws(() => braces.parse(nested("{", "}", 101), { maxDepth: 10000 }), depthError);
  }
});

test("the audit exception covers only the patched lockfile version", () => {
  const lock = readFileSync(resolve(repoRoot, "pnpm-lock.yaml"), "utf8");
  const snapshots = lock.split("\nsnapshots:\n")[1];
  assert.ok(snapshots, "lockfile must contain dependency snapshots");
  const versions = [...snapshots.matchAll(/^  ['"]?braces@([^'":]+)['"]?:$/gm)].map(
    (match) => match[1],
  );
  assert.equal(
    versions.length,
    1,
    "new braces versions require security review before extending the exception",
  );
  const patch = readFileSync(resolve(repoRoot, "patches/braces@3.0.3.patch"));
  const hash = createHash("sha256").update(patch).digest("hex");
  assert.deepEqual(versions, [`3.0.3(patch_hash=${hash})`]);
  assert.ok(lock.includes(`patchedDependencies:\n  braces@3.0.3: ${hash}\n`));
  const workspace = readFileSync(resolve(repoRoot, "pnpm-workspace.yaml"), "utf8");
  assert.match(
    workspace,
    /patchedDependencies:\n  braces@3\.0\.3: patches\/braces@3\.0\.3\.patch\n/,
  );
});
