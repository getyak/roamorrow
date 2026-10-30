#!/usr/bin/env python3
"""Bounded live model + extracted production place-search acceptance.

The production HomeAgent prompt/tool schema and search handler are read at run
start. MapKit search, coordinate conversion, radius filtering, Experience and
quality predicates use production Swift source and the real macOS Apple SDK.
MapViewModel persistence/UI, router dispatch envelope and HomeAgent journal are
NOT exercised. This is supplementary evidence, never iOS Simulator acceptance.
Secrets remain in this process and are never copied to receipts or subprocesses.
"""
from __future__ import annotations

import argparse
import ast
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import textwrap
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps/ios/SoloCompass"
TOKYO = {"name": "东京神保町（公共QA地图范围）", "latitude": 35.6958, "longitude": 139.7585, "cityCode": "tokyo"}
MAX_MODELS = 4
MAX_TOOLS = 8
MAX_PROVIDER_SEARCHES = 12
MODEL_TIMEOUT = 30


def digest(value: bytes | str) -> str:
    return hashlib.sha256(value.encode() if isinstance(value, str) else value).hexdigest()


def config(path: Path) -> dict[str, str]:
    values = {}
    for line in path.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            values[key.strip().removeprefix("export ")] = value.strip().strip("\"'")
    for key in ["DEEPSEEK_API_KEY", "DEEPSEEK_BASE_URL", "DEEPSEEK_MODEL"]:
        if os.environ.get(key):
            values[key] = os.environ[key]
    endpoint = values.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1").rstrip("/") + "/chat/completions"
    url = urllib.parse.urlsplit(endpoint)
    if url.scheme != "https" or url.username or url.password or url.query or url.fragment:
        raise ValueError("Model endpoint must be HTTPS without embedded credentials/query")
    if not values.get("DEEPSEEK_API_KEY"):
        raise ValueError("Model key missing in selected configuration")
    values["endpoint"] = endpoint
    return values


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def source_snapshot() -> dict[str, dict[str, str]]:
    names = ["Services/CompanionHomeAgent.swift", "Services/VoiceAgentToolRouter.swift", "Services/MapKitPOIService.swift", "Services/Geo/MapKitCoordinateSpace.swift", "Services/Geo/CoordinateConverter.swift", "Services/Geo/MainlandChinaBoundary.swift", "Models/Experience.swift", "Models/ExperienceFilter.swift", "Services/AIService.swift", "ViewModels/MapViewModel.swift", "Models/DiscoveryRefreshPolicy.swift"]
    return {name: {"sha256": digest((APP / name).read_bytes())} for name in names}


