//
//  RootTests.swift
//  Authenticator
//
//  Copyright (c) 2017 Authenticator authors
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import XCTest
@testable import Authenticator

class RootTests: XCTestCase {
    let displayTime = DisplayTime(date: Date())

    func testShowBackupInfo() {
        var root = Root(deviceCanScan: false)

        // Ensure there is no modal visible.
        let firstViewModel = root.viewModel(for: [], at: displayTime)
        guard case .none = firstViewModel.modal else {
            XCTFail("Expected .none, got \(firstViewModel.modal)")
            return
        }

        // Show the backup info.
        let showAction: Root.Action = .tokenListAction(.showBackupInfo)
        let showEffect: Root.Effect?
        do {
            showEffect = try root.update(showAction)
        } catch {
            XCTFail("Unexpected error: \(error)")
            return
        }
        XCTAssertNil(showEffect)

        // Ensure the backup info modal is visible.
        let secondViewModel = root.viewModel(for: [], at: displayTime)
        switch secondViewModel.modal {
        case .info(_, .some(let infoViewModel)):
            XCTAssert(infoViewModel.title == "Backups")
        default:
            XCTFail("Expected Backups .info, got \(secondViewModel.modal)")
        }

        // Hide the backup info.
        let hideAction: Root.Action = .infoEffect(.done)
        let hideEffect: Root.Effect?
        do {
            hideEffect = try root.update(hideAction)
        } catch {
            XCTFail("Unexpected error: \(error)")
            return
        }
        XCTAssertNil(hideEffect)

        // Ensure the backup info modal no longer visible.
        let thirdViewModel = root.viewModel(for: [], at: displayTime)
        guard case .none = thirdViewModel.modal else {
            XCTFail("Expected .none, got \(thirdViewModel.modal)")
            return
        }
    }

    func testShowLicenseInfo() {
        var root = Root(deviceCanScan: false)

        // Ensure there is no modal visible.
        let firstViewModel = root.viewModel(for: [], at: displayTime)
        guard case .none = firstViewModel.modal else {
            XCTFail("Expected .none, got \(firstViewModel.modal)")
            return
        }

        // Show the info list.
        let showInfoAction: Root.Action = .tokenListAction(.showInfo)
        let showInfoEffect: Root.Effect?
        do {
            showInfoEffect = try root.update(showInfoAction)
        } catch {
            XCTFail("Unexpected error: \(error)")
            return
        }
        XCTAssertNil(showInfoEffect)

        // Ensure the info list modal is visible.
        let nextViewModel = root.viewModel(for: [], at: displayTime)
        guard case .info(_, .none) = nextViewModel.modal else {
            XCTFail("Expected .info list, got \(nextViewModel.modal)")
            return
        }

        // Show the license info.
        let showAction: Root.Action = .infoListEffect(.showLicenseInfo)
        let showEffect: Root.Effect?
        do {
            showEffect = try root.update(showAction)
        } catch {
            XCTFail("Unexpected error: \(error)")
            return
        }
        XCTAssertNil(showEffect)

        // Ensure the license info modal is visible.
        let secondViewModel = root.viewModel(for: [], at: displayTime)
        switch secondViewModel.modal {
        case .info(_, .some(let infoViewModel)):
            XCTAssert(infoViewModel.title == "Acknowledgements")
        default:
            XCTFail("Expected Acknowledgements .info, got \(secondViewModel.modal)")
        }

        // Hide the license info.
        let hideAction: Root.Action = .infoEffect(.done)
        let hideEffect: Root.Effect?
        do {
            hideEffect = try root.update(hideAction)
        } catch {
            XCTFail("Unexpected error: \(error)")
            return
        }
        XCTAssertNil(hideEffect)

        // Ensure the license info modal no longer visible.
        let thirdViewModel = root.viewModel(for: [], at: displayTime)
        guard case .none = thirdViewModel.modal else {
            XCTFail("Expected .none, got \(thirdViewModel.modal)")
            return
        }
    }

