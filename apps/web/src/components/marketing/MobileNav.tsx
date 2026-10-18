"use client";

/**
 * MobileNav — the responsive menu for marketing nav (W03).
 *
 * Below the md breakpoint the desktop link row disappeared entirely —
 * features, pricing, manifesto, the language switch and the CTA were all
 * unreachable at 320–390px. This is a real, keyboard-accessible menu:
 * `aria-expanded` on the trigger, Esc closes and returns focus to the
 * trigger, Tab cycles inside the panel, and any navigation closes it.
 */

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

export interface MobileNavItem {
  readonly href: string;
  readonly label: string;
}

interface MobileNavProps {
  readonly items: readonly MobileNavItem[];
  readonly langLabel: string;
  readonly langHref: string;
  readonly ctaLabel: string;
  readonly ctaHref: string;
  readonly menuLabel: string;
  readonly closeLabel: string;
}

export function MobileNav({
  items,
  langLabel,
  langHref,
  ctaLabel,
  ctaHref,
  menuLabel,
  closeLabel,
}: MobileNavProps) {
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement | null>(null);
  const panelRef = useRef<HTMLDivElement | null>(null);

  function close(returnFocus = true) {
    setOpen(false);
    if (returnFocus) triggerRef.current?.focus();
  }

  useEffect(() => {
    if (!open) return;
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") {
        e.preventDefault();
        close();
        return;
      }
      if (e.key !== "Tab") return;
      // Focus trap: the panel + its trigger are the only reachable elements.
      const focusables = [
        triggerRef.current,
        ...(panelRef.current
          ? Array.from(panelRef.current.querySelectorAll<HTMLElement>("a, button"))
          : []),
      ].filter((el): el is HTMLElement => el !== null);
      if (focusables.length === 0) return;
      const first = focusables[0]!;
      const last = focusables[focusables.length - 1]!;
      const active = document.activeElement;
      if (e.shiftKey && active === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      }
    }
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [open]);

  return (
    <div className="md:hidden">
      <button
        ref={triggerRef}
        type="button"
        aria-expanded={open}
        aria-controls="mobile-nav-panel"
        aria-label={open ? closeLabel : menuLabel}
        onClick={() => (open ? close(false) : setOpen(true))}
        className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-border-subtle text-fg-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-focus-ring focus-visible:outline-offset-2"
      >
        <span aria-hidden="true">{open ? "×" : "☰"}</span>
      </button>

      {open && (
        <div
          id="mobile-nav-panel"
          ref={panelRef}
          className="absolute inset-x-0 top-[72px] z-50 border-b border-border-subtle bg-bg-warm px-5 pb-6 pt-2 shadow-lg"
        >
          <ul className="flex flex-col">
            {items.map((it) => (
              <li key={it.href}>
                <Link
                  href={it.href}
                  onClick={() => close(false)}
                  className="block min-h-[44px] py-3 font-body text-[16px] text-fg-primary"
                >
                  {it.label}
                </Link>
              </li>
            ))}
          </ul>
          <div className="mt-2 flex flex-col gap-3 border-t border-border-subtle pt-4">
            <Link
              href={langHref}
              onClick={() => close(false)}
              className="inline-flex min-h-[44px] items-center font-mono text-[12px] uppercase tracking-[0.16em] text-fg-muted"
            >
              {langLabel}
            </Link>
            <Link
              href={ctaHref}
              onClick={() => close(false)}
              className="inline-flex min-h-[44px] items-center justify-center rounded-full bg-accent-interactive px-6 font-body text-[16px] font-medium text-on-accent"
            >
              {ctaLabel}
            </Link>
          </div>
        </div>
      )}
    </div>
  );
}
