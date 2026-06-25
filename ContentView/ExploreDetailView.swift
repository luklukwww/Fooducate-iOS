import SwiftUI
import FirebaseFirestore

private let chatService = ChatService(
    mixraiKey: "YOUR_AI_HERE",
    deepseekKey: "YOUR_AI_HERE"
)

struct ExploreDetailView: View {
    let recipeId: String
    
    @State private var recipeImage: String = ""
    @State private var description: String = ""
    @State private var likes: Int = 0
    @State private var comments: [Comment] = []
    @State private var username: String = ""
    @State private var userProfileImage: String = ""
    @State private var isLoading = true
    @State private var isLiked = false
    @State private var showLoginAlert = false
    @AppStorage("userUID") private var userUID: String = ""
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var isRefreshing = false
    @State private var recommendedRecipes: [SpoonacularRecipe] = []
    @State private var currentPage = 0
    private let recipesPerPage = 5
    @State private var isLoadingRecommendations = false
    @State private var isFollowing = false
    @State private var authorUID = ""
    @State private var followCount: Int = 0
    @State private var recipeDetails: RecipeDetails?
    @StateObject private var adminManager = AdminManager.shared
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    @State private var showingBenefits = true
    @State private var showCookingSteps = false
    @State private var showRecipeFamiliaritySelection = false
    @State private var commentText: String = ""
    @State private var isSubmitting = false
    @State private var aiHealthAssessment: String = ""
    @State private var isLoadingAI = false
    @State private var targetData: TargetData?
    @State private var allergyData: [String] = []
    @State private var hasTargetData = false
    @State private var hasAllergyData = false
    @State private var recipeKnowledgeForKnowledge: Bool = true // Default to "Familiar"
    @State private var useDefaultFlavor: Bool = true // Default to "Default Flavor"
    @State private var isProcessingStepsForKnowledge: Bool = false
    @State private var optimizedStepsForKnowledge: [String] = []
    @State private var isRecipeAuthor: Bool = false
    
    // 計時器相關屬性
    @State private var viewStartTime: Date?
    @State private var hasAnalyzedRecipe: Bool = false
    @State private var timerWorkItem: DispatchWorkItem?
    
    // 添加新的狀態變量
    @State private var customFlavor: String = ""
    @State private var showFlavorSelectionSheet = false
    @State private var isCustomFlavor = false
    
    struct Comment: Identifiable {
        let id: String
        let text: String
        let uid: String
        var username: String = "Unknown"
        var userProfileImage: String = ""
    }
    
    struct SpoonacularRecipe: Codable, Identifiable {
        let id: Int
        let title: String
        let image: String
    }
    
    struct SpoonacularResponse: Codable {
        let results: [SpoonacularRecipe]
    }
    
    struct RecipeDetails {
        var category: String
        var createDate: Date?
        var recipeName: String
        var ingredients: [IngredientDetail]
        var nutritions: [NutritionDetail]
        var steps: [String]
        
