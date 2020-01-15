//  Copyright © 2019 Optimove. All rights reserved.

import XCTest
import OptimoveCore
@testable import OptimoveSDK

class RegistrarTests: OptimoveTestCase {

    var registrable: Registrable!
    var networking: MockRegistrarNetworking!
    var modelFactory: ApiPayloadBuilder!

    override func setUp() {
        super.setUp()
        networking = MockRegistrarNetworking()
        modelFactory = ApiPayloadBuilder(
            storage: storage,
            deviceID: SDKDevice.uuid,
            appNamespace: try! Bundle.getApplicationNameSpace()
        )
        registrable = Registrar(
            storage: storage,
            networking: networking
        )
    }

    func test_handle_add_user_as_visitor() {
        // given
        prefillStorageAsVisitor()

        // then
        let networkExpectation = expectation(description: "Request was not generated.")
        networking.assertFunction = { (operation) in
            XCTAssert(operation == .setUser)
            networkExpectation.fulfill()
            return .success("")
        }

        // and
        let successFlagExpectation = expectation(description: "Success flag was not updated.")
        storage.assertFunction = { (value: Any?, key: StorageKey) -> Void in
            if key == .settingUserSuccess {
                XCTAssert(value as? Bool == true)
                successFlagExpectation.fulfill()
            }
        }

        // when
        registrable.handle(.setUser)
        wait(for: [networkExpectation, successFlagExpectation], timeout: defaultTimeout)
    }

    func test_handle_add_user_as_customer() {
        // given
        prefillStorageAsCustomer()

        // then
        let networkExpectation = expectation(description: "Request was not generated.")
        networking.assertFunction = { (operation) in
            XCTAssert(operation == .setUser)
            networkExpectation.fulfill()
            return .success("")
        }

        // and
        let successFlagExpectation = expectation(description: "Success flag was not updated.")
        storage.assertFunction = { (value: Any?, key: StorageKey) -> Void in
            if key == .settingUserSuccess {
                XCTAssert(value as? Bool == true)
                successFlagExpectation.fulfill()
            }
        }

        // when
        registrable.handle(.setUser)
        wait(for: [networkExpectation, successFlagExpectation], timeout: defaultTimeout)
    }

    func test_handle_failure() {
        // given
        prefillStorageAsCustomer()

        // then
        let networkExpectation = expectation(description: "Request was not generated.")
        networking.assertFunction = { (operation) in
            XCTAssert(operation == .setUser)
            networkExpectation.fulfill()
            return .failure(StubError.test)
        }

        // and
        let successFlagExpectation = expectation(description: "Success flag was not updated.")
        storage.assertFunction = { (value: Any?, key: StorageKey) -> Void in
            if key == .settingUserSuccess {
                XCTAssert(value as? Bool == false)
                successFlagExpectation.fulfill()
            }
        }

        // when
        registrable.handle(.setUser)
        wait(for: [networkExpectation, successFlagExpectation], timeout: defaultTimeout)
    }

    func test_retry_add_user() {
        // given
        prefillStorageAsCustomer()
        storage.isSettingUserSuccess = false

        // then
        let networkExpectation = expectation(description: "Request was not generated.")
        networking.assertFunction = { (operation) in
            XCTAssert(operation == .setUser)
            networkExpectation.fulfill()
            return .success("")
        }

        // and
        let successFlagExpectation = expectation(description: "Success flag was not updated.")
        storage.assertFunction = { (value: Any?, key: StorageKey) -> Void in
            if key == .settingUserSuccess {
                XCTAssert(value as? Bool == true)
                successFlagExpectation.fulfill()
            }
        }

        // when
        try! registrable.retryFailedOperationsIfExist()
        wait(for: [networkExpectation, successFlagExpectation], timeout: defaultTimeout)
    }

    func test_retry_migrate_user() {
        // given
        prefillStorageAsCustomer()
        storage.isAddingUserAliasSuccess = false
        storage.failedCustomerIDs = ["a"]

        // then
        let networkExpectation = expectation(description: "Request was not generated.")
        networking.assertFunction = { (operation) in
            XCTAssertEqual(operation, .addUserAlias)
            networkExpectation.fulfill()
            return .success("")
        }

        // and
        let successFlagExpectation = expectation(description: "Success flag was not updated.")
        let failedCustomeerIDsExpectation = expectation(description: "Failed CustomerIDs was not updated.")
        storage.assertFunction = { (value: Any?, key: StorageKey) -> Void in
            if key == .addingUserAliasSuccess {
                XCTAssert(value as? Bool == true)
                successFlagExpectation.fulfill()
            }
            if key == .failedCustomerIDs {
                XCTAssertEqual(try! JSONDecoder().decode(Set<String>.self, from: value as! Data), Set<String>([]))
                failedCustomeerIDsExpectation.fulfill()
            }
        }

        // when
        try! registrable.retryFailedOperationsIfExist()
        wait(
            for:
            [
                networkExpectation,
                successFlagExpectation,
                failedCustomeerIDsExpectation
            ],
            timeout: defaultTimeout
        )
    }
}
