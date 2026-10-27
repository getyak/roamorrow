import * as Sentry from "@sentry/node";

/** Keep automatic telemetry free of account, request and model contents. */
export const privateSentryDataCollection = {
  userInfo: false,
  cookies: false,
  httpHeaders: false,
  httpBodies: [],
  urlQueryParams: false,
  genAI: { inputs: false, outputs: false },
  mcp: { inputs: false, outputs: false },
  databaseQueryData: false,
  queues: false,
  graphQL: { document: false, variables: false },
  stackFrameVariables: false,
} satisfies NonNullable<Sentry.NodeOptions["dataCollection"]>;

/** RequestData can attach a body already supplied through the scope. */
export const scrubSentrySpan: NonNullable<Sentry.NodeOptions["beforeSendSpan"]> = (span) => {
  const attributes = { ...span.attributes };
  delete attributes["http.request.body.data"];
  // Explicit scope user fields are added to spans independently of collection.
  for (const key of ["user.email", "user.name", "user.username", "user.ip", "user.ip_address"]) {
    delete attributes[key];
  }
  return { ...span, attributes };
};

let initialized = false;

export function initSentry(): void {
  if (initialized) return;
  const dsn = process.env.SENTRY_DSN;
  if (!dsn) {
    console.log("Sentry: no SENTRY_DSN, skipping init");
    return;
  }
  Sentry.init({
    dsn,
    environment: process.env.NODE_ENV ?? "development",
    tracesSampleRate: 0,
    dataCollection: privateSentryDataCollection,
    beforeSendSpan: scrubSentrySpan,
    beforeSend(event) {
      return scrubPII(event);
    },
  });
  initialized = true;
  console.log("Sentry: initialized for bot");
}

/**
 * Strip user transcripts, telegram identifiers, and any free-text we may have
 * attached to error context. Keeps stack traces; drops payload bodies.
 */
export function scrubPII(event: Sentry.ErrorEvent): Sentry.ErrorEvent {
  if (event.user) {
    delete event.user.email;
    delete event.user.username;
    delete event.user.ip_address;
  }
  if (event.request) {
    delete event.request.cookies;
    delete event.request.data;
    delete event.request.query_string;
    delete event.request.headers;
  }
  if (event.extra) {
    delete event.extra.transcript;
    delete event.extra.intent;
    delete event.extra.voice_url;
    delete event.extra.message_text;
  }
  if (event.contexts) {
    delete event.contexts.transcript;
  }
  return event;
}

export function captureException(err: unknown, tags?: Record<string, string>): void {
  if (!initialized) return;
  Sentry.captureException(err, tags ? { tags } : undefined);
}