    func testOpenURL() {
        var root = Root(deviceCanScan: false)

        guard let url = URL(string: "https://example.com") else {
            XCTFail("Failed to initialize URL.")
            return
        }

        let action: Root.Action = .infoEffect(.openURL(url))
        let effect: Root.Effect?
        do {
            effect = try root.update(action)
        } catch {
            XCTFail("Unexpected error: \(error)")
            return
        }

        guard case .some(.openURL(url)) = effect else {
            XCTFail("Expected .openURL(\(url)), got \(String(describing: effect))")
            return
        }
    }

    func testEventAddTokenFailed() {
        var root = Root(deviceCanScan: false)
        let event: Root.Event = .addTokenFailed(NSError())
        let effect = root.update(event)
        // TODO: check that the component state hasn't changed

        guard case .some(.showErrorMessage("Failed to add token.")) = effect else {
            XCTFail("Expected .showErrorMessage(\"Failed to add token.\"), got \(String(describing: effect))")
            return
        }
    }

    // MARK: Events

    func testEventAddTokenFromURLSucceeded() {
        var root = Root(deviceCanScan: false)
        let event: Root.Event = .addTokenFromURLSucceeded
        let effect = root.update(event)
        // TODO: check that the component state hasn't changed
        XCTAssertNil(effect)
    }

    func testEventTokenFormSucceeded() {
        var root = Root(deviceCanScan: false)

        // Ensure the initial view model has no modal.
        guard case .none = root.viewModel(for: [], at: displayTime).modal else {
            XCTFail("The initial view model should have no modal.")
            return
        }

        // Show the token entry form.
        do {
            let effect = try root.update(Root.Action.tokenListAction(.beginAddToken))
            XCTAssertNil(effect)
        } catch {
            XCTFail("Caught unexpected error: \(error)")
        }

        // Ensure the view model now has a modal entry form.
        guard case .entryForm = root.viewModel(for: [], at: displayTime).modal else {
            XCTFail("The view model should have a modal entry form.")
            return
        }

        // Signal token entry success.
        let effect = root.update(.tokenFormSucceeded)
        XCTAssertNil(effect)

        // Ensure the token entry form hides on success.
        guard case .none = root.viewModel(for: [], at: displayTime).modal else {
            XCTFail("The final view model should have no modal.")
            return
        }
    }

    func testEventSaveTokenFailed() {
        var root = Root(deviceCanScan: false)
        let event: Root.Event = .saveTokenFailed(NSError())
        let effect = root.update(event)
        // TODO: check that the component state hasn't changed

        guard case .some(.showErrorMessage("Failed to save token.")) = effect else {
            XCTFail("Expected .showErrorMessage(\"Failed to save token.\"), got \(String(describing: effect))")
            return
        }
    }

    func testEventUpdateTokenFailed() {
        var root = Root(deviceCanScan: false)
        let event: Root.Event = .updateTokenFailed(NSError())
        let effect = root.update(event)
        // TODO: check that the component state hasn't changed

        guard case .some(.showErrorMessage("Failed to update token.")) = effect else {
            XCTFail("Expected .showErrorMessage(\"Failed to update token.\"), got \(String(describing: effect))")
            return
        }
    }

    func testEventMoveTokenFailed() {
        var root = Root(deviceCanScan: false)
        let event: Root.Event = .moveTokenFailed(NSError())
        let effect = root.update(event)
        // TODO: check that the component state hasn't changed

        guard case .some(.showErrorMessage("Failed to move token.")) = effect else {
            XCTFail("Expected .showErrorMessage(\"Failed to move token.\"), got \(String(describing: effect))")
            return
        }
    }

    func testEventDeleteTokenFailed() {
        var root = Root(deviceCanScan: false)
        let event: Root.Event = .deleteTokenFailed(NSError())
        let effect = root.update(event)
        // TODO: check that the component state hasn't changed

        guard case .some(.showErrorMessage("Failed to delete token.")) = effect else {
            XCTFail("Expected .showErrorMessage(\"Failed to delete token.\"), got \(String(describing: effect))")
            return
        }
    }

}
