import SwiftUI
import FirebaseFirestore

struct RecipeGridItem: Identifiable {
    let id: String
    let url: String
    let isVisible: Bool
    let sourceType: String
    
    init(id: String, url: String, isVisible: Bool = true, sourceType: String = "api") {
        self.id = id
        self.url = url
        self.isVisible = isVisible
        self.sourceType = sourceType
    }
}

// Struct to store AI chat favorites
struct AIRecipeFavorite: Identifiable, Codable {
    let id = UUID()
    let recipeName: String
    let recipeMessage: String
    let timestamp: Date
    
    // Add preview data
    static let preview = AIRecipeFavorite(
        recipeName: "Sample Recipe",
        recipeMessage: "Recipe Name: Sample Recipe\n\nDescription: A delicious sample recipe.\n\nIngredients:\n- Ingredient 1: 1 cup\n- Ingredient 2: 2 tbsp\n\nSteps:\n1. Do step one\n2. Do step two\n\nNutrition:\n- Calories: 200 kcal\n- Protein: 5g",
        timestamp: Date()
    )
}

struct LikesView: View {
    @StateObject private var userSettings = UserSettings.shared
    @State private var likedRecipes: [RecipeGridItem] = []
    @State private var isLoading = true
    @State private var selectedTab = 0 // 0: Favorites, 1: AI Recipes
    @AppStorage("userUID") private var userUID: String = ""
    @AppStorage("showSegmentInLikesView") private var showSegmentInLikesView: Bool = false
    @State private var savedAIRecipe: AIRecipeFavorite?
    @State private var savedAIRecipes: [AIRecipeFavorite] = [] // 存储多个AI食谱
    @State private var showAIRecipe = false
    @State private var showAIRecipeDetailView = false
    @State private var cookingData: (ingredients: [AddRecipeView.Ingredient], steps: [String], nutritions: [AddRecipeView.Nutrition])?
    @State private var showRecipeFamiliaritySelection = false
    @State private var recipeKnowledge = true
    @State private var isProcessingRecipeSteps = false
    @State private var optimizedSteps: [String] = []
    @State private var originalSteps: [String] = []
    @State private var useDefaultFlavor = true
    
    private var columns: [GridItem] {
        return [
            GridItem(.flexible(), spacing: 5),
            GridItem(.flexible(), spacing: 5),
            GridItem(.flexible(), spacing: 5)
        ]
    }
    
