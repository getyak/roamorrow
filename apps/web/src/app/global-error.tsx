"use client";

import * as Sentry from "@sentry/nextjs";
import { useEffect, useState } from "react";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const [zh, setZh] = useState(false);
  useEffect(() => {
    Sentry.captureException(error);
    const { pathname, search } = window.location;
    const explicit = new URLSearchParams(search).get("lang");
    const firstSegment = pathname.split("/").filter(Boolean)[0] ?? "";
    const marketingRoutes = ["", "pricing", "manifesto", "privacy", "download"];
    const guideRoute =
      /^\/(?:experience\/|trip\/)/.test(pathname) ||
      (/^\/[^/]+\/?$/.test(pathname) &&
        ![...marketingRoutes, "app", "mobile-preview", "zh"].includes(firstSegment));
    setZh(
      pathname.startsWith("/zh")
        ? true
        : explicit === "en"
          ? false
          : explicit === "zh" || guideRoute
            ? true
            : marketingRoutes.includes(firstSegment)
              ? false
              : navigator.language.startsWith("zh"),
    );
  }, [error]);

  return (
    <html lang={zh ? "zh-CN" : "en"}>
      <head>
        <style>{`
        body { margin: 0; background: #faf8f6; color: #1f1a14; font-family: system-ui, sans-serif; }
        main { max-width: 34rem; margin: 15vh auto; padding: 24px; line-height: 1.6; }
        h1 { font-size: clamp(1.6rem, 6vw, 2.25rem); line-height: 1.2; }
        p { color: #6d6358; }
        nav { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 28px; }
        button, a { box-sizing: border-box; display: inline-flex; align-items: center; justify-content: center; min-height: 44px; padding: 10px 20px; border-radius: 10px; font: inherit; font-weight: 600; cursor: pointer; text-decoration: none; }
        button { background: #5d3000; color: white; border: 1px solid #5d3000; }
        a { color: #1f1a14; border: 1px solid #d6cec0; }
        button:focus-visible, a:focus-visible { outline: 3px solid #5d3000; outline-offset: 4px; }
        button:active, a:active { opacity: .75; }
      `}</style>
      </head>
      <body>
        <main>
          <h1>{zh ? "暂时无法打开这一页" : "This page couldn’t open"}</h1>
          <p>
            {zh
              ? "可以重试，或回到地图继续探索。"
              : "Try again, or return to the map to keep exploring."}
          </p>
          <nav aria-label={zh ? "恢复页面" : "Page recovery"}>
            <button onClick={reset}>{zh ? "重试" : "Try again"}</button>
            <a href="/app">{zh ? "回到地图" : "Back to map"}</a>
          </nav>
        </main>
      </body>
    </html>
  );
}
