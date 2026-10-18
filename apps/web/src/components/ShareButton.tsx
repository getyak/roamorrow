"use client";

/**
 * ShareButton — real Web Share with a clipboard fallback (W15).
 *
 * The trip recap's share button previously did nothing. This triggers the
 * system share sheet for the page URL (user-driven — nothing is ever sent to
 * contacts automatically), falls back to copying the URL, and reports the
 * actual outcome. No invented success states.
 */

import { useState } from "react";

interface ShareButtonProps {
  readonly title: string;
  readonly text: string;
  readonly labels: {
    readonly idle: string;
    readonly shared: string;
    readonly copied: string;
    readonly failed: string;
  };
  readonly className?: string;
}

export function ShareButton({ title, text, labels, className = "" }: ShareButtonProps) {
  const [status, setStatus] = useState<string | null>(null);

  async function handleShare() {
    const url = typeof window === "undefined" ? "" : window.location.href;
    if (typeof navigator !== "undefined" && typeof navigator.share === "function") {
      try {
        await navigator.share({ title, text, url });
        setStatus(labels.shared);
        return;
      } catch (err) {
        // User cancelling the share sheet is not an error.
        if (err instanceof DOMException && err.name === "AbortError") return;
        // fall through to the clipboard
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      setStatus(labels.copied);
    } catch {
      setStatus(labels.failed);
    }
  }

  return (
    <>
      <button
        type="button"
        onClick={handleShare}
        className={`min-h-[44px] ${className}`}
        style={{
          padding: "4px 10px",
          borderRadius: 4,
          background: "transparent",
          border: "0.5px solid #D6CEC0",
          fontFamily: "inherit",
          fontSize: 11,
          color: "var(--accent)",
          cursor: "pointer",
        }}
      >
        ↗ {labels.idle}
      </button>
      {status && (
        <span role="status" style={{ fontSize: 10, color: "#8A7860" }}>
          {status}
        </span>
      )}
    </>
  );
}
