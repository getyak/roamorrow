// Reproducible illustrative coordinates, NOT live provider verification.
const p = (id, name, coordinates, url, duration) => ({
  place_ref: `fixture:${id}`,
  name,
  coordinates,
  provider: "demo-fixture",
  source_url: url,
  evidence_status: "demo_fixture",
  duration_minutes: duration,
});
export const places = [
  p("sensoji", "浅草寺", [139.7966, 35.7148], "https://www.senso-ji.jp/english/", 75),
  p("sumida", "隅田公园", [139.803, 35.7135], "https://www.gotokyo.org/en/spot/1/index.html", 45),
  p(
    "ueno",
    "上野公园",
    [139.7741, 35.7154],
    "https://www.kensetsu.metro.tokyo.lg.jp/jimusho/toubuk/ueno/index_top.html",
    90,
  ),
  p("meiji", "明治神宫", [139.6993, 35.6764], "https://www.meijijingu.or.jp/en/", 75),
  p(
    "harajuku",
    "原宿",
    [139.7027, 35.6702],
    "https://www.gotokyo.org/en/destinations/western-tokyo/harajuku/index.html",
    60,
  ),
  p(
    "shibuya",
    "涩谷十字路口",
    [139.7005, 35.6595],
    "https://www.gotokyo.org/en/destinations/western-tokyo/shibuya/index.html",
    45,
  ),
  p("tsukiji", "筑地场外市场", [139.7707, 35.6655], "https://www.tsukiji.or.jp/english/", 75),
  p(
    "ginza",
    "银座",
    [139.7649, 35.6717],
    "https://www.gotokyo.org/en/destinations/central-tokyo/ginza/index.html",
    75,
  ),
  p("tokyo-station", "东京站", [139.7671, 35.6812], "https://www.tokyostationcity.com/en/", 45),
];
export const colors = ["#C4512D", "#246D94", "#6E6C32", "#8056A3", "#297F72", "#A65079", "#76604A"];
export function distance(a, b) {
  const r = (x) => (x * Math.PI) / 180;
  const dlat = r(b[1] - a[1]),
    dlng = r(b[0] - a[0]);
  const h =
    Math.sin(dlat / 2) ** 2 + Math.cos(r(a[1])) * Math.cos(r(b[1])) * Math.sin(dlng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}
