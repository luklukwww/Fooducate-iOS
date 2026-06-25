//
//  DetailOfRecipeView.swift
//  ContentView
//
//  Created by honman luk on 19/10/2024.
//

import SwiftUI
import UIKit
import AVFoundation
import Vision
import FirebaseFirestore

private let chatService = ChatService(
    mixraiKey: "YOUR_AI_HERE",
    deepseekKey: "YOUR_AI_HERE"
)

// HandDetectionView implementation has been moved to HandDetectionView.swift
// The file contains the full implementation of HandDetectionView, CameraView, and CameraViewController

struct NutritionInfo: Codable {
    let calories: String
    let carbs: String
    let fat: String
    let protein: String
    let bad: [NutrientInfo]
    let good: [NutrientInfo]
}

struct NutrientInfo: Codable {
    let amount: String
    let title: String
    let percentOfDailyNeeds: Double
}

// 添加相關食譜的模型結構
struct SimilarRecipe: Codable, Identifiable {
    let id: Int
    let title: String
    let readyInMinutes: Int
    let servings: Int
    
    // 由於API不直接提供圖片，我們生成圖片URL
    var imageUrl: String {
        return "https://spoonacular.com/recipeImages/\(id)-312x231.jpg"
    }
}

struct DetailOfRecipeView: View {
    let recipeId: Int
    @State private var recipeDetails: RecipeDetails?
    @State private var nutritionInfo: NutritionInfo?
    @State private var isLoading = true
    @State private var selectedNutrientType = 0
    @State private var showAllNutrients = false
    @State private var showCookingMode = false
    @State private var currentStep = -1
    @State private var cookingSteps: [String] = []
    @State private var isHandDetectionEnabled = false
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var isFlavorGuideEnabled = false
    @State private var showSettings = false
    @EnvironmentObject var userSettings: UserSettings
    @State private var showLoginAlert = false
    @State private var showSuccessAlert = false
    @State private var navigateToProfile = false
    @Environment(\.presentationMode) var presentationMode
    @State private var aiHealthAssessment: String = ""
    @State private var isLoadingAI = false
    @State private var targetData: TargetData?
    @State private var allergyData: [String] = []
    @State private var hasTargetData = false
    @State private var hasAllergyData = false
    @State private var aiCookingTip: String = ""
    @State private var userType: String = "beginner"
    @State private var showCookingStepsView = false
    @State private var recipeKnowledgeForKnowledge: Bool = true // Default to "Familiar"
    @State private var isProcessingStepsForKnowledge: Bool = false
    @State private var optimizedStepsForKnowledge: [String] = []
    @State private var useDefaultFlavor: Bool = true // Default to use default flavor
    @State private var flavorPreference: String = "" // To store user's flavor preference
    @State private var hasFlavorTrend: Bool = false
    @State private var guessedFlavor: String = ""
    @State private var useGuessedFlavor: Bool = false
    @State private var customFlavor: String = "" // To store custom flavor selection
    @State private var showFlavorSelectionSheet: Bool = false // To control the flavor selection sheet
    @State private var showGestureGuide = false // Add this line back
    
    // 添加相關食譜列表狀態
    @State private var similarRecipes: [SimilarRecipe] = []
    @State private var isLoadingSimilarRecipes: Bool = false
    
    // 計時器相關屬性
    @State private var viewStartTime: Date?
    @State private var hasAnalyzedRecipe: Bool = false
    @State private var timerWorkItem: DispatchWorkItem?
    
