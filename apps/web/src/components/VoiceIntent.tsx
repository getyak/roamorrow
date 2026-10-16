"use client";

import { useEffect, useRef, useState } from "react";

interface VoiceIntentProps {
  readonly intent: string | null;
  readonly hidden?: boolean;
  readonly fallbackNotice?: string;
  readonly onIntentChange: (intent: string | null) => void;
}

/**
 * Web Speech API surface (no shipped TS types). We declare the minimum we
 * use — SpeechRecognition + its events. The runtime check at first call
 * gates the whole feature.
 */
interface SpeechRecognitionEventLike {
  results: ArrayLike<{ 0: { transcript: string }; isFinal: boolean }>;
}

interface SpeechRecognitionLike {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  start: () => void;
  stop: () => void;
  abort: () => void;
  onresult: ((e: SpeechRecognitionEventLike) => void) | null;
  onerror: ((e: { error?: string }) => void) | null;
  onend: (() => void) | null;
}

type SpeechRecognitionCtor = new () => SpeechRecognitionLike;

function getSpeechRecognition(): SpeechRecognitionCtor | null {
  if (typeof window === "undefined") return null;
  const w = window as unknown as {
    SpeechRecognition?: SpeechRecognitionCtor;
    webkitSpeechRecognition?: SpeechRecognitionCtor;
  };
  return w.SpeechRecognition ?? w.webkitSpeechRecognition ?? null;
}

/**
 * W04: the text path is ALWAYS available — voice is an alternative, never a
 * replacement. The mic is a semantic button (tap/keyboard toggles start and
 * stop), permission denial and errors keep the typed draft, and any cancel /
 * unmount aborts the recogniser so no hidden listening survives.
 */
