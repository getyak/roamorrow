import { test, expect, type Page } from "@playwright/test";
import { DEV_FALLBACK_EXPERIENCES } from "../src/lib/dev-fallback";

const origin = process.env.ROAMORROW_BASE_URL ?? "http://localhost:4300";
const results = DEV_FALLBACK_EXPERIENCES.map((experience, i) => ({
  experience,
  reason: "",
  score: 90 - i,
  walkingMinutes: 5 + i,
  health: "questioned",
}));
const sample = { results, source: "sample", degraded: true };

async function setup(page: Page, response: unknown = sample) {
  // This is fixture acceptance. Do not consume map tiles, model calls or account data.
  await page.route(/api\.mapbox\.com|events\.mapbox\.com/, (route) => route.abort());
  await page.route("**/api/me/completions", (route) => route.fulfill({ json: { entries: [] } }));
  await page.route("**/api/experiences/nearby?**", (route) => route.fulfill({ json: response }));
}

async function noOverflow(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
}

async function screenshot(page: Page, name: string) {
  await page.screenshot({ path: test.info().outputPath(name + ".png"), animations: "disabled" });
}

async function doubleText(page: Page) {
  await page.evaluate(() => {
    // Include newly mounted portals; never double an already scaled node twice.
    const sizes = [...document.querySelectorAll<HTMLElement>("body *:not([data-test-scaled])")].map(
      (el) => [el, parseFloat(getComputedStyle(el).fontSize)] as const,
    );
    for (const [el, size] of sizes) {
      el.style.fontSize = `${size * 2}px`;
      el.dataset.testScaled = "true";
    }
  });
}

