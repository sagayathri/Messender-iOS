//
//  Topic.swift
//  MessengeriOS
//

import FirebaseFirestore

struct Topic {
  
  let id: String?
  let name: String
  
  init(name: String) {
    id = nil
    self.name = name
  }
  
  init?(document: QueryDocumentSnapshot) {
    let data = document.data()
    
    guard let name = data["name"] as? String else {
      return nil
    }
    
    id = document.documentID
    self.name = name
  }
  
}

extension Topic: DatabaseRepresentation {
  
  var representation: [String : Any] {
    var rep = ["name": name]
    
    if let id = id {
      rep["id"] = id
    }
    
    return rep
  }
  
}

extension Topic: Comparable {
  
  static func == (lhs: Topic, rhs: Topic) -> Bool {
    return lhs.id == rhs.id
  }
  
  static func < (lhs: Topic, rhs: Topic) -> Bool {
    return lhs.name < rhs.name
  }

}