export function VoiceIntent({
  intent,
  onIntentChange,
  hidden = false,
  fallbackNotice,
}: VoiceIntentProps) {
  const [recording, setRecording] = useState(false);
  const [micStatus, setMicStatus] = useState<string | null>(null);
  const [textValue, setTextValue] = useState("");
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);
  const transcriptRef = useRef("");
  const sessionActiveRef = useRef(false);
  const onIntentChangeRef = useRef(onIntentChange);
  useEffect(() => {
    onIntentChangeRef.current = onIntentChange;
  }, [onIntentChange]);
  const supported = useRef<boolean | null>(null);
  const [micAvailable, setMicAvailable] = useState(true);

  function ensureRecognition(): SpeechRecognitionLike | null {
    if (recognitionRef.current) return recognitionRef.current;
    const Ctor = getSpeechRecognition();
    if (!Ctor) {
      supported.current = false;
      setMicAvailable(false);
      setMicStatus("Voice input isn't supported in this browser — type instead.");
      return null;
    }
    supported.current = true;
    const r = new Ctor();
    r.continuous = false;
    r.interimResults = false;
    r.lang = navigator.language || "en-US";
    const canDeliver = () =>
      sessionActiveRef.current && recognitionRef.current === r && !document.hidden;
    r.onresult = (e) => {
      if (!canDeliver()) return;
      const last = e.results[e.results.length - 1];
      if (last && last[0]) {
        transcriptRef.current = last[0].transcript.trim();
      }
    };
    r.onerror = (e) => {
      if (!canDeliver()) return;
      sessionActiveRef.current = false;
      transcriptRef.current = "";
      if (e.error === "not-allowed" || e.error === "service-not-allowed") {
        // Permission denied — the typed draft below is untouched.
        setMicStatus("Microphone permission was declined. Your typed text is kept.");
      } else if (e.error === "aborted") {
        setMicStatus(null);
      } else {
        setMicStatus("Voice input failed. Your typed text is kept.");
      }
      setRecording(false);
    };
    r.onend = () => {
      if (!canDeliver()) return;
      sessionActiveRef.current = false;
      setRecording(false);
      if (transcriptRef.current.length > 0) {
        onIntentChangeRef.current(transcriptRef.current);
        setMicStatus(null);
      }
    };
    recognitionRef.current = r;
    return r;
  }

  function toggleRecording() {
    if (recording) {
      try {
        recognitionRef.current?.stop();
      } catch {
        // ignore
      }
      setRecording(false);
      return;
    }
    transcriptRef.current = "";
    const r = ensureRecognition();
    if (!r) return;
    try {
      sessionActiveRef.current = true;
      r.start();
      setRecording(true);
      setMicStatus("Listening — tap the mic again to stop.");
    } catch {
      sessionActiveRef.current = false;
      setRecording(false);
      setMicStatus("Voice input could not start. You can type instead.");
    }
  }

  function handleTextSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = textValue.trim();
    if (trimmed.length > 0) {
      onIntentChange(trimmed);
      setTextValue("");
    }
  }

  // A hidden page must stop capture and ignore queued recognition callbacks.
  useEffect(() => {
    function abortRecognition() {
      sessionActiveRef.current = false;
      transcriptRef.current = "";
      const recognition = recognitionRef.current;
      recognitionRef.current = null;
      if (recognition) {
        recognition.onresult = null;
        recognition.onerror = null;
        recognition.onend = null;
        try {
          recognition.abort();
        } catch {
          /* already stopped */
        }
      }
    }
    function onHide() {
      if (document.hidden) {
        abortRecognition();
        setRecording(false);
        setMicStatus(null);
      }
    }
    function onPageHide() {
      abortRecognition();
    }
    if (hidden) {
      abortRecognition();
      setRecording(false);
      setMicStatus(null);
    }
    document.addEventListener("visibilitychange", onHide);
    window.addEventListener("pagehide", onPageHide);
    return () => {
      document.removeEventListener("visibilitychange", onHide);
      window.removeEventListener("pagehide", onPageHide);
      abortRecognition();
    };
  }, [hidden]);

  useEffect(() => {
    if (supported.current === null) {
      supported.current = getSpeechRecognition() !== null;
      if (!supported.current) setMicAvailable(false);
    }
  }, []);

  return (
    <div
      hidden={hidden}
      className="pointer-events-none absolute inset-x-0 bottom-[136px] z-20 flex flex-col items-center gap-2 px-4"
      style={hidden ? { display: "none" } : undefined}
    >
      {intent && (
        <button
          type="button"
          onClick={() => onIntentChange(null)}
          className="pointer-events-auto min-h-[44px] max-w-[90vw] rounded-full bg-deep-teal px-4 py-1.5 text-sm text-paper-cream shadow-md ring-1 ring-paper-cream/20 hover:bg-deep-teal/90"
          aria-label={`Clear intent: ${intent}`}
        >
          <span className="mr-2" aria-hidden="true">
            🎯
          </span>
          <span className="truncate align-middle">{intent}</span>
          <span className="ml-2 text-paper-cream/70" aria-hidden="true">
            ×
          </span>
        </button>
      )}

      {fallbackNotice && !micStatus && (
        <p
          role="status"
          className="pointer-events-auto max-w-md rounded-xl bg-paper-cream/95 px-3 py-2 text-xs text-ink-warm shadow-sm"
        >
          {fallbackNotice}
        </p>
      )}
      {micStatus && (
        <p
          role="status"
          className="pointer-events-auto rounded-full bg-paper-cream/95 px-3 py-1 text-xs text-ink-warm shadow"
        >
          {micStatus}
        </p>
      )}

      {/* Text first: the stable entry. Voice sits beside it, never instead of it. */}
      <form onSubmit={handleTextSubmit} className="pointer-events-auto flex w-full max-w-md gap-2">
        <input
          type="text"
          value={textValue}
          onChange={(e) => setTextValue(e.target.value)}
          placeholder="What do you feel like?"
          aria-label="Type what you feel like doing"
          className="min-h-[44px] min-w-0 flex-1 rounded-full border border-ink-warm/15 bg-paper-cream/95 px-4 py-2 text-sm text-ink-warm shadow focus:border-deep-teal focus:outline-none"
        />
        <button
          type="button"
          onClick={toggleRecording}
          disabled={!micAvailable}
          aria-pressed={recording}
          aria-label={recording ? "Stop voice input" : "Start voice input"}
          className={[
            "flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-full shadow-md ring-2 ring-paper-cream",
            recording ? "bg-warm-amber" : "bg-deep-teal",
            "text-xl text-paper-cream focus:outline-none focus:ring-4 focus:ring-deep-teal/40",
            micAvailable ? "" : "opacity-50",
          ].join(" ")}
        >
          <span aria-hidden="true">{recording ? "●" : "🎙"}</span>
        </button>
        <button
          type="submit"
          disabled={textValue.trim().length === 0}
          className="min-h-[44px] rounded-full bg-deep-teal px-4 py-2 text-sm font-medium text-paper-cream shadow hover:bg-deep-teal/90 disabled:opacity-60"
        >
          Send
        </button>
      </form>
    </div>
  );
}
