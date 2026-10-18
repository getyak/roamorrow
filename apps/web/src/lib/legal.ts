import { BRAND, publicUrl } from "./brand";

/** Public policy destinations, shared by marketing and data-use pages. */
export const LEGAL_URLS = {
  privacy: publicUrl("/privacy/policy"),
  terms: publicUrl("/terms"),
} as const;

export const SUPPORT_EMAIL = BRAND.supportEmail;
