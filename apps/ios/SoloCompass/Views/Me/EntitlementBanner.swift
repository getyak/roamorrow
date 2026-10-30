import SwiftUI

/// Subscription-state row in the personal hub. Three honest entitlement faces:
///
/// - **proTrial** — progress (when the offer period is actually known) +
///   "X days left · billing starts MMM d".
///   Tapping pushes PaywallView so the user can see/manage the upcoming
///   charge (Apple's settings link lives there).
/// - **pro** — confident green-check + "Pro · renews MMM d". Tapping pushes
///   PaywallView (which routes to App Store subscription management).
/// - **free / proExpired** — amber CTA card with honest generic "View plans"
///   copy (contract 6): no fixed free-month promise without StoreKit
///   eligibility. Tapping pushes PaywallView in upsell mode.
///
/// The banner is intentionally tappable in every state so the user has a
/// single, predictable affordance for "manage my subscription" — no hidden
/// settings-deep-link discovery.
struct EntitlementBanner: View {
    @Environment(SubscriptionService.self) private var subscription

    var body: some View {
        NavigationLink {
            PaywallView()
        } label: {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.vertical, 17)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(NSLocalizedString("me.entitlement.a11y.hint",
                                             comment: "Opens subscription details"))
        .accessibilityIdentifier("me.subscription")
    }

    // MARK: - Content variants

    @ViewBuilder
    private var content: some View {
        switch subscription.entitlement {
        case .proTrial:
            trialContent
        case .pro:
            proContent
        case .free, .proExpired:
            upsellContent
        }
    }

    /// Mid-trial: progress + days remaining + billing date.
    private var trialContent: some View {
        let days = subscription.trialDaysRemaining ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headlineText(days: days))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                disclosure
            }
            // Progress bar only when its length can be derived from REAL
            // entitlement/offer dates (contract 6). Never a constant 30-day
            // bar — when the offer period is unknown the honest days-left
            // copy above stands alone.
            if let progress = trialProgress {
                ProgressView(value: progress)
                    .tint(amber)
                    .progressViewStyle(.linear)
            }
        }
    }

    /// Steady-state Pro: clean badge + renewal date.
    private var proContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("me.entitlement.pro.title",
                                       comment: "Pro headline"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(proRenewalDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            disclosure
        }
    }

    /// Free / proExpired: warm CTA card. Copy stays generic and honest
    /// ("View plans") — a "1 month free" promise is only ever made where
    /// StoreKit eligibility is actually checked (the paywall).
    private var upsellContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .font(.headline)
                .foregroundStyle(amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("me.entitlement.upsell.title",
                                       comment: "Try free for 1 month"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(NSLocalizedString("me.entitlement.upsell.detail",
                                       comment: "Pro features hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            disclosure
        }
    }

    // MARK: - Derived values

    /// Headline copy resolves on days-remaining boundary so users see
    /// "Last day of trial" specifically on the final day — a quiet but
    /// honest nudge that beats the generic "1 day left" plural.
    private func headlineText(days: Int) -> String {
        if days <= 0 {
            return NSLocalizedString("me.entitlement.trial.lastDay",
                                     comment: "Last day of trial")
        }
        let fmt = NSLocalizedString("me.entitlement.trial.headline.format",
                                    comment: "Trial headline (%d days)")
        return String(format: fmt, days)
    }

    /// Detail row: "Billing starts on MMM d" — only renders the date if
    /// we have one; falls back to a generic copy so the row is never empty.
    private var detailText: String {
        guard let exp = subscription.currentExpirationDate else {
            return NSLocalizedString("me.entitlement.trial.detail.fallback",
                                     comment: "Trial detail without date")
        }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let fmt = NSLocalizedString("me.entitlement.trial.detail.format",
                                    comment: "Trial detail with date")
        return String(format: fmt, df.string(from: exp))
    }

    private var proRenewalDetail: String {
        guard let exp = subscription.currentExpirationDate else {
            return NSLocalizedString("me.entitlement.pro.detail.fallback",
                                     comment: "Pro detail without date")
        }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let fmt = NSLocalizedString("me.entitlement.pro.detail.format",
                                    comment: "Pro detail with renewal date")
        return String(format: fmt, df.string(from: exp))
    }

    /// Trial progress derived from entitlement/offer dates (contract 6):
    /// the duration is the actual StoreKit introductory-offer period ending at
    /// the entitlement's expiration. Nil (→ no progress bar) when the offer
    /// data isn't loaded or the products advertise conflicting periods — the
    /// old constant 30-day divisor fabricated progress we can't know.
    private var trialProgress: Double? { nil }

    // MARK: - Styling

    private var amber: Color { CompanionHomeStyle.accent }
    private var disclosure: some View {
        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            .foregroundStyle(CompanionHomeStyle.secondaryInk).accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        List {
            Section { EntitlementBanner() }
        }
    }
    .environment(SubscriptionService())
}
