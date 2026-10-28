// Child-only private fault/clock controller: IPC is never exposed as an HTTP API.
import { startLiveServer } from "./live-server.mjs";
if (!process.send) throw Error("acceptance controller requires a private parent IPC channel");
let fault = null,
  offset = 0;
const [dir, cacheDir, port] = process.argv.slice(2);
const runtime = await startLiveServer({
  dir,
  cacheDir,
  port: Number(port),
  envFile: process.env.MAP_CHAIN_ENV_FILE,
  faultMode: () => fault,
  now: () => Date.now() + offset,
});
process.on("message", (message) => {
  if (message.type === "fault" && [null, "provider", "unknown"].includes(message.value))
    fault = message.value;
  else if (message.type === "clock" && Number.isFinite(message.value)) offset = message.value;
  else return;
  process.send({ ack: message.id });
});
const close = () => runtime.server.close(() => process.exit(0));
process.on("SIGTERM", close);
process.on("disconnect", close);
process.send({ ready: true, pid: process.pid });
