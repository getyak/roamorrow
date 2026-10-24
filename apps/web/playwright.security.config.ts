import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  testMatch: "dependency-security.spec.ts",
  workers: 1,
  fullyParallel: false,
  timeout: 30_000,
  reporter: [["list"]],
  outputDir: process.env.SC_SECURITY_ARTIFACT_DIR ?? "test-results/security",
  use: {
    browserName: "chromium",
    channel: process.env.SC_SECURITY_BROWSER_CHANNEL,
    trace: "retain-on-failure",
  },
});
