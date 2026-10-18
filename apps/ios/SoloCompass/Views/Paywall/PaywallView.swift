import SwiftUI
import StoreKit

/// User-visible outcome of the paywall's restore action (I08). Restore must
/// never fake an unlock — only a confirmed success unlocks — and a failed or
/// empty restore must say so instead of silently doing nothing. Pure so tests
/// can pin all three branches.
enum RestoreOutcome: Equatable {
    case unlocked
    case noPurchases
    case failed(String)

    static func resolve(success: Bool, lastError: String?) -> RestoreOutcome {
        guard success else {
            if let lastError, !lastError.isEmpty {
                return .failed(lastError)
            }
            return .noPurchases
        }
        return .unlocked
    }

    /// Inline status copy; `nil` for success because the sheet dismisses.
    var message: String? {
        switch self {
        case .unlocked:
            return nil
        case .noPurchases:
            return NSLocalizedString(
                "paywall.restore.none",
                comment: "No previous purchases found for this Apple ID"
            )
        case .failed(let reason):
            return String(
                format: NSLocalizedString("paywall.restore.failed", comment: "Restore failed: %@"),
                reason
            )
        }
    }
}

/// First user-visible paid moment. Shows the two product cards (yearly
/// emphasized as "Best value"), an eligibility-aware CTA, restore link,
/// and fine-print legal copy.
///
/// Driven by `SubscriptionService` from the environment. On a successful
/// purchase, dismisses and calls the `onUnlocked` closure so the caller
/// can resume whatever gated action triggered the paywall.
public struct PaywallView: View {
    @Environment(SubscriptionService.self) private var subscription
    @Environment(\.dismiss) private var dismiss

    // Start with monthly; never infer a free period from a SKU name.
    @State private var selectedProductID: String = SubscriptionService.monthlyProductID
    @State private var purchaseInFlight = false
    @State private var purchaseError: String?
    @State private var errorTitleKey = "paywall.error.title"
    /// Restore progress + result (I08): a single in-flight guard shared with
    /// purchase so the two StoreKit flows can never run in parallel, and an
    /// inline status when restore finds nothing or fails.
    @State private var restoreInFlight = false
    @State private var restoreMessage: String?
    /// Whether the App Store Apple ID currently looking at this paywall is
    /// eligible for the monthly introductory offer, if that product has one.
    /// Starts `.unknown`: the trial promise is only made once StoreKit has
    /// actually answered — an optimistic claim would promise a discount that
    /// may not exist for this account (I09).
    @State private var introOfferStatus: IntroOfferStatus = .unknown

    enum IntroOfferStatus {
        case unknown
        case eligible
        case ineligible
    }

    /// Trial affordances only read `true` when eligibility is confirmed.
    private var introOfferEligible: Bool {
        introOfferStatus == .eligible && subscription.products.contains {
            $0.id == SubscriptionService.monthlyProductID && $0.subscription?.introductoryOffer != nil
        }
    }

    /// Called after a successful purchase or restore so callers can
    /// resume the action that triggered the paywall.
    var onUnlocked: () -> Void

    /// One in-flight StoreKit flow at a time (I08 + checkpoint review): the
    /// purchase CTA and restore must share a single busy condition so neither
    /// path can race or re-enter the other.
    private var isStoreBusy: Bool { purchaseInFlight || restoreInFlight }

