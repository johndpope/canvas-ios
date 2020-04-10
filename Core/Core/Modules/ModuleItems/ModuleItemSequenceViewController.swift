//
// This file is part of Canvas.
// Copyright (C) 2020-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import UIKit

public class ModuleItemSequenceViewController: UIViewController {
    public typealias AssetType = GetModuleItemSequenceRequest.AssetType

    @IBOutlet weak var pagesContainer: UIView!
    @IBOutlet weak var buttonsContainer: UIView!
    @IBOutlet weak var buttonsHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var spinnerView: UIView!

    let env = AppEnvironment.shared
    var courseID: String!
    var assetType: AssetType!
    var assetID: String!
    var url: URLComponents!

    let pages = PagesViewController()
    var observations: [NSKeyValueObservation]?

    lazy var store = env.subscribe(GetModuleItemSequence(courseID: courseID, assetType: assetType, assetID: assetID)) { [weak self] in
        self?.update(embed: true)
    }
    var sequence: ModuleItemSequence? { store.first }

    public static func create(courseID: String, assetType: AssetType, assetID: String, url: URLComponents) -> Self {
        let controller = loadFromStoryboard()
        controller.courseID = courseID
        controller.assetType = assetType
        controller.assetID = assetID
        controller.url = url
        return controller
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        showSequenceButtons(prev: false, next: false)
        pages.scrollView.isScrollEnabled = false
        embed(pages, in: pagesContainer)

        // places the next arrow on the opposite side
        let transform = CGAffineTransform(scaleX: -1, y: 1)
        nextButton.transform = transform
        nextButton.titleLabel?.transform = transform
        nextButton.imageView?.transform = transform

        // force refresh because we don't provide a refresh control
        store.refresh(force: true)
    }

    func update(embed: Bool) {
        if store.requested, store.pending {
            spinnerView.isHidden = false
            return
        }
        spinnerView.isHidden = true
        guard let url = url.url else { return }
        if embed {
            let viewController: UIViewController
            if let current = sequence?.current, !env.database.viewContext.isObjectDeleted(current) {
                viewController = ModuleItemDetailsViewController.create(courseID: courseID, moduleID: current.moduleID, itemID: current.id)
            } else if assetType != .moduleItem, let match = env.router.match(.parse(url.appendingOrigin("module_item_details"))) {
                viewController = match
            } else {
                let external = ExternalURLViewController.create(name: NSLocalizedString("Unsupported Item", bundle: .core, comment: ""), url: url, courseID: courseID)
                external.authenticate = true
                viewController = external
            }
            setCurrentPage(viewController)
        }
        showSequenceButtons(prev: sequence?.prev != nil, next: sequence?.next != nil)
    }

    func showSequenceButtons(prev: Bool, next: Bool) {
        let show = prev || next
        self.buttonsContainer.isHidden = show == false
        self.buttonsHeightConstraint.constant = show ? 56 : 0
        previousButton.isHidden = prev == false
        nextButton.isHidden = next == false
        self.view.layoutIfNeeded()
    }

    func show(item: ModuleItem, direction: PagesViewController.Direction? = nil) {
        let details = ModuleItemDetailsViewController.create(courseID: courseID, moduleID: item.moduleID, itemID: item.id)
        setCurrentPage(details, direction: direction)
        store = env.subscribe(GetModuleItemSequence(courseID: courseID, assetType: .moduleItem, assetID: item.id)) { [weak self] in
            self?.update(embed: false)
        }
        store.refresh(force: true)
    }

    func setCurrentPage(_ page: UIViewController, direction: PagesViewController.Direction? = nil) {
        pages.setCurrentPage(page, direction: direction)
        observations = syncNavigationBar(with: page)
    }

    @IBAction func goPrevious() {
        guard let prev = sequence?.prev else { return }
        show(item: prev, direction: .reverse)
    }

    @IBAction func goNext() {
        guard let next = sequence?.next else { return }
        show(item: next, direction: .forward)
    }
}
