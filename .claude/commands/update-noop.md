Update my local NOOP iOS build to the latest upstream, preserving my four iOS fixes.

Working dir: /Users/shehzaad/noop-ios
Branch: ios-port-v2 (a clean branch off upstream/main carrying ONLY my four fixes)

There is no longer a `fork` remote — iOS is now official in upstream/main. Only `upstream` (NoopApp/noop) and `mine` (my backup) exist.

My four fixes — the ONLY intended delta between ios-port-v2 and upstream/main:
1. Import picker (DataSourcesView.swift + OnboardingWizard.swift): presentImporter routes WHOOP/Apple Health import through `DocumentPicker.importFile([.data])` inside `#if os(iOS)`, with `showingImporter = true` only in the macOS `#else` branch. handlePickedURL validates the file (isValidFile + wrong-type alert). Upstream defines DocumentPicker.importFile but leaves it unwired — my fix wires it in.
2. Chart clipping: `.clipped()` on TrendChart's frame in Packages/StrandDesign/Sources/StrandDesign/TrendChart.swift.
3. Sessions table: horizontal ScrollView (iOS only, minWidth 644) in WorkoutsView.swift's sessions section.
4. Add-workout button: `.fixedSize(horizontal: false, vertical: true)` in WorkoutsView.swift.

Steps:
1. Ensure I'm on `ios-port-v2` with a clean working tree. If not, stop and tell me (show me any uncommitted changes).
2. `git fetch upstream`. Report upstream/main's latest version vs my current MARKETING_VERSION.
3. If upstream is not ahead, stop and say I'm already current — don't rebuild.
4. Merge `upstream/main` into ios-port-v2. Since my branch is only 4 files different from upstream, conflicts can ONLY occur in those 4 files. Resolve by keeping my fix layered on top of upstream's version of that file. If upstream renamed/refactored something my fix depends on (e.g. handlePickedURL, allowedContentTypes, DocumentPicker.importFile), adapt my fix to the new shape rather than discarding it. Show me any conflicts and how you resolved them before continuing.
5. CRITICAL — verify all four fixes survived, with proof:
   - DataSourcesView.swift + OnboardingWizard.swift: show the `#if os(iOS)` → DocumentPicker.importFile([.data]) block; confirm `showingImporter = true` is macOS-only.
   - TrendChart.swift: show the `.clipped()` line.
   - WorkoutsView.swift: show the horizontal ScrollView and the .fixedSize line.
   Confirm the diff between ios-port-v2 and upstream/main is STILL exactly these four files (plus any forced adaptation from step 4) — nothing unexpected.
6. Check whether upstream's CI-backed iOS target now handles anything my fixes addressed (e.g. if upstream finally wired DocumentPicker themselves, my import patch may be redundant — flag it, don't silently drop it). Only remove a fix if upstream genuinely superseded it, and tell me.
7. Run `xcodegen generate`, then build NOOPiOS for `generic/platform=iOS`, Release, with CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" PROVISIONING_PROFILE_SPECIFIER="". Confirm `** BUILD SUCCEEDED **`.
8. Wrap the built NOOP.app into ~/NOOP-latest.ipa via the Payload method (mkdir Payload, cp -R NOOP.app Payload/, zip -r, rm -rf Payload).
9. Commit the merge on ios-port-v2 with a message noting the new version.
10. STOP. Do not push, do not sign. Report: new version number, proof all four fixes are intact (step 5), whether upstream superseded any of them (step 6), build result, and the .ipa path. I'll sign with Signulous and test on-device myself.

Do not skip step 5 or step 10. Never use `strings` to verify — on-device behaviour is the only check that counts.
