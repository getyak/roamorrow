# Life Studio review target

This offline iOS target compiles the same `SoloCompass/Views/Studio` files used by the main app. It has a separate bundle ID and local document, and explicitly unavailable map/account destinations. It never simulates backend responses.

From `apps/ios`:

```sh
xcodegen generate --spec studio-preview.yml
xcodebuild -project LifeStudioPreview.xcodeproj -scheme LifeStudioPreview \
  -destination 'generic/platform=iOS Simulator' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
```

Choose an installed iPhone simulator in Xcode to run or test. Simulator builds use ad-hoc signing; physical-device installation needs your own signing configuration. The preview supports iOS 17 and newer.

The standalone target opens Studio directly. In the main app, the continuous companion entry takes priority: set `FF_CONTINUOUS_COMPANION=false` and `FF_LIFE_STUDIO=true` for a deliberate Studio review. The Studio flag defaults to enabled only in Debug; Release keeps it disabled until the product experiment is validated.

The browser review at `docs/prototypes/life-studio/index.html` uses separate browser storage. Serve that folder locally for PNG export. It is not the native app and has no Vision extraction or travel services.
