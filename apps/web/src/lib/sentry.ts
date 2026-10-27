import type { ErrorEvent, init } from "@sentry/nextjs";

type SentryInitOptions = NonNullable<Parameters<typeof init>[0]>;

/** Keep automatic telemetry free of account, request and model contents. */
export const privateSentryDataCollection = {
  userInfo: false,
  cookies: false,
  httpHeaders: false,
  httpBodies: [],
  urlQueryParams: false,
  genAI: { inputs: false, outputs: false },
  databaseQueryData: false,
  queues: false,
  graphQL: { document: false, variables: false },
  stackFrameVariables: false,
} satisfies NonNullable<SentryInitOptions["dataCollection"]>;

/** RequestData can attach a body already supplied through the scope. */
export const scrubSentrySpan: NonNullable<SentryInitOptions["beforeSendSpan"]> = (span) => {
  const attributes = { ...span.attributes };
  delete attributes["http.request.body.data"];
  // Explicit scope user fields are added to spans independently of collection.
  for (const key of ["user.email", "user.name", "user.username", "user.ip", "user.ip_address"]) {
    delete attributes[key];
  }
  return { ...span, attributes };
};

/** Strip known secrets and message content before an event leaves the app. */
export function scrubSentryEvent(event: ErrorEvent): ErrorEvent {
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
    delete event.extra.message_text;
    delete event.extra.mapbox_token;
  }
  return event;
}
