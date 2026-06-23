import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var config: HotTubConfig
    @EnvironmentObject private var purchases: PurchaseStore
    @EnvironmentObject private var entitlement: Entitlement
    @State private var volumeText: String = ""
    @State private var suppressNextSave: Bool = false
    @State private var showPaywall: Bool = false
    @FocusState private var volumeFocused: Bool

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section {
                if purchases.isPro {
                    HStack {
                        Label(String(localized: "Soak Pro"), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Text(String(localized: "Unlocked")).foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Label(String(localized: "Unlock Soak Pro"), systemImage: "lock.open")
                            Spacer()
                            Text(purchases.priceText ?? "$3.99").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("UnlockSoakPro")
                    Button(String(localized: "Restore Purchases")) {
                        Task { await purchases.restore() }
                    }
                }
            } header: {
                SectionHeaderLabel(String(localized: "Soak Pro"))
            } footer: {
                if !purchases.isPro {
                    Text(entitlement.trial.isActive
                         ? String(localized: "Your free trial is active. Unlock Soak Pro any time — one-time purchase, no subscription.")
                         : String(localized: "One-time purchase. No subscription, no ads."))
                }
            }

            Section {
                Picker("Units", selection: $config.useMetric) {
                    Text("Metric").tag(true)
                    Text("Imperial").tag(false)
                }
            }

            Section {
                HStack {
                    Text("Volume")
                    Spacer()
                    NumericTextField(text: $volumeText, allowDecimal: false)
                        .focused($volumeFocused)
                        .foregroundStyle(volumeFocused ? Color.primary : Color.accentColor)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onAppear { syncVolumeText() }
                        .onChange(of: volumeText) { _, newValue in
                            if suppressNextSave {
                                suppressNextSave = false
                                return
                            }
                            if let gallons = VolumeUnit.parseGallons(newValue, metric: config.useMetric),
                               VolumeUnit.isValidGallons(gallons) {
                                config.gallons = gallons
                            }
                        }
                        .onChange(of: config.useMetric) { _, _ in
                            if !volumeFocused { syncVolumeText() }
                        }
                    Text(LocalizedStringKey(config.useMetric ? "liters" : "gallons"))
                        .foregroundStyle(.secondary)
                }
                Picker("Sanitizer", selection: $config.sanitizer) {
                    ForEach(Sanitizer.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                SectionHeaderLabel(String(localized: "Your hot tub"))
            }

            Section {
                if config.sanitizer == .chlorine {
                    Picker("Chlorine product", selection: $config.preferredChlorineProduct) {
                        ForEach(ChlorineProduct.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Picker("pH lowerer", selection: $config.preferredPHLowerer) {
                    ForEach(PHLowerer.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                SectionHeaderLabel(String(localized: "Preferred chemicals"))
            }

            Section {
                LinkRow(title: String(localized: "Privacy policy"),
                        url: URL(string: "https://daria-kopaliani.github.io/moondog/hottub/privacy.html")!)
                LinkRow(title: String(localized: "Support"),
                        url: URL(string: "https://daria-kopaliani.github.io/moondog/hottub/support.html")!)
                Link(destination: URL(string: "https://apps.apple.com/app/id6775030424?action=write-review")!) {
                    Label(String(localized: "Rate Soak"), systemImage: "star")
                }
            } footer: {
                Text("v\(appVersion)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.footnote)
                    .padding(.top, 8)
            }
        }
        .headerProminence(.increased)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) { PaywallSheet() }
    }

    private func syncVolumeText() {
        let newText = VolumeUnit.displayValue(gallons: config.gallons, metric: config.useMetric)
        if newText != volumeText {
            suppressNextSave = true
            volumeText = newText
        }
    }
}

private struct LinkRow: View {
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let purchases = PurchaseStore()
    let trial = TrialState()
    return NavigationStack { SettingsView() }
        .environmentObject(HotTubConfig())
        .environmentObject(purchases)
        .environmentObject(trial)
        .environmentObject(Entitlement(purchases: purchases, trial: trial))
}