        struct IngredientDetail {
            var name: String
            var value: String
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部图片
                AsyncImage(url: URL(string: recipeImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipped()
                } placeholder: {
                    ProgressView()
                        .frame(height: 300)
                }
                
                // 主要内容
                VStack(alignment: .leading, spacing: 20) {
                    if let details = recipeDetails {
                        // 标题和作者信息
                        VStack(alignment: .leading, spacing: 12) {
                            Text(details.recipeName)
                                .font(.title)
                                .bold()
                            
                            // AI Health Assessment
                            if !aiHealthAssessment.isEmpty && isLoggedIn {
                                Text("By Flavour Dietitian:")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .padding(.top, 4)
                                
                                Text(aiHealthAssessment)
                                    .font(.body)
                                    .foregroundColor(.black)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                            } else if isLoadingAI && isLoggedIn {
                                ProgressView()
                                    .padding(.top, 8)
                            }
                            
                            HStack {
                                // User profile image
                                if !userProfileImage.isEmpty {
                                    AsyncImage(url: URL(string: userProfileImage.replacingOccurrences(of: "@", with: ""))) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 30, height: 30)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 30, height: 30)
                                    }
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 30, height: 30)
                                }
                                
                                Text("By: \(username)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                if userUID != authorUID && !authorUID.isEmpty {
                                    Button(action: handleFollow) {
                                        Text(isFollowing ? "Following" : "Follow")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(isFollowing ? Color.gray : Color.orange.opacity(0.8))
                                            .cornerRadius(15)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: handleLike) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isLiked ? "heart.fill" : "heart")
                                        Text("\(likes)")
                                    }
                                    .foregroundColor(isLiked ? .red : .gray)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 分类和日期
                        HStack {
                            CategoryPill(text: details.category)
                            if let date = details.createDate {
                                Text("•")
                                    .foregroundColor(.gray)
                                Text(date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 描述
                        Text(description)
                            .padding(.horizontal)
                        
                        // 配料部分
                        RecipeSection(title: "Ingredients") {
                            ForEach(details.ingredients, id: \.name) { ingredient in
                                HStack {
                                    Text("•")
                                        .foregroundColor(.orange)
                                    Text(ingredient.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(ingredient.value)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        // 营养成分
                        RecipeSection(title: "Nutrition Facts") {
                            ForEach(details.nutritions) { nutrition in
                                HStack {
                                    Text(nutrition.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(nutrition.value)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        
                        // 步骤
                        RecipeSection(title: "Steps") {
                            ForEach(Array(details.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 15) {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Color.orange)
                                        .clipShape(Circle())
                                    
                                    Text(step)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        
                        // Recipe Familiarity Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recipe Familiarity:")
                                .font(.headline)
                                .foregroundColor(.orange)
                                .padding(.top, 16)
                            
                            HStack(spacing: 12) {
                                // Familiar option
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        recipeKnowledgeForKnowledge = true
                                        optimizedStepsForKnowledge = [] // Clear optimized steps when toggling
                                    }
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "person.fill.checkmark")
                                            .font(.system(size: 24))
                                            .foregroundColor(recipeKnowledgeForKnowledge ? .white : .orange)
                                            .frame(width: 48, height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(recipeKnowledgeForKnowledge ? Color.orange : Color.orange.opacity(0.1))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(recipeKnowledgeForKnowledge ? Color.orange : Color.clear, lineWidth: 2)
                                            )
                                            .shadow(color: recipeKnowledgeForKnowledge ? Color.orange.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 2)
                                        
                                        Text("Familiar")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(recipeKnowledgeForKnowledge ? .orange : .gray)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(recipeKnowledgeForKnowledge ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(recipeKnowledgeForKnowledge ? Color.orange : Color.gray.opacity(0.1), lineWidth: 1.5)
                                    )
                                }
                                
                                // Unfamiliar option
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        recipeKnowledgeForKnowledge = false
                                        optimizedStepsForKnowledge = [] // Clear optimized steps when toggling
                                    }
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "person.fill.questionmark")
                                            .font(.system(size: 24))
                                            .foregroundColor(!recipeKnowledgeForKnowledge ? .white : .orange)
                                            .frame(width: 48, height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(!recipeKnowledgeForKnowledge ? Color.orange : Color.orange.opacity(0.1))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(!recipeKnowledgeForKnowledge ? Color.orange : Color.clear, lineWidth: 2)
                                            )
                                            .shadow(color: !recipeKnowledgeForKnowledge ? Color.orange.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 2)
                                        
                                        Text("Unfamiliar")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(!recipeKnowledgeForKnowledge ? .orange : .gray)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(!recipeKnowledgeForKnowledge ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(!recipeKnowledgeForKnowledge ? Color.orange : Color.gray.opacity(0.1), lineWidth: 1.5)
                                    )
                                }
                            }
                            
                            // Description text for selection
                            Text(recipeKnowledgeForKnowledge ? 
                                 "You're familiar with this recipe. Instructions will be concise and straightforward." : 
                                 "You're new to this recipe. Instructions will be detailed with additional guidance.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                                .padding(.horizontal, 2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal)
                        
                        // Flavor Preference Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Flavor Preference:")
                                .font(.headline)
                                .foregroundColor(.orange)
                                .padding(.top, 16)
                            
                            VStack(spacing: 10) {
                                // Default Flavor option
                                FlavorOptionCard(
                                    isSelected: useDefaultFlavor && !isCustomFlavor,
                                    icon: "fork.knife.circle.fill",
                                    title: "Default Flavor",
                                    description: "Follow the original recipe with standard flavoring",
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            useDefaultFlavor = true
                                            isCustomFlavor = false
                                            optimizedStepsForKnowledge = []
                                        }
                                    }
                                )
                                
                                // Personalized Flavor option
                                FlavorOptionCard(
                                    isSelected: !useDefaultFlavor && !isCustomFlavor,
                                    icon: "flame.circle.fill",
                                    title: "Personalized Flavor",
                                    description: "Adapt the recipe to your personal flavor preferences",
                                    isDisabled: !isLoggedIn,
                                    action: {
                                        if isLoggedIn {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                useDefaultFlavor = false
                                                isCustomFlavor = false
                                                optimizedStepsForKnowledge = []
                                            }
                                        } else {
                                            showLoginAlert = true
                                        }
                                    }
                                )
                                
                                // 顯示自定義口味選項（如果已選擇）
                                if isCustomFlavor && !customFlavor.isEmpty {
                                    FlavorOptionCard(
                                        isSelected: isCustomFlavor,
                                        icon: "slider.horizontal.3",
                                        title: "Custom Flavor",
                                        description: "Selected: \(customFlavor)",
                                        action: {
                                            showFlavorSelectionSheet = true
                                        }
                                    )
                                }
                                
                                // 更多選項按鈕
                                Button(action: {
                                    showFlavorSelectionSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "ellipsis.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.orange)
                                        
                                        Text("More Options")
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Start Cooking 按鈕 - 移到最上層
                        Button(action: handleStartCooking) {
                            HStack {
                                Text(isProcessingStepsForKnowledge ? "Processing Recipe..." : "Start Cooking")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if isProcessingStepsForKnowledge {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                        .padding(.leading, 5)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isProcessingStepsForKnowledge ? Color.gray : Color.orange)
                            .cornerRadius(15)
                        }
                        .disabled(isProcessingStepsForKnowledge)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .zIndex(1) // 確保按鈕在最上層
                        
                        // 評論區
                        RecipeSection(title: "Comments (\(comments.count))") {
                            if comments.isEmpty {
                                Text("No comments yet")
                                    .foregroundColor(.gray)
                                    .padding(.vertical)
                            } else {
                                ForEach(comments) { comment in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            // Commenter profile image
                                            if !comment.userProfileImage.isEmpty {
                                                AsyncImage(url: URL(string: comment.userProfileImage.replacingOccurrences(of: "@", with: ""))) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 24, height: 24)
                                                        .clipShape(Circle())
                                                } placeholder: {
                                                    Circle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 24, height: 24)
                                                }
                                            } else {
                                                Circle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 24, height: 24)
                                            }
                                            
                                            Text(comment.username)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            
                                            Spacer()
                                            
                                            // 管理員刪除評論按鈕
                                            if adminManager.isAdmin {
                                                Button(role: .destructive) {
                                                    deleteComment(commentId: comment.id)
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.red)
                                                        .imageScale(.small)
                                                }
                                            }
                                        }
                                        
                                        Text(comment.text)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Divider()
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                            
                            // 評論輸入區
                            if isLoggedIn {
                                HStack {
                                    TextField("Write a comment...", text: $commentText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .disabled(isSubmitting)
                                    
                                    Button(action: sendComment) {
                                        if isSubmitting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                        } else {
                                            Image(systemName: "paperplane.fill")
                                                .foregroundColor(.orange.opacity(0.8))
                                        }
                                    }
                                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .allowsHitTesting(true)
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Please login to comment")
                                        .foregroundColor(.gray)
                                    
                                    NavigationLink(destination: ProfileView()) {
                                        Text("Login")
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.orange.opacity(0.8))
                                            .cornerRadius(10)
                                    }
                                }
                                .padding(.top)
                            }
                        }
                    }
                }
                .padding(.top, 20)
            }
        }
        .overlay(
            // 頂部按鈕區域
            HStack {
                // 返回按鈕，固定在左上角
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.orange)
                        .padding(10)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                }
                
