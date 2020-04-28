//  Copyright © 2019 Optimove. All rights reserved.

import Foundation
import os.log
import OptimoveCore

internal final class NotificationDeliveryReporter: AsyncOperation {

    private let bundleIdentifier: String
    private let notificationPayload: NotificationPayload
    private let networking: OptistreamNetworking
    private let builder: OptistreamEventBuilder

    init(bundleIdentifier: String,
         notificationPayload: NotificationPayload,
         networking: OptistreamNetworking,
         builder: OptistreamEventBuilder) {
        self.bundleIdentifier = bundleIdentifier
        self.notificationPayload = notificationPayload
        self.networking = networking
        self.builder = builder
    }

    override func main() {
        state = .executing
        do {
            let timestamp = Date()
            switch notificationPayload.campaign {
            case let campaign as ScheduledNotificationCampaign:
                try report(
                    ScheduledNotificationDelivered(
                        bundleId: bundleIdentifier,
                        campaign: campaign,
                        timestamp: timestamp
                    )
                )
            case let campaign as TriggeredNotificationCampaign:
                try report(
                    TriggeredNotificationRecieved(
                        bundleId: bundleIdentifier,
                        campaign: campaign,
                        timestamp: timestamp
                    )
                )
            default:
                os_log("Unrecognized campaign type.", log: OSLog.reporter, type: .error)
                state = .finished
            }
        } catch {
            os_log("Error: %{public}@", log: OSLog.reporter, type: .error, error.localizedDescription)
            state = .finished
        }
    }

    private func report(_ event: Event) throws {
        let optistreamEvent = try builder.build(event: event)
        networking.send(event: optistreamEvent) { [unowned self] (result) in
            switch result {
            case .success(let response):
                os_log("Delivery reported %{public}@", log: OSLog.reporter, type: .info, response.status)
            case .failure(let error):
                os_log("Error: %{public}@", log: OSLog.reporter, type: .error, error.localizedDescription)
            }
            self.state = .finished
        }
    }
}

extension OSLog {
    static let reporter = OSLog(subsystem: subsystem, category: "reporter")
}