    private var imageSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 10
        let spacing: CGFloat = 5
        let availableWidth = screenWidth - (padding * 2) - spacing * 2
        return (availableWidth / 3) - spacing
    }
    
    var body: some View {
        NavigationView {
            Group {
                if !userSettings.isLoggedIn {
                    // Not logged in view
                    notLoggedInView
                } else {
                    // Main content when logged in
                    mainContentView
                }
            }
        }
        .onAppear(perform: onAppearHandler)
        .onChange(of: selectedTab, perform: onTabChangeHandler)
        .onChange(of: userSettings.isLoggedIn, perform: onLoginStatusChangeHandler)
        .onChange(of: useDefaultFlavor) { newValue in
            print("LikesView - useDefaultFlavor changed to: \(newValue)")
        }
        .sheet(isPresented: $showAIRecipeDetailView) {
            if let savedRecipe = savedAIRecipe {
                AIRecipeDetailView(recipe: savedRecipe) {
                    startCookingWithSavedRecipe()
                }
            }
        }
        .sheet(isPresented: $showAIRecipe) {
            if let data = cookingData {
                CookingStepsForAIChat(
                    ingredients: data.ingredients,
                    steps: data.steps,
                    nutritions: data.nutritions,
                    aiResponse: savedAIRecipe?.recipeMessage ?? "",
                    recipeKnowledgeForKnowledge: recipeKnowledge,
                    customStepsForKnowledge: optimizedSteps.isEmpty ? nil : optimizedSteps
                )
            }
        }
        .sheet(isPresented: $showRecipeFamiliaritySelection) {
            RecipeFamiliaritySelectionView(
                recipeKnowledge: $recipeKnowledge,
                originalRecipeSteps: originalSteps,
                useDefaultFlavor: $useDefaultFlavor,
                isShowing: $showRecipeFamiliaritySelection,
                onCompletion: { processedSteps in
                    if let data = cookingData {
                        // Update the steps with the processed ones
                        cookingData = (
                            ingredients: data.ingredients,
                            steps: processedSteps,
                            nutritions: data.nutritions
                        )
                        
                        // Now show the cooking view
                        showAIRecipe = true
                    }
                }
            )
        }
        .overlay {
            if isProcessingRecipeSteps {
                ZStack {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text(recipeKnowledge ? "Optimizing recipe steps..." : "Creating detailed instructions...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(20)
                    .background(Color.secondary.opacity(0.8))
                    .cornerRadius(10)
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func startCookingWithSavedRecipe() {

        if !useDefaultFlavor {
            useDefaultFlavor = true
        }
        

        guard let savedRecipe = savedAIRecipe else { return }
        
        // Create placeholders for the data
        var ingredients: [AddRecipeView.Ingredient] = []
        var steps: [String] = []
        var nutritions: [AddRecipeView.Nutrition] = []
        
        // Save original steps for AI processing
        originalSteps = []
        
        // Parse the recipe message
        let message = savedRecipe.recipeMessage
        let lines = message.components(separatedBy: "\n")
        
        var section = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty { continue }
            
            // Detect section headers
            if trimmedLine.lowercased().contains("ingredient") {
                section = "ingredients"
                continue
            } else if trimmedLine.lowercased().contains("step") || trimmedLine.lowercased().contains("instructions") || trimmedLine.lowercased().contains("direction") {
                section = "steps"
                continue
            } else if trimmedLine.lowercased().contains("nutrition") {
                section = "nutrition"
                continue
            }
            
            // Process based on the current section
            if section == "ingredients" {
                // Try to parse ingredient line (format: "- Ingredient: amount" or "* Ingredient: amount")
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "*") || trimmedLine.contains(":") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-*]\\s*", with: "", options: .regularExpression)
                    
                    if cleanLine.contains(":") {
                        let parts = cleanLine.components(separatedBy: ":")
                        if parts.count >= 2 {
                            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            ingredients.append(AddRecipeView.Ingredient(name: name, value: value))
                        } else {
                            // Just add as an ingredient without specific amount
                            ingredients.append(AddRecipeView.Ingredient(name: cleanLine, value: "as needed"))
                        }
                    } else {
                        // Try to find the last number and unit in the string
                        let pattern = "([0-9/.,]+)\\s*([a-zA-Z]+)?$"
                        if let regex = try? NSRegularExpression(pattern: pattern) {
                            let range = NSRange(cleanLine.startIndex..., in: cleanLine)
                            if let match = regex.firstMatch(in: cleanLine, range: range) {
                                let nameRange = NSRange(location: 0, length: match.range.location)
                                if let nameRange = Range(nameRange, in: cleanLine) {
                                    let name = String(cleanLine[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                                    let value = String(cleanLine[Range(match.range, in: cleanLine)!]).trimmingCharacters(in: .whitespacesAndNewlines)
                                    ingredients.append(AddRecipeView.Ingredient(name: name, value: value))
                                }
                            } else {
                                // Couldn't parse, add as is
                                ingredients.append(AddRecipeView.Ingredient(name: cleanLine, value: "as needed"))
                            }
                        }
                    }
                } else {

                    ingredients.append(AddRecipeView.Ingredient(name: trimmedLine, value: "as needed"))
                }
            } else if section == "steps" {

                let cleanedStep = trimmedLine.replacingOccurrences(of: "^\\d+\\.?\\s*|^Step\\s*\\d+:?\\s*", with: "", options: .regularExpression)
                
                if !cleanedStep.isEmpty {
                    steps.append(cleanedStep)
                    originalSteps.append(cleanedStep)
                }
            } else if section == "nutrition" {

                if trimmedLine.contains(":") {
                    let parts = trimmedLine.replacingOccurrences(of: "^[-*]\\s*", with: "", options: .regularExpression)
                                          .components(separatedBy: ":")
                    
                    if parts.count >= 2 {
                        let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        nutritions.append(AddRecipeView.Nutrition(name: name, value: value))
                    }
                }
            }
        }
        
        // If no ingredients or steps were found, create some defaults to avoid empty views
        if ingredients.isEmpty {
            ingredients.append(AddRecipeView.Ingredient(name: "No ingredients specified", value: ""))
        }
        
        if steps.isEmpty {
            steps.append("No steps specified")
        }
        
        // If no nutritions were found, add some defaults
        if nutritions.isEmpty {
            nutritions.append(AddRecipeView.Nutrition(name: "Calories", value: "Not specified"))
        }
        
        // Set the cooking data
        let recipeToCook = (ingredients: ingredients, steps: steps, nutritions: nutritions)
        
        // Store cooking data but don't show cooking view yet
        cookingData = recipeToCook
        
        // Instead of immediately processing steps, show the familiarity selection view
        showRecipeFamiliaritySelection = true
    }
    
    // Add a function to process recipe steps based on user's familiarity
    private func processRecipeStepsForKnowledge() {
        guard let data = cookingData, !originalSteps.isEmpty else {
            // If no data or no original steps, just show cooking view with original data
            showAIRecipe = true
            return
        }
        
        // Set loading state
        isProcessingRecipeSteps = true
        
        // Get recipe context
        let recipeName = savedAIRecipe?.recipeName ?? "Recipe"
        let stepsText = originalSteps.enumerated().map { index, step in
            "Step \(index + 1): \(step)"
        }.joined(separator: "\n")
        
        // Create a ChatService instance
        let chatService = ChatService(
            mixraiKey: "YOUR_AI_HERE",
            deepseekKey: "YOUR_AI_HERE"
        )
        
        // Prepare context message based on user's familiarity
        let contextMessage: String
        
        if recipeKnowledge {
            // User is familiar with the recipe - request optimized steps
            contextMessage = """
            Recipe: \(recipeName)
            
            Original steps:
            \(stepsText)
            
            I'm FAMILIAR with this recipe. Please optimize these steps by:
            1. Fixing any errors or typos
            2. Ensuring each step is clear but concise
            3. Maintaining the original flow of the recipe
            
            Please respond with ONLY the optimized steps in this exact format:
            Step 1: [optimized step]
            Step 2: [optimized step]
            ...and so on.
            """
        } else {
            // User is unfamiliar with the recipe - request detailed steps broken down extensively
            contextMessage = """
            Recipe: \(recipeName)
            
            Original steps:
            \(stepsText)
            
            I'm UNFAMILIAR with this recipe. Please break down the steps into much more detailed instructions by:
            1. Breaking down each original step into multiple, smaller sub-steps
            2. Creating separate steps for preparations (e.g., "Preheat oven to 350°F" becomes its own step)
            3. Adding specific details about cooking techniques (e.g., what "sauté until translucent" looks like)
            4. Including visual cues and timing information (e.g., "bake for 10 minutes or until golden brown")
            5. Explaining each action in detail assuming the user has minimal cooking experience
            
            For example, an original step like:
            "Heat oil in a pan, add chicken and vegetables, cook for 5 minutes, then add sauce."
            
            Should be broken down into:
            Step 1: Place a large skillet on the stovetop.
            Step 2: Turn the heat to medium-high.
            Step 3: Add 2 tablespoons of oil to the skillet.
            Step 4: Wait until the oil is hot (it will shimmer slightly).
            Step 5: Carefully add the chicken pieces to the hot oil.
            Step 6: Cook the chicken for 2-3 minutes, stirring occasionally.
            Step 7: Add the vegetables to the skillet with the chicken.
            Step 8: Continue cooking for another 2-3 minutes until vegetables begin to soften.
            Step 9: Pour the sauce over the chicken and vegetables.
            
            Please respond with ONLY the detailed steps in this exact format:
            Step 1: [detailed sub-step]
            Step 2: [detailed sub-step]
            ...and so on.
            
            Important: The goal is to give me at least twice as many steps as the original recipe, with each step being a single, simple action.
            """
        }
        
        // Send to AI for processing
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                
                // Process AI response
                let responseLines = response.components(separatedBy: "\n")
                var processedSteps: [String] = []
                
                for line in responseLines {
                    if line.contains("Step") {
                        let components = line.components(separatedBy: ":")
                        if components.count > 1 {
                            let stepContent = components[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                            processedSteps.append(stepContent)
                        }
                    }
                }
                
                // Update UI on main thread
                await MainActor.run {
                    optimizedSteps = processedSteps
                    isProcessingRecipeSteps = false
                    showAIRecipe = true
                }
            } catch {
                // Handle error and fall back to original steps
                await MainActor.run {
                    print("Error getting AI processing for steps: \(error.localizedDescription)")
                    isProcessingRecipeSteps = false
                    showAIRecipe = true // Still show cooking steps with original instructions
                }
            }
        }
    }
    
    private var navigationTitle: String {
        if !userSettings.isLoggedIn {
            return ""
        }
        
        if !showSegmentInLikesView {
            return "Favorites"
        }
        
        return selectedTab == 0 ? "Favorites" : "AI Recipes"
    }
    
    @ViewBuilder
    private func recipesGrid(items: [RecipeGridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                // For API recipes, navigate to DetailOfRecipeView
                if item.sourceType == "api" {
                    NavigationLink(destination: DetailOfRecipeView(recipeId: Int(item.id) ?? 0)) {
                        recipeImageView(item: item)
                    }
                }
                // For community recipes, navigate to ExploreDetailView
                else {
                    NavigationLink(destination: ExploreDetailView(recipeId: item.id)) {
                        recipeImageView(item: item)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }
    
    // Helper function to create recipe image view with source indicator
    private func recipeImageView(item: RecipeGridItem) -> some View {
        ZStack(alignment: .topLeading) {
            AsyncImage(url: URL(string: item.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imageSize, height: imageSize)
                    .cornerRadius(10)
                    .clipped()
            } placeholder: {
                ProgressView()
                    .frame(width: imageSize, height: imageSize)
            }
            
            // Source indicator badge
            if item.sourceType == "api" {
                Text("HOME")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .padding(5)
            } else if item.sourceType == "community" {
                Text("COM")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .padding(5)
            }
        }
    }
    
    private func refreshContent() async {
        await MainActor.run {
            if selectedTab == 0 || !showSegmentInLikesView {
                fetchLikedRecipes()
            }
        }
    }
    
    // Load the saved AI recipe from UserDefaults
    private func loadSavedAIRecipe() {
        // 尝试加载多个食谱
        if let savedData = UserDefaults.standard.data(forKey: "savedAIRecipes_\(userUID)"),
           let decoded = try? JSONDecoder().decode([AIRecipeFavorite].self, from: savedData) {
            self.savedAIRecipes = decoded
            
            // 如果有食谱，启用分段视图
            if !decoded.isEmpty {
                self.showSegmentInLikesView = true
                // 设置当前食谱为第一个（向后兼容）
                self.savedAIRecipe = decoded[0]
            }
        } 
        // 向后兼容 - 如果没有找到多个食谱，尝试加载单个食谱
        else if let savedData = UserDefaults.standard.data(forKey: "savedAIRecipe_\(userUID)"),
                let decoded = try? JSONDecoder().decode(AIRecipeFavorite.self, from: savedData) {
            self.savedAIRecipe = decoded
            self.savedAIRecipes = [decoded]
            self.showSegmentInLikesView = true
            
            // 将单个食谱转换为数组格式保存
            if let encoded = try? JSONEncoder().encode([decoded]) {
                UserDefaults.standard.set(encoded, forKey: "savedAIRecipes_\(userUID)")
            }
        }
    }
    
    private func fetchLikedRecipes() {
        isLoading = true
        let db = Firestore.firestore()
        
        db.collection("User")
            .document(userUID)
            .collection("Likes")
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error getting likes: \(error)")
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }

                if documents.isEmpty {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.likedRecipes = []
                    }
                    return
                }
                
                var fetchedRecipes: [RecipeGridItem] = []
                let group = DispatchGroup()
                
                for document in documents {
                    group.enter()
                    
                    let recipeId = document.documentID
                    let data = document.data()
                    
                    // Check if it contains RecipeImg directly (from API/DetailOfRecipeView)
                    if let imageUrl = data["RecipeImg"] as? String, !imageUrl.isEmpty {
                        let sourceType = data["sourceType"] as? String ?? "api"
                        fetchedRecipes.append(RecipeGridItem(
                            id: recipeId,
                            url: imageUrl,
                            isVisible: true,
                            sourceType: sourceType
                        ))
                        group.leave()
                    } else {
                        // If no RecipeImg in the like document, try to fetch from the Recipe collection (community recipes)
                        db.collection("Recipe").document(recipeId).getDocument { (document, error) in
                            defer { group.leave() }
                            
                            if let document = document,
                               let data = document.data(),
                               let imageUrl = data["RecipeImg"] as? String {
                                let isVisible = data["isVisible"] as? Bool ?? true
                                fetchedRecipes.append(RecipeGridItem(
                                    id: document.documentID,
                                    url: imageUrl,
                                    isVisible: isVisible,
                                    sourceType: "community"
                                ))
                            }
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    self.likedRecipes = fetchedRecipes
                    self.isLoading = false
                }
            }
    }
    
    @ViewBuilder
    private var favoritesContentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                } else if likedRecipes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.top, 40)
                        
                        Text("No favorites yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Explore recipes and tap the heart icon to add to favorites")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding()
                } else {
                    recipesGrid(items: likedRecipes)
                }
            }
            .refreshable {
                if userSettings.isLoggedIn {
                    await refreshContent()
                }
            }
        }
    }
    
    @ViewBuilder
    private var aiRecipeContentView: some View {
        ScrollView {
            // 如果没有保存的食谱，显示空状态
            if savedAIRecipes.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 90, height: 90)
                        
                        Image(systemName: "book.closed")
                            .font(.system(size: 35))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 20)
                    
                    Text("No AI recipes saved yet")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    Text("Save a recipe from the AI Chat to see it here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding(.top, 8)
            } else {
                // 直接显示食谱列表，移除多余的标题和说明
                VStack(spacing: 8) {
                    ForEach(savedAIRecipes.indices, id: \.self) { index in
                        let recipe = savedAIRecipes[index]
                        recipeCard(recipe: recipe, index: index)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
        }
        .background(Color.orange.opacity(0.01))
    }
    
    // 单个食谱卡片视图
    private func recipeCard(recipe: AIRecipeFavorite, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题区域和日期放在同一行，节省空间
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                    
                    Text(recipe.recipeName)
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Text(formattedDate(recipe.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Divider()
                .background(Color.orange.opacity(0.3))
                .padding(.vertical, 2)
            
            // 提取食谱元素显示
            recipePreview(recipe: recipe)
            
            HStack(spacing: 8) {
                // 查看按钮
                Button(action: {
                    savedAIRecipe = recipe
                    showAIRecipeDetailView = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                        Text("View")
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange, lineWidth: 1.5)
                    )
                }
                
                // 烹饪按钮
                Button(action: {
                    savedAIRecipe = recipe
                    startCookingWithSavedRecipe()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                        Text("Cook")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // 删除按钮
                Button(action: {
                    deleteRecipe(at: index)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.orange.opacity(0.8))
                        )
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
    
    // 提取并显示食谱预览信息
    private func recipePreview(recipe: AIRecipeFavorite) -> some View {
        // 在方法外部解析内容
        let (_, extractedNutrition) = extractRecipeInfo(from: recipe.recipeMessage)
        
        return VStack(alignment: .leading, spacing: 2) {
            // 只显示营养信息，不显示食材信息
            if !extractedNutrition.isEmpty {
                HStack(alignment: .top, spacing: 2) {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    
                    Text(extractedNutrition.first ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    // 辅助方法：从食谱消息中提取信息
    private func extractRecipeInfo(from message: String) -> (ingredients: [String], nutrition: [String]) {
        let lines = message.components(separatedBy: "\n")
        var ingredients: [String] = []
        var nutrition: [String] = []
        
        var currentSection = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty { continue }
            
            // 检测段落
            if trimmedLine.lowercased().contains("ingredient") {
                currentSection = "ingredients"
                continue
            } else if trimmedLine.lowercased().contains("nutrition") {
                currentSection = "nutrition"
                continue
            }
            
            // 提取信息
            if currentSection == "ingredients" && (trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•")) {
                let cleanedLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                ingredients.append(cleanedLine)
                if ingredients.count >= 2 { break } // 只取前两个原料
            }
            
            if currentSection == "nutrition" && (trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") || trimmedLine.contains("Calories")) {
                let cleanedLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                nutrition.append(cleanedLine)
                if nutrition.count >= 1 { break } // 只取第一个营养信息
            }
        }
        
        return (ingredients, nutrition)
    }
    
    // 删除食谱功能
    private func deleteRecipe(at index: Int) {
        // 从数组中移除食谱
        savedAIRecipes.remove(at: index)
        
        // 保存更新后的数组到UserDefaults
        if let encoded = try? JSONEncoder().encode(savedAIRecipes) {
            UserDefaults.standard.set(encoded, forKey: "savedAIRecipes_\(userUID)")
            
            // 如果删除所有食谱，更新UI状态
            if savedAIRecipes.isEmpty {
                showSegmentInLikesView = false
                UserDefaults.standard.removeObject(forKey: "savedAIRecipe_\(userUID)")
            } else {
                // 更新单个食谱引用为最新的食谱（向后兼容）
                UserDefaults.standard.set(try? JSONEncoder().encode(savedAIRecipes[0]), 
                                          forKey: "savedAIRecipe_\(userUID)")
            }
        }
    }
    
    private func onAppearHandler() {
        if userSettings.isLoggedIn && (selectedTab == 0 || !showSegmentInLikesView) {
            fetchLikedRecipes()
        }
        // Load the saved AI recipe
        loadSavedAIRecipe()
    }
    
    private func onTabChangeHandler(newValue: Int) {
        if userSettings.isLoggedIn && newValue == 0 {
            fetchLikedRecipes()
        }
    }
    
    private func onLoginStatusChangeHandler(newValue: Bool) {
        if newValue && (selectedTab == 0 || !showSegmentInLikesView) {
            fetchLikedRecipes()
        } else if !newValue {
            likedRecipes = []
        }
    }
    
    private var notLoggedInView: some View {
        VStack {
            Text("Please login to view your likes")
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            NavigationLink(destination: ProfileView()) {
                Text("Login")
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(8)
            }
        }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if userSettings.isLoggedIn && showSegmentInLikesView {
                // Only show segmented control if the user has saved an AI recipe
                Picker("View", selection: $selectedTab) {
                    Text("Favorites").tag(0)
                    Text("AI Recipes").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 2)
                .padding(.bottom, 2)
            }
            
            Group {
                if !userSettings.isLoggedIn {
                    // 未登入狀態
                    VStack(spacing: 20) {
                        Text("Please login to view your favorites")
                            .font(.headline)
                        NavigationLink(destination: ProfileView()) {
                            Text("Go to Login")
                                .foregroundColor(.white)
                                .frame(width: 200)
                                .padding()
                                .background(Color.orange.opacity(0.8))
                                .cornerRadius(10)
                        }
                    }
                } else if selectedTab == 0 || !showSegmentInLikesView {
                    // Favorites
                    favoritesContentView
                } else if selectedTab == 1 && showSegmentInLikesView {
                    // AI Recipe Favorite
                    aiRecipeContentView
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Detail view for the saved AI recipe
struct AIRecipeDetailView: View {
    let recipe: AIRecipeFavorite
    let onCookTapped: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Add state variables for different recipe sections
    @State private var recipeName: String = ""
    @State private var description: String = ""
    @State private var ingredients: [(String, String)] = []
    @State private var steps: [String] = []
    @State private var nutritions: [(String, String)] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Recipe name section
                    VStack(alignment: .leading) {
                        Text("Recipe Name")
                            .font(.headline)
                            .foregroundColor(Color.orange.opacity(0.8))
                        
                        Text(recipeName)
                            .font(.title2)
                            .bold()
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Description section
                    if !description.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(Color.orange.opacity(0.8))
                            
                            Text(description)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Ingredients section
                    VStack(alignment: .leading) {
                        Text("Ingredients")
                            .font(.headline)
                            .foregroundColor(Color.orange.opacity(0.8))
                        
                        ForEach(ingredients.indices, id: \.self) { index in
                            HStack {
                                Text("•")
                                    .foregroundColor(.orange)
                                
                                Text(ingredients[index].0)
                                    .fontWeight(.medium)
                                
                                if !ingredients[index].1.isEmpty {
                                    Spacer()
                                    Text(ingredients[index].1)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // Steps section
                    VStack(alignment: .leading) {
                        Text("Steps")
                            .font(.headline)
                            .foregroundColor(Color.orange.opacity(0.8))
                        
                        ForEach(steps.indices, id: \.self) { index in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .foregroundColor(.orange)
                                    .fontWeight(.bold)
                                
                                Text(steps[index])
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 8)
                            
                            if index < steps.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // Nutrition section
                    if !nutritions.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Nutrition Facts")
                                .font(.headline)
                                .foregroundColor(Color.orange.opacity(0.8))
                            
                            ForEach(nutritions.indices, id: \.self) { index in
                                HStack {
                                    Text(nutritions[index].0)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text(nutritions[index].1)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                                
                                if index < nutritions.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Cook button
                    Button(action: {
                        dismiss()
                        onCookTapped()
                    }) {
                        HStack {
                            Text("Start Cooking")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Image(systemName: "fork.knife")
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .padding(.vertical)
            }
            .navigationTitle("Recipe Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                parseRecipeMessage()
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Parse the recipe message into structured data
    private func parseRecipeMessage() {
        // Initialize default values
        recipeName = recipe.recipeName
        description = ""
        ingredients = []
        steps = []
        nutritions = [
            ("Calories", ""),
            ("Carbohydrates", ""),
            ("Protein", ""),
            ("Fat", "")
        ]
        
        // Parse the content
        let content = recipe.recipeMessage
        let lines = content.components(separatedBy: .newlines)
        var currentSection = ""
        var descriptionLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty { continue }
            
            // Detect section headers
            if trimmedLine.lowercased().contains("recipe:") || trimmedLine.lowercased().contains("recipe name:") {
                currentSection = "name"
                continue
            } else if trimmedLine.lowercased().contains("description:") {
                currentSection = "description"
                continue
            } else if trimmedLine.lowercased().contains("ingredients:") {
                currentSection = "ingredients"
                continue
            } else if trimmedLine.lowercased().contains("instructions:") || trimmedLine.lowercased().contains("steps:") {
                currentSection = "steps"
                continue
            } else if trimmedLine.lowercased().contains("nutrition:") || trimmedLine.lowercased().contains("nutritional information:") {
                currentSection = "nutrition"
                continue
            }
            
            // Process content based on current section
            switch currentSection {
            case "description":
                descriptionLines.append(trimmedLine)
                
            case "ingredients":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    
                    if cleanLine.contains(":") {
                        let parts = cleanLine.split(separator: ":", maxSplits: 1).map(String.init)
                        if parts.count == 2 {
                            let name = parts[0].trimmingCharacters(in: .whitespaces)
                            let value = parts[1].trimmingCharacters(in: .whitespaces)
                            ingredients.append((name, value))
                        } else {
                            ingredients.append((cleanLine, ""))
                        }
                    } else {
                        // Try to match common ingredient format like "2 tbsp olive oil"
                        let pattern = "^([0-9¼½¾⅓⅔⅛⅜⅝⅞.]+\\s*(?:cup|cups|tbsp|tsp|tablespoon|tablespoons|teaspoon|teaspoons|oz|ounce|ounces|pound|pounds|lb|lbs|g|kg|ml|l|pinch|dash|to taste|bunch|bunches))\\s+(.+)$"
                        
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                            let nsString = cleanLine as NSString
                            let matches = regex.matches(in: cleanLine, options: [], range: NSRange(location: 0, length: nsString.length))
                            
                            if let match = matches.first {
                                let amountRange = match.range(at: 1)
                                let nameRange = match.range(at: 2)
                                
                                if amountRange.location != NSNotFound && nameRange.location != NSNotFound {
                                    let amount = nsString.substring(with: amountRange).trimmingCharacters(in: .whitespaces)
                                    let name = nsString.substring(with: nameRange).trimmingCharacters(in: .whitespaces)
                                    ingredients.append((name, amount))
                                } else {
                                    ingredients.append((cleanLine, ""))
                                }
                            } else {
                                ingredients.append((cleanLine, ""))
                            }
                        } else {
                            ingredients.append((cleanLine, ""))
                        }
                    }
                }
                
            case "steps":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    steps.append(cleanLine)
                } else if let number = trimmedLine.first, number.isNumber {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^\\d+\\.?\\s*", with: "", options: .regularExpression)
                    steps.append(cleanLine)
                } else {
                    // If line doesn't start with number or bullet but is in steps section, add it as a step
                    steps.append(trimmedLine)
                }
                
            case "nutrition":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    let parts = cleanLine.split(separator: ":", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        let name = parts[0].trimmingCharacters(in: .whitespaces)
                        let value = parts[1].trimmingCharacters(in: .whitespaces)
                        
                        // Update existing item or add new one
                        if let index = nutritions.firstIndex(where: { $0.0.lowercased() == name.lowercased() }) {
                            nutritions[index].1 = value
                        } else {
                            nutritions.append((name, value))
                        }
                    }
                }
                
            default:
                break
            }
        }
        
        // Combine description lines
        description = descriptionLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LikesView_Previews: PreviewProvider {
    static var previews: some View {
        LikesView()
    }
} 
