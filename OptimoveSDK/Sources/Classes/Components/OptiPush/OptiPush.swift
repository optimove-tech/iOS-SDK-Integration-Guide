//  Copyright © 2019 Optimove. All rights reserved.

import Foundation
import UserNotifications
import OptimoveCore

final class OptiPush {

    private let registrar: Registrable
    private var storage: OptimoveStorage

    init(registrar: Registrable,
         storage: OptimoveStorage) {
        self.storage = storage
        self.registrar = registrar
        Logger.debug("OptiPush initialized.")
        registrar.retryFailedOperationsIfExist()
    }

}

extension OptiPush: Component {

    func handle(_ context: OperationContext) throws {
        switch context.operation {
        case let .deviceToken(token: token):
            storage.apnsToken = token
            registrar.handle(.setInstallation)
        case .setUserId, .optIn, .optOut:
            guard storage.apnsToken != nil else { return }
            registrar.handle(.setInstallation)
        default:
            break
        }
    }
}