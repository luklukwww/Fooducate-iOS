import SwiftUI
import FirebaseFirestore

struct AdminUserListView: View {
    @State private var users: [(uid: String, username: String, isAdmin: Bool)] = []
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var userToDelete: (uid: String, username: String)? = nil
    @StateObject private var adminManager = AdminManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(users, id: \.uid) { user in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(user.username)
                                .font(.headline)
                            Text(user.uid)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if user.isAdmin {
                            Text("Admin")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                        }
                        
                        if !user.isAdmin {
                            Button(role: .destructive) {
                                userToDelete = (user.uid, user.username)
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Users")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .alert("Delete User", isPresented: $showDeleteAlert, presenting: userToDelete) { user in
            Button("Delete", role: .destructive) {
                deleteUser(uid: user.uid)
            }
            Button("Cancel", role: .cancel) { }
        } message: { user in
            Text("Are you sure you want to delete user '\(user.username)'?")
        }
        .onAppear {
            fetchUsers()
        }
        .refreshable {
            await refresh()
        }
    }
    
    private func fetchUsers() {
        let db = Firestore.firestore()
        db.collection("User").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting users: \(error)")
                isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                isLoading = false
                return
            }
            
            self.users = documents.compactMap { doc -> (uid: String, username: String, isAdmin: Bool)? in
                guard let username = doc.data()["uname"] as? String else { return nil }
                let isAdmin = doc.data()["isAdmin"] as? Bool ?? false
                return (uid: doc.documentID, username: username, isAdmin: isAdmin)
            }.sorted { $0.username < $1.username }
            
            isLoading = false
        }
    }
    
    private func deleteUser(uid: String) {
        adminManager.deleteUser(uid: uid) { success in
            if success {
                users.removeAll { $0.uid == uid }
            }
        }
    }
    
    private func refresh() async {
        await MainActor.run {
            isLoading = true
            fetchUsers()
        }
    }
} 