def native_bridge(out: Path) -> Path:
    """Reuse QA extraction setup, replace ALL provider/geo boundaries with source."""
    harness = ROOT / "scripts/qa/agent-place-search-host.py"
    host = harness.read_text()
    setup = host[:host.index("temporary = tempfile.TemporaryDirectory")]
    scope = {"__file__": str(harness), "__name__": "v4_native_extraction"}
    exec(compile(setup, str(harness), "exec"), scope)
    literals = {}
    for node in ast.parse(host).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            try:
                literals[node.targets[0].id] = ast.literal_eval(node.value)
            except (ValueError, TypeError):
                pass
    block = scope["block"]
    stubs = scope["stubs"]
    stubs = stubs.replace(block(stubs, "@MainActor final class MapKitPOIService {"), "")
    overpass = (APP / "Services/OverpassService.swift").read_text()
    actual_overpass = "public enum OverpassService {\n" + block(overpass, "    public struct POI:") + "\n" + block(overpass, "    public static func category(") + "\n}\n"
    stubs = stubs.replace(block(stubs, "enum OverpassService {"), actual_overpass)
    stubs = stubs.replace("enum ExperienceCategory: String, Sendable { case culture, nature, food, coffee, work, wellness, nightlife, hidden }", "")
    stubs = stubs.replace("// ENRICHMENT_RADII", "enum EnrichmentAgent { " + scope["progressive_radii"] + " }")
    router_wrapper = scope["wrapper"]
    main = r'''
    func liveSearch(_ args: String) async throws -> String { try await executeSearchPlaces(args: args) }
}
@main struct LiveEval {
    @MainActor static func main() async {
        let started = Date()
        let data = FileHandle.standardInput.readDataToEndOfFile()
        do {
            let input = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let args = input["args"] as? [String: Any] ?? [:]
            if input["operation"] as? String == "raw_comparison" {
                let center = CLLocationCoordinate2D(latitude: 35.6817, longitude: 139.7708)
                let space = MapKitCoordinateSpace.shared
                try await space.prepare(near: center)
                guard let searchCenter = space.searchCoordinate(center) else { throw MapKitCoordinateSpace.CalibrationError.unavailable }
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "東京駅"
                request.region = .init(center: searchCenter, latitudinalMeters: 4000, longitudinalMeters: 4000)
                request.resultTypes = .pointOfInterest
                if #available(macOS 15.0, *) { request.regionPriority = .required }
                let response = try await MKLocalSearch(request: request).start()
                for item in response.mapItems {
                    try await space.prepare(near: item.placemark.coordinate, countryCode: item.placemark.isoCountryCode)
                }
                let mapped = response.mapItems.compactMap { MapKitPOIService.poi(from: $0) }
                let filtered = MapKitPOIService.withinRadius(mapped, center: center, meters: 2000)
                let rows: [[String: Any]] = response.mapItems.prefix(6).map { item in
                    ["name": item.name ?? "", "latitude": item.placemark.coordinate.latitude,
                     "longitude": item.placemark.coordinate.longitude, "country": item.placemark.isoCountryCode ?? "",
                     "category": item.pointOfInterestCategory?.rawValue ?? ""]
                }
                let value: [String: Any] = ["ok": true, "query": "東京駅", "raw_map_items": response.mapItems.count,
                    "mapped_pois": mapped.count, "within_radius_pois": filtered.count, "raw_rows": rows,
                    "elapsed_ms": Int(Date().timeIntervalSince(started) * 1000)]
                print(String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self))
                return
            }
            let raw = String(decoding: try JSONSerialization.data(withJSONObject: args), as: UTF8.self)
            let vm = MapViewModel()
            vm.selectedCity = "tokyo"
            vm.cityPickedExplicitlyThisSession = true
            vm.lastVisibleMapCenter = .init(latitude: 35.6958, longitude: 139.7585)
            let router = VoiceAgentToolRouter(vm: vm)
            let searching = Task { @MainActor in try await router.liveSearch(raw) }
            if input["operation"] as? String == "change_city_during_search" {
                try await Task.sleep(for: .milliseconds(10))
                vm.selectedCity = "lisbon"
                vm.lastVisibleMapCenter = .init(latitude: 38.7223, longitude: -9.1393)
            }
            let rawResult = try await searching.value
            let parsed = try JSONSerialization.jsonObject(with: Data(rawResult.utf8))
            let records: [[String: Any]] = vm.allExperiences.map { e in
                ["id": e.id, "name": e.title, "coordinates": e.location.coordinates,
                 "category": e.category.rawValue, "rating": e.location.rating as Any? ?? NSNull(),
                 "solo_score": e.soloScore.overall, "confidence_level": e.confidence.level,
                 "confidence_reason": e.confidence.reason,
                 "sources": e.sources.map { ["title": $0.attribution ?? "", "url": $0.url?.absoluteString ?? ""] }]
            }
            let value: [String: Any] = ["ok": true, "elapsed_ms": Int(Date().timeIntervalSince(started) * 1000),
                "tool_result": parsed, "actual_experience_records": records,
                "vm_boundary": "isolated in-memory QA fixture; no iOS persistence or UI",
                "provider_boundary": "production MapKitPOIService and coordinate sources, real macOS Apple Maps SDK"]
            print(String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self))
        } catch {
            let value: [String: Any] = ["ok": false, "error": String(describing: error),
                                      "elapsed_ms": Int(Date().timeIntervalSince(started) * 1000)]
            print(String(decoding: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self))
        }
    }
}
'''
    sources = [scope["experience_source"], literals["fixture_extension"], scope["skeleton"], "\n}\n", scope["policy"], scope["badge"], stubs, scope["origin"], "\n}\n", scope["quality_protocol"], scope["filter_source"], router_wrapper[router_wrapper.index("@MainActor final class VoiceAgentToolRouter"):], scope["extracted"], main]
    # The actual coordinate service remains intact. Tokyo is WGS84 and outside
    # mainland/SAR calibration regions; it needs no auxiliary anchor requests.
    sources += [(APP / name).read_text() for name in ["Services/Geo/MainlandChinaBoundary.swift", "Services/Geo/CoordinateConverter.swift", "Services/Geo/MapKitCoordinateSpace.swift", "Services/MapKitPOIService.swift"]]
    generated = out / "native-search.swift"
    generated.write_text("\n".join(sources))
    executable = out / "native-search"
    command = ["xcrun", "swiftc", "-parse-as-library", "-strict-concurrency=complete", "-module-cache-path", str(out / "ModuleCache"), str(generated), "-o", str(executable)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    (out / "native-compile.txt").write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError("native SDK extraction compilation failed; see native-compile.txt")
    return executable


def extract_prompt() -> tuple[list[dict], dict]:
    text = (APP / "Services/CompanionHomeAgent.swift").read_text()
    found = re.search(r'let prompt = """\n(.*?)\n\s*"""', text, re.S)
    area = "<selected_public_map_search_center>" + json.dumps(TOKYO, ensure_ascii=False, separators=(",", ":")) + "</selected_public_map_search_center>"
    if not found:
        raise ValueError("Current production HomeAgent prompt template not found")
    prompt = textwrap.dedent(found.group(1))
    replacements = {r"\(summaryJSON)": "[]", r"\(selectedAreaContext)": area, r"\(Date().ISO8601Format())": dt.datetime.now(dt.timezone.utc).isoformat(), r"\(evidence)": ""}
    for key, value in replacements.items():
        prompt = prompt.replace(key, value)
    if "\\(" in prompt:
        raise ValueError("Unknown production prompt interpolation; update explicit QA rendering")
    current = re.search(r'let currentAreaFact = """\n(.*?)\n\s*"""', text, re.S)
    scope_fact = "No place or area scope was selected for this message. Do not silently inherit a scope from historical messages or a newly browsed map pin."
    area_fact = textwrap.dedent(current.group(1)).replace(r"\(selectedAreaContext)", area).replace(r"\(currentScopeFact)", scope_fact) if current else area
    if "\\(" in area_fact:
        raise ValueError("Unknown production current-turn interpolation; update explicit QA rendering")
    router = (APP / "Services/VoiceAgentToolRouter.swift").read_text()
    tool = re.search(r'name: "search_places",\s*description: "((?:\\.|[^"\\])*)",\s*parametersJSON: #"""\s*(.*?)\s*"""#', router, re.S)
    if not tool:
        raise ValueError("Production search_places schema not found")
    schema = json.loads(tool.group(2))
    definition = {"type": "function", "function": {"name": "search_places", "description": tool.group(1), "parameters": schema}}
    return [{"role": "system", "content": prompt}, {"role": "system", "content": area_fact}], definition


def model_request(values: dict, messages: list, tools: list, *, streaming: bool) -> dict:
    body = {"model": values.get("DEEPSEEK_MODEL", "deepseek-flash"), "messages": messages, "max_tokens": 512, "temperature": 0.3, "thinking": {"type": "disabled"}, "stream": streaming}
    if tools:
        body.update(tools=tools, tool_choice="auto", parallel_tool_calls=False)
    request = urllib.request.Request(values["endpoint"], data=json.dumps(body).encode(), headers={"Authorization": "Bearer " + values["DEEPSEEK_API_KEY"], "Content-Type": "application/json", "Accept": "text/event-stream" if streaming else "application/json"})
    started = time.monotonic()
    receipt = {"ok": False, "streaming_transport_probe": streaming, "first_event_ms": None, "first_content_ms": None, "first_tool_delta_ms": None}
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=MODEL_TIMEOUT) as response:
            receipt["http_status"] = response.status
            if streaming:
                content, calls, usage, finish = "", {}, None, None
                for raw in response:
                    elapsed = round((time.monotonic() - started) * 1000)
                    if elapsed > MODEL_TIMEOUT * 1000:
                        raise TimeoutError("absolute model deadline")
                    if not raw.startswith(b"data:"):
                        continue
                    if receipt["first_event_ms"] is None:
                        receipt["first_event_ms"] = elapsed
                    value = raw[5:].strip()
                    if value == b"[DONE]":
                        break
                    chunk = json.loads(value)
                    receipt["response_id"] = chunk.get("id")
                    receipt["model"] = chunk.get("model")
                    usage = chunk.get("usage") or usage
                    choice = (chunk.get("choices") or [{}])[0]
                    finish = choice.get("finish_reason") or finish
                    delta = choice.get("delta", {})
                    if delta.get("content"):
                        receipt["first_content_ms"] = receipt["first_content_ms"] if receipt["first_content_ms"] is not None else elapsed
                        content += delta["content"]
                    for call in delta.get("tool_calls", []):
                        receipt["first_tool_delta_ms"] = receipt["first_tool_delta_ms"] if receipt["first_tool_delta_ms"] is not None else elapsed
                        index = call.get("index", 0)
                        accumulated = calls.setdefault(index, {"id": "", "type": "function", "function": {"name": "", "arguments": ""}})
                        if call.get("id"):
                            accumulated["id"] = call["id"]
                        accumulated["function"]["name"] += call.get("function", {}).get("name", "")
                        accumulated["function"]["arguments"] += call.get("function", {}).get("arguments", "")
                message = {"role": "assistant", "content": content or None}
                if calls:
                    message["tool_calls"] = [calls[i] for i in sorted(calls)]
                receipt.update(ok=finish in ["stop", "tool_calls"], finish_reason=finish, usage=usage, message=message)
            else:
                payload = json.load(response)
                choice = (payload.get("choices") or [{}])[0]
                receipt.update(ok=choice.get("finish_reason") in ["stop", "tool_calls"], finish_reason=choice.get("finish_reason"), response_id=payload.get("id"), model=payload.get("model"), usage=payload.get("usage"), message=choice.get("message"))
    except urllib.error.HTTPError as error:
        receipt.update(http_status=error.code, error="upstream_http_error")
    except Exception as error:
        receipt.update(error=type(error).__name__)
    receipt["total_ms"] = round((time.monotonic() - started) * 1000)
    return receipt


