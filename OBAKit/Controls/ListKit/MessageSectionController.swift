//
//  MessageSectionController.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import UIKit
import IGListKit
import SwipeCellKit
import OBAKitCore

// MARK: - MessageSectionData

final class MessageSectionData: ListViewModel, ListDiffable {
    var author: String?
    var date: String?
    var subject: String
    var summary: String?
    var isUnread: Bool

    /// The maximum number of lines to display for the summary before truncation. Set to `0` for unlimited lines.
    /// - Note: A multiple of this value is used when the user's content size is set to an accessibility size.
    var summaryNumberOfLines: Int = 2

    /// The maximum number of lines to display for the subject before truncation. Set to `0` for unlimited lines.
    /// - Note: A multiple of this value is used when the user's content size is set to an accessibility size.
    var subjectNumberOfLines: Int = 1

    public func diffIdentifier() -> NSObjectProtocol {
        return self
    }

    public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
        guard let rhs = object as? MessageSectionData else {
            return false
        }

        return author == rhs.author && date == rhs.date && subject == rhs.subject && summary == rhs.summary && isUnread == rhs.isUnread
    }

    public init(author: String?, date: String?, subject: String, summary: String?, isUnread: Bool, tapped: ListRowActionHandler?) {
        self.author = author
        self.date = date
        self.subject = subject
        self.summary = summary
        self.isUnread = isUnread

        super.init(tapped: tapped)
    }
}

final class ServiceAlertData: NSObject {
    let serviceAlert: ServiceAlert
    let id: String
    let title: String
    let agency: String
    let isUnread: Bool

    public init(serviceAlert: ServiceAlert, id: String, title: String, agency: String, isUnread: Bool) {
        self.serviceAlert = serviceAlert
        self.id = id
        self.title = title
        self.agency = agency
        self.isUnread = isUnread
    }
}

final class ServiceAlertsSectionData: NSObject, ListDiffable {
    var serviceAlerts: [ServiceAlertData]

    public init(serviceAlertData: [ServiceAlertData]) {
        self.serviceAlerts = serviceAlertData
    }

    func diffIdentifier() -> NSObjectProtocol {
        return "ServiceAlertsSectionIdentifier" as NSString
    }

    func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
        return false // TODO: me
        guard let object = object as? ServiceAlertsSectionData else { return false }
//        return object.serviceAlerts == self.serviceAlerts
    }
}

protocol ServiceAlertsSectionControllerDelegate: class {
    func serviceAlertsSectionController(_ controller: ServiceAlertsSectionController, didSelectAlert alert: ServiceAlert)
}

final class ServiceAlertsSectionController: OBAListSectionController<ServiceAlertsSectionData> {
    weak var delegate: ServiceAlertsSectionControllerDelegate?

    override func numberOfItems() -> Int {
        return sectionData?.serviceAlerts.count ?? 0
    }

    override func cellForItem(at index: Int) -> UICollectionViewCell {
        let cell = dequeueReusableCell(type: ServiceAlertCell.self, at: index)
        cell.serviceAlert = sectionData?.serviceAlerts[index]

        return cell
    }

    override func didSelectItem(at index: Int) {
        guard let alert = sectionData?.serviceAlerts[index].serviceAlert else { return }
        delegate?.serviceAlertsSectionController(self, didSelectAlert: alert)
    }
}

// MARK: - MessageCell

final class ServiceAlertCell: BaseSelfSizingTableCell {
    private let useDebugColors = false

    // MARK: - UI

    private var contentStack: UIStackView!
    private let unreadDot: UIImageView = {
        let image: UIImage
        if #available(iOS 13.0, *) {
            image = UIImage(systemName: "exclamationmark.circle.fill")!
        } else {
            image = Icons.errorOutline
        }

        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.setCompressionResistance(vertical: .required)
        view.setHugging(horizontal: .defaultHigh)

        if #available(iOS 13, *) {
            view.preferredSymbolConfiguration = .init(font: .preferredFont(forTextStyle: .headline))
        }
        view.tintColor = ThemeColors.shared.brand

        return view
    }()

    private var textStack: UIStackView!

    private let subjectLabel: UILabel = .obaLabel(font: .preferredFont(forTextStyle: .body))
    private let agencyLabel: UILabel = .obaLabel(font: .preferredFont(forTextStyle: .footnote), textColor: ThemeColors.shared.secondaryLabel)

    private var chevronView: UIImageView!

    // MARK: - Data

    var data: MessageSectionData? {
        didSet {
            configureView()
        }
    }

    var serviceAlert: ServiceAlertData? {
        didSet {
            configureView()
        }
    }

    // MARK: - UICollectionViewCell

    override func prepareForReuse() {
        super.prepareForReuse()

        subjectLabel.text = nil
        agencyLabel.text = nil

        configureView()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.textStack = UIStackView.stack(axis: .vertical, distribution: .equalSpacing, arrangedSubviews: [subjectLabel, agencyLabel])
        self.textStack.spacing = ThemeMetrics.compactPadding

        self.contentStack = UIStackView.stack(axis: .horizontal, distribution: .fill, alignment: .leading, arrangedSubviews: [unreadDot, textStack])
        contentStack.spacing = ThemeMetrics.padding

        chevronView = UIImageView.autolayoutNew()
        chevronView.image = Icons.chevron
        chevronView.setCompressionResistance(vertical: .required)
        chevronView.setHugging(horizontal: .defaultHigh)

        let outerStack = UIStackView.stack(axis: .horizontal, distribution: .fill, alignment: .center, arrangedSubviews: [contentStack, chevronView])

        contentView.addSubview(outerStack)

        outerStack.pinToSuperview(.readableContent) {
            $0.trailing.priority = .required - 1
        }

        configureView()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        configureView()
    }

    private func configureView() {
        guard let data = serviceAlert else { return }

        let imageName = data.isUnread ? "exclamationmark.circle.fill" : "exclamationmark.circle"
        if #available(iOS 13, *) {
            unreadDot.image = UIImage(systemName: imageName)
        }

        subjectLabel.text = data.title
        agencyLabel.text = data.agency

        contentStack.axis = isAccessibility ? .vertical : .horizontal
        contentStack.alignment = isAccessibility ? .leading : .center

        isAccessibilityElement = true
        accessibilityTraits = [.button, .staticText]
        accessibilityLabel = data.title
        accessibilityLabel = Strings.serviceAlert
        accessibilityValue = data.title

        if useDebugColors {
            subjectLabel.backgroundColor = .green
            contentView.backgroundColor = .yellow
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - MessageSectionController

final class MessageSectionController: OBAListSectionController<MessageSectionData> {
    override public func cellForItem(at index: Int) -> UICollectionViewCell {
        let cell = dequeueReusableCell(type: ServiceAlertCell.self, at: index)
        cell.data = sectionData

        return cell
    }

    public override func didSelectItem(at index: Int) {
        guard
            let data = sectionData,
            let tapped = data.tapped
        else { return }

        tapped(data)
    }
}
