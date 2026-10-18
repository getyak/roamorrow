import { ImageResponse } from "next/og";
import { RoamorrowMark } from "@/components/brand/RoamorrowMark";
import { BRAND } from "@/lib/brand";

export const size = { width: 32, height: 32 };
export const contentType = "image/png";

export default function Icon() {
  return new ImageResponse(
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        width: "100%",
        height: "100%",
        background: BRAND.colors.paper,
      }}
    >
      <RoamorrowMark size={size.width * 0.9} />
    </div>,
    size,
  );
}
