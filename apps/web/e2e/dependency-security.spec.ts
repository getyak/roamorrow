import { expect, test } from "@playwright/test";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";

// Load the real sanitizer selected by the analytics dependency, without running analytics.
const web = createRequire(resolve(__dirname, "../package.json"));
const analytics = createRequire(web.resolve("posthog-js"));
const browserBundle = resolve(dirname(analytics.resolve("dompurify")), "purify.js");
interface SanitizerWindow extends Window {
  DOMPurify: { sanitize(input: string | Node, options?: Record<string, unknown>): string | Node };
}

test.beforeEach(async ({ page }) => {
  await page.setContent("<html><body></body></html>");
  await page.addScriptTag({ path: browserBundle });
});

test("keeps safe formatting while removing executable HTML and URL attributes", async ({
  page,
}) => {
  const result = await page.evaluate(() => {
    const purifier = (window as SanitizerWindow).DOMPurify;
    const container = document.createElement("div");
    container.innerHTML = String(
      purifier.sanitize(
        '<p>Hello <strong>solo</strong> <a href="https://example.test/">link</a></p><img src="x" onerror="window.injected=true"><a href="javascript:alert(1)">bad</a><script>window.injected=true</script>',
      ),
    );
    return {
      strong: container.querySelector("strong")?.textContent,
      safeURL: container.querySelector("a")?.getAttribute("href"),
      scripts: container.querySelectorAll("script").length,
      eventHandler: container.querySelector("img")?.getAttribute("onerror"),
      unsafeURL: container.querySelectorAll("a")[1]?.getAttribute("href"),
    };
  });
  expect(result).toEqual({
    strong: "solo",
    safeURL: "https://example.test/",
    scripts: 0,
    eventHandler: null,
    unsafeURL: null,
  });
});

test("SAFE_FOR_TEMPLATES scrubs expressions split across an attached shadow root", async ({
  page,
}) => {
  // https://github.com/advisories/GHSA-cg2g-xh64-v4q7
  const text = await page.evaluate(() => {
    const host = document.createElement("div");
    const shadow = host.attachShadow({ mode: "open" });
    shadow.append(
      document.createTextNode("{"),
      document.createElement("script"),
      document.createTextNode("{7*7}"),
      document.createElement("script"),
      document.createTextNode("}"),
    );
    document.body.append(host);
    (window as SanitizerWindow).DOMPurify.sanitize(host, {
      SAFE_FOR_TEMPLATES: true,
      IN_PLACE: true,
    });
    return shadow.textContent ?? "";
  });
  expect(text).not.toContain("{{");
  expect(text).not.toContain("}}");
});
