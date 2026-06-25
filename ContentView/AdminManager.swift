import Foundation
import FirebaseFirestore

class AdminManager: ObservableObject {
    static let shared = AdminManager()
    @Published var isAdmin = false
    
    func reset() {
        isAdmin = false
    }
    
    func checkAdminStatus(uid: String) {
        let db = Firestore.firestore()
        db.collection("User").document(uid).getDocument { document, error in
            if let document = document, document.exists {
                self.isAdmin = document.data()?["isAdmin"] as? Bool ?? false
            }
        }
    }
    
    func deleteRecipe(recipeId: String, completion: @escaping (Bool) -> Void) {
        guard isAdmin else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        db.collection("Recipe").document(recipeId).delete { error in
            completion(error == nil)
        }
    }
    
    func deleteUser(uid: String, completion: @escaping (Bool) -> Void) {
        guard isAdmin else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        db.collection("User").document(uid).delete { error in
            if error == nil {
                // 同時刪除該用戶的所有食譜
                db.collection("Recipe")
                    .whereField("UID", isEqualTo: uid)
                    .getDocuments { snapshot, _ in
                        if let documents = snapshot?.documents {
                            let group = DispatchGroup()
                            
                            for doc in documents {
                                group.enter()
                                db.collection("Recipe").document(doc.documentID).delete { _ in
                                    group.leave()
                                }
                            }
                            
                            group.notify(queue: .main) {
                                completion(true)
                            }
                        } else {
                            completion(true)
                        }
                    }
            } else {
                completion(false)
            }
        }
    }
    
    func deleteComment(recipeId: String, commentId: String, completion: @escaping (Bool) -> Void) {
        guard isAdmin else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        db.collection("Recipe")
            .document(recipeId)
            .collection("Comment")
            .document(commentId)
            .delete { error in
                completion(error == nil)
            }
    }
} 