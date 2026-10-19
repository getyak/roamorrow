import { NextResponse, type NextRequest } from "next/server";
import { nomadsNetworkHeaders } from "./lib/nomads-proxy";

// Request headers reach the existing external rewrite; no fetch or body read is
// performed here, preserving the agent stream and request cancellation.
// https://nextjs.org/docs/15/app/api-reference/file-conventions/middleware#setting-headers
export async function middleware(request: NextRequest) {
  try {
    const headers = await nomadsNetworkHeaders(request.headers, process.env.NOMADS_PROXY_SECRET);
    return NextResponse.next({ request: { headers } });
  } catch {
    return NextResponse.json(
      { error: "旅居助手暂时无法连接，请稍后重试。", code: "NOMADS_PROXY_UNAVAILABLE" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }
}

export const config = { matcher: ["/nomads/api/agent/:path*"] };