    public init(onUnlocked: @escaping () -> Void = {}) {
        self.onUnlocked = onUnlocked
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                // Mid-trial state takes precedence: a paying-trial user
                // re-opening the paywall (from MeSheet) should see "X days
                // left" + manage, not the upsell pitch again.
                if subscription.entitlement == .proTrial {
                    midTrialBanner
                } else if introOfferEligible && selectedProductID == SubscriptionService.monthlyProductID {
                    trialBanner
                }
                bullets
                productCards
                ctaButton
                continueFreeButton
                fineprint
                actionLinks
                LegalDocumentLinks()
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.caption)
                        .foregroundStyle(CT.bannerError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(minWidth: 44, minHeight: 44)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(NSLocalizedString("paywall.close", comment: "Close paywall"))
                }
            }
        }
        .task {
            if subscription.products.isEmpty {
                await subscription.loadProducts()
            }
            // Refresh intro-offer eligibility after products are in hand.
            // Unknown stays neutral while StoreKit resolves eligibility.
            if let monthly = subscription.products.first(where: { $0.id == SubscriptionService.monthlyProductID }) {
                introOfferStatus = await subscription.isEligibleForIntroOffer(monthly) ? .eligible : .ineligible
            }
            // Make sure the mid-trial banner reads from a fresh
            // currentExpirationDate. refreshEntitlement is idempotent.
            await subscription.refreshEntitlement()
        }
        .alert(
            NSLocalizedString(errorTitleKey, comment: "Contextual plan-loading or purchase error"),
            isPresented: .constant(purchaseError != nil),
            actions: {
                Button(NSLocalizedString("common.ok", comment: "OK")) {
                    purchaseError = nil
                }
            },
            message: { Text(purchaseError ?? "") }
        )
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(CT.sunGold)
            Text(NSLocalizedString("paywall.hero.title", comment: "Unlock Roamorrow Pro"))
                .font(.title.bold())
            Text(NSLocalizedString("paywall.hero.subtitle", comment: "Subtitle"))
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    /// An offer exists and eligibility is confirmed. No free-period promise
    /// is inferred; product cards and Apple confirmation carry actual terms.
    private var trialBanner: some View {
        let amber = CT.sunGold
        let priceCopy = NSLocalizedString("paywall.offer.details", comment: "Offer details are verified in the Apple confirmation")
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.title3)
                .foregroundStyle(amber)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("paywall.offer.headline",
                                       comment: "Confirmed introductory offer exists"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(priceCopy)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(amber.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(amber.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// Status banner for users already inside the trial period — replaces
    /// the "Get 1 month free" pitch with renewal context and a manage link.
    private var midTrialBanner: some View {
        let amber = CT.sunGold
        let days = subscription.trialDaysRemaining ?? 0
        let headline: String = {
            let fmt = NSLocalizedString("paywall.midTrial.headline.format",
                                        comment: "Trial-active headline (%d days)")
            return String(format: fmt, days)
        }()
        let detail: String = {
            guard let exp = subscription.currentExpirationDate else {
                return NSLocalizedString("paywall.midTrial.detail.fallback",
                                         comment: "Trial-active detail without date")
            }
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            let fmt = NSLocalizedString("paywall.midTrial.detail.format",
                                        comment: "Trial-active detail with renewal date")
            return String(format: fmt, df.string(from: exp))
        }()
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(amber)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(amber.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 12) {
            bullet("paywall.feature.explore", icon: "sparkle.magnifyingglass")
            bullet("paywall.feature.voice", icon: "mic.fill")
            bullet("paywall.feature.insight", icon: "brain.head.profile")
            bullet("paywall.feature.quota", icon: "speedometer")
        }
    }

    private func bullet(_ key: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(CT.sunGoldDeep)
            Text(NSLocalizedString(key, comment: ""))
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var productCards: some View {
        VStack(spacing: 12) {
            if subscription.isLoading && subscription.products.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if subscription.products.isEmpty {
                Text(NSLocalizedString("paywall.products.unavailable", comment: "No plan prices are available yet"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(subscription.products, id: \.id) { product in
                    productCard(product)
                }
            }
        }
    }

    private func productCard(_ product: Product) -> some View {
        let isYearly = product.id == SubscriptionService.yearlyProductID
        let isMonthly = product.id == SubscriptionService.monthlyProductID
        let isSelected = selectedProductID == product.id
        let showTrialBadge = isMonthly && introOfferEligible && subscription.entitlement != .proTrial
        // Dark brown for badge text — same WCAG-AA-clear pairing the CTA uses
        // on the amber fill.
        let badgeText = CT.accent
        return Button {
            selectedProductID = product.id
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.headline)
                        if showTrialBadge {
                            Text(NSLocalizedString("paywall.offer.badge",
                                                   comment: "Confirmed introductory offer badge"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(CT.sunGold))
                                .foregroundStyle(badgeText)
                        } else if isYearly {
                            Text(NSLocalizedString("paywall.bestValue", comment: "Best value badge"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(CT.sunGold))
                                .foregroundStyle(badgeText)
                        }
                    }
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                    Text(periodLabel(product))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? CT.sunGold.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? CT.sunGold
                            : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        // Announce the full decision: name, price, period and whether this plan
        // is the current selection (I09).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(productAccessibilityLabel(product)))
        .accessibilityValue(Text(isSelected
            ? NSLocalizedString("paywall.plan.selected", comment: "Selected")
            : ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// "Monthly, $4.99/month" — the full plan meaning for VoiceOver, localized
    /// in EN and ZH like every other user string.
    private func productAccessibilityLabel(_ product: Product) -> String {
        String(
            format: NSLocalizedString("paywall.plan.a11y", comment: "%1$@, %2$@%3$@"),
            product.displayName,
            product.displayPrice,
            periodLabel(product)
        )
    }

    private func periodLabel(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        let value = period.value
        switch period.unit {
        case .day:
            return value == 1
                ? NSLocalizedString("paywall.period.day", comment: "/day")
                : String(format: NSLocalizedString("paywall.period.dayN", comment: "/%1$dd"), value)
        case .week:
            return value == 1
                ? NSLocalizedString("paywall.period.week", comment: "/week")
                : String(format: NSLocalizedString("paywall.period.weekN", comment: "/%1$dw"), value)
        case .month:
            return value == 1
                ? NSLocalizedString("paywall.period.month", comment: "/month")
                : String(format: NSLocalizedString("paywall.period.monthN", comment: "/%1$dm"), value)
        case .year:
            return value == 1
                ? NSLocalizedString("paywall.period.year", comment: "/year")
                : String(format: NSLocalizedString("paywall.period.yearN", comment: "/%1$dy"), value)
        @unknown default: return ""
        }
    }

    /// Offer copy requires an actual offer and confirmed eligibility.
    private var ctaTitle: String {
        if subscription.isLoading && subscription.products.isEmpty {
            return NSLocalizedString("paywall.products.loading", comment: "Plan catalog is loading")
        }
        if subscription.products.isEmpty {
            return NSLocalizedString("paywall.products.retry", comment: "Retry loading plans before subscribing")
        }
        let isMonthly = selectedProductID == SubscriptionService.monthlyProductID
        if isMonthly && introOfferEligible && subscription.entitlement != .proTrial {
            return NSLocalizedString("paywall.cta.offer",
                                     comment: "Subscribe with the verified introductory offer")
        }
        return NSLocalizedString("paywall.cta.subscribe",
                                 comment: "Plain subscribe CTA")
    }

    private var ctaButton: some View {
        // The CTA must always be tappable (except mid-purchase). Previously
        // Release builds disabled it whenever `products.isEmpty`, which made
        // the button physically un-tappable on device when App Store Connect
        // hadn't returned the catalog yet — the user got a dead button with no
        // feedback. Instead we keep it tappable and, on tap, retry the product
        // load and surface an explicit error if the catalog is still empty
        // (see `runPurchase()`).
        let isDisabled = isStoreBusy || (subscription.isLoading && subscription.products.isEmpty)
        // White text on the gold fill (#D4A843) only reaches ~2.2:1 contrast,
        // below WCAG AA (4.5:1). Use a dark brown that's harmonious with the
        // gold and clears AA comfortably (~6.4:1) for low-vision legibility.
        let ctaText = CT.accent
        return Button {
            Task { await runPurchase() }
        } label: {
            HStack {
                if purchaseInFlight {
                    ProgressView().tint(ctaText)
                } else {
                    Text(ctaTitle)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CT.sunGold)
            .foregroundStyle(ctaText)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isDisabled)
    }

    private var continueFreeButton: some View {
        Button {
            dismiss()
        } label: {
            Text(NSLocalizedString("paywall.continueFree", comment: "Continue with Free"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private var fineprint: some View {
        // A catalog/eligibility answer does not establish a free trial or
        // its duration. Only the store's actual offer/confirmation does.
        Text(NSLocalizedString("paywall.fineprint", comment: "Neutral subscription fine print"))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
    }

    private var actionLinks: some View {
        HStack(spacing: 24) {
            Button(NSLocalizedString("paywall.restore", comment: "Restore purchases")) {
                Task { await runRestore() }
            }
            .font(.caption)
            .frame(minHeight: 44)
            // One in-flight StoreKit flow at a time (I08): a second tap must
            // not race a running purchase or restore.
            .disabled(isStoreBusy)
            .opacity(isStoreBusy ? 0.5 : 1)
            .accessibilityLabel(Text(NSLocalizedString("paywall.restore.a11y", comment: "Restore purchases")))

            Spacer()

            Link(
                NSLocalizedString("paywall.manage", comment: "Manage subscription"),
                destination: URL(string: "https://apps.apple.com/account/subscriptions")!
            )
            .font(.caption)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func runPurchase() async {
        // Guard re-entry: purchase must not race a running restore or itself.
        guard !purchaseInFlight, !restoreInFlight else { return }
        errorTitleKey = "paywall.error.title"
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        // The catalog can be empty on first tap if App Store Connect was slow
        // (or the network blipped) during `.task`'s initial load. Retry once
        // before giving up so the user isn't stuck behind a transient miss.
        if subscription.products.isEmpty {
            errorTitleKey = "paywall.products.errorTitle"
            await subscription.loadProducts()
            // A retry only loads the catalog. Show its prices before a
            // separate, explicit Subscribe action can open Apple confirmation.
            if !subscription.products.isEmpty { return }
        }

        guard let product = subscription.products.first(where: { $0.id == selectedProductID })
            ?? subscription.products.first
        else {
            purchaseError = subscription.lastError
                ?? NSLocalizedString("paywall.error.unavailable", comment: "Products unavailable")
            return
        }

        let success = await subscription.purchase(product)
        if success {
            onUnlocked()
            dismiss()
        } else if let err = subscription.lastError {
            purchaseError = err
        }
    }

    private func runRestore() async {
        // Guard re-entry so restore can't fire twice or run beside a purchase.
        guard !purchaseInFlight, !restoreInFlight else { return }
        restoreInFlight = true
        restoreMessage = nil
        // The service clears prior errors before this attempt. Comparing
        // strings here would hide a repeated current failure.
        defer { restoreInFlight = false }
        let success = await subscription.restorePurchases()
        let attemptError = subscription.lastError
        let outcome = RestoreOutcome.resolve(success: success, lastError: attemptError)
        guard outcome != .unlocked else {
            onUnlocked()
            dismiss()
            return
        }
        restoreMessage = outcome.message
        #if canImport(UIKit)
        if let message = outcome.message {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        #endif
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionService())
}
