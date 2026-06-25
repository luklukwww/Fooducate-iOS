import SwiftUI
import FirebaseFirestore

struct FollowingListView: View {
    @State private var followingUsers: [(uid: String, username: String)] = []
    @State private var isLoading = true
    @AppStorage("userUID") private var userUID: String = ""
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            } else if followingUsers.isEmpty {
                Text("Not following anyone yet")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                LazyVStack(spacing: 15) {
                    ForEach(followingUsers, id: \.uid) { user in
                        NavigationLink(destination: UserPostsView(authorUID: user.uid, authorName: user.username)) {
                            HStack {
                                Text(user.username)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 1)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchFollowingUsers()
        }
    }
    
    private func fetchFollowingUsers() {
        isLoading = true
        let db = Firestore.firestore()
        
        // 獲取當前用戶Follow
        db.collection("User")
            .document(userUID)
            .collection("Follow")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting following: \(error)")
                    isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    isLoading = false
                    return
                }
                
                let group = DispatchGroup()
                var tempUsers: [(uid: String, username: String)] = []
                
                // 獲取每個被關注用戶的用戶名
                for doc in documents {
                    group.enter()
                    let followedUID = doc.documentID
                    
                    db.collection("User").document(followedUID).getDocument { userDoc, error in
                        defer { group.leave() }
                        
                        if let userDoc = userDoc,
                           let username = userDoc.data()?["uname"] as? String {
                            tempUsers.append((uid: followedUID, username: username))
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    self.followingUsers = tempUsers.sorted { $0.username < $1.username }
                    self.isLoading = false
                }
            }
    }
} 
