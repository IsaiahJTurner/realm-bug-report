//
//  ViewController.swift
//  Realm Bug report
//
//  Created by Isaiah Turner on 5/22/19.
//  Copyright © 2019 Isaiah Turner. All rights reserved.
//

import UIKit
import RealmSwift

class Row: Object {
    @objc dynamic var title: String?
}
class DataStore {
    static let shared = DataStore()
    private init() {
        do {
            try realm.write {
                realm.add([Row(value: ["title": "0"]), Row(value: ["title": "1"]), Row(value: ["title": "section 2"])])
            }
        } catch let error {
            print("Realm error adding data", error)
        }
    }
    let realm = try! Realm(configuration:  Realm.Configuration(fileURL: nil, inMemoryIdentifier: "Realm", syncConfiguration: nil, encryptionKey: nil, readOnly: false, schemaVersion: 0, migrationBlock: nil, deleteRealmIfMigrationNeeded: true, shouldCompactOnLaunch: nil, objectTypes: nil))
}

/// Used to group change notifications that occur within the same table view.
class SectionedNotificationTokenBlock {
    struct Changes {
        var deletions = [IndexPath]()
        var insertions = [IndexPath]()
        var modifications = [IndexPath]()
    }
    private var queuedChanges = Changes()
    /// Called with all queued changes.
    private var updateBlock: (Changes) -> Void
    /// Groups change notifications that occur within the same table view.
    ///
    /// - Parameter sectionedUpdateBlock: The block to be called whenever an update occurs.
    init(_ updateBlock: @escaping (Changes) -> Void) {
        self.updateBlock = updateBlock
    }
    /// Returns a closure you can provide as the handler for `observe`.
    ///
    /// - Parameter section: The section of the content in your table view.
    func block<CollectionType>(forSection section: Int, initialBlock: (() -> Void)? = nil, errorBlock: ((Error) -> Void)? = nil) -> ((RealmCollectionChange<CollectionType>) -> Void) {
        return { change in
            switch change {
            case .error(let error):
                errorBlock?(error)
            case .update(_, let deletions, let insertions, let modifications):
                self.queuedChanges.deletions.append(contentsOf: deletions.map { IndexPath(row: $0, section: section) })
                self.queuedChanges.insertions.append(contentsOf: insertions.map { IndexPath(row: $0, section: section) })
                self.queuedChanges.modifications.append(contentsOf: modifications.map { IndexPath(row: $0, section: section) })
                OperationQueue.current?.underlyingQueue?.async(execute: self.drainQueue)
            case .initial(_):
                initialBlock?()
            }
        }
    }
    /// Calls the sectioned notification token block with all changes.
    private func drainQueue() {
        guard queuedChanges.deletions.count > 0 || queuedChanges.insertions.count > 0 || queuedChanges.modifications.count > 0 else { return }
        self.updateBlock(queuedChanges)
        self.queuedChanges = Changes()
    }
}

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var tableView: UITableView!
    let rows1 = DataStore.shared.realm.objects(Row.self).filter(NSPredicate(format: "title != %@", "section 2"))
    let rows2 = DataStore.shared.realm.objects(Row.self).filter(NSPredicate(format: "title = %@", "section 2"))
    var rows1NotificationToken: NotificationToken? {
        didSet { oldValue?.invalidate() }
    }
    var rows2NotificationToken: NotificationToken? {
        didSet { oldValue?.invalidate() }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let sectionedNotificationTokenBlock = SectionedNotificationTokenBlock { (changes) in
            self.tableView.performBatchUpdates({
                self.tableView.insertRows(at: changes.insertions, with: .automatic)
                self.tableView.reloadRows(at: changes.modifications, with: .automatic)
                self.tableView.deleteRows(at: changes.deletions, with: .automatic)
            })
        }
        rows1NotificationToken = rows1.observe(sectionedNotificationTokenBlock.block(forSection: 0, initialBlock: {
            self.tableView.reloadSections([0], with: .automatic)
        }, errorBlock: { (error) in
            print("Realm error reloading rows", error)
        }))
        rows2NotificationToken = rows2.observe(sectionedNotificationTokenBlock.block(forSection: 1, initialBlock: {
            self.tableView.reloadSections([1], with: .automatic)
        }, errorBlock: { (error) in
            print("Realm error reloading rows", error)
        }))
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basicTableViewCell", for: indexPath)
        cell.textLabel?.text = indexPath.section == 0 ? self.rows1[indexPath.row].title : self.rows2[indexPath.row].title
        return cell
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return self.rows1.count
        }
        return self.rows2.count
    }
    @IBAction func tappedCrashButton(_ crashButton: UIButton) {
        do {
            try DataStore.shared.realm.write {
                DataStore.shared.realm.objects(Row.self).filter(NSPredicate(format: "title = %@", "section 2")).first?.title = "move to section 1"
            }
        } catch let error {
            print("Realm error updating data", error)
        }
    }
    deinit {
        rows1NotificationToken = nil
        rows2NotificationToken = nil
    }
}

