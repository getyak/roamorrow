import { ImageResponse } from "next/og";
import { BrandOg } from "@/components/brand/BrandOg";
import { BRAND } from "@/lib/brand";

export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const alt = `${BRAND.name} — ${BRAND.supportingLineZh}`;

export default function OGImageZh() {
  return new ImageResponse(<BrandOg locale="zh" />, size);
}
