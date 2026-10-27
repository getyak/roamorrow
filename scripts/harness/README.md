# Harness runtime scripts

Lifecycle and probe commands for the private local DeepSeek onboarding harness
(`deploy/compose.harness.yml`, project `roamorrow-harness-local`).

| Command                                                | Purpose                                                                                                                            |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| `./scripts/harness/up.sh`                              | Validate `deploy/harness.runtime-env` (names only, never values) and start the stack                                               |
| `./scripts/harness/up-cached.sh <artifact>/api-server` | Start with an already cached runtime image and a reviewed Linux binary from a registered artifact; no build or pull                |
| `./scripts/harness/status.sh`                          | Container status + loopback readiness                                                                                              |
| `./scripts/harness/probe.sh`                           | Readiness probes: loopback API, capabilities, unauthorized rejection, `/mcp` behavior, private-DB readiness query, no DB host port |
| `./scripts/harness/migrate.sh`                         | Re-apply idempotent harness migrations inside the runtime image                                                                    |
| `./scripts/harness/down.sh`                            | Tear down stack **and volumes** (test runtime: never left running)                                                                 |

Setup once:

```bash
cp deploy/harness.runtime-env.example deploy/harness.runtime-env
chmod 600 deploy/harness.runtime-env
# fill in real values; the file is git-ignored and provided outside source
./scripts/harness/up.sh
./scripts/harness/probe.sh
```

Optional authenticated probes: `export HARNESS_PROBE_TOKEN=<supabase access
token for a verified-email test identity>`. The token is used in headers only
and never printed. Probes never print tokens, email addresses, mail text or
prompt content.

API base: `http://127.0.0.1:4437` (loopback only). The database publishes no
host port. `restart` is `no` for every service: this is a test runtime, not a
deployment.

The cached path is limited to local acceptance; it does not verify the normal
Dockerfile image build. See the [runtime guide](../../docs/development/harness-backend.md)
for its fresh payload, container recreation and teardown boundaries.
