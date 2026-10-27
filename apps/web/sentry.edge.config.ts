import * as Sentry from "@sentry/nextjs";
import { privateSentryDataCollection, scrubSentryEvent, scrubSentrySpan } from "./src/lib/sentry";

if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    tracesSampleRate: 0.1,
    environment: process.env.NODE_ENV ?? "development",
    dataCollection: privateSentryDataCollection,
    beforeSendSpan: scrubSentrySpan,
    beforeSend: scrubSentryEvent,
  });
}