                Spacer()
                
                // 管理員或作者刪除按鈕 - 重構邏輯確保正確顯示
                if isLoggedIn {
                    // 從 AppStorage 重新獲取 userUID，確保是最新的
                    let currentUID = UserDefaults.standard.string(forKey: "userUID") ?? ""
                    
                    if authorUID == currentUID || adminManager.isAdmin {
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(10)
                                .background(Circle().fill(Color.white))
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 50)
            .padding(.bottom, 10)
            , alignment: .top
        )
        .edgesIgnoringSafeArea(.top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .alert("Please Login", isPresented: $showLoginAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need to login.")
        }
        .alert("Delete Recipe", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                // 從 AppStorage 重新獲取 userUID，確保是最新的
                let currentUID = UserDefaults.standard.string(forKey: "userUID") ?? ""
                
                // 檢查當前用戶是否為食譜作者或管理員
                if authorUID == currentUID {
                    // 如果用戶是作者，直接刪除
                    deleteRecipe()
                } else if adminManager.isAdmin {
                    // 如果用戶是管理員，使用管理員刪除方法
                    adminManager.deleteRecipe(recipeId: recipeId) { success in
                        if success {
                            dismiss()
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this recipe?")
        }
        .onAppear {

            print("ExploreDetailView onAppear - UserUID: \(userUID), IsLoggedIn: \(isLoggedIn)")
            
            fetchRecipeDetails()
            checkIfLiked()
            // 只在用戶登入時檢查管理員狀態和是否為作者
            if isLoggedIn {
                adminManager.checkAdminStatus(uid: userUID)
            }
        }
        .onDisappear {
            // Cancel the timer if the view disappears
            timerWorkItem?.cancel()
        }
        .sheet(isPresented: $showCookingSteps) {
            if let details = recipeDetails {
                let ingredients = details.ingredients.map { ingredient in
                    IngredientDetail(name: ingredient.name, value: ingredient.value)
                }
                
                let relevantNutritions = details.nutritions.filter { nutrition in
                    ["Calories", "Carbohydrates", "Fat", "Protein"].contains(nutrition.name)
                }
                
                CookingStepsView(cookingSteps: CookingSteps(
                    ingredients: ingredients,
                    steps: !optimizedStepsForKnowledge.isEmpty ? optimizedStepsForKnowledge : details.steps,
                    nutritions: relevantNutritions,
                    isUserLoggedIn: isLoggedIn
                ))
            }
        }
        .sheet(isPresented: $showRecipeFamiliaritySelection) {
            RecipeFamiliaritySelectionView(
                recipeKnowledge: $recipeKnowledgeForKnowledge,
                useDefaultFlavor: $useDefaultFlavor,
                onSelection: {
                    showRecipeFamiliaritySelection = false
                    
                    // Process the recipe with selected options
                    if let details = recipeDetails {
                        processRecipeStepsForKnowledge(details.steps)
                    }
                }
            )
        }
        .sheet(isPresented: $showFlavorSelectionSheet) {
            FlavorSelectionSheet(selectedFlavor: $customFlavor)
                .onDisappear {
                    if !customFlavor.isEmpty {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            useDefaultFlavor = false
                            isCustomFlavor = true
                            optimizedStepsForKnowledge = []
                        }
                    }
                }
        }
    }
    
    func fetchRecipeDetails() {
        print("Fetching recipe details for ID: \(recipeId)")
        let db = Firestore.firestore()
        
        db.collection("Recipe").document(recipeId).getDocument { document, error in
            if let error = error {
                print("Error fetching recipe: \(error.localizedDescription)")
                self.isLoading = false
                return
            }
            
            guard let document = document, document.exists else {
                print("Recipe document not found")
                self.isLoading = false
                return
            }
            
            let data = document.data()
            self.recipeImage = data?["RecipeImg"] as? String ?? ""
            self.description = data?["description"] as? String ?? ""
            self.likes = data?["like"] as? Int ?? 0
            
            // 解析食谱详细信息
            let ingredients = (data?["ingredients"] as? [[String: Any]])?.map { ingredient in
                RecipeDetails.IngredientDetail(
                    name: ingredient["name"] as? String ?? "",
                    value: ingredient["value"] as? String ?? ""
                )
            } ?? []
            
            // 修复营养信息的解析
            let nutritions = (data?["nutritions"] as? [[String: Any]])?.map { nutrition in
                NutritionDetail(
                    name: nutrition["name"] as? String ?? "",
                    value: nutrition["value"] as? String ?? ""
                )
            } ?? []
            
            self.recipeDetails = RecipeDetails(
                category: data?["Category"] as? String ?? "",
                createDate: (data?["CreateDate"] as? Timestamp)?.dateValue(),
                recipeName: data?["Rname"] as? String ?? "",
                ingredients: ingredients,
                nutritions: nutritions,
                steps: data?["steps"] as? [String] ?? []
            )
            

            self.viewStartTime = Date()
            self.startViewDurationTimer()
            // 直接獲取推薦食譜，不需要先進行食物檢測
            self.fetchRecommendations()
            
            // Get user info
            if let uid = data?["UID"] as? String {
                self.authorUID = uid
                
                // 從 AppStorage 重新獲取 userUID
                let currentUID = UserDefaults.standard.string(forKey: "userUID") ?? ""
                self.isRecipeAuthor = (uid == currentUID)
                
                // 添加日誌以檢查作者身份
                print("Recipe UID: \(uid), Current User UID: \(currentUID), Is Author: \(self.isRecipeAuthor), Is Admin: \(self.adminManager.isAdmin), Is Logged In: \(self.isLoggedIn)")
                
                // 獲取作者用戶信息
                db.collection("User").document(uid).getDocument { userDoc, error in
                    if let error = error {
                        print("Error fetching author info: \(error.localizedDescription)")
                        return
                    }
                    
                    if let userDoc = userDoc, userDoc.exists {
                        self.username = userDoc.data()?["uname"] as? String ?? "Unknown"
                        self.userProfileImage = userDoc.data()?["uimg"] as? String ?? ""
                        self.followCount = userDoc.data()?["follow"] as? Int ?? 0
                        print("Author username loaded: \(self.username)")
                        print("Author profile image: \(self.userProfileImage)")
                    } else {
                        print("Author document not found")
                    }
                    
                    // 在加載完作者信息後設置 isLoading 為 false
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
                
                // 檢查是否已關注
                if isLoggedIn {
                    db.collection("User")
                        .document(userUID)
                        .collection("Follow")
                        .document(uid)
                        .getDocument { (document, _) in
                            isFollowing = document?.exists ?? false
                        }
                }
            } else {
                // 如果沒有找到作者ID，直接設置 isLoading 為 false
                self.isLoading = false
            }
            
            // Get comments
            db.collection("Recipe").document(recipeId)
                .collection("Comment")
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching comments: \(error.localizedDescription)")
                        return
                    }
                    
                    if let documents = snapshot?.documents {
                        var tempComments = documents.compactMap { doc -> Comment? in
                            guard let commentText = doc.data()["comennt"] as? String,
                                  let uid = doc.data()["uid"] as? String else {
                                return nil
                            }
                            return Comment(id: doc.documentID, text: commentText, uid: uid)
                        }
                        
                        // 获取评论用户名
                        let group = DispatchGroup()
                        
                        for (index, comment) in tempComments.enumerated() {
                            group.enter()
                            db.collection("User").document(comment.uid).getDocument { userDoc, error in
                                if let userDoc = userDoc, userDoc.exists,
                                   let username = userDoc.data()?["uname"] as? String {
                                    tempComments[index].username = username
                                    tempComments[index].userProfileImage = userDoc.data()?["uimg"] as? String ?? ""
                                }
                                group.leave()
                            }
                        }
                        
                        group.notify(queue: .main) {
                            self.comments = tempComments
                        }
                    }
                }
            
            // 添加用戶數據獲取和AI評估
            if self.isLoggedIn {
                self.fetchUserData()
            }
        }
    }
    
    // 新增 - 開始計時並在10秒後分析食譜
    private func startViewDurationTimer() {
        // Cancel any existing timer
        timerWorkItem?.cancel()
        
        // Create a new work item for the timer
        let workItem = DispatchWorkItem {
            self.analyzeRecipeAfterDuration()
        }
        
        // Store the work item reference so we can cancel it if needed
        timerWorkItem = workItem
        
        // Schedule the work item to execute after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
    }
    
    // 新增 - 計算瀏覽時長並在超過閾值時分析食譜
    private func analyzeRecipeAfterDuration() {
        // 確保用戶已登入且還沒有分析過這個食譜
        guard let viewStartTime = viewStartTime,
              isLoggedIn,
              !hasAnalyzedRecipe,
              !userUID.isEmpty,
              let details = recipeDetails
        else { return }
        
        // 確認已經過了10秒
        let viewDuration = Date().timeIntervalSince(viewStartTime)
        if viewDuration >= 10.0 {
            // 標記為已分析，避免重複分析
            hasAnalyzedRecipe = true
            
            // 準備食譜詳情的字符串
            var recipeInfo = "Recipe Name: \(details.recipeName)\n"
            recipeInfo += "Category: \(details.category)\n"
            recipeInfo += "Ingredients:\n"
            for ingredient in details.ingredients {
                recipeInfo += "- \(ingredient.name): \(ingredient.value)\n"
            }
            
            recipeInfo += "Steps:\n"
            for (index, step) in details.steps.enumerated() {
                recipeInfo += "Step \(index + 1): \(step)\n"
            }
            
            recipeInfo += "Description: \(description)\n"
            
            // 打印用於確認
            print("已瀏覽食譜 \(details.recipeName) 超過10秒，正在使用AI分析食譜...")
            
            // 用AI分析食譜
            RecipeAnalysisService.shared.analyzeRecipe(recipeDetails: recipeInfo) { flavor, foodType, error in
                if let error = error {
                    print("AI分析食譜時出錯: \(error.localizedDescription)")
                    
                    // 錯誤時使用默認值 - 根據食譜名稱進行簡單推斷
                    let defaultFlavor = self.inferDefaultFlavor(title: details.recipeName, category: details.category)
                    let defaultType = self.inferDefaultType(title: details.recipeName, category: details.category)
                    
                    print("使用默認值 - 口味: \(defaultFlavor), 類型: \(defaultType)")
                    RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: defaultFlavor)
                    RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: defaultType)
                    return
                }
                
                if let flavor = flavor, let foodType = foodType {
                    print("AI分析結果 - 口味: \(flavor), 類型: \(foodType)")
                    
                    // 更新數據庫中的用戶偏好
                    RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: flavor)
                    RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: foodType)
                } else {
                    // API返回空值時也使用默認值
                    let defaultFlavor = self.inferDefaultFlavor(title: details.recipeName, category: details.category)
                    let defaultType = self.inferDefaultType(title: details.recipeName, category: details.category)
                    
                    print("API未返回有效值，使用默認值 - 口味: \(defaultFlavor), 類型: \(defaultType)")
                    
                    RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: defaultFlavor)
                    RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: defaultType)
                }
            }
        }
    }
    
    // 根據食譜標題推斷默認口味
    private func inferDefaultFlavor(title: String, category: String) -> String {
        let lowercaseTitle = title.lowercased()
        let lowercaseCategory = category.lowercased()
        
        // 首先檢查類別
        if lowercaseCategory.contains("spicy") || lowercaseCategory.contains("hot") {
            return "Spicy"
        } else if lowercaseCategory.contains("sweet") || lowercaseCategory.contains("dessert") {
            return "Sweet"
        } else if lowercaseCategory.contains("sour") {
            return "Sour"
        } else if lowercaseCategory.contains("bitter") {
            return "Bitter"
        }
        
        // 然後檢查標題
        if lowercaseTitle.contains("spicy") || lowercaseTitle.contains("hot") || 
           lowercaseTitle.contains("chili") || lowercaseTitle.contains("pepper") {
            return "Spicy"
        } else if lowercaseTitle.contains("sweet") || lowercaseTitle.contains("sugar") || 
                  lowercaseTitle.contains("honey") || lowercaseTitle.contains("chocolate") {
            return "Sweet"
        } else if lowercaseTitle.contains("sour") || lowercaseTitle.contains("lemon") || 
                  lowercaseTitle.contains("vinegar") || lowercaseTitle.contains("pickle") {
            return "Sour"
        } else if lowercaseTitle.contains("bitter") || lowercaseTitle.contains("coffee") || 
                  lowercaseTitle.contains("beer") || lowercaseTitle.contains("green tea") {
            return "Bitter"
        } else {
            // 默認口味為Savory
            return "Savory"
        }
    }
    
    // 根據食譜標題推斷默認類型
    private func inferDefaultType(title: String, category: String) -> String {
        let lowercaseTitle = title.lowercased()
        let lowercaseCategory = category.lowercased()
        
        // 首先檢查類別
        if lowercaseCategory.contains("chinese") {
            return "Chinese"
        } else if lowercaseCategory.contains("italian") {
            return "Italian"
        } else if lowercaseCategory.contains("japanese") {
            return "Japanese"
        } else if lowercaseCategory.contains("mexican") {
            return "Mexican"
        } else if lowercaseCategory.contains("american") {
            return "American"
        } else if lowercaseCategory.contains("middle eastern") {
            return "Middle Eastern"
        } else if lowercaseCategory.contains("indian") {
            return "Indian"
        }
        
        // 然後檢查標題
        if lowercaseTitle.contains("chinese") || lowercaseTitle.contains("stir fry") || 
           lowercaseTitle.contains("soy sauce") || lowercaseTitle.contains("wok") {
            return "Chinese"
        } else if lowercaseTitle.contains("italian") || lowercaseTitle.contains("pasta") || 
                  lowercaseTitle.contains("pizza") || lowercaseTitle.contains("risotto") {
            return "Italian"
        } else if lowercaseTitle.contains("japanese") || lowercaseTitle.contains("sushi") || 
                  lowercaseTitle.contains("miso") || lowercaseTitle.contains("teriyaki") {
            return "Japanese"
        } else if lowercaseTitle.contains("mexican") || lowercaseTitle.contains("taco") || 
                  lowercaseTitle.contains("burrito") || lowercaseTitle.contains("salsa") {
            return "Mexican"
        } else if lowercaseTitle.contains("american") || lowercaseTitle.contains("burger") || 
                  lowercaseTitle.contains("bbq") || lowercaseTitle.contains("grill") {
            return "American"
        } else if lowercaseTitle.contains("middle eastern") || lowercaseTitle.contains("hummus") || 
                  lowercaseTitle.contains("falafel") || lowercaseTitle.contains("tahini") {
            return "Middle Eastern"
        } else if lowercaseTitle.contains("indian") || lowercaseTitle.contains("curry") || 
                  lowercaseTitle.contains("masala") || lowercaseTitle.contains("tandoori") {
            return "Indian"
        } else {
            // 默認類型為Other
            return "Other"
        }
    }
    
    //推薦食譜
    private func fetchRecommendations() {
        isLoadingRecommendations = true
        let apiKey = "YOUR_API_KEY_HERE"
        let urlString = "https://api.spoonacular.com/recipes/complexSearch?sort=popularity&number=5&apiKey=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.isLoadingRecommendations = false
                self.recommendedRecipes = []
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingRecommendations = false
                
                if let error = error {
                    print("Request error: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(SpoonacularResponse.self, from: data)
                    self.recommendedRecipes = response.results
                } catch {
                    print("Decoding error: \(error)")
                }
            }
        }.resume()
    }
    
    private func handleLike() {
        guard isLoggedIn else {
            showLoginAlert = true
            return
        }
        
        let db = Firestore.firestore()
        let recipeRef = db.collection("Recipe").document(recipeId)
        
        if isLiked {
            // Remove like
            recipeRef.updateData([
                "like": FieldValue.increment(Int64(-1))
            ]) { error in
                if error == nil {
                    likes -= 1
                    isLiked = false
                    removeLikeFromUser()
                }
            }
        } else {
            // Add like
            recipeRef.updateData([
                "like": FieldValue.increment(Int64(1))
            ]) { error in
                if error == nil {
                    likes += 1
                    isLiked = true
                    addLikeToUser()
                    
                    // 在按讚時分析食譜並記錄口味和類型
                    self.analyzeRecipeForLike()
                }
            }
        }
    }
    
    private func checkIfLiked() {
        // 只在用戶登入時檢查點讚狀態
        guard isLoggedIn else { return }
        
        let db = Firestore.firestore()
        db.collection("User").document(userUID)
            .collection("Likes").document(recipeId).getDocument { document, error in
                if let document = document, document.exists {
                    isLiked = true
                }
            }
    }
    
    private func addLikeToUser() {
        let db = Firestore.firestore()
        db.collection("User").document(userUID)
            .collection("Likes").document(recipeId).setData([:])
    }
    
    private func removeLikeFromUser() {
        let db = Firestore.firestore()
        db.collection("User").document(userUID)
            .collection("Likes").document(recipeId).delete()
    }
    
    private func refresh() async {
        isRefreshing = true
        // 重新獲取
        
        fetchRecipeDetails()
        isRefreshing = false
    }
    
    private func handleFollow() {
        guard isLoggedIn else {
            showLoginAlert = true
            return
        }
        
        let db = Firestore.firestore()
        let followRef = db.collection("User")
            .document(userUID)
            .collection("Follow")
            .document(authorUID)
        
        let authorRef = db.collection("User").document(authorUID)
        
        if isFollowing {
            // 取消關注
            followRef.delete { error in
                if error == nil {
                    // 更新 follow 計數
                    authorRef.updateData([
                        "follow": FieldValue.increment(Int64(-1))
                    ]) { error in
                        if error == nil {
                            isFollowing = false
                            followCount -= 1
                        }
                    }
                }
            }
        } else {
            // 添加關注
            followRef.setData([:]) { error in
                if error == nil {
                    // 更新 follow 計數
                    authorRef.updateData([
                        "follow": FieldValue.increment(Int64(1))
                    ]) { error in
                        if error == nil {
                            isFollowing = true
                            followCount += 1
                        }
                    }
                }
            }
        }
    }
    
    // 添加刪除評論的函數
    private func deleteComment(commentId: String) {
        adminManager.deleteComment(recipeId: recipeId, commentId: commentId) { success in
            if success {
                // 從列表中移除評論
                comments.removeAll { $0.id == commentId }
            }
        }
    }
    
    private func handleStartCooking() {
        guard let details = recipeDetails else { return }
        
        // Instead of showing the selection view again, directly process the recipe steps
        // with the familiarity level that's already been selected in the UI
        if !details.steps.isEmpty {
            processRecipeStepsForKnowledge(details.steps)
        }
    }
    
    private func processRecipeStepsForKnowledge(_ steps: [String]) {
        isProcessingStepsForKnowledge = true
        
        // Fetch user's flavor preference if needed
        var userFlavorPreference = "balanced"
        if !useDefaultFlavor && isLoggedIn {
            // Attempt to fetch the user's flavor preference from Firestore
            let db = Firestore.firestore()
            db.collection("User").document(userUID).getDocument { document, error in
                if let document = document, document.exists,
                   let flavorPref = document.data()?["flavor_preference"] as? String {
                    userFlavorPreference = flavorPref
                }
                // Continue with AI processing after getting flavor preference
                self.processWithAI(steps: steps, flavorPreference: userFlavorPreference)
            }
        } else {
            // Use default flavor
            processWithAI(steps: steps, flavorPreference: nil)
        }
    }
    
    private func processWithAI(steps: [String], flavorPreference: String?) {
        // Build the request message for AI
        let stepsText = steps.enumerated().map { index, step in
            return "Step \(index + 1): \(step.trimmingCharacters(in: .whitespacesAndNewlines))"
        }.joined(separator: "\n")
        
        // Prepare context message based on familiarity
        var contextMessage = """
        Recipe: \(recipeDetails?.recipeName ?? "Recipe")
        
        Original Recipe Steps:
        \(stepsText)
        
        """
        
        // Add flavor preference context if available
        if !useDefaultFlavor {
            if isCustomFlavor && !customFlavor.isEmpty {
                // 使用自定義口味
                contextMessage += """
                The user prefers \(customFlavor) flavors. Please adapt the recipe to enhance these flavor preferences while keeping the dish's integrity.
                
                """
            } else if flavorPreference != nil {
                // 使用用戶偏好口味
                contextMessage += """
                The user prefers \(flavorPreference!) flavors. Please adapt the recipe to enhance these flavor preferences while keeping the dish's integrity.
                
                """
            }
        }
        
        if recipeKnowledgeForKnowledge {
            // Familiar with recipe - AI should optimize steps
            contextMessage += """
            The user is familiar with this recipe. Please optimize the cooking steps by:
            1. Fixing any typos or unclear instructions
            2. Ensuring each step is clear and concise
            3. Maintaining the original step sequence
            4. Keeping the original meaning intact
            """
            
            if !useDefaultFlavor && flavorPreference != nil {
                contextMessage += """
                5. Adjusting seasoning and flavoring to match the user's preference for \(flavorPreference!) flavors
                """
            }
            
            contextMessage += """
            
            Respond with ONLY the optimized steps. Format each step as:
            Step 1: [Optimized instruction]
            Step 2: [Optimized instruction]
            ...and so on.
            """
        } else {
            // Not familiar with recipe - AI should provide detailed steps
            contextMessage += """
            The user is NOT familiar with this recipe. Please break down each step into individual actions, where each action becomes its own separate step. For example:
            
            ORIGINAL:
            "Mix the ingredients, place in oven and bake for 30 minutes, then let cool."
            
            SHOULD BECOME:
            Step 1: Gather all ingredients in a mixing bowl.
            Step 2: Mix the ingredients thoroughly until well combined.
            Step 3: Preheat the oven to 350°F (175°C).
            Step 4: Transfer the mixture to a baking dish.
            Step 5: Place the baking dish in the center of the oven.
            Step 6: Set a timer for 30 minutes.
            Step 7: Check for doneness by inserting a toothpick (it should come out clean).
            Step 8: Remove from the oven using oven mitts.
            Step 9: Let cool for 15 minutes before serving.
            
            Important guidelines:
            1. Break down EVERY complex step into individual actions
            2. Make each action its own separate numbered step
            3. Include specific details about:
               - Exact measurements and timings
               - Temperature settings
               - Visual cues for doneness
               - Tools needed for each step
            4. Include preparation steps (preheating, gathering tools, etc.)
            5. Add safety tips where relevant
            6. Explain cooking techniques in simple terms for beginners
            """
            
            if !useDefaultFlavor && flavorPreference != nil {
                contextMessage += """
                7. Suggest adjustments to seasoning and flavoring to match the user's preference for \(flavorPreference!) flavors
                """
            }
            
            contextMessage += """
            
            Respond with ONLY the detailed steps. Format each step as:
            Step 1: [Single action instruction]
            Step 2: [Single action instruction]
            ...and so on.
            """
        }
        
        print("Sending to AI for recipe processing:\n\(contextMessage)")
        
        // Send to AI for processing
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                print("AI Response for steps:\n\(response)")
                
                await MainActor.run {
                    // Process the response and extract steps
                    let processedSteps = processAIResponseForKnowledge(response)
                    
                    // Save processed steps
                    optimizedStepsForKnowledge = processedSteps
                    
                    // Show cooking steps with optimized instructions
                    isProcessingStepsForKnowledge = false
                    showCookingSteps = true
                }
            } catch {
                print("Error getting AI response for steps: \(error)")
                await MainActor.run {
                    isProcessingStepsForKnowledge = false
                    
                    // If error, just use the original steps
                    if let details = recipeDetails {
                        optimizedStepsForKnowledge = details.steps
                        showCookingSteps = true
                    }
                }
            }
        }
    }
    
    private func processAIResponseForKnowledge(_ response: String) -> [String] {
        // Split response into individual steps
        let lines = response.split(separator: "\n")
        var processedSteps: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.starts(with: "Step") {
                // Extract step content (remove the "Step X: " prefix)
                if let content = trimmedLine.range(of: "Step \\d+:\\s*", options: .regularExpression) {
                    let stepContent = trimmedLine[content.upperBound...]
                    if !stepContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        processedSteps.append(String(stepContent))
                    }
                } else {

                    processedSteps.append(trimmedLine)
                }
            } else if !trimmedLine.isEmpty && !processedSteps.isEmpty {

                processedSteps[processedSteps.count - 1] += " " + trimmedLine
            }
        }
        

        return processedSteps
    }
    
    private func sendComment() {
        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSubmitting = true
        
        let db = Firestore.firestore()
        let commentData: [String: Any] = [
            "comennt": commentText.trimmingCharacters(in: .whitespacesAndNewlines),
            "uid": userUID,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("Recipe")
            .document(recipeId)
            .collection("Comment")
            .addDocument(data: commentData) { error in
                DispatchQueue.main.async {
                    isSubmitting = false
                    if let error = error {
                        print("Error sending comment: \(error.localizedDescription)")
                    } else {
                        print("Comment sent successfully")
                        commentText = ""
                        fetchRecipeDetails()
                    }
                }
            }
    }
    
    private func fetchUserData() {
        guard isLoggedIn,
              let userUID = UserDefaults.standard.string(forKey: "userUID") else {
            print("User not logged in or no userUID found")
            return
        }

        let db = Firestore.firestore()
        
        // Fetch target data
        db.collection("User").document(userUID)
            .collection("target").document("current")
            .getDocument { document, error in
                if let error = error {
                    print("Error fetching target data: \(error)")
                    return
                }
                
                if let data = document?.data() {
                    let ingestion = data["Ingestion"] as? Double ?? 0
                    self.hasTargetData = ingestion > 0
                    
                    if self.hasTargetData {
                        self.targetData = TargetData(
                            ingestion: ingestion,
                            ingested: data["Ingested"] as? Double ?? 0,
                            carbs: data["Carbs"] as? Int ?? 0,
                            carbsIngested: data["CarbsIngested"] as? Int ?? 0,
                            protein: data["Protein"] as? Int ?? 0,
                            proteinIngested: data["ProteinIngested"] as? Int ?? 0,
                            fat: data["Fat"] as? Int ?? 0,
                            fatIngested: data["FatIngested"] as? Int ?? 0,
                            carbsExceededCount: data["CarbsExceededCount"] as? Int ?? 0,
                            fatExceededCount: data["FatExceededCount"] as? Int ?? 0,
                            proteinExceededCount: data["ProteinExceededCount"] as? Int ?? 0,
                            totalIngestedExceededCount: data["TotalIngestedExceededCount"] as? Int ?? 0
                        )
                        print("Target data fetched successfully")
                        self.checkAndGetAIAssessment()
                    }
                }
            }
        
        // Fetch allergy data
        db.collection("User").document(userUID)
            .collection("allergy")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching allergy data: \(error)")
                    return
                }
                
                self.allergyData = snapshot?.documents.compactMap { doc in
                    doc.data()["allergen"] as? String
                } ?? []
                
                self.hasAllergyData = !self.allergyData.isEmpty
                if self.hasAllergyData {
                    print("Allergy data fetched successfully")
                    self.checkAndGetAIAssessment()
                }
            }
    }

    private func getAIHealthAssessment() {
        guard let details = recipeDetails else { return }
        
        var contextMessage = """
        Recipe Information:
        Title: \(details.recipeName)
        
        Ingredients:
        \(details.ingredients.map { "- " + $0.name + ": " + $0.value }.joined(separator: "\n"))
        
        Nutrition Information:
        \(details.nutritions.map { $0.name + ": " + $0.value }.joined(separator: "\n"))
        """
        
        if let targetData = targetData {
            contextMessage += """
            
            User's Current Nutrition Status:
            Daily Target Calories: \(Int(targetData.ingestion)) kcal (Current: \(Int(targetData.ingested)) kcal)
            Daily Target Carbs: \(targetData.carbs)g (Current: \(targetData.carbsIngested)g)
            Daily Target Protein: \(targetData.protein)g (Current: \(targetData.proteinIngested)g)
            Daily Target Fat: \(targetData.fat)g (Current: \(targetData.fatIngested)g)
            """
        }
        
        if !allergyData.isEmpty {
            contextMessage += """
            
            User's Allergies:
            \(allergyData.joined(separator: ", "))
            """
        }
        
        contextMessage += """
        
        Please assess this recipe base on nutrition, dietary fit, and allergy risks, classifying it as safe, allergenic, or potential allergen，explain its impact on nutritional intake after consumption,now hong kong time,and within 30 words，without**.
        
        """
        
        print("Sending to AI:\n\(contextMessage)")
        
        isLoadingAI = true
        
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                print("AI Response:\n\(response)")
                await MainActor.run {
                    self.aiHealthAssessment = response
                    self.isLoadingAI = false
                }
            } catch {
                print("Error getting AI response: \(error)")
                await MainActor.run {
                    self.aiHealthAssessment = "Unable to get AI health assessment at this time."
                    self.isLoadingAI = false
                }
            }
        }
    }

    private func checkAndGetAIAssessment() {
        guard let _ = recipeDetails, isLoggedIn else {
            return
        }
        
        if hasTargetData && targetData == nil {
            return
        }
        if hasAllergyData && allergyData.isEmpty {
            return
        }
        
        getAIHealthAssessment()
    }

    private func deleteRecipe() {
        let db = Firestore.firestore()
        isLoading = true
        
        db.collection("Recipe").document(recipeId).delete { error in
            if let error = error {
                print("Error deleting recipe: \(error)")
                isLoading = false
            } else {
                // Delete all likes for this recipe
                deleteAllLikesForRecipe()
                
                // Return to previous screen
                dismiss()
            }
        }
    }

    private func deleteAllLikesForRecipe() {
        let db = Firestore.firestore()
        
        // Get all users
        db.collection("User").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error getting users: \(error)")
                return
            }
            
            guard let users = snapshot?.documents else {
                return
            }
            
            let group = DispatchGroup()
            
            for user in users {
                group.enter()
                let likeRef = db.collection("User").document(user.documentID)
                    .collection("Likes").document(recipeId)
                
                likeRef.getDocument { (document, error) in
                    if let document = document, document.exists {
                        likeRef.delete { error in
                            if let error = error {
                                print("Error deleting like for user \(user.documentID): \(error)")
                            }
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }
            }
        }
    }
    
    // 處理用戶按讚時的食譜分析
    private func analyzeRecipeForLike() {
        guard isLoggedIn, !userUID.isEmpty, let details = recipeDetails else { return }
        
        // 準備食譜詳情的字符串
        var recipeInfo = "Recipe Name: \(details.recipeName)\n"
        recipeInfo += "Category: \(details.category)\n"
        recipeInfo += "Ingredients:\n"
        for ingredient in details.ingredients {
            recipeInfo += "- \(ingredient.name): \(ingredient.value)\n"
        }
        
        recipeInfo += "Steps:\n"
        for (index, step) in details.steps.enumerated() {
            recipeInfo += "Step \(index + 1): \(step)\n"
        }
        
        recipeInfo += "Description: \(description)\n"
        
        // 用AI分析食譜
        print("用戶點讚食譜 \(details.recipeName)，正在使用AI分析食譜...")
        
        RecipeAnalysisService.shared.analyzeRecipe(recipeDetails: recipeInfo) { flavor, foodType, error in
            if let error = error {
                print("AI分析食譜時出錯: \(error.localizedDescription)")
                
                // 錯誤時使用默認值進行記錄
                let defaultFlavor = self.inferDefaultFlavor(title: details.recipeName, category: details.category)
                let defaultType = self.inferDefaultType(title: details.recipeName, category: details.category)
                
                print("使用默認值 - 口味: \(defaultFlavor), 類型: \(defaultType)")
                
                // 設置isLiked為true
                RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: defaultFlavor, isLiked: true)
                RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: defaultType, isLiked: true)
                return
            }
            
            if let flavor = flavor, let foodType = foodType {
                print("AI分析結果 - 口味: \(flavor), 類型: \(foodType)")
                
                // 更新數據庫中的用戶偏好
                RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: flavor, isLiked: true)
                RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: foodType, isLiked: true)
            } else {
                // API返回空值時也使用默認值
                let defaultFlavor = self.inferDefaultFlavor(title: details.recipeName, category: details.category)
                let defaultType = self.inferDefaultType(title: details.recipeName, category: details.category)
                
                print("API未返回有效值，使用默認值 - 口味: \(defaultFlavor), 類型: \(defaultType)")
                
                RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: defaultFlavor, isLiked: true)
                RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: defaultType, isLiked: true)
            }
        }
    }
}

// 辅助视图
struct CategoryPill: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
            .foregroundColor(.orange)
            .cornerRadius(15)
    }
}

struct RecipeSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.title2)
                .bold()
            
            content
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}


extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ExploreDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExploreDetailView(recipeId: "testRecipeId")
                .onAppear {
                    // 模擬未登入狀態
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    UserDefaults.standard.set("", forKey: "userUID")
                }
        }
        .previewDisplayName("Not Logged In")
    }
}

// 添加 FlavorOptionCard 結構體
struct FlavorOptionCard: View {
    var isSelected: Bool
    var icon: String
    var title: String
    var description: String
    var isDisabled: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .orange)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.orange : Color.orange.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: isSelected ? Color.orange.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .orange : .primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.orange.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : Color.gray.opacity(0.1), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .overlay(
            Group {
                if isDisabled {
                    Text("Login required")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .cornerRadius(4)
                }
            },
            alignment: .topTrailing
        )
    }
}
