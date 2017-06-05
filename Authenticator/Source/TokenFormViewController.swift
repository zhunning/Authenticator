//
//  TokenFormViewController.swift
//  Authenticator
//
//  Copyright (c) 2015 Authenticator authors
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

import UIKit

final class TokenFormViewController<Form: TableViewModelRepresentable>: UITableViewController where Form.HeaderModel == TokenFormHeaderModel<Form.Action>, Form.RowModel == TokenFormRowModel<Form.Action> {
    fileprivate let dispatchAction: (Form.Action) -> Void
    fileprivate var viewModel: TableViewModel<Form> {
        didSet {
            guard oldValue.sections.count == viewModel.sections.count else {
                // Automatic updates aren't implemented for changing number of sections
                tableView.reloadData()
                return
            }

            let changes = viewModel.sections.indices.flatMap { sectionIndex -> [Change<IndexPath>] in
                let oldSection = oldValue.sections[sectionIndex]
                let newSection = viewModel.sections[sectionIndex]
                let changes = changesFrom(oldSection.rows, to: newSection.rows)
                return changes.map({ change in
                    change.map({ row in
                        IndexPath(row: row, section: sectionIndex)
                    })
                })
            }
            tableView.applyChanges(changes, updateRow: updateRowAtIndexPath)
        }
    }

    init(viewModel: TableViewModel<Form>, dispatchAction: @escaping (Form.Action) -> Void) {
        self.viewModel = viewModel
        self.dispatchAction = dispatchAction
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .otpBackgroundColor
        view.tintColor = .otpForegroundColor
        tableView.separatorStyle = .none

        // Set up top bar
        title = viewModel.title
        updateBarButtonItems()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if CommandLine.isDemo {
            // If this is a demo, don't show the keyboard.
            return
        }

        focusFirstField()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unfocus()
    }

    // MARK: Focus

    @discardableResult
    private func focusFirstField() -> Bool {
        for cell in tableView.visibleCells {
            if let focusCell = cell as? FocusCell {
                return focusCell.focus()
            }
        }
        return false
    }