test.describe("Map-first experience handoff", () => {
  for (const [width, scheme] of [
    [1280, "light"],
    [390, "light"],
    [390, "dark"],
    [320, "light"],
  ] as const) {
    test(`${width} ${scheme}: visible cards to directions, keyboard and focus return`, async ({
      page,
    }) => {
      await page.setViewportSize({ width, height: 844 });
      await page.emulateMedia({ colorScheme: scheme, reducedMotion: "reduce" });
      await setup(page);
      const started = Date.now();
      await page.goto(origin + "/app");
      const cards = page.locator("[data-experience-card]");
      await expect(cards).toHaveCount(5);
      await expect(cards.first()).toBeInViewport();
      await expect(page.getByText("Preview sample · not live data")).toBeVisible();
      await expect(page.getByRole("textbox")).toBeHidden();
      await screenshot(page, `app-${width}-${scheme}`);
      await noOverflow(page);
      await cards.first().focus();
      await page.keyboard.press("Enter");
      const directions = page.getByRole("link", { name: "Get walking directions" });
      await expect(directions).toBeInViewport({ ratio: 1 });
      const href = new URL((await directions.getAttribute("href"))!);
      expect(href.searchParams.get("destination")).toBe("18.7905,98.9824");
      expect(href.searchParams.has("origin")).toBe(false);
      const box = await directions.boundingBox();
      expect(box!.height).toBeGreaterThanOrEqual(44);
      await test.info().attach("automated-path.json", {
        body: JSON.stringify({
          width,
          scheme,
          elapsedMs: Date.now() - started,
          path: ["/app", "first experience card (Enter)", "details with directions link"],
          humanUsabilityTest: false,
        }),
        contentType: "application/json",
      });
      await screenshot(page, `detail-${width}-${scheme}`);
      await page.keyboard.press("Escape");
      await expect(cards.first()).toBeFocused();
      await page.getByRole("button", { name: "See list", exact: true }).click();
      await expect(cards).toHaveCount(results.length);
      await page.getByRole("button", { name: "My footprint", exact: true }).click();
      await expect(page.getByRole("heading", { name: "My footprint" })).toBeVisible();
      await page.getByRole("button", { name: "Back to map", exact: true }).click();
      await expect(cards).toHaveCount(5);
      await page.getByRole("button", { name: "See list", exact: true }).click();
      await page.getByRole("button", { name: "Ask (optional)", exact: true }).click();
      await expect(page.getByRole("textbox")).toBeVisible();
      await expect(page.getByRole("button", { name: "Close Ask", exact: true })).toHaveAttribute(
        "aria-expanded",
        "true",
      );
    });
  }

  test("loading, error, retry, empty and reload remain usable without expanding", async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await setup(page);
    let release!: () => void;
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    let state = "loading";
    await page.route("**/api/experiences/nearby?**", async (route) => {
      if (state === "loading") await gate;
      await route.fulfill(
        state === "error"
          ? { status: 502, json: { error: "fixture outage" } }
          : { json: state === "empty" ? { results: [] } : sample },
      );
    });
    await page.goto(origin + "/app");
    await expect(page.getByText("Loading experiences…")).toBeVisible();
    state = "error";
    release();
    await expect(
      page.getByRole("region", { name: "Nearby experiences and footprint" }).getByRole("alert"),
    ).toContainText("Could not load experiences");
    await screenshot(page, "error-390");
    state = "empty";
    await page.getByRole("button", { name: "Try again", exact: true }).click();
    await expect(page.getByText("No experiences found in this area.")).toBeVisible();
    await screenshot(page, "empty-390");
    state = "ready";
    await page.getByRole("button", { name: "Try again", exact: true }).click();
    await expect(page.locator("[data-experience-card]")).toHaveCount(5);
    await page.reload();
    await expect(page.locator("[data-experience-card]")).toHaveCount(5);
    await page.evaluate(() => dispatchEvent(new Event("offline")));
    // The app reads navigator.onLine, rather than trusting the event payload.
    await page.context().setOffline(true);
    await page.evaluate(() => dispatchEvent(new Event("offline")));
    await expect(page.getByText(/You are offline/)).toBeVisible();
    await page.context().setOffline(false);
  });

  test("location denial keeps browsing and optional Ask keeps its draft", async ({ page }) => {
    await setup(page);
    await page.addInitScript(() => {
      Object.defineProperty(navigator, "geolocation", {
        value: {
          getCurrentPosition: (_success: unknown, error: (value: unknown) => void) =>
            error({ code: 1 }),
        },
      });
    });
    await page.goto(origin + "/app");
    await page.getByRole("button", { name: "Use my location" }).click();
    await expect(page.getByText(/Location permission was declined/)).toBeVisible();
    await expect(page.locator("[data-experience-card]")).toHaveCount(5);
    await page.getByRole("button", { name: "Ask (optional)", exact: true }).click();
    const input = page.getByRole("textbox", { name: "Type what you feel like doing" });
    await input.fill("quiet place with a seat");
    await page.getByRole("button", { name: "Close Ask", exact: true }).click();
    await page.getByRole("button", { name: "Ask (optional)", exact: true }).click();
    await expect(input).toHaveValue("quiet place with a seat");
  });

  test("200% text and long content keep the destination, unknowns and route action", async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    const first = results[0]!;
    const experience = {
      ...first.experience,
      title: first.experience.title.repeat(5),
      soloScore: { ...first.experience.soloScore, overall: 0, basedOnCount: 0 },
    };
    await setup(page, { results: [{ ...first, experience, walkingMinutes: null }] });
    await page.goto(origin + "/app");
    await expect(page.locator("[data-experience-card]")).toHaveCount(1);
    await doubleText(page);
    await noOverflow(page);
    await page.locator("[data-experience-card]").click();
    await doubleText(page);
    expect(
      await page
        .getByRole("link", { name: "Get walking directions" })
        .evaluate((el) => getComputedStyle(el).fontSize),
    ).toBe("32px");
    await expect(page.getByRole("link", { name: "Get walking directions" })).toBeInViewport();
    await expect(page.getByText("Walk time unknown", { exact: true }).last()).toBeVisible();
    await screenshot(page, "text-200-detail-390");
    await noOverflow(page);
  });

  test("desktop Ask stays clickable after submitting and showing fallback notices", async ({
    page,
  }) => {
    await setup(page);
    for (const width of [1280, 768]) {
      await page.setViewportSize({ width, height: 844 });
      await page.goto(origin + "/app");
      await page.getByRole("button", { name: "Ask (optional)", exact: true }).click();
      const input = page.getByRole("textbox", { name: "Type what you feel like doing" });
      const send = page.getByRole("button", { name: "Send", exact: true });
      await input.fill("Somewhere quiet with a seat");
      await send.click();
      await expect(page.getByText(/your request has not been ranked by AI/)).toBeVisible();
      await input.fill("Somewhere with shade");
      await send.click();
      await expect(input).toHaveValue("");
      await expect(page.locator("[data-experience-card]")).toHaveCount(5);
      await screenshot(page, `ask-${width}`);
      await noOverflow(page);
    }
  });

  test("Ask from footprint returns to experience choices after submission", async ({ page }) => {
    await setup(page);
    await page.goto(origin + "/app");
    await page.getByRole("button", { name: "See list", exact: true }).click();
    await page.getByRole("button", { name: "My footprint", exact: true }).click();
    await page.getByRole("button", { name: "Ask (optional)", exact: true }).click();
    await page.getByRole("textbox").fill("A quiet place to sit");
    await page.getByRole("button", { name: "Send", exact: true }).click();
    await expect(page.locator("[data-experience-card]")).toHaveCount(5);
    await expect(page.getByRole("heading", { name: "Sample experiences" })).toBeVisible();
  });

  test("200% narrow map header can open and close Ask without interception", async ({ page }) => {
    await setup(page);
    for (const width of [320, 390]) {
      await page.setViewportSize({ width, height: 844 });
      await page.goto(origin + "/app");
      await doubleText(page);
      await page.getByRole("button", { name: "Ask (optional)", exact: true }).click();
      await expect(page.getByRole("textbox")).toBeVisible();
      await screenshot(page, `ask-200-${width}`);
      await page.getByRole("button", { name: "Close Ask", exact: true }).click();
      await expect(page.getByRole("textbox")).toBeHidden();
      await noOverflow(page);
    }
  });

  test("touch hands off only the selected coordinates, without claiming a route result", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      hasTouch: true,
    });
    try {
      const page = await context.newPage();
      await setup(page);
      await context.route("https://www.google.com/maps/dir/**", (route) =>
        route.fulfill({ body: "Test interception: Google Maps handoff, no route result tested." }),
      );
      await page.goto(origin + "/app");
      await page.locator("[data-experience-card]").first().tap();
      const popupPromise = context.waitForEvent("page");
      await page.getByRole("link", { name: "Get walking directions" }).tap();
      const popup = await popupPromise;
      await popup.waitForLoadState();
      expect(new URL(popup.url()).searchParams.get("destination")).toBe("18.7905,98.9824");
      await popup.close();
    } finally {
      await context.close();
    }
  });

  test("marketing uses the map accent and keeps ritual previews secondary in both languages", async ({
    page,
  }) => {
    await setup(page);
    for (const path of ["/", "/zh"]) {
      await page.setViewportSize({ width: 390, height: 844 });
      await page.goto(origin + path);
      const preview = page.locator("#capabilities details");
      await expect(preview).not.toHaveAttribute("open");
      await expect(preview.locator("summary")).toContainText("Preview");
      await expect(page.locator('[data-capability="blindbox"]')).toBeHidden();
      const cta = page.locator('main a[href="/app"]').first();
      expect(await cta.evaluate((el) => getComputedStyle(el).backgroundColor)).toBe(
        "rgb(47, 107, 107)",
      );
      await screenshot(page, path === "/" ? "landing-390" : "landing-zh-390");
      await noOverflow(page);
      await preview.locator("summary").click();
      await expect(page.locator('[data-capability="blindbox"]')).toBeVisible();
      await preview.locator("summary").click();
    }
    await page.setViewportSize({ width: 1280, height: 844 });
    await page.goto(origin + "/");
    await screenshot(page, "landing-1280");
  });

  test("marketing text at 200% can still open the map in light and dark", async ({ page }) => {
    await setup(page);
    await page.setViewportSize({ width: 390, height: 844 });
    for (const colorScheme of ["light", "dark"] as const) {
      await page.emulateMedia({ colorScheme, reducedMotion: "reduce" });
      await page.goto(origin + "/");
      await doubleText(page);
      await noOverflow(page);
      const cta = page.locator('main a[href="/app"]').first();
      await cta.scrollIntoViewIfNeeded();
      await expect(cta).toBeInViewport();
      await screenshot(page, `landing-200-${colorScheme}-390`);
      await cta.click();
      await expect(page.locator("[data-experience-card]")).toHaveCount(5);
    }
  });
});
