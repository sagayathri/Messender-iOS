//
//  ChatsViewController.swift
//  MessengeriOS
//


import UIKit
import Photos
import Firebase
import MessageKit
import FirebaseFirestore
import InputBarAccessoryView
import MobileCoreServices

final class ChatsViewController: MessagesViewController {
    
    private var isSendingPhoto = false {
        didSet {
            DispatchQueue.main.async {
                self.messageInputBar.leftStackViewItems.forEach { item in
                    item.inputBarAccessoryView?.inputTextView.isEditable = !self.isSendingPhoto
                    if (!(item.inputBarAccessoryView?.inputTextView.isEditable)!) {
                        item.inputBarAccessoryView?.inputTextView.text = "File is loading please wait for a while..."
                        item.inputBarAccessoryView?.inputTextView.textColor = .darkGray
                    }
                    else {
                        item.inputBarAccessoryView?.inputTextView.text = ""
                        item.inputBarAccessoryView?.inputTextView.textColor = .black
                    }
                }
            }
        }
    }
  
    private let db = Firestore.firestore()
    private var reference: CollectionReference?
    private let storage = Storage.storage().reference()

    private var messages: [Message] = []
    private var messageListener: ListenerRegistration?

    private let user: User
    private let topic: Topic

    var downloadURL: URL? = nil
    
    deinit {
        messageListener?.remove()
    }

    init(user: User, topic: Topic) {
        self.user = user
        self.topic = topic
        super.init(nibName: nil, bundle: nil)

        title = topic.name
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
  
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let id = topic.id else {
            navigationController?.popViewController(animated: true)
            return
        }

        reference = db.collection(["topics", id, "thread"].joined(separator: "/"))

        messageListener = reference?.addSnapshotListener { querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("Error listening for topic updates: \(error?.localizedDescription ?? "No error")")
                return
            }

            for i in 0 ..< snapshot.documents.count {
                if (snapshot.documentChanges.count == snapshot.documents.count) {
                    self.handleDocumentChange(snapshot.documents[i], snapshot.documentChanges[i])
                }
                else {
                    self.handleDocumentChange(snapshot.documents[i], snapshot.documentChanges[0])
                }
            }
        }
    
        navigationItem.largeTitleDisplayMode = .never

        maintainPositionOnKeyboardFrameChanged = true
        messageInputBar.inputTextView.tintColor = .primary
        messageInputBar.sendButton.setTitleColor(.primary, for: .normal)

        messageInputBar.delegate = self
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
    
