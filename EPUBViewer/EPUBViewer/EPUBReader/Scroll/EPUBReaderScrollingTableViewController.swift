//
//  EPUBReaderScrollingTableViewController.swift
//  EPUBViewer
//
//  Created by Jaehong Kang on 2020/01/21.
//  Copyright © 2020 Jaehong Kang. All rights reserved.
//

import UIKit
import EPUBKit
import Combine

class EPUBReaderScrollingTableViewController: UITableViewController {
    enum Section: CaseIterable {
        case main
    }

    static let cellReuseIdentifier = "Cell"

    private var epubMetadataObservation: AnyCancellable?
    private var epubPageCoordinatorSubscription: AnyCancellable?

    private var prefetchedWebViewControllers = [IndexPath: EPUBReaderWebViewController]()

    lazy var dataSource = UITableViewDiffableDataSource<Section, EPUB.PagePosition>(tableView: tableView) { [unowned self](tableView, indexPath, pagePosition) -> UITableViewCell? in
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath) as? EPUBReaderScrollingTableViewCell else {
            fatalError()
        }

        // Configure the cell...
        cell.webViewController = self.prefetchedWebViewControllers[indexPath] ?? cell.webViewController ?? EPUBReaderWebViewController(configuration: .init())
        self.prefetchedWebViewControllers[indexPath] = nil
        
        cell.pagePositionInfo = (self.epubPageCoordinator, pagePosition)

        return cell
    }

    let epub: EPUB
    let epubPageCoordinator: EPUB.PageCoordinator

    init(epub: EPUB) {
        self.epub = epub
        self.epubPageCoordinator = epub.newPageCoordinator()

        super.init(style: .plain)

        self.epubMetadataObservation = epub.$metadata
            .sink { [unowned self](metadata) in
                self.title = [metadata.creator, metadata.title].compactMap { $0 }.joined(separator: " - ")
            }

        self.epubPageCoordinatorSubscription = epubPageCoordinator.pagePositionsPublisher
            .removeDuplicates()
            .throttle(for: .milliseconds(500), scheduler: RunLoop.main, latest: true)
            .sink(receiveCompletion: { (completion) in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    debugPrint(error)
                }
            }, receiveValue: { [unowned self](pagePositions) in
                self.updateDataSource(with: pagePositions)
            })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

        tableView.register(EPUBReaderScrollingTableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
        tableView.dataSource = dataSource
        tableView.prefetchDataSource = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.epubPageCoordinator.pageSize = .init(width: view.bounds.size.width, height: .greatestFiniteMagnitude)
        updateDataSource()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        self.epubPageCoordinator.pageSize = .init(width: size.width, height: .greatestFiniteMagnitude)
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return dataSource.itemIdentifier(for: indexPath)?.pageSize.height ?? 0
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? EPUBReaderScrollingTableViewCell else {
            return
        }

        cell.webViewController.flatMap { addChild($0) }
    }

    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? EPUBReaderScrollingTableViewCell else {
            return
        }

        cell.webViewController?.removeFromParent()
    }

    // MARK: -

    func updateDataSource(with pagePositions: [EPUB.PagePosition]? = nil) {
        guard let pagePositions = pagePositions ?? (try? self.epubPageCoordinator.pagePositions.get()) else {
            return
        }

        var snapshot = self.dataSource.snapshot()

        Section.allCases.difference(from: snapshot.sectionIdentifiers).forEach {
            switch $0 {
            case .insert(let offset, let element, _):
                if offset == snapshot.sectionIdentifiers.count {
                    snapshot.appendSections([element])
                } else {
                    snapshot.insertSections([element], beforeSection: snapshot.sectionIdentifiers[offset])
                }
            case .remove(_, let element, _):
                snapshot.deleteSections([element])
            }
        }

        pagePositions.difference(from: snapshot.itemIdentifiers).forEach {
            switch $0 {
            case .insert(let offset, let element, _):
                if offset == snapshot.itemIdentifiers.count {
                    snapshot.appendItems([element])
                } else {
                    snapshot.insertItems([element], beforeItem: snapshot.itemIdentifiers[offset])
                }
            case .remove(_, let element, _):
                snapshot.deleteItems([element])
            }
        }

        self.dataSource.apply(snapshot)
    }
}

extension EPUBReaderScrollingTableViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        indexPaths.map { (key: $0, value: dataSource.itemIdentifier(for: $0)) }
            .forEach {
                guard let pagePositionInfo = $0.value else {
                    return
                }

                let webViewController = EPUBReaderWebViewController(configuration: .init())
                webViewController.view.frame = tableView.bounds
                webViewController.pageCoordinator = self.epubPageCoordinator
                webViewController.position = pagePositionInfo

                prefetchedWebViewControllers[$0.key] = webViewController
            }
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        indexPaths.forEach {
            prefetchedWebViewControllers.removeValue(forKey: $0)
        }
    }
}