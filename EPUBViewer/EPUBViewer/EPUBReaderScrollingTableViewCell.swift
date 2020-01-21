//
//  EPUBReaderScrollingTableViewCell.swift
//  EPUBViewer
//
//  Created by Jaehong Kang on 2020/01/21.
//  Copyright © 2020 Jaehong Kang. All rights reserved.
//

import UIKit
import WebKit
import EPUBKit
import Combine

class EPUBReaderScrollingTableViewCell: UITableViewCell {
    lazy var webViewController: EPUBReaderWebViewController = .init(configuration: .init())

    var pagePositionInfo: (EPUB.PageCoordinator, EPUB.PagePosition)? {
        didSet {
            webViewController.pageCoordinator = pagePositionInfo?.0
            webViewController.position = pagePositionInfo?.1
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        webViewController.webView.scrollView.isScrollEnabled = false
        webViewController.webView.scrollView.contentInsetAdjustmentBehavior = .never

        webViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webViewController.view.frame = contentView.bounds
        webViewController.view.backgroundColor = .clear
        contentView.addSubview(webViewController.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
