import { BRAND } from "@/lib/brand";
import { RoamorrowMark } from "./RoamorrowMark";

export function BrandOg({ locale = "en" }: { locale?: "en" | "zh" }) {
  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        background: BRAND.colors.paper,
        color: BRAND.colors.ink,
        padding: "64px 76px",
        fontFamily: "sans-serif",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
        <RoamorrowMark size={76} />
        <span style={{ fontSize: 42, fontWeight: 600, letterSpacing: -1.5 }}>{BRAND.name}</span>
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          fontSize: 84,
          lineHeight: 1.08,
          letterSpacing: -3,
          fontWeight: 600,
        }}
      >
        <span>Find your way.</span>
        <span>Feel at home.</span>
      </div>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          fontSize: 24,
          color: BRAND.colors.brown,
        }}
      >
        <span>
          {locale === "zh" ? BRAND.supportingLineZh : "For solo travel and life on the move."}
        </span>
        <span>{BRAND.host}</span>
      </div>
    </div>
  );
}