    fileprivate func nextVisibleFocusCellAfterIndexPath(_ currentIndexPath: IndexPath) -> FocusCell? {
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
            for indexPath in visibleIndexPaths {
                if currentIndexPath.compare(indexPath) == .orderedAscending {
                    if let focusCell = tableView.cellForRow(at: indexPath) as? FocusCell {
                        return focusCell
                    }
                }
            }
        }
        return nil
    }

    @discardableResult
    private func unfocus() -> Bool {
        return view.endEditing(false)
    }

    // MARK: - Target Actions

    func leftBarButtonAction() {
        if let action = viewModel.leftBarButton?.action {
            dispatchAction(action)
        }
    }

    func rightBarButtonAction() {
        if let action = viewModel.rightBarButton?.action {
            dispatchAction(action)
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInSection(section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let rowModel = viewModel.modelForRowAtIndexPath(indexPath) else {
            return UITableViewCell()
        }
        return cellForRowModel(rowModel, inTableView: tableView)
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // An apparent rendering error can occur when the form is scrolled programaticallty, causing a cell scrolled off
        // of the screen to appear with a black background when scrolled back onto the screen. Setting the background
        // color of the cell to the table view's background color, instead of to clearColor(), fixes the issue.
        cell.backgroundColor = .otpBackgroundColor
        cell.selectionStyle = .none

        cell.textLabel?.textColor = .otpForegroundColor
        if let cell = cell as? TextFieldRowCell<Form.Action> {
            cell.textField.backgroundColor = .otpLightColor
            cell.textField.tintColor = .otpDarkColor
            cell.delegate = self
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let rowModel = viewModel.modelForRowAtIndexPath(indexPath) else {
            return 0
        }
        return heightForRowModel(rowModel)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let headerModel = viewModel.modelForHeaderInSection(section) else {
            return CGFloat.ulpOfOne
        }
        return heightForHeaderModel(headerModel)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerModel = viewModel.modelForHeaderInSection(section) else {
            return nil
        }
        return viewForHeaderModel(headerModel)
    }
}

// MARK: - View Model Helpers

extension TokenFormViewController {
    // MARK: Bar Button View Model

    private func barButtonItemForViewModel(_ viewModel: BarButtonViewModel<Form.Action>, target: AnyObject?, action: Selector) -> UIBarButtonItem {
        func systemItemForStyle(_ style: BarButtonStyle) -> UIBarButtonSystemItem {
            switch style {
            case .done:
                return .done
            case .cancel:
                return .cancel
            }
        }

        let barButtonItem = UIBarButtonItem(
            barButtonSystemItem: systemItemForStyle(viewModel.style),
            target: target,
            action: action
        )
        barButtonItem.isEnabled = viewModel.enabled
        return barButtonItem
    }

    func updateBarButtonItems() {
        navigationItem.leftBarButtonItem = viewModel.leftBarButton.map { (viewModel) in
            let action = #selector(TokenFormViewController.leftBarButtonAction)
            return barButtonItemForViewModel(viewModel, target: self, action: action)
        }
        navigationItem.rightBarButtonItem = viewModel.rightBarButton.map { (viewModel) in
            let action = #selector(TokenFormViewController.rightBarButtonAction)
            return barButtonItemForViewModel(viewModel, target: self, action: action)
        }
    }

    // MARK: Row Model

    func cellForRowModel(_ rowModel: Form.RowModel, inTableView tableView: UITableView) -> UITableViewCell {
        switch rowModel {
        case let .textFieldRow(row):
            let cell = tableView.dequeueReusableCellWithClass(TextFieldRowCell<Form.Action>.self)
            cell.updateWithViewModel(row.viewModel)
            cell.dispatchAction = dispatchAction
            cell.delegate = self
            return cell

        case let .segmentedControlRow(row):
            let cell = tableView.dequeueReusableCellWithClass(SegmentedControlRowCell<Form.Action>.self)
            cell.updateWithViewModel(row.viewModel)
            cell.dispatchAction = dispatchAction
            return cell
        }
    }

    func updateRowAtIndexPath(_ indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            // If the given row is not visible, the table view will have no cell for it, and it
            // doesn't need to be updated.
            return
        }
        guard let rowModel = viewModel.modelForRowAtIndexPath(indexPath) else {
            // If there is no row model for the given index path, just tell the table view to
            // reload it and hope for the best.
            tableView.reloadRows(at: [indexPath], with: .automatic)
            return
        }

        switch rowModel {
        case let .textFieldRow(row):
            if let cell = cell as? TextFieldRowCell<Form.Action> {
                cell.updateWithViewModel(row.viewModel)
            } else {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        case let .segmentedControlRow(row):
            if let cell = cell as? SegmentedControlRowCell<Form.Action> {
                cell.updateWithViewModel(row.viewModel)
            } else {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        }
    }

    func heightForRowModel(_ rowModel: Form.RowModel) -> CGFloat {
        switch rowModel {
        case let .textFieldRow(row):
            return TextFieldRowCell<Form.Action>.heightWithViewModel(row.viewModel)
        case let .segmentedControlRow(row):
            return SegmentedControlRowCell<Form.Action>.heightWithViewModel(row.viewModel)
        }
    }

    // MARK: Header Model

    func viewForHeaderModel(_ headerModel: Form.HeaderModel) -> UIView {
        switch headerModel {
        case let .buttonHeader(header):
            return ButtonHeaderView(viewModel: header.viewModel, dispatchAction: dispatchAction)
        }
    }

    func heightForHeaderModel(_ headerModel: Form.HeaderModel) -> CGFloat {
        switch headerModel {
        case let .buttonHeader(header):
            return ButtonHeaderView.heightWithViewModel(header.viewModel)
        }
    }
}

extension TokenFormViewController {
    func updateWithViewModel(_ viewModel: TableViewModel<Form>) {
        self.viewModel = viewModel
        updateBarButtonItems()
    }
}

extension TokenFormViewController: TextFieldRowCellDelegate {
    func textFieldCellDidReturn<Action>(_ textFieldCell: TextFieldRowCell<Action>) {
        // Unfocus the field that returned
        textFieldCell.unfocus()

        if textFieldCell.textField.returnKeyType == .next {
            // Try to focus the next text field cell
            if let currentIndexPath = tableView.indexPath(for: textFieldCell) {
                if let nextFocusCell = nextVisibleFocusCellAfterIndexPath(currentIndexPath) {
                    nextFocusCell.focus()
                }
            }
        } else if textFieldCell.textField.returnKeyType == .done {
            // Try to submit the form
            dispatchAction(viewModel.doneKeyAction)
        }
    }
}
