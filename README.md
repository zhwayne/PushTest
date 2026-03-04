# PushTest

PushTest is a macOS SwiftUI app for sending Apple Push Notification service (APNs) requests using token-based authentication (`.p8`), with payload templates and a local request history.

## Features

- Send APNs requests to **Sandbox** or **Production**
- Supports `apns-push-type`: `alert`, `background`, `liveactivity`
- Built-in JSON editor (auto-indent, formatting, syntax highlighting)
- Built-in payload templates:
  - Alert
  - Background (`content-available`)
  - Live Activity (`start` / `update` / `end`)
- Shows APNs response: status code, `apns-id`, reason/body, latency
- History (SwiftData): replay, copy a cURL template, search/filter, detail window

## Requirements

- macOS 15.6+ (current project deployment target)
- Xcode with SwiftUI + SwiftData support
- Apple Developer account access to create an APNs Auth Key (`.p8`)

## Run

1. Open `PushTest.xcodeproj` in Xcode.
2. Resolve Swift Package dependencies (syntax highlighting uses `Highlightr`).
3. Select scheme `PushTest` and Run.

Optional CLI build:

```bash
xcodebuild -project PushTest.xcodeproj -scheme PushTest build
```

## Quick Start (Send a Push)

1. In **Credentials**, fill:
   - Team ID
   - Key ID (auto-filled if the `.p8` filename contains it, e.g. `AuthKey_ABC123DEFG.p8`)
   - Bundle ID (of the receiving iOS app)
   - Import P8
2. In **Target**, choose:
   - Environment: Sandbox / Production
   - Push Type: Alert / Background / Live Activity
   - Event (Live Activity only): Start / Update / End
3. Paste the target token into **Push Token**.
4. (Optional) adjust Priority / Collapse ID / Topic Override.
5. Edit payload JSON, then click **Validate** and **Send Push**.

## Environment, Push Type, and Topic

- Hosts:
  - Sandbox: `api.sandbox.push.apple.com`
  - Production: `api.push.apple.com`
- Default topic:
  - `alert`, `background`: `<BundleID>`
  - `liveactivity`: `<BundleID>.push-type.liveactivity`
- You can override the topic in the UI if needed.

## Getting Tokens

This app does not generate tokens. You must obtain them from the receiving iOS app running on a real device.

### Device Token (Remote Notifications)

Example (UIKit):

```swift
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            guard granted, error == nil else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs device token:", hex)
    }
}
```

Paste the printed hex string into PushTest's **Push Token** field.

### Live Activity Push Token

Live Activity pushes require a different token than the normal device token. You must request a Live Activity with push token support in your iOS app and then read `pushTokenUpdates`.

Example (ActivityKit, iOS 16.1+):

```swift
import ActivityKit

@available(iOS 16.1, *)
func startActivityAndPrintPushToken() async {
    let attributes = LiveActivityAttributes(id: "sample-id")
    let state = LiveActivityAttributes.ContentState(status: "started", progress: 0)

    do {
        // iOS 17+: request(attributes:content:pushType:)
        // iOS 16.1: request(attributes:contentState:pushType:)
        let activity = try Activity<LiveActivityAttributes>.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil),
            pushType: .token
        )

        for await tokenData in activity.pushTokenUpdates {
            let hex = tokenData.map { String(format: "%02x", $0) }.joined()
            print("Live Activity push token:", hex)
        }
    } catch {
        print("Failed to request activity:", error)
    }
}
```

In PushTest, set `Push Type = Live Activity` and paste the Live Activity push token into **Push Token**.

## Notes

- Priority:
  - `10` is typically used for user-visible alerts
  - `5` is typically used for background-style pushes (and is often preferred for Live Activity updates)
- The generated cURL in History is a template and uses `authorization: bearer <JWT>` as a placeholder.

## Security / Privacy Notes

- The imported `.p8` key is stored in memory only and is cleared when the app exits or when you tap **Clear Credentials**.
- History is persisted locally via SwiftData and includes full token values (for replay), payload JSON, and APNs response bodies.
  - The History UI shows a masked token, but the underlying stored record includes the full token.
- If you use real production tokens, consider clearing history before sharing the machine or app data.

## Troubleshooting

- `403 Forbidden` / `InvalidProviderToken`: verify Team ID, Key ID, and that the `.p8` is an APNs Auth Key with APNs enabled.
- `BadDeviceToken`: token/environment mismatch (Sandbox vs Production), or using a device token where a Live Activity token is required.
- Live Activity requests failing: ensure:
  - `apns-push-type: liveactivity`
  - topic is `<BundleID>.push-type.liveactivity`
- Payload validation: use **Apply Template** and **Format JSON**.

## Contributing

Issues and pull requests are welcome.

## License

GPL-3.0-only. See `LICENSE`.
