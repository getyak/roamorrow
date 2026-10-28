import { readFileSync } from "node:fs";
import {
  validateBriefInput,
  validateBriefResponse,
} from "../infra/supabase/functions/_shared/city-brief-contract.ts";

try {
  const [mode, fileOrCity, cityOrTarget, targetOrForce] = process.argv.slice(2);
  if (mode === "request") {
    if (!["true", "false"].includes(targetOrForce)) throw new Error("Invalid force flag");
    process.stdout.write(
      JSON.stringify(
        validateBriefInput({
          city_code: fileOrCity,
          target: cityOrTarget,
          force: targetOrForce === "true",
        }),
      ),
    );
  } else if (mode === "verify") {
    const results = validateBriefResponse(
      JSON.parse(readFileSync(fileOrCity, "utf8")),
      cityOrTarget,
      targetOrForce,
    );
    for (const r of results)
      console.log(`${r.target}: ${r.kind}; verified accounting; items written ${r.itemsWritten}`);
  } else throw new Error("Invalid mode");
} catch {
  console.error("City brief validation failed; no complete fresh persisted result was verified.");
  process.exitCode = 1;
}
