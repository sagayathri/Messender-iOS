//
//  TopicsViewController.swift
//  MessengeriOS
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class TopicsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var topicsTableView: UITableView!
    @IBOutlet weak var loggedName: UILabel!
    
    private var currentTopicAlertController: UIAlertController?
    
    private let db = Firestore.firestore()
    
    private var topicReference: CollectionReference {
        return db.collection("topics")
    }
    
    private var topics = [Topic]()
    private var currentChannelAlertController: UIAlertController?
    private var topicListener: ListenerRegistration?
    
    var currentUser: User? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        topicsTableView.delegate = self
        topicsTableView.dataSource = self
        
        //Gets the current User from Firebase
        currentUser = Auth.auth().currentUser
        
        //Gets the name from UserDefaults
        loggedName.text = UserDefaultsClass.displayName

        //Loads all available topics from the database
        topicListener = topicReference.addSnapshotListener { querySnapshot, error in
            guard let snapshot = querySnapshot else {
              print("Error listening for topic updates: \(error?.localizedDescription ?? "No error")")
              return
            }

            snapshot.documentChanges.forEach { change in
              self.handleDocumentChange(change)
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func LogOut(_ sender: UIButton) {
        //Logs out the currentUser
        let ac = UIAlertController(title: nil, message: "Are you sure you want to sign out?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        ac.addAction(UIAlertAction(title: "Sign Out", style: .destructive, handler: { _ in
            do {
                //Updates database that the currentUser is Logged Out
                try Auth.auth().signOut()
                self.navigationController?.popViewController(animated: true)
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
        }))
        present(ac, animated: true, completion: nil)
    }
    
    @IBAction func addTopic(_ sender: UIButton) {
        //Create a new topic
        let ac = UIAlertController(title: "Create a new Topic", message: nil, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        ac.addTextField { field in
            field.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
            field.enablesReturnKeyAutomatically = true
            field.autocapitalizationType = .words
            field.clearButtonMode = .whileEditing
            field.placeholder = "Topic name"
            field.returnKeyType = .done
            field.tintColor = .primary
        }
        
        let createAction = UIAlertAction(title: "Create", style: .default, handler: { _ in
            self.createTopic()
        })
        createAction.isEnabled = false
        ac.addAction(createAction)
        ac.preferredAction = createAction
        
        present(ac, animated: true) {
            ac.textFields?.first?.becomeFirstResponder()
        }
        currentTopicAlertController = ac
    }
    
    @objc private func textFieldDidChange(_ field: UITextField) {
        guard let ac = currentTopicAlertController else {
            return
        }

        ac.preferredAction?.isEnabled = field.hasText
    }
    
    // MARK: - Helpers
    private func createTopic() {
        guard let ac = currentTopicAlertController else {
            return
        }

        //Checks for topicTV is empty
        guard let topicName = ac.textFields?.first?.text else {
            return
        }

        let topic = Topic(name: topicName)
        //Creates a topic in database
        topicReference.addDocument(data: topic.representation) { error in
            if let e = error {
                print("Error saving topic: \(e.localizedDescription)")
            }
        }
    }
    
    //Appends the topic
    private func addTopicToTable(_ topic: Topic) {
        //Check for topic is not null
        guard !topics.contains(topic) else {
            return
        }

        //Appends the topics list
        topics.append(topic)
    
        //Reload the tableView
        topicsTableView.reloadData()
    }
    
    //Updates the topic
    private func updateTopicInTable(_ topic: Topic) {
        guard let index = topics.firstIndex(of: topic) else {
            return
        }

        topics[index] = topic
        topicsTableView.reloadData()
    }
    
    //Delete the topic
    private func removeTopicFromTable(_ topic: Topic) {
        guard let index = topics.firstIndex(of: topic) else {
            return
        }

        topics.remove(at: index)
        topicsTableView.reloadData()
    }
    
    private func handleDocumentChange(_ change: DocumentChange) {
        guard let topic = Topic(document: change.document) else {
            return
        }

        switch change.type {
            case .added:
                addTopicToTable(topic)
            case .modified:
                updateTopicInTable(topic)
            case .removed:
                removeTopicFromTable(topic)
        }
    }
}

extension TopicsViewController {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return topics.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        tableView.separatorStyle = .none
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = topics[indexPath.row].name

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let topic = topics[indexPath.row]
        currentUser = Auth.auth().currentUser
        if let user = currentUser {
            let vc = ChatsViewController(user: user, topic: topic)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
