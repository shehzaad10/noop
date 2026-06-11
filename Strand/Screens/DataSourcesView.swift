import SwiftUI
import UniformTypeIdentifiers
import StrandDesign

struct DataSourcesView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var repo: Repository
    @EnvironmentObject var live: LiveState
    @State private var showingImporter = false
    @State private var importTarget: ImportTarget = .whoop
    @State private var fileTypeError: String? = nil

    var body: some View {
        ScreenScaffold(title: "Data Sources",
                       subtitle: "Everything stays on this Mac. Bring your history in once, then it's yours.") {
            whoopCard
            appleHealthCard
            liveCard
        }
        // macOS: .fileImporter with UTI types works correctly here.
        // iOS: SwiftUI's .fileImporter bridges through a broken UTI-translation layer that greys
        //      out zips even with [.item]. On iOS, presentImporter() calls DocumentPicker.importFile
        //      directly (UIKit, no SwiftUI wrapper) so this modifier is never triggered there.
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: importTarget.allowedContentTypes,
                      allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            handlePickedURL(url, for: importTarget)
        }
        .alert("Wrong file type", isPresented: .init(
            get: { fileTypeError != nil },
            set: { if !$0 { fileTypeError = nil } }
        )) {
            Button("OK", role: .cancel) { fileTypeError = nil }
        } message: {
            if let msg = fileTypeError { Text(msg) }
        }
    }

    private var whoopCard: some View {
        card(title: "WHOOP Export", icon: "square.and.arrow.down.fill",
             subtitle: "Import your full WHOOP history — recovery, strain, sleep, workouts — from a data export (.zip). Works for WHOOP 4.0, 5.0 and MG. Get one at app.whoop.com → Data Management.") {
            let importingWhoop = model.isImporting(.whoop)
            HStack(spacing: 12) {
                Button {
                    presentImporter(.whoop)
                } label: {
                    Label(importingWhoop ? "Importing…" : "Choose export…",
                          systemImage: "tray.and.arrow.down")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(StrandPalette.accent)
                .disabled(model.hasActiveImport)
                if importingWhoop { ProgressView().controlSize(.small) }
            }
            if let s = model.whoopImportSummary {
                Text(s).font(StrandFont.subhead)
                    .foregroundStyle(model.whoopImportFailed ? StrandPalette.statusWarning : StrandPalette.statusPositive)
            }
            Text("\(repo.days.count) days · \(repo.sleeps.count) sleeps stored")
                .font(StrandFont.footnote).foregroundStyle(StrandPalette.textTertiary)
        }
    }

    private var appleHealthCard: some View {
        card(title: "Apple Health", icon: "heart.fill",
             subtitle: "Import an Apple Health export (Health app → profile → Export All Health Data → export.zip). 7 years of HR, HRV, sleep, SpO₂, steps and more — streamed locally. Large exports take a minute or two.") {
            let importingAppleHealth = model.isImporting(.appleHealth)
            HStack(spacing: 12) {
                Button { presentImporter(.appleHealth) } label: {
                    Label(importingAppleHealth ? "Working…" : "Choose export.zip…", systemImage: "tray.and.arrow.down")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent).tint(StrandPalette.accent)
                .disabled(model.hasActiveImport)
                if importingAppleHealth { ProgressView().controlSize(.small) }
            }
            if let s = model.appleHealthImportSummary {
                Text(s).font(StrandFont.subhead)
                    .foregroundStyle(model.appleHealthImportFailed ? StrandPalette.statusWarning : StrandPalette.statusPositive)
            }
        }
    }

    private func presentImporter(_ target: ImportTarget) {
        importTarget = target
        #if os(iOS)
        // UIDocumentPickerViewController via DocumentPicker.importFile reliably shows all files.
        // SwiftUI's .fileImporter is skipped on iOS; showingImporter is never set to true here.
        Task { @MainActor in
            guard let url = await DocumentPicker.importFile([.data]) else { return }
            handlePickedURL(url, for: target)
        }
        #else
        showingImporter = true
        #endif
    }

    private func handlePickedURL(_ url: URL, for target: ImportTarget) {
        guard target.isValidFile(url) else {
            fileTypeError = "Please choose a \(target.validExtensionHint) file."
            return
        }
        switch target {
        case .whoop:
            model.importWhoop(url: url)
        case .appleHealth:
            model.importAppleHealth(url: url)
        }
    }

    private enum ImportTarget {
        case whoop
        case appleHealth

        // macOS only — .fileImporter with these UTIs works correctly on macOS.
        // iOS uses DocumentPicker.importFile([.data]) directly; this property is unused there.
        var allowedContentTypes: [UTType] {
            switch self {
            case .whoop:       return [.zip, .folder]
            case .appleHealth: return [.zip, .xml, .folder]
            }
        }

        func isValidFile(_ url: URL) -> Bool {
            let ext = url.pathExtension.lowercased()
            switch self {
            case .whoop:       return ext == "zip" || url.hasDirectoryPath
            case .appleHealth: return ext == "zip" || ext == "xml" || url.hasDirectoryPath
            }
        }

        var validExtensionHint: String {
            switch self {
            case .whoop:       return ".zip"
            case .appleHealth: return ".zip or .xml"
            }
        }
    }
    private var liveCard: some View {
        card(title: "WHOOP Strap (Live BLE)", icon: "antenna.radiowaves.left.and.right",
             subtitle: "Pairs directly with your strap over Bluetooth — no WHOOP app, no cloud.") {
            HStack(spacing: 8) {
                // Three-state, consistent with the Live screen's connection pill — a connected-but-
                // not-yet-streaming strap (e.g. an experimental WHOOP 5/MG link) no longer reads as
                // "Not connected" on one screen and "Connected" on another (issue #8).
                let (dot, label): (Color, String) =
                    live.bonded ? (StrandPalette.statusPositive, "Bonded — streaming.")
                    : live.connected ? (StrandPalette.statusWarning, "Connected.")
                    : (StrandPalette.statusCritical, "Not connected — open Live to pair.")
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(label).font(StrandFont.subhead).foregroundStyle(StrandPalette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func card<C: View>(title: String, icon: String, subtitle: String,
                              @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(StrandPalette.accent)
                Text(title).font(StrandFont.headline).foregroundStyle(StrandPalette.textPrimary)
            }
            Text(subtitle).font(StrandFont.subhead).foregroundStyle(StrandPalette.textSecondary)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(StrandPalette.hairline))
    }
}
