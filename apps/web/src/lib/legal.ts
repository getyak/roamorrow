import { BRAND } from "./brand";

/** Public policy destinations, shared by marketing and data-use pages. */
export const LEGAL_URLS = {
  privacy: "https://gist.github.com/kubbot/e177b6ab042c8d5bd79417300031a5c9",
  terms: "https://gist.github.com/kubbot/08f720b1191b6f9c913699c16227581a",
} as const;

export const SUPPORT_EMAIL = BRAND.supportEmail;
