/** Returns the hour at a known place timezone; absent evidence stays unknown. */
export function localHourAt(date: Date, timeZone?: string): number | null {
  if (!timeZone || !Number.isFinite(date.getTime())) return null;
  try {
    const hour = new Intl.DateTimeFormat("en-GB", {
      timeZone,
      hour: "numeric",
      hourCycle: "h23",
    }).format(date);
    return Number(hour);
  } catch {
    return null;
  }
}
