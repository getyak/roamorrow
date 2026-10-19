import type { NextConfig } from "next";
import { withSentryConfig } from "@sentry/nextjs";
import path from "node:path";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  output: "standalone",
  outputFileTracingRoot: path.join(process.cwd(), "../.."),
  transpilePackages: ["@solo-compass/core", "@solo-compass/ai", "@solo-compass/data"],
  // The independent Nomads worker owns its canonical directory slashes.
  // https://nextjs.org/docs/15/app/api-reference/file-conventions/middleware#advanced-middleware-flags
  skipTrailingSlashRedirect: true,
  async rewrites() {
    return {
      beforeFiles: [
        {
          source: "/nomads/:path*/",
          destination: "https://nomads.cubxxw.com/nomads/:path*/",
        },
        {
          source: "/nomads/:path*",
          destination: "https://nomads.cubxxw.com/nomads/:path*",
        },
      ],
      afterFiles: [],
      fallback: [],
    };
  },
};

export default withSentryConfig(nextConfig, { silent: true });
