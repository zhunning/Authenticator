//
//  TokenList.swift
//  Authenticator
//
//  Copyright (c) 2015-2016 Authenticator authors
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

import Foundation
import UIKit
import MobileCoreServices
import OneTimePassword

struct TokenList: Component {
    fileprivate var filter: String?

    // MARK: View Model

    typealias ViewModel = TokenListViewModel

    func viewModel(for persistentTokens: [PersistentToken], at displayTime: DisplayTime) -> TokenListViewModel {
        let isFiltering = !(filter ?? "").isEmpty
        let rowModels = filteredTokens(persistentTokens).map({
            TokenRowModel(persistentToken: $0, displayTime: displayTime, canReorder: !isFiltering)
        })
        return TokenListViewModel(
            rowModels: rowModels,
            ringProgress: ringProgress(for: persistentTokens, at: displayTime),
            totalTokens: persistentTokens.count,
            isFiltering: isFiltering
        )
    }

    /// Returns a sorted, uniqued array of the periods of timer-based tokens
    private func timeBasedTokenPeriods(for persistentTokens: [PersistentToken]) -> [TimeInterval] {
        var periods = Set<TimeInterval>()
        persistentTokens.forEach { (persistentToken) in
            if case .timer(let period) = persistentToken.token.generator.factor {
                periods.insert(period)
            }
        }
        return Array(periods).sorted()
    }

    private func ringProgress(for persistentTokens: [PersistentToken], at displayTime: DisplayTime) -> Double? {
        guard let ringPeriod = timeBasedTokenPeriods(for: persistentTokens).first else {
            // If there are no time-based tokens, return nil to hide the progress ring.
            return nil
        }
        guard ringPeriod > 0 else {
            // If the period is >= zero, return zero to display the ring but avoid the potential
            // divide-by-zero error below.
            return 0
        }
        // Calculate the percentage progress in the current period.
        return fmod(displayTime.timeIntervalSince1970, ringPeriod) / ringPeriod
    }

    private func filteredTokens(_ persistentTokens: [PersistentToken]) -> [PersistentToken] {
        guard let filter = self.filter, !filter.isEmpty else {
            return persistentTokens
        }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return persistentTokens.filter({
            $0.token.issuer.range(of: filter, options: options) != nil ||
                $0.token.name.range(of: filter, options: options) != nil
        })
    }
}

extension TokenList {
    enum Action {
        case beginAddToken
        case editPersistentToken(PersistentToken)

        case updatePersistentToken(PersistentToken)
        case moveToken(fromIndex: Int, toIndex: Int)
        case deletePersistentToken(PersistentToken)

        case copyPassword(String)

        case filter(String)
        case clearFilter

        case showBackupInfo
        case showInfo
    }

    enum Effect {
        case beginTokenEntry
        case beginTokenEdit(PersistentToken)

        case updateToken(PersistentToken)
        case moveToken(fromIndex: Int, toIndex: Int)
        case deletePersistentToken(PersistentToken)

        case showErrorMessage(String)
        case showSuccessMessage(String)
        case showBackupInfo
        case showInfo
    }

    mutating func update(_ action: Action) -> Effect? {
        switch action {
        case .beginAddToken:
            return .beginTokenEntry

        case .editPersistentToken(let persistentToken):
            return .beginTokenEdit(persistentToken)

        case .updatePersistentToken(let persistentToken):
            return .updateToken(persistentToken)

        case let .moveToken(fromIndex, toIndex):
            return .moveToken(fromIndex: fromIndex, toIndex: toIndex)

        case .deletePersistentToken(let persistentToken):
            return .deletePersistentToken(persistentToken)

        case .copyPassword(let password):
            return copyPassword(password)

        case .filter(let filter):
            self.filter = filter
            return nil

        case .clearFilter:
            self.filter = nil
            return nil

        case .showBackupInfo:
            return .showBackupInfo

        case .showInfo:
            return .showInfo
        }
    }

    private mutating func copyPassword(_ password: String) -> Effect {
        let pasteboard = UIPasteboard.general
        pasteboard.setValue(password, forPasteboardType: kUTTypeUTF8PlainText as String)
        // Show an ephemeral success message.
        return .showSuccessMessage("Copied")
    }
}

extension TokenList.Action: Equatable {}
func == (lhs: TokenList.Action, rhs: TokenList.Action) -> Bool {
    switch (lhs, rhs) {
    case (.beginAddToken, .beginAddToken):
        return true
    case let (.editPersistentToken(l), .editPersistentToken(r)):
        return l == r
    case let (.updatePersistentToken(l), .updatePersistentToken(r)):
        return l == r
    case let (.moveToken(l), .moveToken(r)):
        return l == r
    case let (.deletePersistentToken(l), .deletePersistentToken(r)):
        return l == r
    case let (.copyPassword(l), .copyPassword(r)):
        return l == r
    case (.clearFilter, .clearFilter):
        return true
    case let (.filter(l), .filter(r)):
        return l == r
    case (.showBackupInfo, .showBackupInfo):
        return true
    case (.showInfo, .showInfo):
        return true
    case (.beginAddToken, _), (.editPersistentToken, _), (.updatePersistentToken, _), (.moveToken, _),
         (.deletePersistentToken, _), (.copyPassword, _), (.filter, _), (.clearFilter, _), (.showBackupInfo, _),
         (.showInfo, _):
        // Using this verbose case for non-matching `Action`s instead of `default` ensures a
        // compiler error if a new `Action` is added and not expicitly checked for equality.
        return false
    }
}