        //Hides the avatar images
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.textMessageSizeCalculator.incomingAvatarSize = .zero
            layout.emojiMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.emojiMessageSizeCalculator.incomingAvatarSize = .zero
            layout.photoMessageSizeCalculator.incomingAvatarSize = .zero
            layout.photoMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.locationMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.locationMessageSizeCalculator.incomingAvatarSize = .zero
            layout.videoMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.videoMessageSizeCalculator.incomingAvatarSize = .zero
            layout.attributedTextMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.attributedTextMessageSizeCalculator.outgoingAvatarSize = .zero
        }
    
        // Creates a camera button
        let cameraItem = InputBarButtonItem(type: .system)
        cameraItem.tintColor = .primary
        cameraItem.image = UIImage(systemName: "camera")
        cameraItem.addTarget(self, action: #selector(cameraButtonPressed), for: .primaryActionTriggered)
        cameraItem.setSize(CGSize(width: 60, height: 30), animated: false)

        messageInputBar.leftStackView.alignment = .center
        messageInputBar.setLeftStackViewWidthConstant(to: 50, animated: false)
        messageInputBar.setStackViewItems([cameraItem], forStack: .left, animated: false)
    }
  
    // MARK: - Actions
    @objc private func cameraButtonPressed() {
        let picker = UIImagePickerController()
        picker.delegate = self
        
        //Logs out the currentUser
        let ac = UIAlertController(title: nil, message: "Please choose an option", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Camera", style:  .destructive, handler: { _ in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
               picker.sourceType = .camera
            } else {
               picker.sourceType = .photoLibrary
            }
            //Opens up the camare app if physical camera is present
            self.present(picker, animated: true, completion: nil)
        }))
        ac.addAction(UIAlertAction(title: "Photo", style:  .destructive, handler: { _ in
            picker.sourceType = .photoLibrary
            //Opens up the gallary app
            self.present(picker, animated: true, completion: nil)
        }))
        ac.addAction(UIAlertAction(title: "Document", style: .destructive, handler: { _ in
            let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.text", "com.apple.iwork.pages.pages", "public.data"], in: .import)
            documentPicker.delegate = self
             //Opens up file explorer
            self.present(documentPicker, animated: true, completion: nil)
        }))
        ac.addAction(UIAlertAction(title: "Exit", style: .cancel, handler: nil))
        
        //Presents alert box
        present(ac, animated: true, completion: nil)
    }
  
    // MARK: - Helpers
    //Saves the messages locally
    private func save(_ message: Message) {
        reference?.addDocument(data: message.representation) { error in
            if let e = error {
                print("Error sending message: \(e.localizedDescription)")
                return
            }
            self.isSendingPhoto = false
            self.messagesCollectionView.reloadData()
            self.messagesCollectionView.scrollToBottom()
        }
    }
  
    //Create message views
    private func insertNewMessage(_ message: Message) {
        guard !messages.contains(message) else {
            return
        }

        messages.append(message)
        messages.sort()

        let isLatestMessage = messages.firstIndex(of: message) == (messages.count - 1)
        let shouldScrollToBottom = messagesCollectionView.isAtBottom && isLatestMessage

        messagesCollectionView.reloadData()

        if shouldScrollToBottom {
            DispatchQueue.main.async {
                self.messagesCollectionView.scrollToBottom(animated: true)
            }
        }
    }
  
    private func handleDocumentChange(_ document: QueryDocumentSnapshot, _ change: DocumentChange) {
        guard var message = Message(document: document) else {
            return
        }

        //Checks for a new or old message
        switch change.type {
        case .added:
            if let url = message.downloadURL {
                downloadImage(at: url) { image in
                guard let image = image else {
                return
                }

                message.image = image
                self.insertNewMessage(message)
                }
            }else {
                insertNewMessage(message)
            }
          
        default:
          break
        }
    }
  
    //Uploads files to Firebase
    private func uploadImage(_ image: UIImage, to topic: Topic, completion: @escaping (URL?) -> Void) {
        guard let topicID = topic.id else {
            completion(nil)
            return
        }

        guard let scaledImage = image.scaledToSafeUploadSize, let data = scaledImage.jpegData(compressionQuality: 0.4) else {
            completion(nil)
            return
        }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let imageName = [UUID().uuidString, String(Date().timeIntervalSince1970)].joined()
        storage.child(topicID).child(imageName).putData(data, metadata: metadata){ metadata, error in
            self.storage.child(topicID).child(imageName).downloadURL { (url, error) in
                if error != nil {
                    print("Error ",error as Any)
                }
                else {
                    if (url?.absoluteString) != nil {
                        self.downloadURL = url
                        var message = Message(user: self.user, image: image)
                        message.downloadURL = self.downloadURL
                        self.save(message)
                    }
                }
            }
        }
    }
    
    private func uploadFile(_ filePath: URL, completion: @escaping (URL?) -> Void) {
        guard let topicID = topic.id else {
            completion(nil)
            return
        }
        let fileName = filePath.lastPathComponent
        // Upload contact to database
        storage.child(topicID).child(fileName).putFile(from: filePath, metadata: nil) { metadata, error in
            // You can also access to download URL after upload.
            self.storage.child(topicID).child(fileName).downloadURL { (url, error) in
                if error != nil {
                    print("Error ",error as Any)
                }
                guard let downloadURL = url else {
                    return
                }
                var message = Message(user: self.user, fileURL: filePath)
                message.content = "file"
                message.fileURL = downloadURL
                self.save(message)
            }
        }
    }
    
    //Sending photo on a chat
    private func sendPhoto(_ image: UIImage) {
        isSendingPhoto = true

        uploadImage(image, to: topic) { [weak self] url in
            guard let `self` = self else {
                return
            }
            self.isSendingPhoto = false
            self.messagesCollectionView.scrollToBottom()
        }
    }
    
    //Sending photo on a chat
    private func sendFile(_ url: URL) {
        isSendingPhoto = true

        self.uploadFile(url) { [weak self] url in
            guard let `self` = self else {
                return
            }
            self.isSendingPhoto = false
            self.messagesCollectionView.scrollToBottom()
        }
    }
  
    func downloadImage(at url: URL, completion: @escaping (UIImage?) -> Void) {
        let ref = Storage.storage().reference(forURL: url.absoluteString)
        let megaByte = Int64(1 * 1024 * 1024)

        ref.getData(maxSize: megaByte) { data, error in
            guard let imageData = data else {
                completion(nil)
                return
            }

            completion(UIImage(data: imageData))
        }
    }
}

// MARK: - MessagesDisplayDelegate

extension ChatsViewController: MessagesDisplayDelegate {

    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .primary : .incomingMessage
    }

    func shouldDisplayHeader(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> Bool {
        return false
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }
}

// MARK: - MessagesLayoutDelegate
extension ChatsViewController: MessagesLayoutDelegate {

    func avatarSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return .zero
    }

    func footerViewSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return CGSize(width: 0, height: 8)
    }

    func heightForLocation(message: MessageType, at indexPath: IndexPath, with maxWidth: CGFloat, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 0
    }
}

// MARK: - MessagesDataSource
extension ChatsViewController: MessagesDataSource {
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        if messages.count == 0 {
            print("There are no messages")
            return 0
        } else {
            return messages.count
        }
    }
    
    func currentSender() -> SenderType {
        return Sender(senderId: user.uid, displayName: UserDefaultsClass.displayName)
    }

    func numberOfMessages(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
  
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(
          string: name,
          attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: UIColor(white: 0.3, alpha: 1)
          ]
        )
    }
}

// MARK: - MessageInputBarDelegate

extension ChatsViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        let message = Message(user: user, content: text)

        save(message)
        inputBar.inputTextView.text = ""
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ChatsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)

        //Resizes the image
        if let asset = info[.phAsset] as? PHAsset {
            let size = CGSize(width: 500, height: 500)
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: nil) { result, info in
                guard let image = result else {
                  return
                }

                self.sendPhoto(image)
            }
        } else if let image = info[.originalImage] as? UIImage {
            sendPhoto(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension ChatsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
         // you get from the urls parameter the urls from the files selected
        for url in urls {
            sendFile(url)
        }
    }
    
    func documentPickerControllerDidCancel(_ picker: UIDocumentPickerViewController) {
        picker.dismiss(animated: true, completion: nil)
    }
}




