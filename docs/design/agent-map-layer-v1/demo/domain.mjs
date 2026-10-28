import { randomUUID, createHash, randomBytes } from "node:crypto";
import { readFileSync, writeFileSync, renameSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { places, colors, distance } from "./fixtures.mjs";
import { tools, validate } from "./contract.mjs";
const clone = (x) => structuredClone(x);
const id = (p) => `${p}_${randomUUID().slice(0, 12)}`;
const canonical = (x) =>
  JSON.stringify(x, (_, v) =>
    v && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(
          Object.keys(v)
            .sort()
            .map((k) => [k, v[k]]),
        )
      : v,
  );
const hash = (x) => createHash("sha256").update(x).digest("hex");
export class DomainError extends Error {
  constructor(code, message, details = {}, retryable = false) {
    super(message);
    Object.assign(this, { code, details, retryable });
  }
}
const fail = (c, m, d = {}, r = false) => {
  throw new DomainError(c, m, d, r);
};
export function createDomain(
  dir,
  baseURL,
  { catalog = places, routeLookup = null, mode: runtimeMode = "fixture" } = {},
) {
  const isLive = runtimeMode === "live";
  const routeCost = (a, b) =>
    isLive
      ? (routeLookup?.(a, b, "walking")?.duration_seconds ?? Infinity)
      : distance(a.coordinates, b.coordinates);
  mkdirSync(dir, { recursive: true });
  const file = join(dir, "state.json");
  let db;
  try {
    db = JSON.parse(readFileSync(file, "utf8"));
  } catch (e) {
    if (e.code !== "ENOENT") throw e;
    db = { maps: {}, shares: {}, edits: {}, keys: {} };
  }
  function save() {
    const temp = file + ".tmp";
    writeFileSync(temp, JSON.stringify(db), { mode: 0o600 });
    renameSync(temp, file);
  }
  function owned(mid, subject) {
    const m = db.maps[mid];
    if (!m || m.owner !== subject) fail("NOT_FOUND", "地图不存在或当前会话无权访问");
    return m;
  }
  const snapshot = (m) => clone(m.snapshot);
  function schedule(day, mode, allowUnknown, fault) {
    if (day.stops.length > 12) fail("INFEASIBLE", "一天最多 12 个停靠点");
    if (day.end_minute <= day.start_minute) fail("VALIDATION_ERROR", "结束时间必须晚于出发时间");
    if (fault === "provider")
      fail(
        "PROVIDER_UNAVAILABLE",
        "演示：交通服务暂不可用，原图已保留",
        { retry_after_seconds: 2 },
        true,
      );
    day.legs = [];
    let clock = day.start_minute,
      total = 0,
      lowerBound = day.start_minute;
    for (let i = 0; i < day.stops.length; i++) {
      const stop = day.stops[i];
      stop.feasibility_status = "unknown";
      if (i) {
        const prev = day.stops[i - 1];
        const unknown = fault === "unknown";
        const km = distance(prev.coordinates, stop.coordinates);
        const speed = { walking: 4.5, cycling: 13, driving: 24, transit: 18 }[mode];
        const liveCell = isLive && !unknown ? routeLookup?.(prev, stop, mode) : null;
        if (isLive && !unknown && !liveCell)
          fail("PROVIDER_UNAVAILABLE", "真实路网数据缺失，未生成估算替代", {}, true);
        const minutes = unknown
          ? null
          : isLive
            ? Math.ceil(liveCell.duration_seconds / 60)
            : Math.max(
                3,
                Math.ceil(
                  (km / speed) * 60 * (mode === "transit" ? 1.3 : 1.2) +
                    (mode === "transit" ? 8 : 0),
                ),
              );
        if (unknown && !allowUnknown)
          fail("PROVIDER_UNAVAILABLE", "缺少可验证的交通时间，原图已保留", {}, true);
        day.legs.push({
          from_stop_id: prev.stop_id,
          to_stop_id: stop.stop_id,
          mode,
          duration_minutes: minutes,
          evidence_status: unknown ? "unknown" : isLive ? "resolved" : "demo_estimate",
          geometry_status: liveCell?.geometry ? "routed" : isLive ? "unknown" : "schematic",
          ...(liveCell?.geometry
            ? {
                geometry: liveCell.geometry,
                distance_meters: liveCell.distance_meters,
                source_url: liveCell.source_url,
                fetched_at: liveCell.fetched_at,
              }
            : {}),
        });
        if (minutes === null) {
          clock = null;
          total = null;
        } else {
          lowerBound += minutes;
          if (clock !== null) clock += minutes;
          if (total !== null) total += minutes;
        }
      }
      stop.arrival_minute = clock;
      if (stop.fixed_start_minute !== null) {
        if (lowerBound > stop.fixed_start_minute) fail("INFEASIBLE", "无法赶上锁定预约");
        clock = stop.fixed_start_minute;
        lowerBound = stop.fixed_start_minute;
      }
      lowerBound += stop.duration_minutes;
      stop.start_minute = clock;
      stop.end_minute = clock === null ? null : clock + stop.duration_minutes;
      clock = stop.end_minute;
      if (lowerBound > day.end_minute)
        fail("INFEASIBLE", "这一天超过结束时间，已保留原行程", {
          reason: "缩短停留、提前出发或换到其他天",
        });
    }
    day.total_travel_minutes = total;
    day.ends_at_minute = clock;
    day.feasibility_status = "unknown";
  }
  function call(name, args, subject, { fault, previewOnly = false } = {}) {
    const tool = tools.find((t) => t.name === name);
    if (!tool) fail("VALIDATION_ERROR", "未知工具");
    try {
      validate(tool.inputSchema, args);
    } catch (e) {
      fail("VALIDATION_ERROR", e.message);
    }
    if (!subject) fail("NOT_FOUND", "需要演示所有者会话");
    const key = name === "search_places" ? null : `${subject}:${name}:${args.idempotency_key}`;
    const payload = canonical(args);
    if (key && db.keys[key]) {
      if (db.keys[key].payload !== payload)
        fail("IDEMPOTENCY_CONFLICT", "同一个重试 key 不能换参数");
      return clone(db.keys[key].result);
    }
    const oldDB = clone(db);
    try {
      let data,
        warnings = [];
      let m;
      if (args.map_id) {
        m = owned(args.map_id, subject);
        if ("expected_version" in args && m.snapshot.version !== args.expected_version)
          fail("VERSION_CONFLICT", "地图刚被更新，请先读回最新版本", {
            current_version: m.snapshot.version,
            snapshot: snapshot(m),
          });
      }
      if (name === "create_map") {
        try {
          new Intl.DateTimeFormat("en", { timeZone: args.timezone });
        } catch {
          fail("VALIDATION_ERROR", "无效的 IANA 时区");
        }
        if (
          args.start_date &&
          (!Number.isFinite(Date.parse(args.start_date)) ||
            new Date(args.start_date).toISOString().slice(0, 10) !== args.start_date)
        )
          fail("VALIDATION_ERROR", "日期无效");
        const mid = id("map");
        const snap = {
          map_id: mid,
          title: args.title,
          city: args.city,
          timezone: args.timezone,
          start_date: args.start_date ?? null,
          version: 1,
          status: "draft",
          demo: !isLive,
          days: Array.from({ length: args.day_count }, (_, i) => ({
            day_id: id("day"),
            day_index: i + 1,
            label: `第 ${i + 1} 天`,
            color: colors[i],
            transport_mode: "transit",
            allow_unknown_travel: false,
            start_minute: 540,
            end_minute: 1080,
            stops: [],
            legs: [],
            total_travel_minutes: 0,
            ends_at_minute: 540,
            feasibility_status: "unknown",
          })),
        };
        m = { owner: subject, snapshot: snap, mode: "transit", allowUnknown: false };
        db.maps[mid] = m;
        data = {
          snapshot: snapshot(m),
          edit_url: `${baseURL}/m/${mid}`,
          assumptions: isLive
            ? ["无日期时使用相对天", "Wikidata 地点与 OSRM 步行路网；营业日待核查"]
            : ["无出行日期时使用相对天", "09:00–18:00 是计划值", "地点为演示资料，交通为演示估算"],
        };
      } else if (name === "search_places") {
        if (args.area) {
          const ring = args.area.coordinates[0];
          if (canonical(ring[0]) !== canonical(ring.at(-1)))
            fail("VALIDATION_ERROR", "Polygon 必须闭合");
        }
        // This adapter intentionally resolves only its explicit Tokyo fixture.
        const cityOK = /tokyo|东京|東京/i.test(m.snapshot.city);
        const contains = (point, ring) => {
          let inside = false;
          for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
            const [xi, yi] = ring[i],
              [xj, yj] = ring[j];
            if (
              yi > point[1] !== yj > point[1] &&
              point[0] < ((xj - xi) * (point[1] - yi)) / (yj - yi) + xi
            )
              inside = !inside;
          }
          return inside;
        };
        data = {
          queries: args.queries.map((query) => {
            const matched = cityOK
              ? catalog.filter(
                  (p) =>
                    p.name === query &&
                    (!args.area || contains(p.coordinates, args.area.coordinates[0])),
                )
              : [];
            return {
              query,
              status: matched.length > 1 ? "ambiguous" : matched.length ? "resolved" : "not_found",
              candidates: clone(matched),
            };
          }),
        };
      } else if (name === "plot_places") {
        if (m.snapshot.days.reduce((n, d) => n + d.stops.length, 0) + args.items.length > 40)
          fail("INFEASIBLE", "地图最多 40 个停靠点");
        const stopIds = [];
        for (const item of args.items) {
          if (item.lock_to_day && item.fixed_start_minute === undefined)
            fail("VALIDATION_ERROR", "锁定日期需要明确固定时刻");
          const p = catalog.find((p) => p.place_ref === item.place_ref);
          if (!p || !/tokyo|东京|東京/i.test(m.snapshot.city))
            fail("PLACE_UNRESOLVED", "请先解析并确认地点");
          const day = m.snapshot.days.find((d) => d.day_id === item.day_id);
          if (!day) fail("VALIDATION_ERROR", "日期不属于这张地图");
          if (day.stops.length >= 12) fail("INFEASIBLE", "一天最多 12 个停靠点");
          if (m.snapshot.days.some((d) => d.stops.some((s) => s.place_ref === p.place_ref)))
            fail("VALIDATION_ERROR", "该地点已在地图中，使用移动操作");
          const sid = id("stop");
          stopIds.push(sid);
          day.stops.push({
            stop_id: sid,
            place_ref: p.place_ref,
            name: p.canonical_name ?? p.name,
            coordinates: clone(p.coordinates),
            source_url: p.source_url,
            provider: p.provider,
            ...(p.source_revision ? { source_revision: p.source_revision } : {}),
            ...(p.fetched_at ? { fetched_at: p.fetched_at } : {}),
            ...(p.canonical_name ? { canonical_name: p.canonical_name } : {}),
            experience_id: item.experience_id ?? null,
            duration_minutes: item.duration_minutes,
            locked_day_id: item.lock_to_day ? item.day_id : null,
            fixed_start_minute: item.fixed_start_minute ?? null,
            arrival_minute: null,
            feasibility_status: "unknown",
            start_minute: null,
            end_minute: null,
          });
        }
        m.snapshot.version++;
        m.snapshot.status = "draft";
        data = { snapshot: snapshot(m), stop_ids: stopIds };
      } else if (name === "build_route") {
        const dayIds = args.day_plans.map((d) => d.day_id);
        if (new Set(dayIds).size !== dayIds.length)
          fail("VALIDATION_ERROR", "day_plans 不能重复日期");
        for (const plan of args.day_plans) {
          const day = m.snapshot.days.find((d) => d.day_id === plan.day_id);
          if (!day) fail("VALIDATION_ERROR", "日期不属于地图");
          if (
            plan.stop_ids.length !== day.stops.length ||
            plan.stop_ids.some((sid) => !day.stops.some((s) => s.stop_id === sid))
          )
            fail("VALIDATION_ERROR", "必须包含该天全部停靠点");
          day.stops = plan.stop_ids.map((sid) => day.stops.find((s) => s.stop_id === sid));
          if (plan.order_policy === "optimize" && day.stops.length > 2) {
            const rest = day.stops.slice(1),
              ordered = [day.stops[0]];
            while (rest.length) {
              rest.sort((a, b) => routeCost(ordered.at(-1), a) - routeCost(ordered.at(-1), b));
              ordered.push(rest.shift());
            }
            day.stops = ordered;
          }
          day.transport_mode = args.transport_mode;
          day.allow_unknown_travel = args.allow_unknown_travel;
          day.start_minute = plan.start_minute;
          day.end_minute = plan.end_minute;
          schedule(day, args.transport_mode, args.allow_unknown_travel, fault);
        }
        m.mode = args.transport_mode;
        m.allowUnknown = args.allow_unknown_travel;
        m.snapshot.version++;
        m.snapshot.status = "ready_with_warnings";
        data = { snapshot: snapshot(m), affected_day_ids: dayIds };
      } else if (name === "update_day") {
        const before = clone(m.snapshot.days),
          op = args.operation;
        let affected = [];
        const findStop = () => {
          for (const d of m.snapshot.days) {
            const index = d.stops.findIndex((s) => s.stop_id === op.stop_id);
            if (index >= 0) return { day: d, index, stop: d.stops[index] };
          }
          fail("VALIDATION_ERROR", "停靠点不在地图中");
        };
        if (op.type === "move_stop") {
          const found = findStop(),
            target = m.snapshot.days.find((d) => d.day_id === op.target_day_id);
          if (!target) fail("VALIDATION_ERROR", "目标日期无效");
          if (found.stop.locked_day_id && found.stop.locked_day_id !== target.day_id)
            fail("INFEASIBLE", "预约绑定原日期，不能直接改天");
          found.day.stops.splice(found.index, 1);
          if (op.target_index > target.stops.length) fail("VALIDATION_ERROR", "插入位置超出目标天");
          target.stops.splice(op.target_index, 0, found.stop);
          affected = [...new Set([found.day.day_id, target.day_id])];
          if (op.order_policy === "optimize") {
            for (const day of m.snapshot.days.filter((d) => affected.includes(d.day_id))) {
              // Fixture-only heuristic: retain start anchor and every fixed time slot.
              if (day.stops.some((s) => s.fixed_start_minute !== null) || day.stops.length < 3)
                continue;
              const ordered = [day.stops[0]],
                rest = day.stops.slice(1);
              while (rest.length) {
                rest.sort((a, b) => routeCost(ordered.at(-1), a) - routeCost(ordered.at(-1), b));
                ordered.push(rest.shift());
              }
              day.stops = ordered;
            }
          }
        }
        if (op.type === "reorder_stops") {
          const day = m.snapshot.days.find((d) => d.day_id === op.day_id);
          if (
            !day ||
            day.stops.length !== op.stop_ids.length ||
            op.stop_ids.some((sid) => !day.stops.some((s) => s.stop_id === sid))
          )
            fail("VALIDATION_ERROR", "重排必须包含该天每个停靠点一次");
          day.stops = op.stop_ids.map((sid) => day.stops.find((s) => s.stop_id === sid));
          affected = [day.day_id];
        }
        if (op.type === "set_start_time") {
          const day = m.snapshot.days.find((d) => d.day_id === op.day_id);
          if (!day) fail("VALIDATION_ERROR", "日期无效");
          day.start_minute = op.start_minute;
          affected = [day.day_id];
        }
        if (op.type === "set_stop_duration") {
          const found = findStop();
          found.stop.duration_minutes = op.duration_minutes;
          affected = [found.day.day_id];
        }
        if (op.type === "undo") {
          const edit = db.edits[op.edit_id];
          if (
            !edit ||
            edit.map_id !== m.snapshot.map_id ||
            edit.committed_version !== m.snapshot.version ||
            edit.undone
          )
            fail("UNDO_CONFLICT", "已有后续编辑，不能覆盖；请重新调整");
          affected = edit.affected_day_ids;
          for (const d of edit.before) {
            const i = m.snapshot.days.findIndex((x) => x.day_id === d.day_id);
            m.snapshot.days[i] = clone(d);
          }
          if (!args.dry_run) edit.undone = true;
        }
        if (op.type !== "undo")
          for (const d of m.snapshot.days.filter((d) => affected.includes(d.day_id)))
            schedule(d, d.transport_mode, d.allow_unknown_travel, fault);
        const selectedBefore = before.filter((d) => affected.includes(d.day_id)),
          after = clone(m.snapshot.days.filter((d) => affected.includes(d.day_id)));
        const diff = after.map(
          (d) =>
            `${d.label}：${selectedBefore.find((b) => b.day_id === d.day_id).stops.length} → ${d.stops.length} 个地点；交通 ${d.total_travel_minutes ?? "未知"} 分钟（演示估算）`,
        );
        let eid = null;
        if (!args.dry_run) {
          m.snapshot.version++;
          m.snapshot.status = "ready_with_warnings";
          eid = id("edit");
          db.edits[eid] = {
            map_id: m.snapshot.map_id,
            committed_version: m.snapshot.version,
            affected_day_ids: affected,
            before: selectedBefore,
            after,
          };
        }
        data = {
          snapshot: snapshot(m),
          affected_day_ids: affected,
          before: selectedBefore,
          after,
          edit_id: eid,
          diff,
          preview: args.dry_run,
        };
        if (args.dry_run) db = oldDB;
      } else if (name === "get_map_link") {
        if (m.snapshot.status === "draft") fail("INFEASIBLE", "先排好路线再分享");
        if (
          args.visible_stop_ids.some(
            (sid) => !m.snapshot.days.some((d) => d.stops.some((s) => s.stop_id === sid)),
          )
        )
          fail("VALIDATION_ERROR", "公开停靠点不属于地图");
        const token = randomBytes(18).toString("base64url"),
          expires = new Date(Date.now() + args.expires_in_days * 86400000).toISOString();
        db.shares[hash(token)] = {
          map_id: m.snapshot.map_id,
          expires_at: expires,
          revoked: false,
          visible_stop_ids: args.visible_stop_ids,
        };
        data = {
          share_url: `${baseURL}/s/${token}`,
          edit_url: `${baseURL}/m/${m.snapshot.map_id}`,
          expires_at: expires,
          map_version: m.snapshot.version,
          access: "view",
        };
      }
      if (["create_map", "plot_places", "build_route", "update_day"].includes(name))
        warnings = isLive
          ? [
              {
                code: "opening_hours_unknown",
                message: "真实地点与步行路网；日期、营业时间与预约仍需核查",
              },
            ]
          : [
              {
                code: "demo_fixture",
                message: "演示资料与估算；未核查营业日、实时交通或实际可达性",
              },
            ];
      const result = { ok: true, data, warnings };
      validate(tool.outputSchema, result);
      if (previewOnly) {
        db = oldDB;
        return result;
      }
      if (key && !args.dry_run) {
        db.keys[key] = { payload, result: clone(result) };
        save();
      }
      return result;
    } catch (e) {
      db = oldDB;
      throw e;
    }
  }
  return {
    call,
    get(mid, subject) {
      return snapshot(owned(mid, subject));
    },
    share(token, subject) {
      const grant = db.shares[hash(token)];
      if (!grant || grant.revoked || Date.parse(grant.expires_at) < Date.now())
        fail("NOT_FOUND", "分享链接不存在或已过期");
      const m = db.maps[grant.map_id];
      const publicSnap = snapshot(m);
      for (const day of publicSnap.days) {
        const fullCount = day.stops.length;
        day.stops = day.stops.filter((s) => grant.visible_stop_ids.includes(s.stop_id));
        day.legs = day.legs.filter((l) => {
          const i = day.stops.findIndex((s) => s.stop_id === l.from_stop_id);
          return i >= 0 && day.stops[i + 1]?.stop_id === l.to_stop_id;
        });
        if (day.stops.length !== fullCount) {
          day.total_travel_minutes = null;
          day.ends_at_minute = null;
          for (const stop of day.stops) {
            stop.arrival_minute = null;
            stop.start_minute = null;
            stop.end_minute = null;
          }
        }
      }
      return { snapshot: publicSnap, can_edit: m.owner === subject };
    },
    fork(token, subject) {
      const shared = this.share(token, subject);
      const snap = clone(shared.snapshot);
      const mid = id("map");
      snap.map_id = mid;
      snap.title = snap.title.slice(0, 152) + " · 我的副本";
      snap.version = 1;
      const ids = new Map();
      for (const day of snap.days) {
        ids.set(day.day_id, id("day"));
        for (const stop of day.stops) ids.set(stop.stop_id, id("stop"));
      }
      for (const day of snap.days) {
        day.day_id = ids.get(day.day_id);
        for (const stop of day.stops) {
          stop.stop_id = ids.get(stop.stop_id);
          if (stop.locked_day_id) stop.locked_day_id = ids.get(stop.locked_day_id);
        }
        for (const leg of day.legs) {
          leg.from_stop_id = ids.get(leg.from_stop_id);
          leg.to_stop_id = ids.get(leg.to_stop_id);
        }
      }
      const old = db.maps[shared.snapshot.map_id];
      validate(tools[0].outputSchema.$defs.Map, snap, { $defs: tools[0].outputSchema.$defs });
      db.maps[mid] = {
        owner: subject,
        snapshot: snap,
        mode: old.mode,
        allowUnknown: old.allowUnknown,
      };
      save();
      return { snapshot: snap };
    },
  };
}
