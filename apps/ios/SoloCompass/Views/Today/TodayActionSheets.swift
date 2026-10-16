import SwiftUI

/// Explicit confirmation: changing a date picker never commits an assumed
/// 30-day allowance. The traveler supplies the duration they have confirmed.
struct TodayEntryDateSheet: View {
    let preferences: UserPreferences
    let onDismiss: () -> Void
    @State private var entryDate: Date
    @State private var length: String
    @State private var isSaving = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(preferences: UserPreferences, onDismiss: @escaping () -> Void) {
        self.preferences = preferences
        self.onDismiss = onDismiss
        _entryDate = State(initialValue: min(preferences.visaEntryDate ?? Date(), Date()))
        _length = State(initialValue: preferences.visaLengthDays.map(String.init) ?? "")
    }

    private var validLength: Int? {
        guard let number = Int(length), (1...365).contains(number) else { return nil }
        return number
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("cityos.visa.entryDate", comment: "Entry date"))
                            DatePicker(NSLocalizedString("cityos.visa.entryDate", comment: "Entry date"), selection: $entryDate, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                        }
                    } else {
                        DatePicker(NSLocalizedString("cityos.visa.entryDate", comment: "Entry date"), selection: $entryDate, in: ...Date(), displayedComponents: .date)
                    }
                    LabeledContent(NSLocalizedString("today.entry.days.label", comment: "Persistent stay length field label")) {
                        HStack(spacing: 8) {
                            TextField(NSLocalizedString("today.entry.days.example", comment: "Example stay length"), text: $length)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 68, maxWidth: 128, minHeight: 44)
                                .accessibilityLabel(NSLocalizedString("today.entry.days", comment: "Confirmed stay length in days"))
                            Text(NSLocalizedString("today.entry.days.unit", comment: "Days unit"))
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(NSLocalizedString("today.entry.explanation", value: "Use the stay length you have confirmed. This personal countdown does not determine visa or tax eligibility.", comment: "Countdown scope"))
                }
            }
            .disabled(isSaving)
            .navigationTitle(NSLocalizedString("today.header.setEntryDate", comment: "Set entry date"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", comment: "Cancel"), action: onDismiss).disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("action.save", value: "Save", comment: "Save")) {
                        guard let validLength, !isSaving else { return }
                        isSaving = true
                        preferences.visaLengthDays = validLength
                        preferences.visaEntryDate = entryDate
                        Task {
                            // Keep an enabled reminder aligned with the new dates;
                            // this never asks for fresh notification permission.
                            await ComplianceService(preferences: preferences).syncVisaReminder()
                            isSaving = false
                            onDismiss()
                        }
                    }
                    .disabled(validLength == nil || isSaving)
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}

/// A sealed receipt shows metadata without unwrapping content ahead of time.
struct TodayCapsuleReceiptDetail: View {
    let capsule: TimeCapsule
    let onDismiss: () -> Void
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(NSLocalizedString("today.seal.yesterdayTitle", comment: "Sealed moment"), systemImage: "archivebox.fill")
                    LabeledContent(NSLocalizedString("today.receipt.saved", value: "Sealed", comment: "Sealed date")) {
                        Text(capsule.createdAt, format: .dateTime.year().month().day())
                    }
                    LabeledContent(NSLocalizedString("today.receipt.return", value: "Ready from", comment: "Earliest eligible return date")) {
                        Text(capsule.scheduledFor, format: .dateTime.year().month().day())
                    }
                } footer: {
                    Text(NSLocalizedString("today.receipt.explanation", value: "Your moment stays sealed here. After the date above, return near the original place to let it resurface.", comment: "Receipt does not open capsule"))
                }
            }
            .navigationTitle(NSLocalizedString("today.receipt.title", value: "Sealed receipt", comment: "Capsule metadata"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.done", comment: "Done"), action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