    // 收藏相關狀態
    @State private var isLiked: Bool = false
    @State private var isCheckingLikeStatus: Bool = false
    @AppStorage("userUID") private var userUID: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if showCookingMode {
                cookingView
            } else {
                normalView
            }
        }
        // Add Background Hand Gesture Detector for navigation
        .overlay(
            BackgroundHandGestureDetector(
                isEnabled: $isHandDetectionEnabled,
                onUpSwipe: {
                    // Right swipe (previous step)
                    if showCookingMode {
                        if currentStep > -1 {
                            currentStep -= 1
                        }
                    }
                },
                onDownSwipe: {
                    // Left swipe (next step)
                    if showCookingMode {
                        if currentStep < cookingSteps.count {
                            currentStep += 1
                        } else {
                            showCookingMode = false
                            currentStep = -1
                        }
                    }
                }
            )
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    if showCookingMode && currentStep != cookingSteps.count {  // 不是最後一頁時才允許滑動
                        let threshold: CGFloat = 50
                        if value.translation.width < -threshold {
                            // 向左滑
                            withAnimation {
                                if currentStep < cookingSteps.count {
                                    currentStep += 1
                                }
                            }
                        } else if value.translation.width > threshold {
                            // 向右滑
                            withAnimation {
                                if currentStep > -1 {
                                    currentStep -= 1
                                }
                            }
                        }
                    }
                }
        )
        .onAppear {
            fetchRecipeDetails()
            fetchNutritionInfo()
            if userSettings.isLoggedIn {
                fetchUserData()
                fetchFlavorPreference()
            }
            fetchUserType()
            UITabBar.appearance().isHidden = true
            recipeKnowledgeForKnowledge = true // Set default recipe knowledge to "Familiar"
        }
        .onDisappear {
            UITabBar.appearance().isHidden = false
            // Cancel the timer if the view disappears
            timerWorkItem?.cancel()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true) // Hide the navigation bar completely
        .edgesIgnoringSafeArea(.top)
        .fullScreenCover(isPresented: $showCookingStepsView) {
            if let details = recipeDetails {
                CookingStepsViewForAPI(
                    recipeDetails: details, 
                    nutritionInfo: nutritionInfo, 
                    recipeKnowledgeForKnowledge: recipeKnowledgeForKnowledge,
                    customStepsForKnowledge: !optimizedStepsForKnowledge.isEmpty ? optimizedStepsForKnowledge : nil
                )
                .environmentObject(userSettings)
                .onAppear {
                    print("Opening cooking view with \(optimizedStepsForKnowledge.isEmpty ? "original" : "optimized") steps")
                    if !optimizedStepsForKnowledge.isEmpty {
                        print("Using \(optimizedStepsForKnowledge.count) optimized steps")
                    }
                }
            }
        }
        // 登入提示
        .alert("Please Login", isPresented: $showLoginAlert) {
            Button("Login", role: .none) {
                navigateToProfile = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please login to save this recipe")
        }
        // 收藏成功提示
        .alert("Added to Favorites", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This recipe has been successfully added to your favorites")
        }
        .background(
            NavigationLink(destination: ProfileView(), isActive: $navigateToProfile) {
                EmptyView()
            }
        )
    }
    
    // 烹飪模式
    private var cookingView: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 0) {
                    if currentStep == -1 {
                        VStack(spacing: 16) {
                            Spacer()
                            
                            VStack(spacing: 20) {
                                Text("Please prepare the ingredients:")
                                    .font(.title2.bold())
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if let details = recipeDetails {
                                            ForEach(details.extendedIngredients, id: \.id) { ingredient in
                                                Text("• \(ingredient.original)")
                                                    .font(.system(size: 24, weight: .bold))
                                                    .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: UIScreen.main.bounds.height * 0.4)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Spacer()
                            
                            Text("← Swipe left to start cooking →")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.bottom, 30)
                        }
                    } else if currentStep < cookingSteps.count {
                        // 烹飪步驟
                        VStack(spacing: 16) {
                            Spacer()
                            
                            VStack(spacing: 20) {
                                Text("Step \(currentStep + 1)")
                                    .font(.title2.bold())
                                
                                Text(cookingSteps[currentStep])
                                    .font(.system(size: 24, weight: .bold))
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.center)
                                
                                if !aiCookingTip.isEmpty {
                                    HStack(spacing: 12) {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.orange)
                                        
                                        Text(aiCookingTip)
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.orange.opacity(0.1))
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            Spacer()
                            
                            Text("← Swipe to change steps →")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.bottom, 30)
                        }
                        .onAppear {
                            if userSettings.isLoggedIn {
                                getAICookingTip(step: cookingSteps[currentStep])
                            }
                        }
                    } else {
                        cookingCompleteView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.orange)
                    },
                    trailing: EmptyView()
                )
            }
        }
        .onChange(of: showCookingMode) { newValue in
            if !newValue {
                isHandDetectionEnabled = false
                isFlavorGuideEnabled = false
                synthesizer.stopSpeaking(at: .immediate)
            }
        }
        .onChange(of: currentStep) { _ in
            if isFlavorGuideEnabled {
                speakCurrentContent()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                VStack {
                    Text("Flavour Assist")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    VStack(spacing: 0) {

                        
                        // Flavour Gesture 選項
                        HStack(spacing: 15) {
                            Image(systemName: isHandDetectionEnabled ? "hand.raised.fill" : "hand.raised")
                                .font(.system(size: 22))
                                .foregroundColor(.black)
                            
                            Text("Flavour Gesture")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Button(action: {
                                showGestureGuide = true
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 18))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $isHandDetectionEnabled)
                                .labelsHidden()
                                .tint(.orange)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.white)
                        .sheet(isPresented: $showGestureGuide) {
                            GestureGuideView(isPresented: $showGestureGuide)
                                .presentationDetents([.height(500)])
                        }
                        
                        Divider()
                            .padding(.leading, 20)
                        
                        // Flavor Guide 選項
                        HStack(spacing: 15) {
                            Image(systemName: isFlavorGuideEnabled ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: 22))
                                .foregroundColor(.black)
                            
                            Text("Flavor Guide")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Toggle("", isOn: $isFlavorGuideEnabled)
                                .labelsHidden()
                                .tint(.orange)
                                .onChange(of: isFlavorGuideEnabled) { oldValue, newValue in
                                    if newValue {
                                        speakCurrentContent()
                                    } else {
                                        synthesizer.stopSpeaking(at: .immediate)
                                    }
                                }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.white)
                        
                        Divider()
                            .padding(.leading, 20)
                        
                        // Set Timer 選項
                        HStack(spacing: 15) {
                            Image(systemName: "timer")
                                .font(.system(size: 22))
                                .foregroundColor(.orange)
                            
                            Text("Set Timer")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.white)
                        .onTapGesture {
                            // 在這裡添加計時器功能
                        }
                    }
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showSettings = false
                        }
                        .font(.headline)
                        .foregroundColor(.orange)
                    }
                }
            }
            .presentationDetents([.height(270)])
        }
    }

    private var normalView: some View {
        ZStack(alignment: .top) {
            if isLoading {
                ProgressView()
            } else if let details = recipeDetails {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 圖片部分
                        RecipeHeaderImageView(imageUrl: details.image, isLiked: isLiked, onLikeTapped: {
                            isLiked.toggle()
                            updateLikeStatus()
                        })
                        
                        // 內容
                        VStack(alignment: .leading, spacing: 16) {
                            Text(details.title)
                                .font(.title)
                                .bold()
                            
                            //Health Score
                            HealthScoreView(
                                score: details.healthScore,
                                aiHealthAssessment: aiHealthAssessment,
                                isLoggedIn: userSettings.isLoggedIn,
                                isLoadingAI: isLoadingAI
                            )
                            
                            // 顯示營養資訊
                            if let nutrition = nutritionInfo {
                                NutritionInfoView(
                                    nutrition: nutrition,
                                    selectedNutrientType: $selectedNutrientType,
                                    showAllNutrients: $showAllNutrients
                                )
                            }
                            
                            // 食材
                            IngredientsView(ingredients: details.extendedIngredients)

                            // 烹飪步驟
                            InstructionsView(instructions: details.instructions)
                            
                            // 添加相關食譜推薦
                            SimilarRecipesView(similarRecipes: similarRecipes, isLoading: isLoadingSimilarRecipes)
                            
                            // Recipe Familiarity Selection
                            RecipeFamiliarityView(
                                recipeKnowledgeForKnowledge: $recipeKnowledgeForKnowledge,
                                optimizedStepsForKnowledge: $optimizedStepsForKnowledge
                            )
                            
                            // Flavor Preference Selection
                            FlavorPreferenceView(
                                useDefaultFlavor: $useDefaultFlavor,
                                useGuessedFlavor: $useGuessedFlavor,
                                flavorPreference: flavorPreference,
                                guessedFlavor: guessedFlavor,
                                hasFlavorTrend: hasFlavorTrend,
                                isLoggedIn: userSettings.isLoggedIn,
                                optimizedStepsForKnowledge: $optimizedStepsForKnowledge,
                                onFetchFlavorPreference: {
                                    if flavorPreference.isEmpty {
                                        fetchFlavorPreference()
                                    }
                                },
                                customFlavor: $customFlavor,
                                showFlavorSelectionSheet: $showFlavorSelectionSheet
                            )
                            
                            // 開始製作
                            Button(action: {
                                processRecipeStepsForKnowledge()
                            }) {
                                HStack {
                                    if isProcessingStepsForKnowledge {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                            .padding(.trailing, 5)
                                        Text("Processing...")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    } else {
                                        Text("Start Cooking")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Image(systemName: "fork.knife")
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isProcessingStepsForKnowledge ? Color.orange.opacity(0.8) : Color.orange)
                                .cornerRadius(10)
                            }
                            .disabled(isProcessingStepsForKnowledge)
                            .padding(.top, 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.white)
                                .edgesIgnoringSafeArea(.bottom)
                        )
                    }
                }
                .edgesIgnoringSafeArea(.top)
            }
            
            // Back button overlay (always visible)
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.orange)
                    .padding(10)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .padding(.top, 48) // Safe area top padding
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Remove the second like button that was here
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formattedInstructions(_ instructions: String) -> String {
        let cleanString = instructions.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let steps = cleanString.components(separatedBy: ". ")
        var formattedSteps: [String] = []
        
        for (index, step) in steps.enumerated() {
            if !step.trimmingCharacters(in: .whitespaces).isEmpty {
                formattedSteps.append("Step \(index + 1): \(step.trimmingCharacters(in: .whitespaces))")
            }
        }
        
        return formattedSteps.joined(separator: "\n\n")
    }
    
    private func fetchRecipeDetails() {
        let urlString = "https://api.spoonacular.com/recipes/\(recipeId)/information?includeNutrition=false&apiKey=YOUR_API_KEY_HERE"
        
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Request error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            if let data = data {
                do {
                    let decodedDetails = try JSONDecoder().decode(RecipeDetails.self, from: data)
                    DispatchQueue.main.async {
                        self.recipeDetails = decodedDetails
                        self.isLoading = false
                        
                        // 初始化計時器
                        self.viewStartTime = Date()
                        
                        // 啟動10秒計時器
                        self.startViewDurationTimer()
                        
                        self.checkAndGetAIAssessment()
                        
                        // 食譜詳情加載成功後獲取相關食譜
                        self.fetchSimilarRecipes()
                        
                        // 檢查收藏狀態
                        if self.userSettings.isLoggedIn {
                            self.checkLikeStatus()
                        }
                    }
                    print("Fetched recipe details successfully")
                } catch {
                    print("Error decoding JSON: \(error)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
        }.resume()
    }
    
    // 檢查食譜是否已被收藏
    private func checkLikeStatus() {
        guard userSettings.isLoggedIn, !userUID.isEmpty else { return }
        
        isCheckingLikeStatus = true
        let db = Firestore.firestore()
        
        db.collection("User")
            .document(userUID)
            .collection("Likes")
            .document(String(recipeId))
            .getDocument { (document, error) in
                DispatchQueue.main.async {
                    if let document = document, document.exists {
                        self.isLiked = true
                    } else {
                        self.isLiked = false
                    }
                    self.isCheckingLikeStatus = false
                }
            }
    }
    
    // 更新收藏狀態
    private func updateLikeStatus() {
        guard userSettings.isLoggedIn else {
            // If user is not logged in, show login prompt
            showLoginAlert = true
            return
        }
        
        guard !userUID.isEmpty, let details = recipeDetails else { return }
        
        let db = Firestore.firestore()
        let likeRef = db.collection("User").document(userUID).collection("Likes").document(String(recipeId))
        
        if isLiked {
            // Add to favorites
            let data: [String: Any] = [
                "timestamp": FieldValue.serverTimestamp(),
                "recipeId": recipeId,
                "title": details.title,
                "RecipeImg": details.image ?? "",
                "sourceType": "api"  // Mark as API recipe
            ]
            
            likeRef.setData(data) { error in
                if let error = error {
                    print("Error adding document: \(error)")
                    DispatchQueue.main.async {
                        self.isLiked = false
                    }
                } else {
                    print("Recipe added to favorites")
                    DispatchQueue.main.async {
                        self.showSuccessAlert = true
                    }
                    
                    // 在收藏成功後分析食譜並記錄口味和類型
                    self.analyzeRecipeForLike()
                }
            }
        } else {
            // Remove from favorites
            likeRef.delete() { error in
                if let error = error {
                    print("Error removing document: \(error)")
                    DispatchQueue.main.async {
                        self.isLiked = true
                    }
                } else {
                    print("Recipe removed from favorites")
                }
            }
        }
    }
    
    // 新增 - 處理用戶收藏時的食譜分析
    private func analyzeRecipeForLike() {
        guard userSettings.isLoggedIn, !userUID.isEmpty, let details = recipeDetails else { return }
        
        // 準備食譜詳情的字符串
        var recipeInfo = "Recipe Name: \(details.title)\n"
        recipeInfo += "Ingredients:\n"
        for ingredient in details.extendedIngredients {
            recipeInfo += "- \(ingredient.original)\n"
        }
        
        if let instructions = details.instructions {
            recipeInfo += "Instructions:\n\(instructions)\n"
        }
        
        // 打印用於確認
        print("用戶收藏食譜 \(details.title)，正在使用AI分析食譜...")
        
        // 用AI分析食譜
        RecipeAnalysisService.shared.analyzeRecipe(recipeDetails: recipeInfo) { flavor, foodType, error in
            if let error = error {
                print("AI分析食譜時出錯: \(error.localizedDescription)")
                
                // 錯誤時使用默認值 - 根據食譜標題進行簡單推斷
                let defaultFlavor = self.inferDefaultFlavor(title: details.title)
                let defaultType = self.inferDefaultType(title: details.title)
                
                print("使用默認值 - 口味: \(defaultFlavor), 類型: \(defaultType)")
                
                // 設置isLiked為true因為這是收藏動作
                RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: defaultFlavor, isLiked: true)
                RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: defaultType, isLiked: true)
                return
            }
            
            if let flavor = flavor, let foodType = foodType {
                print("AI分析結果 - 口味: \(flavor), 類型: \(foodType)")
                
                // 更新數據庫中的用戶偏好，設置isLiked為true
                RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: flavor, isLiked: true)
                RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: foodType, isLiked: true)
            } else {
                // API返回空值時也使用默認值
                let defaultFlavor = self.inferDefaultFlavor(title: details.title)
                let defaultType = self.inferDefaultType(title: details.title)
                
                print("API未返回有效值，使用默認值 - 口味: \(defaultFlavor), 類型: \(defaultType)")
                
                RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: defaultFlavor, isLiked: true)
                RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: defaultType, isLiked: true)
            }
        }
    }
    
    // 根據食譜標題推斷默認口味
    private func inferDefaultFlavor(title: String) -> String {
        let lowercaseTitle = title.lowercased()
        
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
    private func inferDefaultType(title: String) -> String {
        let lowercaseTitle = title.lowercased()
        
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

    private func healthScoreEmoji(score: Int) -> String {
        switch score {
        case 0..<20:
            return "🤔"
        case 20..<40:
            return "😌"
        case 40..<60:
            return "😋"
        case 60..<80:
            return "🥰"
        case 80..<95:
            return "🤩"
        default:
            return "👑"  
        }
    }

    private func fetchNutritionInfo() {
        let urlString = "https://api.spoonacular.com/recipes/\(recipeId)/nutritionWidget.json?apiKey=YOUR_API_KEY_HERE"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let nutrition = try JSONDecoder().decode(NutritionInfo.self, from: data)
                    DispatchQueue.main.async {
                        self.nutritionInfo = nutrition
                        self.checkAndGetAIAssessment()
                    }
                    print("Fetched nutrition info successfully")
                } catch {
                    print("Error decoding nutrition info: \(error)")
                }
            }
        }.resume()
    }
    
    // 準備烹飪
    private func prepareCookingSteps() {
        if let instructions = recipeDetails?.instructions {
            let cleanString = instructions.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            let steps = cleanString.components(separatedBy: ". ")
            cookingSteps = steps.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        currentStep = -1
    }
    
    private func speakCurrentContent() {
        guard isFlavorGuideEnabled else { return }
        
        let textToSpeak: String
        
        if currentStep == -1 {
            // 准备食材阶段
            var ingredientsText = "Please prepare the following ingredients: "
            if let details = recipeDetails {
                ingredientsText += details.extendedIngredients.map { $0.original }.joined(separator: ", ")
            }
            textToSpeak = ingredientsText
        } else if currentStep < cookingSteps.count {
            // 烹饪步骤阶段
            textToSpeak = "Step \(currentStep + 1): \(cookingSteps[currentStep])"
        } else {
            // 完成阶段
            textToSpeak = "Cooking Complete! Well done!"
        }
        
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
    
    private func updateNutritionIntake(completion: (() -> Void)? = nil) {
        guard userSettings.isLoggedIn,
              let userUID = UserDefaults.standard.string(forKey: "userUID") else {
            showLoginAlert = true
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("User").document(userUID)
            .collection("target").document("current")
        
        // 獲取當前的營養數據
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                // 獲取當前值
                var currentIngested = document.data()?["Ingested"] as? Double ?? 0
                var currentCarbsIngested = document.data()?["CarbsIngested"] as? Double ?? 0
                var currentFatIngested = document.data()?["FatIngested"] as? Double ?? 0
                var currentProteinIngested = document.data()?["ProteinIngested"] as? Double ?? 0
                
                // 如果有營養信息，更新用戶的攝入量
                if let nutrition = nutritionInfo {
                    // 轉換字符串到數值
                    let calories = Double(nutrition.calories.replacingOccurrences(of: "k", with: "").replacingOccurrences(of: "cal", with: "")) ?? 0
                    let carbs = Double(nutrition.carbs.replacingOccurrences(of: "g", with: "")) ?? 0
                    let fat = Double(nutrition.fat.replacingOccurrences(of: "g", with: "")) ?? 0
                    let protein = Double(nutrition.protein.replacingOccurrences(of: "g", with: "")) ?? 0
                    
                    // 更新值（加法）
                    currentIngested += calories
                    currentCarbsIngested += carbs
                    currentFatIngested += fat
                    currentProteinIngested += protein
                    
                    // 更新數據庫
                    let updatedData: [String: Any] = [
                        "Ingested": currentIngested,
                        "CarbsIngested": currentCarbsIngested,
                        "FatIngested": currentFatIngested,
                        "ProteinIngested": currentProteinIngested
                    ]
                    
                    userRef.updateData(updatedData) { error in
                        if let error = error {
                            print("Error updating nutrition: \(error)")
                        } else {
                            DispatchQueue.main.async {
                                showSuccessAlert = true
                                completion?()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var cookingCompleteView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("🎉 Cooking Complete!")
                .font(.title.bold())
                .padding(.top, 40)
            
            if userSettings.isLoggedIn {
                Button(action: {
                    updateNutritionIntake {
                        // After recording, return to details page
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showCookingMode = false
                            currentStep = -1
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }) {
                    Text("Record Nutrition Intake")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
            }
            
            Button(action: {
                showCookingMode = false
                currentStep = -1
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Return to Recipe")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding(.top, 10)
            }
            
            Spacer()
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
                .tint(.orange)
        } message: {
            Text("Nutrition intake has been recorded!")
        }
        .alert("Please Login", isPresented: $showLoginAlert) {
            Button("OK", role: .cancel) { }
                .tint(.orange)
        } message: {
            Text("Please login to record nutrition intake.")
        }
    }

    private func fetchUserData() {
        guard userSettings.isLoggedIn,
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
        Title: \(details.title)
        Health Score: \(details.healthScore)
        
        Ingredients:
        \(details.extendedIngredients.map { "- " + $0.original }.joined(separator: "\n"))
        
        """
        
        if let nutrition = nutritionInfo {
            contextMessage += """
            
            Nutrition Information:
            Calories: \(nutrition.calories)
            Carbs: \(nutrition.carbs)
            Fat: \(nutrition.fat)
            Protein: \(nutrition.protein)
            """
        }
        
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
        
        Please assess this recipe base on nutrition, dietary fit, and allergy risks, classifying it as safe, allergenic, or potential allergen，explain its impact on nutritional intake after consumption，and within 30 words，without**.
        
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
        guard let _ = recipeDetails,
              let _ = nutritionInfo else {
            return
        }
        
        if userSettings.isLoggedIn {
            if hasTargetData && targetData == nil {
                return
            }
            if hasAllergyData && allergyData.isEmpty {
                return
            }
        }
        
        getAIHealthAssessment()
    }

    private func fetchUserType() {
        guard userSettings.isLoggedIn,
              let userUID = UserDefaults.standard.string(forKey: "userUID") else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("User").document(userUID).getDocument { document, error in
            if let document = document, document.exists {
                userType = document.data()?["user_type"] as? String ?? "beginner"
                print("Fetched user type: \(userType)")
            }
        }
    }

    private func getAICookingTip(step: String) {
        guard userSettings.isLoggedIn else {
            print("User not logged in - skipping AI tips")
            return
        }
        
        let contextMessage = """
        User type: \(userType)
        Cooking step: \(step)
        
        Please provide a short cooking tip (max 20 words) based on user type.
        For beginner users, focus on food safety and basic timing.
        For advanced users, focus on taste and texture.
        """
        
        print("Sending to AI: \(contextMessage)")
        
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                print("AI Response: \(response)")
                await MainActor.run {
                    aiCookingTip = response
                }
            } catch {
                print("Error getting AI tip: \(error.localizedDescription)")
            }
        }
    }

    // Process recipe steps based on user's knowledge level
    private func processRecipeStepsForKnowledge() {
        // Set loading state immediately
        self.isProcessingStepsForKnowledge = true
        
        // If custom flavor is selected, proceed immediately
        if !customFlavor.isEmpty {
            processRecipeWithFlavor()
            return
        }
        
        // If guessed flavor is selected, proceed immediately
        if useGuessedFlavor && !guessedFlavor.isEmpty {
            processRecipeWithFlavor()
            return
        }
        
        // Fetch flavor preference if user chooses personalized flavor
        if !useDefaultFlavor && userSettings.isLoggedIn {
            fetchFlavorPreference()
        } else {
            // Proceed with default flavor
            processRecipeWithFlavor()
        }
    }
    
    private func fetchFlavorPreference() {
        guard userSettings.isLoggedIn,
              let userUID = UserDefaults.standard.string(forKey: "userUID") else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("User").document(userUID).getDocument { document, error in
            if let error = error {
                print("Error fetching user flavor preference: \(error)")
                return
            }
            
            if let document = document, document.exists,
               let flavorPref = document.data()?["flavor_preference"] as? String {
                self.flavorPreference = flavorPref
                print("Fetched flavor preference: \(flavorPref)")
            } else {
                self.flavorPreference = "balanced"
                print("No specific flavor preference found, using default")
            }
        }
        
        // Also fetch flavor trend data for "Guess You Like" option
        fetchFlavorTrend()
    }
    
    // New function to fetch flavor trend data
    private func fetchFlavorTrend() {
        guard userSettings.isLoggedIn,
              let userUID = UserDefaults.standard.string(forKey: "userUID") else {
            return
        }
        
        let db = Firestore.firestore()
        let flavorTrendRef = db.collection("User").document(userUID).collection("FlavorTrend")
        
        // First check if the FlavorTrend subcollection exists
        flavorTrendRef.getDocuments { (snapshot, error) in
            if let error = error {
                print("Error checking for FlavorTrend subcollection: \(error)")
                self.hasFlavorTrend = false
                return
            }
            
            guard let snapshot = snapshot, !snapshot.documents.isEmpty else {
                print("No FlavorTrend subcollection found")
                self.hasFlavorTrend = false
                return
            }
            
            self.hasFlavorTrend = true
            
            // Get the user's current flavor preference to exclude it from suggestions
            db.collection("User").document(userUID).getDocument { (document, error) in
                if let error = error {
                    print("Error fetching user document: \(error)")
                    return
                }
                
                var userCurrentPreference = ""
                if let document = document, document.exists,
                   let flavorPref = document.data()?["flavor_preference"] as? String {
                    userCurrentPreference = flavorPref
                    print("User's current flavor preference: \(flavorPref)")
                }
                
                // Create a dictionary to track flavor frequencies
                var flavorCounts: [String: Int] = [:]
                
                // Process all flavor documents
                for document in snapshot.documents {
                    let flavorName = document.documentID
                    // Skip the user's current preference
                    if flavorName.lowercased() == userCurrentPreference.lowercased() {
                        continue
                    }
                    
                    if let frequency = document.data()["Frequency"] as? Int {
                        flavorCounts[flavorName] = frequency
                    }
                }
                
                // Find the flavor with the highest frequency
                if let topFlavor = flavorCounts.max(by: { $0.value < $1.value }) {
                    self.guessedFlavor = topFlavor.key
                    print("Guessed flavor with highest frequency: \(topFlavor.key) with count \(topFlavor.value)")
                } else {
                    print("No alternative flavors found besides the user's preference")
                    self.guessedFlavor = ""
                }
            }
        }
    }
    
    private func processRecipeWithFlavor() {
        // Log processing start
        let flavorDescription = useDefaultFlavor 
            ? "Default" 
            : (useGuessedFlavor 
                ? "Guessed: \(guessedFlavor)" 
                : (!customFlavor.isEmpty 
                    ? "Custom: \(customFlavor)" 
                    : "Personalized: \(flavorPreference)"))
                    
        print("Started processing recipe with familiarity: \(recipeKnowledgeForKnowledge ? "Familiar" : "Unfamiliar") and flavor: \(flavorDescription)")
        
        if let details = self.recipeDetails {
            // Extract instructions as single steps
            var steps: [String] = []
            if let instructions = details.instructions {
                let cleanString = instructions.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                steps = cleanString.components(separatedBy: ". ").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            }
            
            let recipeName = details.title
            let stepsText = steps.enumerated().map { index, step in
                "Step \(index + 1): \(step)"
            }.joined(separator: "\n")
            
            // Prepare AI request message
            var contextMessage = """
            Recipe: \(recipeName)
            
            Original steps:
            \(stepsText)
            
            """
            
            // Add knowledge level context
            if recipeKnowledgeForKnowledge {
                // Familiar with recipe
                contextMessage += """
                I'm FAMILIAR with this recipe. Please optimize these steps by:
                1. Fixing any errors or typos
                2. Ensuring each step is clear but concise
                3. Maintaining the original flow of the recipe
                
                """
            } else {
                // Unfamiliar with recipe
                contextMessage += """
                I'm UNFAMILIAR with this recipe. Please provide detailed steps by:
                1. Breaking down complex instructions into simpler sub-steps
                2. Adding specific details about cooking techniques
                3. Including visual cues for doneness or consistency
                4. Explaining why certain steps are important
                
                """
            }
            
            // Add flavor preference context
            if useGuessedFlavor && !guessedFlavor.isEmpty {
                // Use guessed flavor
                contextMessage += """
                
                I'd like to try \(guessedFlavor) flavors. Please adjust the recipe to:
                1. Enhance or emphasize \(guessedFlavor) flavors where possible
                2. Suggest alternative ingredients or additional seasonings to match this flavor profile
                3. Include specific tips for achieving this flavor profile
                
                """
            } else if !customFlavor.isEmpty {
                // Use custom flavor
                contextMessage += """
                
                I'd like to try \(customFlavor) flavors. Please adjust the recipe to:
                1. Enhance or emphasize \(customFlavor) flavors where possible
                2. Suggest alternative ingredients or additional seasonings to match this flavor profile
                3. Include specific tips for achieving this flavor profile
                
                """
            } else if !useDefaultFlavor && !flavorPreference.isEmpty {
                // Use personalized flavor
                contextMessage += """
                
                I prefer \(flavorPreference) flavors. Please adjust the recipe to:
                1. Enhance or emphasize \(flavorPreference) flavors where possible
                2. Suggest alternative ingredients or additional seasonings to match my preference
                3. Include specific tips for achieving my preferred flavor profile
                
                """
            }
            
            contextMessage += """
            
            Please respond with ONLY the optimized steps in this exact format:
            Step 1: [optimized step]
            Step 2: [optimized step]
            ...and so on.
            """
            
            Task {
                do {
                    let flavorType = useGuessedFlavor 
                        ? "Guessed (\(guessedFlavor))" 
                        : (useDefaultFlavor 
                            ? "Default" 
                            : (!customFlavor.isEmpty 
                                ? "Custom (\(customFlavor))" 
                                : "Personalized (\(flavorPreference))"))
                    
                    print("Sending recipe to AI for processing with flavor preference: \(flavorType)")
                    let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                    print("AI response received, processing steps...")
                    
                    // Process the AI response
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
                    
                    print("Processed \(processedSteps.count) steps from AI")
                    
                    // Update the UI
                    await MainActor.run {
                        self.optimizedStepsForKnowledge = processedSteps
                        self.isProcessingStepsForKnowledge = false
                        self.showCookingStepsView = true
                    }
                } catch {
                    print("Error getting AI optimization: \(error.localizedDescription)")
                    await MainActor.run {
                        self.isProcessingStepsForKnowledge = false
                        self.showCookingStepsView = true // Still show cooking steps with original instructions
                    }
                }
            }
        } else {
            print("No recipe details available")
            self.isProcessingStepsForKnowledge = false
            self.showCookingStepsView = true
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
              userSettings.isLoggedIn,
              !hasAnalyzedRecipe,
              let userUID = UserDefaults.standard.string(forKey: "userUID"),
              let details = recipeDetails
        else { return }
        
        // 確認已經過了10秒
        let viewDuration = Date().timeIntervalSince(viewStartTime)
        if viewDuration >= 10.0 {
            // 標記為已分析，避免重複分析
            hasAnalyzedRecipe = true
            
            // 準備食譜詳情的字符串
            var recipeInfo = "Recipe Name: \(details.title)\n"
            recipeInfo += "Ingredients:\n"
            for ingredient in details.extendedIngredients {
                recipeInfo += "- \(ingredient.original)\n"
            }
            
            if let instructions = details.instructions {
                recipeInfo += "Instructions:\n\(instructions)\n"
            }
            
            // 打印用於確認
            print("已瀏覽食譜 \(details.title) 超過10秒，正在使用AI分析食譜...")
            
            // 用AI分析食譜
            RecipeAnalysisService.shared.analyzeRecipe(recipeDetails: recipeInfo) { flavor, foodType, error in
                if let error = error {
                    print("AI分析食譜時出錯: \(error.localizedDescription)")
                    
                    // 錯誤時使用默認值 - 根據食譜標題進行簡單推斷
                    let defaultFlavor = self.inferDefaultFlavor(title: details.title)
                    let defaultType = self.inferDefaultType(title: details.title)
                    
                    print("使用默認值 - 口味: \(defaultFlavor), 類型: \(defaultType)")
                    
                    // 即使API出錯，也使用默認值更新數據庫
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
                    let defaultFlavor = self.inferDefaultFlavor(title: details.title)
                    let defaultType = self.inferDefaultType(title: details.title)
                    
                    print("API未返回有效值，使用默認值 - 口味: \(defaultFlavor), 類型: \(defaultType)")
                    
                    RecipeAnalysisService.shared.updateFlavorTrend(userUID: userUID, flavor: defaultFlavor)
                    RecipeAnalysisService.shared.updateFoodTypeHistory(userUID: userUID, foodType: defaultType)
                }
            }
        }
    }
    
    // 添加獲取相關食譜的函數
    private func fetchSimilarRecipes() {
        isLoadingSimilarRecipes = true
        
        let urlString = "https://api.spoonacular.com/recipes/\(recipeId)/similar?apiKey=YOUR_API_KEY_HERE"
        
        guard let url = URL(string: urlString) else {
            isLoadingSimilarRecipes = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching similar recipes: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingSimilarRecipes = false
                }
                return
            }
            
            if let data = data {
                do {
                    let decodedRecipes = try JSONDecoder().decode([SimilarRecipe].self, from: data)
                    DispatchQueue.main.async {
                        // 最多顯示6個相關食譜
                        self.similarRecipes = Array(decodedRecipes.prefix(6))
                        self.isLoadingSimilarRecipes = false
                    }
                    print("Fetched \(decodedRecipes.count) similar recipes")
                } catch {
                    print("Error decoding similar recipes: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingSimilarRecipes = false
                    }
                }
            }
        }.resume()
    }
}

struct RecipeDetails: Codable {
    let id: Int?
    let title: String
    let image: String?
    let preparationMinutes: Int?
    let cookingMinutes: Int?
    let healthScore: Int
    let extendedIngredients: [Ingredient]
    let instructions: String?
}

struct Ingredient: Codable {
    let id: Int?
    let original: String
}
 
struct NutritionCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.orange)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct NutrientRow: View {
    let nutrient: NutrientInfo
    
    var body: some View {
        HStack {
            Text(nutrient.title)
            Spacer()
            Text(nutrient.amount)
            Text("(Daily: \(Int(nutrient.percentOfDailyNeeds))%)")
                .font(.caption)
                
        }
        .padding(.vertical, 4)
    }
}

struct HighlightedText: View {
    let text: String
    
    var body: some View {
        let attributedText = attributedStringWithHighlighting(text)
        
        Text(attributedText)
            .font(.body)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 創建帶有高亮的歸因字符串
    private func attributedStringWithHighlighting(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // 定義過敏關鍵詞列表
        let allergyKeywords = ["allerg", "allergy", "allergenic", "allergen"]
        
        // 遍歷文本查找過敏關鍵詞
        for keyword in allergyKeywords {
            // 找出所有關鍵詞的位置
            var searchRange = attributedString.startIndex..<attributedString.endIndex
            while let range = attributedString[searchRange].range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) {
                // 給這個範圍設置紅色和粗體
                attributedString[range].foregroundColor = .red
                attributedString[range].font = .body.bold()
                
                // 更新搜索範圍，從當前找到的範圍之後開始
                searchRange = range.upperBound..<attributedString.endIndex
            }
        }
        
        return attributedString
    }
}

struct DetailFlavorOptionCard: View {
    let isSelected: Bool
    let icon: String
    let title: String
    let description: String
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .white : .orange)
                    .frame(width: 50, height: 50)
                    .background(
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.orange : Color.orange.opacity(0.1))
                            
                            if isSelected {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .padding(4)
                            }
                        }
                    )
                    .shadow(color: isSelected ? Color.orange.opacity(0.4) : Color.clear, radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDisabled ? .gray : (isSelected ? .orange : .primary))
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(isDisabled ? .gray.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .orange : .gray.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : Color.gray.opacity(0.1), lineWidth: 1.5)
            )
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled)
    }
}

// Header Image View
struct RecipeHeaderImageView: View {
    let imageUrl: String?
    let isLiked: Bool
    let onLikeTapped: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let imageUrlString = imageUrl, let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width, height: 250)
                        .clipped()
                } placeholder: {
                    ProgressView()
                        .frame(height: 250)
                }
            }
            
            // Like 按鈕 - 更改為白色背景
            Button(action: onLikeTapped) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundColor(isLiked ? .red : .orange)
                    .padding(10)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .padding(.trailing, 16)
            .padding(.top, 50) // 增加頂部距離避免狀態欄衝突
        }
    }
}

// Health Score View
struct HealthScoreView: View {
    let score: Int
    let aiHealthAssessment: String
    let isLoggedIn: Bool
    let isLoadingAI: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Health Score: \(score)")
                    .font(.headline)
                Text(healthScoreEmoji(score: score))
                    .font(.title2)
            }
            
            // AI Health Assessment
            if !aiHealthAssessment.isEmpty && isLoggedIn {
                Text("By AI Flavour Dietitian:")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
                
                HighlightedText(text: aiHealthAssessment)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            } else if isLoadingAI && isLoggedIn {
                ProgressView()
                    .padding(.top, 8)
            }
        }
        .padding(.top, 4)
    }
    
    func healthScoreEmoji(score: Int) -> String {
        switch score {
        case 0..<20:
            return "🤔"
        case 20..<40:
            return "😌"
        case 40..<60:
            return "😋"
        case 60..<80:
            return "🥰"
        case 80..<95:
            return "🤩"
        default:
            return "👑"  
        }
    }
}

// Nutrition Info View
struct NutritionInfoView: View {
    let nutrition: NutritionInfo
    @Binding var selectedNutrientType: Int
    @Binding var showAllNutrients: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                NutritionCard(title: "Calories", value: nutrition.calories)
                NutritionCard(title: "Carbs", value: nutrition.carbs)
                NutritionCard(title: "Fat", value: nutrition.fat)
                NutritionCard(title: "Protein", value: nutrition.protein)
            }
            .padding(.vertical, 8)
            
            Picker("Nutrition Type", selection: $selectedNutrientType) {
                Text("Warnings").tag(0)
                Text("Benefits").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .accentColor(.orange)
            .padding(.vertical, 8)
            
            NutrientListView(
                nutrients: selectedNutrientType == 0 ? nutrition.bad : nutrition.good,
                showAllNutrients: $showAllNutrients
            )
        }
        .padding(.vertical, 8)
    }
}

// Nutrient List View
struct NutrientListView: View {
    let nutrients: [NutrientInfo]
    @Binding var showAllNutrients: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let displayedNutrients = showAllNutrients ? nutrients : Array(nutrients.prefix(5))
            
            ForEach(displayedNutrients, id: \.title) { nutrient in
                NutrientRow(nutrient: nutrient)
            }
            
            if nutrients.count > 5 {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            showAllNutrients.toggle()
                        }
                    }) {
                        Text(showAllNutrients ? "Show Less" : "Show More...")
                            .foregroundColor(Color.orange.opacity(0.8))
                            .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        }
    }
}

// Ingredients View
struct IngredientsView: View {
    let ingredients: [Ingredient]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredients:")
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.top, 8)

            ForEach(ingredients, id: \.id) { ingredient in
                Text("- \(ingredient.original)")
                    .padding(.leading, 8)
                    .padding(.vertical, 2)
            }
        }
    }
}

// Instructions View
struct InstructionsView: View {
    let instructions: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instructions:")
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.top, 16)

            if let instructions = instructions {
                Text(formattedInstructions(instructions))
            } else {
                Text("No instructions available.")
                    .foregroundColor(.orange.opacity(0.8))
            }
        }
    }
    
    private func formattedInstructions(_ instructions: String) -> String {
        let cleanString = instructions.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let steps = cleanString.components(separatedBy: ". ")
        var formattedSteps: [String] = []
        
        for (index, step) in steps.enumerated() {
            if !step.trimmingCharacters(in: .whitespaces).isEmpty {
                formattedSteps.append("Step \(index + 1): \(step.trimmingCharacters(in: .whitespaces))")
            }
        }
        
        return formattedSteps.joined(separator: "\n\n")
    }
}

// Recipe Familiarity View
struct RecipeFamiliarityView: View {
    @Binding var recipeKnowledgeForKnowledge: Bool
    @Binding var optimizedStepsForKnowledge: [String]
    
    var body: some View {
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
    }
}

// Flavor Preference View
struct FlavorPreferenceView: View {
    @Binding var useDefaultFlavor: Bool
    @Binding var useGuessedFlavor: Bool
    let flavorPreference: String
    let guessedFlavor: String
    let hasFlavorTrend: Bool
    let isLoggedIn: Bool
    @Binding var optimizedStepsForKnowledge: [String]
    let onFetchFlavorPreference: () -> Void
    @Binding var customFlavor: String
    @Binding var showFlavorSelectionSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flavor Preference:")
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.top, 16)
            
            VStack(spacing: 10) {
                // Default Flavor option
                DetailFlavorOptionCard(
                    isSelected: useDefaultFlavor,
                    icon: "fork.knife.circle.fill",
                    title: "Default Flavor",
                    description: "Follow the original recipe with standard flavoring",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            useDefaultFlavor = true
                            useGuessedFlavor = false
                            optimizedStepsForKnowledge = []
                        }
                    }
                )
                
                // Personalized Flavor option
                DetailFlavorOptionCard(
                    isSelected: !useDefaultFlavor && !useGuessedFlavor && customFlavor.isEmpty,
                    icon: "flame.circle.fill",
                    title: flavorPreference.isEmpty ? "Personalized Flavor" : "Personalized (\(flavorPreference))",
                    description: "Adapt the recipe to match your flavor preferences",
                    isDisabled: !isLoggedIn,
                    action: {
                        if isLoggedIn {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                useDefaultFlavor = false
                                useGuessedFlavor = false
                                customFlavor = ""
                                optimizedStepsForKnowledge = []
                                
                                onFetchFlavorPreference()
                            }
                        }
                    }
                )
                
                // Guess You Like option
                if hasFlavorTrend && !guessedFlavor.isEmpty && isLoggedIn {
                    DetailFlavorOptionCard(
                        isSelected: useGuessedFlavor,
                        icon: "lightbulb.circle.fill",
                        title: "Guess You Like (\(guessedFlavor))",
                        description: "Try this flavor based on your previous preferences",
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                useDefaultFlavor = false
                                useGuessedFlavor = true
                                customFlavor = ""
                                optimizedStepsForKnowledge = []
                            }
                        }
                    )
                }
                
                // Custom Flavor option (if selected)
                if !customFlavor.isEmpty {
                    DetailFlavorOptionCard(
                        isSelected: !useDefaultFlavor && !useGuessedFlavor && !customFlavor.isEmpty,
                        icon: "star.circle.fill",
                        title: "Custom (\(customFlavor))",
                        description: "Your personally selected flavor profile",
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                useDefaultFlavor = false
                                useGuessedFlavor = false
                                optimizedStepsForKnowledge = []
                            }
                        }
                    )
                }
                
                // More options button
                Button(action: {
                    showFlavorSelectionSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.orange)
                        
                        Text("More flavor options")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.orange.opacity(0.7))
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                .disabled(!isLoggedIn)
                .opacity(isLoggedIn ? 1.0 : 0.6)
                .padding(.top, 6)
            }
        }
        .sheet(isPresented: $showFlavorSelectionSheet) {
            CustomFlavorSelectionView(selectedFlavor: $customFlavor)
                .onDisappear {
                    if !customFlavor.isEmpty {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            useDefaultFlavor = false
                            useGuessedFlavor = false
                            optimizedStepsForKnowledge = []
                        }
                        // Log the custom flavor selection
                        print("Custom flavor selected: \(customFlavor)")
                    }
                }
        }
    }
}

// 添加相關食譜視圖元件
struct SimilarRecipesView: View {
    let similarRecipes: [SimilarRecipe]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !similarRecipes.isEmpty || isLoading {
                Text("Similar Recipes:")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding(.top, 16)
                
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .frame(height: 150)
                        Spacer()
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(similarRecipes) { recipe in
                                NavigationLink(destination: DetailOfRecipeView(recipeId: recipe.id)) {
                                    VStack(alignment: .center, spacing: 8) {
                                        // 圖片
                                        AsyncImage(url: URL(string: recipe.imageUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 140, height: 100)
                                                .cornerRadius(10)
                                                .clipped()
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 140, height: 100)
                                                .cornerRadius(10)
                                                .overlay(
                                                    ProgressView()
                                                )
                                        }
                                        
                                        // 名稱
                                        Text(recipe.title)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 140)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        // 烹飪時間
                                        Text("\(recipe.readyInMinutes) mins • \(recipe.servings) servings")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 140)
                                    .padding(.bottom, 8)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}

