# Life Studio review target

This offline iOS target compiles the same `SoloCompass/Views/Studio` files used by the main app. It has a separate bundle ID and local document, and explicitly unavailable map/account destinations. It never simulates backend responses.

For a local run, start from `apps/ios`. The shared helper selects the allowlisted
Primary iPhone and owns the same device for the build, unit tests, and UI test.
Check resource pressure first; defer the native run when another task owns the
device or the host cannot afford a build.

```sh
dev-storage-guard audit
dev-storage-guard resources
export SC_PREVIEW_ARTIFACT="$(dev-storage-guard new-artifact roamorrow-preview677)"
xcodegen generate --spec studio-preview.yml
dev-ios-session run -- bash -euo pipefail -c '
  : "${IOS_SIMULATOR_ID:?dev-ios-session must select the allowlisted device}"
  preview_args=(
    -project LifeStudioPreview.xcodeproj -scheme LifeStudioPreview
    -configuration Debug
    -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID"
    -derivedDataPath "$SC_PREVIEW_ARTIFACT/DerivedData"
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
  )
  xcodebuild build-for-testing "${preview_args[@]}"
  xcodebuild test-without-building "${preview_args[@]}" \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
    -only-testing:LifeStudioPreviewTests \
    -resultBundlePath "$SC_PREVIEW_ARTIFACT/UnitTests.xcresult"
  xcodebuild test-without-building "${preview_args[@]}" \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
    -only-testing:LifeStudioPreviewUITests \
    -resultBundlePath "$SC_PREVIEW_ARTIFACT/UITests.xcresult"
'
```

Preserve the logs, screenshots, and both result bundles as delivery evidence,
then remove only this registered local artifact with
`dev-storage-guard remove-artifact "$SC_PREVIEW_ARTIFACT"`. Keep the worktree and
existing simulator data. The helper releases its session and shuts down only a
device it booted; do not select an arbitrary booted device or erase shared data.
The UI test edits the standalone preview's local composition, so preserve an
earlier preview document before testing on a reused device. The preview supports
iOS 17 and newer; the commands above use unsigned Simulator builds.

`.github/workflows/studio-preview-ci.yml` separately generates and compiles this
project, then runs `LifeStudioPreviewTests` and `LifeStudioPreviewUITests` on one
available iPhone in a fresh macOS runner. Result bundles must show at least four
passing unit tests and one passing UI test, with no failures, skips, or expected
failures; an empty suite cannot satisfy the job. It triggers for the preview target,
shared Studio sources/resources, and its CI/selector inputs. It uses no account,
signing credentials, archive, or TestFlight/App Store upload step. A green SoloCompass job alone does
not establish that these separate targets compile or that their tests ran.

The standalone target opens Studio directly. In the main app, the continuous companion entry takes priority: set `FF_CONTINUOUS_COMPANION=false` and `FF_LIFE_STUDIO=true` for a deliberate Studio review. The Studio flag defaults to enabled only in Debug; Release keeps it disabled until the product experiment is validated.

The browser review at `docs/prototypes/life-studio/index.html` uses separate browser storage. Serve that folder locally for PNG export. It is not the native app and has no Vision extraction or travel services.
