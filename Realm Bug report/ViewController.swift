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
        rows1NotificationToken = rows1.observe { (change) in
            switch change {
            case .error(let error):
                print("Realm error reloading rows", error)
            case .initial(_):
                self.tableView.reloadSections([0], with: .automatic)
            case .update(_, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                self.tableView.performBatchUpdates({
                    self.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                    self.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                    self.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                }, completion: nil)
            }
        }
        rows2NotificationToken = rows2.observe { (change) in
            switch change {
            case .error(let error):
                print("Realm error reloading rows", error)
            case .initial(_):
                self.tableView.reloadSections([1], with: .automatic)
            case .update(_, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                self.tableView.performBatchUpdates({
                    self.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 1) }, with: .automatic)
                    self.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 1) }, with: .automatic)
                    self.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 1)}, with: .automatic)
                }, completion: nil)
            }
        }
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

