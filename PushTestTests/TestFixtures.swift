import CryptoKit
import Foundation
@testable import PushTest

enum TestFixtures {
    static func makeCredentials(bundleID: String = "top.iyabb.PushTest") -> APNsCredentials {
        let key = P256.Signing.PrivateKey()
        return APNsCredentials(
            teamID: "TEAM123456",
            keyID: "KEY1234567",
            bundleID: bundleID,
            p8PEM: key.pemRepresentation
        )
    }

    static func makeDraft(
        event: LiveActivityEvent = .start,
        pushType: APNsPushType = .liveactivity,
        token: String = "abcd1234abcd1234abcd1234abcd1234"
    ) -> PushRequestDraft {
        PushRequestDraft(
            event: event,
            pushType: pushType,
            deviceToken: token,
            priority: 10,
            collapseID: "collapse-1",
            payloadJSON: APNsPayloadTemplates.template(pushType: pushType, event: event),
            topicOverride: nil
        )
    }
}
