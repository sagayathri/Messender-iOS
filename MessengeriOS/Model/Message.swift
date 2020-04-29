//
//  Message.swift
//  MessengeriOS
//

import Firebase
import MessageKit
import FirebaseFirestore
import ContactsUI

struct Message: MessageType {
    let id: String?
    var content: String = ""
    let sentDate: Date
    let sender: SenderType
      
    var kind: MessageKind {
        if let image = image {
            let mediaItem = ImageMediaItem(image: image)
            return .photo(mediaItem)
        }
        else if content == "file" {
            let fileImage = UIImage(named: "file")
            var mediaItem = ImageMediaItem(image: fileImage!)
            mediaItem.size = CGSize(width: 100, height: 100)
            return .photo(mediaItem)
        }
        else {
            return .text(content)
        }
    }

    var messageId: String {
        return id ?? UUID().uuidString
    }

    var fileURL: URL?
    var image: UIImage?
    var downloadURL: URL? = nil
    
    init(user: User, content: String) {
        sender = Sender(senderId: user.uid, displayName: UserDefaultsClass.displayName)
        self.content = content
        sentDate = Date()
        id = nil
    }

    init(user: User, image: UIImage) {
        sender = Sender(senderId: user.uid, displayName: UserDefaultsClass.displayName)
        self.image = image
        content = ""
        sentDate = Date()
        id = nil
    }
    
    init(user: User, fileURL: URL) {
        sender = Sender(senderId: user.uid, displayName: UserDefaultsClass.displayName)
        self.fileURL = fileURL
        content = ""
        sentDate = Date()
        id = nil
    }
    
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let timestamp: Timestamp = data["created"] as? Timestamp else {
            return nil
        }
        sentDate = timestamp.dateValue()
        guard let senderID = data["senderID"] as? String else {
          return nil
        }
        guard let senderName = data["senderName"] as? String else {
          return nil
        }

        id = document.documentID

        sender = Sender(senderId: senderID , displayName: senderName)

        if let content = data["content"] as? String {
            self.content = content
        }
        else if let urlString = data["url"] as? String, let url = URL(string: urlString) {
                if self.content != "" {
                    fileURL = url
                }
                else {
                    downloadURL = url
                }
        }
        else {
            return nil
        }
    }
}

struct ImageMediaItem: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize

    init(image: UIImage) {
        self.image = image
        self.size = CGSize(width: 240, height: 240)
        self.placeholderImage = UIImage()
    }
}

extension Message: DatabaseRepresentation {
    var representation: [String : Any] {
        var rep: [String : Any] = [ "created": sentDate,
                                "senderID": sender.senderId,
                                "senderName": sender.displayName]

        if let url = downloadURL {
            rep["url"] = url.absoluteString
        }
        else if let url = fileURL {
            rep["url"] = url.absoluteString
            rep["content"] = "file"
        }else {
            rep["content"] = content
        }
        return rep
    }
}

extension Message: Comparable {
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }

    static func < (lhs: Message, rhs: Message) -> Bool {
        return lhs.sentDate < rhs.sentDate
    }
}
