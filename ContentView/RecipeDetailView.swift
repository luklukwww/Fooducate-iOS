import SwiftUI
import FirebaseFirestore

struct RecipeDetailView: View {
    let recipeId: String
    
    @State private var recipeData: RecipeDetails?
    @State private var comments: [CommentData] = []
    @State private var isLoading = true
    
    struct RecipeDetails {
        let imageURL: String
        let description: String
        let likes: Int
        let uid: String
        var username: String = ""
    }
    
    struct CommentData: Identifiable {
        let id: String
        let comment: String
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else if let recipe = recipeData {
                    // 顯示圖片
                    AsyncImage(url: URL(string: recipe.imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 300)
                            .clipped()
                    } placeholder: {
                        ProgressView()
                            .frame(height: 300)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("By: \(recipe.username)")
                                .font(.headline)
                            Spacer()
                            HStack {
                                Image(systemName: "heart.fill")
                                Text("\(recipe.likes)")
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                        
                        // 描述
                        Text(recipe.description)
                            .padding(.horizontal)
                        
                        // 評論區
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Comments")
                                .font(.headline)
                                .padding(.top)
                            
                            ForEach(comments) { comment in
                                VStack(alignment: .leading) {
                                    Text(comment.comment)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchRecipeDetails()
        }
    }
    
    func fetchRecipeDetails() {
        let db = Firestore.firestore()
        
        // 獲取食譜view
        db.collection("Recipe").document(recipeId).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                let rimg = data?["rimg"] as? String ?? ""
                let description = data?["description"] as? String ?? ""
                let likes = data?["like"] as? Int ?? 0
                let uid = data?["uid"] as? String ?? ""
                
                db.collection("User").document(uid).getDocument { userDoc, error in
                    if let userDoc = userDoc, userDoc.exists {
                        let username = userDoc.data()?["uname"] as? String ?? "Unknown"
                        
                        self.recipeData = RecipeDetails(
                            imageURL: rimg,
                            description: description,
                            likes: likes,
                            uid: uid,
                            username: username
                        )
                    }
                }
                
                // 獲取評論
                db.collection("Recipe").document(recipeId)
                    .collection("Comment")
                    .getDocuments { snapshot, error in
                        if let documents = snapshot?.documents {
                            self.comments = documents.compactMap { doc -> CommentData? in
                                if let comment = doc.data()["comment"] as? String {
                                    return CommentData(id: doc.documentID, comment: comment)
                                }
                                return nil
                            }
                        }
                        self.isLoading = false
                    }
            }
        }
    }
} 
