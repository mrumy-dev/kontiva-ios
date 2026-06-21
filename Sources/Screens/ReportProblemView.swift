import SwiftUI
import UIKit
import KontivaCore

/// Problem melden: compose a redacted, copy-to-clipboard bug report — fully local,
/// no network. Pushed inside the "Mehr" tab's navigation stack.
struct ReportProblemView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    @State private var summary = ""
    @State private var expected = ""
    @State private var actual = ""
    @State private var steps = ""
    @State private var area: ReportArea = .overview
    @State private var composed: String?
    @State private var copied = false

    private var canCompose: Bool { !summary.isEmpty }

    var body: some View {
        Form {
            Section {
                Picker(loc(.reportArea), selection: $area) {
                    ForEach(ReportArea.allCases) { Text(loc($0.titleKey)).tag($0) }
                }
                field(loc(.reportSummary), text: $summary)
                field(loc(.reportExpected), text: $expected)
                field(loc(.reportActual), text: $actual)
                field(loc(.reportSteps), text: $steps)
            } footer: {
                Text(loc(.reportRedactionNote))
            }

            Section {
                Button(loc(.commonDone)) { compose() }
                    .disabled(!canCompose)
            } footer: {
                Text(loc(.reportCopyHint))
            }

            if let composed {
                Section(loc(.reportTitle)) {
                    Text(composed)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        UIPasteboard.general.string = composed
                        copied = true
                    } label: {
                        Label(copied ? loc(.commonDone) : loc(.commonCopy),
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
        .tint(KontivaTheme.accent)
        .navigationTitle(loc(.reportTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: KontivaTheme.Space.xxs) {
            Text(label).font(.caption).foregroundStyle(KontivaTheme.textSecondary)
            TextField(label, text: text, axis: .vertical).lineLimit(1...4)
        }
    }

    private func compose() {
        let report = BugReport(
            summary: summary, expectedBehavior: expected,
            actualBehavior: actual, reproductionSteps: steps,
            appVersion: AppInfo.version,
            macOSVersion: AppInfo.systemVersion,
            appLanguage: model.settings.language.rawValue,
            selectedArea: loc(area.titleKey))
        composed = report.composeRedacted()
        copied = false
    }
}

/// The app areas offered in the report's "where" picker (iOS has no shared AppSection).
private enum ReportArea: String, CaseIterable, Identifiable {
    case overview, planning, bills, sparen, schulden, insights, settings
    var id: String { rawValue }
    var titleKey: L10nKey {
        switch self {
        case .overview: return .overviewTitle
        case .planning: return .planningTitle
        case .bills:    return .billsTitle
        case .sparen:   return .navSparen
        case .schulden: return .navSchulden
        case .insights: return .navInsights
        case .settings: return .navSettings
        }
    }
}

enum AppInfo {
    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.1"
    }
    static var systemVersion: String { "iOS \(UIDevice.current.systemVersion)" }
}