def native_search(executable: Path, args: dict, operation="search") -> dict:
    if args.get("progressive") is not False or not 500 <= args.get("radius_meters", 2000) <= 2000:
        return {"ok": False, "error": "QA budget requires explicit progressive:false and 500<=radius_meters<=2000; no provider called", "provider_search_calls": 0}
    lat, lon = args.get("latitude"), args.get("longitude")
    if (lat is None) != (lon is None) or (lat is not None and (abs(lat - TOKYO["latitude"]) > 0.000001 or abs(lon - TOKYO["longitude"]) > 0.000001)):
        return {"ok": False, "error": "QA permits only the explicitly selected public Tokyo map center; no provider called", "provider_search_calls": 0}
    started = time.monotonic()
    try:
        result = subprocess.run([str(executable)], input=json.dumps({"operation": operation, "args": args}), capture_output=True, text=True, timeout=35)
        lines = [line for line in result.stdout.splitlines() if line.startswith("{")]
        value = json.loads(lines[-1]) if lines else {"ok": False, "error": "native_result_unavailable"}
    except subprocess.TimeoutExpired:
        value = {"ok": False, "error": "native_process_deadline"}
    value.update(provider_search_calls=1, subprocess_total_ms=round((time.monotonic() - started) * 1000))
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--live-model", action="store_true")
    parser.add_argument("--native-only", action="store_true")
    parser.add_argument("--sdk-diagnostic", action="store_true")
    parser.add_argument("--streaming-probe", action="store_true", help="Explicit SSE transport sample, not current shipping HomeAgent transport")
    arguments = parser.parse_args()
    out = arguments.out.resolve()
    if (out / "receipt.json").exists():
        raise SystemExit("A receipt already exists here; choose a fresh artifact subdirectory to preserve evidence")
    out.mkdir(parents=True, exist_ok=True)
    before = source_snapshot()
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    receipt = {"started_at": dt.datetime.now(dt.timezone.utc).isoformat(), "git_revision": revision, "source_files": before, "scope": "Production HomeAgent prompt/tool schema + production extracted search handler + real macOS MapKit SDK; isolated model transport/VM/store adapter, not full shipping HomeAgent or iOS UI", "budgets": {"model_requests": MAX_MODELS, "max_output_tokens_each": 512, "tool_calls": MAX_TOOLS, "provider_search_calls": MAX_PROVIDER_SEARCHES}, "model_requests": [], "tool_calls": [], "sdk_scenarios": [], "accepted": False, "notes": ["SSE measurements are a transport sample only when --streaming-probe is explicit; current HomeAgent uses non-streaming sendAgentMessage.", "SDK-internal HTTP request count is opaque; receipts bound explicit API search invocations, not unseen Apple network traffic.", "No private mail/calendar, navigation side effects, bookings, payments or personal history are used."]}
    try:
        executable = native_bridge(out)
        receipt["generated_native_source_sha256"] = digest((out / "native-search.swift").read_bytes())
        receipt["native_compile_succeeded"] = True
        if arguments.sdk_diagnostic:
            result = native_search(executable, {"query": "東京駅", "radius_meters": 2000, "progressive": False}, "raw_comparison")
            receipt["sdk_scenarios"].append({"name": "raw_vs_production_mapping_tokyo_station", "result": result})
            print(json.dumps({"scenario": "raw_vs_production_mapping_tokyo_station", "result": result}, ensure_ascii=False), flush=True)
        if arguments.native_only:
            scenarios = [("tokyo_bookstore", {"query": "本屋", "radius_meters": 2000, "progressive": False}, "search"), ("unknown_rating_not_inferred", {"query": "本屋", "rating_min": 8, "radius_meters": 2000, "progressive": False}, "search"), ("nonsense_query_no_unrelated_fallback", {"query": "qzxv-roamorrow-no-venue-964172", "radius_meters": 500, "progressive": False}, "search"), ("city_change_during_real_search", {"query": "本屋", "radius_meters": 2000, "progressive": False}, "change_city_during_search")]
            for name, args, operation in scenarios:
                result = native_search(executable, args, operation)
                receipt["sdk_scenarios"].append({"name": name, "input": args, "result": result})
                print(json.dumps({"scenario": name, "ok": result.get("ok"), "elapsed_ms": result.get("subprocess_total_ms")}), flush=True)
        if arguments.live_model:
            if not arguments.env_file:
                raise ValueError("--env-file required for live model")
            values = config(arguments.env_file)
            receipt["configuration"] = {"endpoint_host": urllib.parse.urlsplit(values["endpoint"]).hostname, "model": values.get("DEEPSEEK_MODEL", "deepseek-flash"), "key_configured": True}
            initial, tool = extract_prompt()
            messages = initial + [{"role": "user", "content": "我没有授权定位，地图手动选在东京神保町。请用地点工具找附近2公里内的书店，不扩圈；是否安静、评分和营业状态都要以资料为准，未知就说明。先不要加入行程。"}]
            (out / "model-input.public.json").write_text(json.dumps({"messages": messages, "tools": [tool]}, ensure_ascii=False, indent=2) + "\n")
            for round_index in range(MAX_MODELS):
                response = model_request(values, messages, [tool], streaming=arguments.streaming_probe)
                receipt["model_requests"].append({"round": round_index, **response})
                print(json.dumps({"model_round": round_index, "ok": response.get("ok"), "status": response.get("http_status"), "total_ms": response["total_ms"]}), flush=True)
                if not response.get("ok"):
                    break
                message = response.get("message") or {}
                messages.append(message)
                calls = message.get("tool_calls") or []
                if not calls:
                    if round_index == 1 and receipt["tool_calls"]:
                        messages.append({"role": "user", "content": "现在只找有来源证实评分至少8分的书店，还是2公里且不扩圈；如果评分未知，不能替我当作满足。不要保存或加入行程。"})
                        continue
                    break
                for call in calls:
                    if len(receipt["tool_calls"]) >= MAX_TOOLS:
                        raise ValueError("tool call budget exhausted")
                    if call.get("function", {}).get("name") != "search_places":
                        raise ValueError("model requested unavailable tool")
                    args = json.loads(call["function"]["arguments"])
                    searches = sum(t["result"].get("provider_search_calls", 0) for t in receipt["tool_calls"]) + sum(t["result"].get("provider_search_calls", 0) for t in receipt["sdk_scenarios"])
                    if searches >= MAX_PROVIDER_SEARCHES:
                        raise ValueError("provider search budget exhausted")
                    result = native_search(executable, args)
                    receipt["tool_calls"].append({"id": call["id"], "name": "search_places", "input": args, "result": result})
                    # Public evidence adapter matches the grounded-result shape;
                    # this is not the production journal/checkpoint implementation.
                    grounded = {"original_tool_result": result.get("tool_result") or {"ok": False, "error": result.get("error")}, "actual_experience_records": result.get("actual_experience_records", []), "location_caution": "Selected public map area is not device GPS. Ratings, quietness and opening hours are unknown unless a returned source proves them."}
                    messages.append({"role": "tool", "tool_call_id": call["id"], "content": json.dumps(grounded, ensure_ascii=False)})
        after = source_snapshot()
        receipt["source_changed_during_run"] = [name for name in before if before[name] != after[name]]
        receipt["accepted"] = False
        receipt["notes"].append("Inspect actual outputs/assertions; a smoke run alone does not accept the overall native product.")
    except Exception as error:
        receipt["failure"] = {"type": type(error).__name__, "message": str(error)[:300]}
        print(json.dumps({"runner_failure": type(error).__name__, "message": str(error)[:180]}), flush=True)
    finally:
        receipt["finished_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        (out / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    return 0 if "failure" not in receipt else 1


if __name__ == "__main__":
    raise SystemExit(main())
