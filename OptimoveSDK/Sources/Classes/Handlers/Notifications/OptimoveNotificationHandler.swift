//  Copyright © 2019 Optimove. All rights reserved.

import UIKit
import UserNotifications
import os.log
import OptimoveCore

final class OptimoveNotificationHandler {

    private let synchronizer: Synchronizer
    private let deeplinkService: DeeplinkService

    init(synchronizer: Synchronizer,
         deeplinkService: DeeplinkService) {
        self.synchronizer = synchronizer
        self.deeplinkService = deeplinkService
    }
}

// MARK: - Private Methods
private extension OptimoveNotificationHandler {

    func reportNotification(response: UNNotificationResponse) {
        Logger.info("User react '\(response.actionIdentifier)' to a notification.")
        do {
            let event = try createEvent(from: response)
            let task = UIApplication.shared.beginBackgroundTask(withName: "com.optimove.sdk")
            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                synchronizer.handle(.report(event: event))
                let delay: TimeInterval = min(UIApplication.shared.backgroundTimeRemaining, 2.0)
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    UIApplication.shared.endBackgroundTask(task)
                }
            default:
                UIApplication.shared.endBackgroundTask(task)
            }
        } catch {
            Logger.error(error.localizedDescription)
        }
    }

    func createEvent(from response: UNNotificationResponse) throws -> Event {
        let notificationDetails = response.notification.request.content.userInfo
        let data = try JSONSerialization.data(withJSONObject: notificationDetails)
        let notification = try JSONDecoder().decode(NotificationPayload.self, from: data)
        guard let campaign = notification.campaign else {
            throw GuardError.custom(
                """
                The campaign of type is not supported.
                Probably this is a test notification.
                """
            )
        }
        return NotificationOpenedEvent(
            bundleIdentifier: try Bundle.getApplicationNameSpace(),
            notificationType: campaign.type,
            pushMetadata: campaign.pushMetadata
        )
    }

    func handleDeepLinkDelegation(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        guard let dynamicLink = userInfo[OptimoveKeys.Notification.dynamicLink.rawValue] as? String else {
            Logger.debug("Notification does not contain a dynamic link.")
            return
        }
        do {
            let urlComp = try unwrap(URLComponents(string: dynamicLink))
            let params: [String: String]? = urlComp.queryItems?.reduce(into: [String: String](), { (result, next) in
                result.updateValue(next.value ?? "", forKey: next.name)
            })
            // The dropFirst() is to eliminate the "/" prefix of the path
            let screenName = String(urlComp.path.dropFirst())
            Logger.debug("Sending a deeplink with screenName: \(screenName) and params: \(String(describing: params))")
            deeplinkService.setDeepLinkComponents(
                OptimoveDeepLinkComponents(
                    screenName: screenName,
                    parameters: params
                )
            )
        } catch {
            Logger.error(error.localizedDescription)
        }
    }

}

extension OptimoveNotificationHandler: OptimoveNotificationHandling {

    func isOptipush(notification: UNNotification) -> Bool {
        return notification.request.content.userInfo[OptimoveKeys.Notification.isOptipush.rawValue] as? String == "true"
    }

    func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        didComplete: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        didComplete(.noData)
    }

    func willPresent(
        notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
        completionHandler([.alert, .sound, .badge])
    }

    func didReceive(
        response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        reportNotification(response: response)
        if isNotificationOpened(response: response) {
            handleDeepLinkDelegation(response)
        }
        completionHandler()
    }
}

// MARK: - Helper methods
extension OptimoveNotificationHandler {
    private func isNotificationOpened(response: UNNotificationResponse) -> Bool {
        return response.actionIdentifier == UNNotificationDefaultActionIdentifier
    }
}
