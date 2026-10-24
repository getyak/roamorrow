import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { webcrypto } from "node:crypto";
import * as vm from "node:vm";
import * as ts from "typescript";

export interface EdgeHandlerOptions {
  env: Record<string, string>;
  supabase: unknown;
  fetchImpl: (input: string | URL, init?: RequestInit) => Promise<Response>;
  moduleMocks?: Record<string, unknown>;
}

/** Execute production handlers and their local shared modules without network imports. */
export function loadEdgeHandler(
  absolutePath: string,
  options: EdgeHandlerOptions,
): (request: Request) => Promise<Response> {
  let handler: ((request: Request) => Promise<Response>) | undefined;
  const context = vm.createContext({
    Deno: {
      env: { get: (key: string) => options.env[key] },
      serve: (value: (request: Request) => Promise<Response>) => {
        handler = value;
      },
    },
    Request,
    Response,
    Headers,
    URL,
    URLSearchParams,
    TextEncoder,
    TextDecoder,
    crypto: webcrypto,
    atob,
    btoa,
    console,
    fetch: options.fetchImpl,
  });
  const cache = new Map<string, { exports: Record<string, unknown> }>();

  function load(path: string): Record<string, unknown> {
    const cached = cache.get(path);
    if (cached) return cached.exports;
    const module = { exports: {} as Record<string, unknown> };
    cache.set(path, module);
    const { outputText } = ts.transpileModule(readFileSync(path, "utf8"), {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
        esModuleInterop: true,
      },
      fileName: path,
    });
    const require = (id: string): unknown => {
      if (id.includes("@supabase/supabase-js")) return { createClient: () => options.supabase };
      if (options.moduleMocks && id in options.moduleMocks) return options.moduleMocks[id];
      if (id.startsWith(".")) {
        const target = resolve(dirname(path), id);
        return load(target.endsWith(".ts") ? target : `${target}.ts`);
      }
      throw new Error(`unexpected require: ${id}`);
    };
    const evaluate = vm.runInContext(
      `(function(require, module, exports) {\n${outputText}\n})`,
      context,
      { filename: path },
    );
    evaluate(require, module, module.exports);
    return module.exports;
  }

  load(absolutePath);
  if (!handler) throw new Error("Deno.serve handler was not registered");
  return handler;
}
