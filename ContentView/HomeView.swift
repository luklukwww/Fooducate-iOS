import SwiftUI
import FirebaseFirestore

// Add ChatService definition
private let chatService = ChatService(
    mixraiKey: "YOUR_AI_HERE",
    deepseekKey: "YOUR_AI_HERE"
)

// 如果 NutritionStatusView 在不同的模組中，需要導入該模組
// import YourModuleName

struct MainTabView: View {
    @EnvironmentObject private var tabBarManager: TabBarManager
    @EnvironmentObject var userSettings: UserSettings
    @State private var showNutritionStatus = false
    @State private var ballPosition = CGPoint(x: UIScreen.main.bounds.width - 76, y: UIScreen.main.bounds.height - 180)
    @StateObject private var nutritionManager = NutritionManager.shared
    @State private var sheetDetent: PresentationDetent = .medium
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 253/255, green: 179/255, blue: 80/255, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.iconColor = .white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = .white
    }

    var body: some View {
        ZStack {
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                    }
                Exploreview()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                    }
                LikesView()
                    .tabItem {
                        Image(systemName: "heart.fill")
                    }
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                    }
            }
            .background(Color.clear)
            
            // 保留可拖動的懸浮球
            GeometryReader { geometry in
                Button {
                    if userSettings.isLoggedIn {
                        if let userUID = UserDefaults.standard.string(forKey: "userUID") {
                            nutritionManager.fetchNutritionData(userUID: userUID)
                        }
                    }
                    showNutritionStatus.toggle()
                } label: {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .position(x: ballPosition.x, y: ballPosition.y)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            var newX = value.location.x
                            var newY = value.location.y
                            newX = min(max(28, newX), geometry.size.width - 28)
                            let topLimit: CGFloat = 50
                            let bottomLimit = geometry.size.height - 140
                            newY = min(max(topLimit, newY), bottomLimit)
                            ballPosition = CGPoint(x: newX, y: newY)
                        }
                )
            }
            
            VStack {
                Spacer()
                if tabBarManager.isVisible {
                    Rectangle()
                        .fill(Color(red: 253/255, green: 179/255, blue: 80/255))
                        .frame(height: 49)
                        .edgesIgnoringSafeArea(.bottom)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .sheet(isPresented: $showNutritionStatus) {
            NutritionStatusView(sheetDetent: $sheetDetent)
                .presentationDetents([.medium, .large], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground(.white)
                .interactiveDismissDisabled()
        }
    }
}

// MARK: - AI Chat View
struct AIChatView: View {
    var body: some View {
        VStack {
            Text("AI Chat Interface")
                .font(.largeTitle)
                .padding()
        }
        .navigationTitle("AI Chat")
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var userSettings: UserSettings
    @State private var aiSuggestedCategory: String = "Other recipe"
    @State private var recipeQuery: String = ""
    @State private var mostPopularRecipes: [Recipe] = []
    @State private var mostLovedRecipes: [Recipe] = []
    @State private var selectedCategory: String = "Breakfast"
    @State private var navigateToResults = false
    @State private var searchedRecipes: [Recipe] = []
    @State private var isImagePickerPresented = false
    @State private var selectedImage: UIImage?
    @State private var lastSearchQuery: String = "Other recipe"
    @StateObject private var nutritionManager = NutritionManager.shared
    @State private var showWarningMessage = false
    @State private var popularOffset: Int = 0 // Add offset for popular recipes
    @State private var lovedOffset: Int = 0 // Add offset for loved recipes
    @State private var userPreferenceRecipes: [Recipe] = [] // Add array for user preference recipes
    @State private var userPreferenceQuery: String = "" // Store the AI generated query based on user preferences
    @AppStorage("userFlavorPreference") private var savedFlavorPreference: String = ""
    @AppStorage("userFoodType") private var savedFoodType: String = ""
    @State private var isLoadingFoodRecommendations = false
    @State private var retryCount = 0  // 添加重试计数器
    @State private var maxRetries = 3  // 最大重试次数
    // 添加猜你喜欢相关状态变量
    @State private var guessYouLikeRecipes: [Recipe] = []
    @State private var guessYouLikeQuery: String = ""
    @State private var isLoadingGuessYouLike = false
    @State private var hasFoodTypeHistory = false
    @State private var isLoadingCategoryNext = false
    @State private var isLoadingRecipeSection = false
    @State private var hasTargetData = false // 追蹤用戶是否有 target 子集合數據
    
    private let foodDetector: FoodDetector
    
    init() {
        print("Initializing HomeView")
        self.foodDetector = FoodDetector()
        // 根據當前時間設置默認類別
        let hour = Calendar.current.component(.hour, from: Date())
        let defaultCategory: String
        switch hour {
        case 5..<11:  // 5:00 AM - 10:59 AM
            defaultCategory = "Breakfast"
        case 11..<14:  // 11:00 AM - 1:59 PM
            defaultCategory = "Lunch"
        case 14..<17:  // 2:00 PM - 4:59 PM
            defaultCategory = "Desserts"
        case 17..<22:  // 5:00 PM - 9:59 PM
            defaultCategory = "Dinner"
        default:
            defaultCategory = "Breakfast"
        }
        _selectedCategory = State(initialValue: defaultCategory)
    }

    let categories = ["Breakfast", "Lunch", "Dinner", "Desserts"]  // 移除 "All" 並重新排序

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    searchAndCategorySection
                    recipeSection(title: "", recipes: mostPopularRecipes)
                    
                    // 修改条件，即使 userPreferenceRecipes 為空也顯示該部分，只要用戶已登錄
                    if userSettings.isLoggedIn {
                        userPreferenceSection
                    }
                    
                    // 如果有FoodTypeHistory資料，顯示"猜你喜歡"部分
                    if hasFoodTypeHistory && !guessYouLikeRecipes.isEmpty && userSettings.isLoggedIn {
                        recipeSection(title: "Guess You Like: \(guessYouLikeQuery)", recipes: guessYouLikeRecipes)
                    }
                    
                    // Always show this section for both logged-in and non-logged-in users
                    recipeSection(title: (userSettings.isLoggedIn && hasTargetData) ? aiSuggestedCategory : "Other recipe", recipes: mostLovedRecipes)
                }
                .padding(.top, 5)
                .background(
                    Group {
                        // 直接使用傳統的NavigationLink，這對所有iOS版本都有效
                        NavigationLink(
                            destination: RecipeSearchResultView(recipes: searchedRecipes),
                            isActive: $navigateToResults,
                            label: { EmptyView() }
                        )
                    }
                )
            }
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .onAppear {
                fetchPopularRecipes(category: selectedCategory)
                fetchAISuggestion()
                
                // Always fetch user preference recipes when view appears
                if userSettings.isLoggedIn {
                    print("🔄 REFRESHING FOOD TYPE RECOMMENDATIONS")
                    isLoadingFoodRecommendations = true
                    fetchUserPreferenceRecipes()
                    
                    // 檢查並獲取FoodTypeHistory資料
                    fetchGuessYouLikeFoodType()
                }
            }
        }
    }

    private var searchAndCategorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome Fooducate")
                .font(.title2)
                .bold()
                .padding(.leading, 15)
            
            Text("What do you want to cook today ?")
                .padding(.leading, 15)
                .font(.body)
                .padding(.bottom, 5)
            
            HStack {
                TextField("Search Recipe", text: $recipeQuery)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                Button(action: {
                    if recipeQuery.isEmpty {
                        showWarningMessage = true // Show warning if input is empty
                    } else {
                        showWarningMessage = false // Hide warning if input is valid
                        searchRecipes(query: recipeQuery, shouldNavigate: true)
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.customOrange)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
            
            // Warning message for empty input
            if showWarningMessage {
                Text("Please enter at least one character.")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.leading, 15)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Category")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.title3)
                            .bold()
                        
                            Button(action: {
                            isLoadingCategoryNext = true
                                popularOffset += 5
                                fetchPopularRecipes(category: selectedCategory, offset: popularOffset)
                            // 延遲1秒後重置加載狀態，確保視覺效果明顯
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isLoadingCategoryNext = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isLoadingCategoryNext {
                                    Text("Loading...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.customOrange)
                                } else {
                                    Text("Next batch")
                                        .font(.caption)
                                        .foregroundColor(.customOrange)
                                    
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.customOrange)
                            }
                        }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .disabled(isLoadingCategoryNext)
                    }
                    .padding(.leading, 15)
                    .padding(.top, 5)

                    HStack(spacing: 15) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                                popularOffset = 0 // Reset offset when changing category
                                fetchPopularRecipes(category: category, offset: popularOffset)
                            }) {
                                Text(category)
                                    .padding(8)
                                    .background(selectedCategory == category ? Color.customOrange : Color(.systemGray4))
                                    .foregroundColor(Color(.white))
                                    .cornerRadius(11)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(image: $selectedImage, isPresented: $isImagePickerPresented)
            }
            .onChange(of: selectedImage) { newImage in
                print("Selected image changed")
                if let image = newImage {
                    print("Image selected, starting food detection...")
                    
                    foodDetector.detectFood(from: image) { prediction in
                        print("Food detection completed")
                        if let prediction = prediction {
                            print("Detection result: \(prediction)")
                            if let foodName = prediction.components(separatedBy: " - ").first {
                                print("Extracted food name: \(foodName)")
                                DispatchQueue.main.async {
                                    print("Updating UI with food name: \(foodName)")
                                    self.recipeQuery = foodName
                                    self.searchRecipes(query: foodName, shouldNavigate: true)
                                }
                            } else {
                                print("Failed to extract food name from prediction")
                            }
                        } else {
                            print("No prediction result received")
                        }
                    }
                } else {
                    print("No image selected")
                }
            }
        }
    }

    private func recipeSection(title: String, recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                HStack {
                    Text(title)
                        .font(.title3)
                        .bold()
                    
                    // Show refresh button for AI-suggested categories or Most Loved
                    if userSettings.isLoggedIn || title == "Other recipe" {
                        Button(action: {
                            isLoadingRecipeSection = true
                            lovedOffset += 5
                            if title.starts(with: "Flavour Dietitian:") {
                                fetchAISuggestion()
                            } else if title.starts(with: "Guess You Like:") {
                                fetchGuessYouLikeFoodType()
                            } else {
                                fetchDefaultRecipes(offset: lovedOffset)
                            }
                            // 延遲1秒後重置加載狀態
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isLoadingRecipeSection = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isLoadingRecipeSection {
                                    Text("Loading...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.customOrange)
                                } else {
                                    if title.starts(with: "Flavour Dietitian:") || title.starts(with: "Guess You Like:") {
                                        Text("New type")
                                            .font(.caption)
                                            .foregroundColor(.customOrange)
                                    } else {
                                        Text("Next batch")
                                            .font(.caption)
                                            .foregroundColor(.customOrange)
                                    }
                                    
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.customOrange)
                        }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .disabled(isLoadingRecipeSection)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
                
                // 只在 Flavour Dietitian 部分顯示健康推薦標籤
                if title.starts(with: "Flavour Dietitian:") && hasTargetData {
                    HStack {
                        Text("Healthy Recommendation: Based on your nutritional needs")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                }
                
                // 在 Guess You Like 部分顯示推薦標籤
                if title.starts(with: "Guess You Like:") {
                    HStack {
                        Text("Based on your frequently viewed food types")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(recipes) { recipe in
                        NavigationLink(destination: DetailOfRecipeView(recipeId: recipe.id)) {
                            RecipeCard(recipe: recipe)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
            }
        }
    }

    private var userPreferenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Recipe type: \(userPreferenceQuery.isEmpty ? "Loading..." : userPreferenceQuery)")
                        .font(.title2)
                        .bold()
                        
                    Button(action: {
                        isLoadingFoodRecommendations = true
                        fetchUserPreferenceRecipes()
                    }) {
                        HStack(spacing: 4) {
                            if isLoadingFoodRecommendations {
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.customOrange)
                            } else {
                                Text("New type")
                                    .font(.caption)
                                    .foregroundColor(.customOrange)
                        
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.orange)
                        .font(.title3)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isLoadingFoodRecommendations)
                }
                .padding(.horizontal)
                
                // 修改條件，確保標籤總是顯示
                HStack {
                    if !savedFoodType.isEmpty && savedFoodType != "Other" {
                        Text("Based on your preference for \(savedFoodType) cuisine")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                    } else {
         
                        Text("Based on your recipe preferences")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            if isLoadingFoodRecommendations && userPreferenceRecipes.isEmpty {
                HStack {
                    Spacer()
                    VStack {
                        ProgressView()
                            .padding()
                        Text("Finding \(savedFoodType) recipes for you...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .frame(height: 150)
            } else if !userPreferenceRecipes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(userPreferenceRecipes) { recipe in
                            NavigationLink(destination: DetailOfRecipeView(recipeId: recipe.id)) {
                                RecipeCard(recipe: recipe)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange.opacity(0.5))
                            .padding()
                        
                        Text("No recipes found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            isLoadingFoodRecommendations = true
                            fetchUserPreferenceRecipes()
                        }) {
                            Text("Try again")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                    }
                    Spacer()
                }
                .frame(height: 200)
            }
        }
        .padding(.vertical, 5)
    }

    struct RecipeCard: View {
        let recipe: Recipe

        var body: some View {
            VStack(spacing: 0) {
                AsyncImage(url: URL(string: recipe.image)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 200)
                        .clipped()
                        .cornerRadius(10)
                } placeholder: {
                    ProgressView()
                        .frame(width: 150, height: 200)
                }
                .frame(width: 150, height: 200)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)

                Text(recipe.title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .frame(width: 150)
                    .lineLimit(2)
                    .padding(.vertical, 8)
            }
            .frame(width: 150, height: 240)
            .background(Color.white)
            .cornerRadius(10)
        }
    }

    func fetchPopularRecipes(category: String, offset: Int = 0) {
        let apiKey = "YOUR_API_KEY_HERE"
        let formattedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.spoonacular.com/recipes/complexSearch?query=\(formattedCategory)&sort=popularity&number=5&offset=\(offset)&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let decodedData = try? JSONDecoder().decode(RecipeResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.mostPopularRecipes = decodedData.results
                    self.isLoadingCategoryNext = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingCategoryNext = false
                }
            }
        }.resume()
    }

    func searchRecipes(query: String, shouldNavigate: Bool) {
        print("開始搜索: \(query), 需要導航: \(shouldNavigate)")
        let apiKey = "YOUR_API_KEY_HERE"
        let formattedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.spoonacular.com/recipes/complexSearch?query=\(formattedQuery)&apiKey=\(apiKey)"
        
        print("API URL: \(urlString)")
        guard let url = URL(string: urlString) else { 
            print("無效的URL")
            return 
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            // 檢查網絡錯誤
            if let error = error {
                print("搜索API錯誤: \(error.localizedDescription)")
                // 在主線程顯示錯誤
                DispatchQueue.main.async {
                    // 即使出錯，仍然設置navigateToResults為true
                    if shouldNavigate {
                        self.searchedRecipes = [] // 清空結果
                        self.navigateToResults = true // 仍然導航，但會顯示空結果
                    }
                }
                return
            }
            
            // 檢查HTTP響應
            if let httpResponse = response as? HTTPURLResponse {
                print("API響應狀態碼: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("API返回非成功狀態碼")
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("錯誤響應: \(errorString)")
                    }
                    DispatchQueue.main.async {
                        if shouldNavigate {
                            self.searchedRecipes = [] // 清空結果
                            self.navigateToResults = true // 仍然導航，但會顯示空結果
                        }
                    }
                    return
                }
            }
            

            guard let data = data else {
                print("API未返回數據")
                DispatchQueue.main.async {
                    if shouldNavigate {
                        self.searchedRecipes = []
                        self.navigateToResults = true
                    }
                }
                return
            }
            
            // 嘗試解碼結果
            do {
                let decodedData = try JSONDecoder().decode(RecipeResponse.self, from: data)
                print("成功獲取搜索結果，找到\(decodedData.results.count)個食譜")
                
                DispatchQueue.main.async {
                    if shouldNavigate {
                        self.searchedRecipes = decodedData.results
                        print("設置navigateToResults為true，將導航到結果頁面")
                        self.navigateToResults = true
                    } else {
                        self.mostLovedRecipes = decodedData.results
                    }
                }
            } catch {
                print("JSON解碼錯誤: \(error.localizedDescription)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("收到的JSON: \(jsonString)")
                }
                
                DispatchQueue.main.async {
                    if shouldNavigate {
                        self.searchedRecipes = [] // 清空結果
                        self.navigateToResults = true // 仍然導航，但會顯示空結果
                    }
                }
            }
        }.resume()
    }

    private func fetchAISuggestion() {
        print("Starting fetchAISuggestion")
        
        guard userSettings.isLoggedIn,
              let userUID = UserDefaults.standard.string(forKey: "userUID") else {
            print("User not logged in or no userUID found")
            self.hasTargetData = false
            fetchDefaultRecipes()
            return
        }
        
        print("UserUID found: \(userUID)")
        let db = Firestore.firestore()
        
        // First check target subcollection and current document
        db.collection("User").document(userUID).collection("target").document("current").getDocument { targetSnapshot, targetError in
            if let targetError = targetError {
                print("Error fetching target: \(targetError)")
                DispatchQueue.main.async {
                    self.hasTargetData = false
                }
                return
            }
            
            guard let targetData = targetSnapshot?.data() else {
                print("No target data found")
                DispatchQueue.main.async {
                    self.hasTargetData = false
                    self.fetchDefaultRecipes()
                }
                return
            }
            

            DispatchQueue.main.async {
                self.hasTargetData = true
            }
            
            print("Target data found: \(targetData)")
            
            // Get target values
            let targetCarbs = targetData["Carbs"] as? Double ?? 0
            let targetFat = targetData["Fat"] as? Double ?? 0
            let targetProtein = targetData["Protein"] as? Double ?? 0
            let targetCalories = targetData["ingestion"] as? Double ?? 0
            
            // Get current values
            let currentCarbs = targetData["ingested"] as? Double ?? 0
            let currentFat = targetData["Fat"] as? Double ?? 0
            let currentProtein = targetData["Protein"] as? Double ?? 0
            
            print("Target - Carbs: \(targetCarbs), Fat: \(targetFat), Protein: \(targetProtein), Calories: \(targetCalories)")
            print("Current - Carbs: \(currentCarbs), Fat: \(currentFat), Protein: \(currentProtein)")
            
            // Calculate remaining needs
            let remainingCarbs = targetCarbs - currentCarbs
            let remainingFat = targetFat - currentFat
            let remainingProtein = targetProtein - currentProtein
            
            // Determine which nutrient needs the most attention
            let nutrients = [
                ("carbs", remainingCarbs),
                ("protein", remainingProtein),
                ("fat", remainingFat)
            ]
            
            if let (nutrientType, _) = nutrients.max(by: { $0.1 < $1.1 }) {
                print("Nutrient needing most attention: \(nutrientType)")
                
                // 根據不同的營養需求使用不同的提示
                let messages = [
                    "Based on my intake, suggest one food category. Only provide the category name, nothing else."
                ]
                
                let randomMessage = messages.randomElement() ?? messages[0]
                print("Sending message to AI: \(randomMessage)")
                
                // 簡化回應
                let singleWordResponses: [String: [String]] = [
                    "carbs": ["rice", "pasta", "bread", "oats", "quinoa"],
                    "protein": ["fish", "chicken", "eggs", "tofu", "beef"],
                    "fat": ["avocado", "nuts", "salmon", "olives", "seeds"]
                ]
                
                let simulatedAIResponse = singleWordResponses[nutrientType]?.randomElement() ?? "vegetables"
                print("Received AI response: \(simulatedAIResponse)")
                
                DispatchQueue.main.async {
                    print("Updating UI with AI suggestion: \(simulatedAIResponse)")
                    self.aiSuggestedCategory = "Flavour Dietitian: " + simulatedAIResponse
                    self.searchRecipes(query: simulatedAIResponse, shouldNavigate: false)
                }
            }
        }
    }

    private func fetchDefaultRecipes(offset: Int = 0) {
        let apiKey = "YOUR_API_KEY_HERE"
        let urlString = "https://api.spoonacular.com/recipes/complexSearch?sort=popularity&number=5&offset=\(offset)&apiKey=\(apiKey)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let decodedData = try? JSONDecoder().decode(RecipeResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.mostLovedRecipes = decodedData.results
                    self.isLoadingRecipeSection = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingRecipeSection = false
                }
            }
        }.resume()
    }

    private func fetchUserPreferenceRecipes() {
        guard userSettings.isLoggedIn else {
            print("User not logged in - skipping preference-based recommendations")
            isLoadingFoodRecommendations = false
            return
        }
        
        // Get user food type from AppStorage - focus on food type instead of flavor
        let foodType = savedFoodType.isEmpty ? "Other" : savedFoodType
        
        print("🍽️ USER FOOD TYPE PREFERENCE: \(foodType)")
        
        // Create a more specific message for AI chat service focused on food type
        let promptMessage: String
        
        switch foodType.lowercased() {
        case "chinese":
            promptMessage = "Suggest ONE specific Chinese dish or ingredient that is popular in recipes. Keep your answer to just 1-2 words ONLY. Be random, creative, and authentic."
        case "italian":
            promptMessage = "Suggest ONE specific Italian dish or ingredient that is popular in recipes. Keep your answer to just 1-2 words ONLY. Be random, creative, and authentic."
        case "japanese":
            promptMessage = "Suggest ONE specific Japanese dish or ingredient that is popular in recipes. Keep your answer to just 1-2 words ONLY. Be random, creative, and authentic."
        case "mexican":
            promptMessage = "Suggest ONE specific Mexican dish or ingredient that is popular in recipes. Keep your answer to just 1-2 words ONLY. Be random, creative, and authentic."
        case "american":
            promptMessage = "Suggest ONE specific American dish or ingredient that is popular in recipes. Keep your answer to just 1-2 words ONLY. Be random, creative, and authentic."
        case "middle eastern":
            promptMessage = "Suggest ONE specific Middle Eastern dish or ingredient that is popular in recipes. Keep your answer to just 1-2 words ONLY. Be random, creative, and authentic."
        case "indian":
            promptMessage = "Suggest ONE specific Indian dish or ingredient that is popular in recipes. Keep your answer to just 1-2 words ONLY. Be random, creative, and authentic."
        default:
            promptMessage = "Suggest ONE popular food dish or ingredient from any cuisine that has many recipes. Keep your answer to just 1-2 words ONLY. Be random and creative."
        }
        
        print(" SENDING TO AI: \"\(promptMessage)\"")
        
        // Use the ChatService to get AI recommendation
        Task {
            do {
                let aiResponse = try await chatService.sendMessage(promptMessage, provider: .mixrai)
                print(" AI RESPONSE: \"\(aiResponse)\"")
                
                // Trim any extra text to get just 1-2 words
                let cleanedResponse = cleanAIResponse(aiResponse)
                print(" CLEANED AI RESPONSE: \"\(cleanedResponse)\"")
                
                if cleanedResponse.isEmpty || cleanedResponse.lowercased() == "food" {
      
                    await MainActor.run {
                        let fallbackQuery = getFallbackQuery(for: foodType)
                        print("⚠️ AI returned empty result, USING FALLBACK QUERY: \"\(fallbackQuery)\"")
                        userPreferenceQuery = fallbackQuery
                        fetchRecipesForPreference(query: fallbackQuery)
                    }
                } else {
                    await MainActor.run {
                        userPreferenceQuery = cleanedResponse
                        let queryWithFoodType = "\(cleanedResponse) \(foodType)"
                        print(" FINAL SEARCH QUERY: \"\(queryWithFoodType)\"")
                        fetchRecipesForPreference(query: cleanedResponse)
                    }
                }
            } catch {
                print("❌ ERROR GETTING AI RECOMMENDATION: \(error.localizedDescription)")
                
                // Fallback to a default recommendation based on food type
                await MainActor.run {
                    let fallbackQuery = getFallbackQuery(for: foodType)
                    print("⚠️ USING FALLBACK QUERY: \"\(fallbackQuery)\"")
                    userPreferenceQuery = fallbackQuery
                    fetchRecipesForPreference(query: fallbackQuery)
                }
            }
        }
    }
    
    private func getFallbackQuery(for foodType: String) -> String {
        // Provide fallback food terms based on cuisine type
        switch foodType.lowercased() {
        case "chinese":
            let options = ["dumplings", "noodles", "fried rice", "tofu", "wonton"]
            return options.randomElement() ?? "dumplings"
        case "italian":
            let options = ["pasta", "pizza", "risotto", "lasagna", "gnocchi"]
            return options.randomElement() ?? "pasta"
        case "japanese":
            let options = ["sushi", "ramen", "tempura", "udon", "miso"]
            return options.randomElement() ?? "sushi"
        case "mexican":
            let options = ["tacos", "enchiladas", "quesadilla", "burrito", "mole"]
            return options.randomElement() ?? "tacos"
        case "american":
            let options = ["burger", "hotdog", "bbq", "steak", "sandwich"]
            return options.randomElement() ?? "burger"
        case "middle eastern":
            let options = ["hummus", "falafel", "shawarma", "kebab", "tahini"]
            return options.randomElement() ?? "kebab"
        case "indian":
            let options = ["curry", "biryani", "samosa", "naan", "dal"]
            return options.randomElement() ?? "curry"
        default:
            let options = ["pasta", "chicken", "rice", "salad", "soup"]
            return options.randomElement() ?? "chicken"
        }
    }
    
    private func cleanAIResponse(_ response: String) -> String {
        // Extract just the first 1-2 words from AI response and remove any non-alphanumeric characters
        let words = response.components(separatedBy: .whitespacesAndNewlines)
                          .filter { !$0.isEmpty }
                          .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        
        if words.isEmpty {
            return "food" // Default fallback
        } else if words.count == 1 {
            return words[0]
        } else if words.count == 2 {
            return "\(words[0]) \(words[1])"
        } else {
            // Just take the first two words
            return "\(words[0]) \(words[1])"
        }
    }
    
    private func fetchRecipesForPreference(query: String) {
        let apiKey = "YOUR_API_KEY_HERE"
        let formattedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.spoonacular.com/recipes/complexSearch?query=\(formattedQuery)&sort=popularity&number=5&apiKey=\(apiKey)"
        
        print("Fetching recipes with URL: \(urlString)")
        
        guard let url = URL(string: urlString) else { 
            print("Invalid URL")
            DispatchQueue.main.async {
                self.isLoadingFoodRecommendations = false
                self.retryWithNewQuery()
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingFoodRecommendations = false
                    self.retryWithNewQuery()
                }
                return
            }
            
            if let data = data {
                do {
                    let decodedData = try JSONDecoder().decode(RecipeResponse.self, from: data)
                    print("Retrieved \(decodedData.results.count) recipes for preference query")
                    
                    DispatchQueue.main.async {
                        // 检查是否有结果
                        if decodedData.results.isEmpty && self.retryCount < self.maxRetries {
                            // 没有结果，重试
                            print("🔄 No recipes found for '\(query)', trying with a new query...")
                            self.retryWithNewQuery()
                        } else {
                            // 有结果或者已达到最大重试次数
                            self.userPreferenceRecipes = decodedData.results
                            self.isLoadingFoodRecommendations = false
                            self.retryCount = 0  // 重置计数器
                        }
                    }
                } catch {
                    print("Decoding error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingFoodRecommendations = false
                        self.retryWithNewQuery()  // 解码错误时尝试重试
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingFoodRecommendations = false
                    self.retryWithNewQuery()  // 没有数据时尝试重试
                }
            }
        }.resume()
    }
    
    // 添加一个新方法来处理重试逻辑
    private func retryWithNewQuery() {

        if retryCount < maxRetries {
            retryCount += 1
            print(" Retry attempt \(retryCount)/\(maxRetries)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isLoadingFoodRecommendations = true
                self.fetchUserPreferenceRecipes()
            }
        } else {
            print("Reached maximum retry attempts (\(maxRetries))")
            retryCount = 0

            userPreferenceQuery += " (No recipes found)"
            isLoadingFoodRecommendations = false
        }
    }

    // 新增函數：獲取FoodTypeHistory子集合中最常見的食品類型（排除用戶當前首選類型）
    private func fetchGuessYouLikeFoodType() {
        guard userSettings.isLoggedIn,
              let userUID = UserDefaults.standard.string(forKey: "userUID") else {
            print("User not logged in or no userUID found - skipping guess you like")
            return
        }
        
        isLoadingGuessYouLike = true
        print("Fetching user's FoodTypeHistory")
        
        let db = Firestore.firestore()
        
        // 獲取用戶的當前food_type
        db.collection("User").document(userUID).getDocument { (userDoc, userError) in
            if let userError = userError {
                print("Error fetching user document: \(userError)")
                self.isLoadingGuessYouLike = false
                return
            }
            
            let currentUserFoodType = userDoc?.data()?["food_type"] as? String ?? ""
            print("Current user food_type: \(currentUserFoodType)")
            
            // 第二步：獲取FoodTypeHistory子集合
            db.collection("User").document(userUID).collection("FoodTypeHistory").getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching FoodTypeHistory: \(error)")
                    self.isLoadingGuessYouLike = false
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("No FoodTypeHistory documents found")
                    self.hasFoodTypeHistory = false
                    self.isLoadingGuessYouLike = false
                    return
                }
                
                self.hasFoodTypeHistory = true
                print("Found \(documents.count) FoodTypeHistory documents")
                
                // 創建一個字典來跟蹤每種食物類型的頻率
                var foodTypeCounts: [String: Int] = [:]
                
                // 遍歷所有文檔，收集食物類型和頻率
                for document in documents {
                    let foodTypeName = document.documentID
                    // 排除用戶當前的food_type
                    if foodTypeName.lowercased() == currentUserFoodType.lowercased() {
                        continue
                    }
                    
                    let frequency = document.data()["Frequency"] as? Int ?? 0
                    foodTypeCounts[foodTypeName] = frequency
                }
                
                // 查找頻率最高的食物類型
                if let topFoodType = foodTypeCounts.max(by: { $0.value < $1.value }) {
                    print("Guess You Like food type: \(topFoodType.key) with count \(topFoodType.value)")
                    self.guessYouLikeQuery = topFoodType.key
                    
                    // 使用找到的食物類型進行食譜搜索
                    self.fetchGuessYouLikeRecipes(foodType: topFoodType.key)
                } else {
                    print("No alternative food types found besides user's preference")
                    self.isLoadingGuessYouLike = false
                }
            }
        }
    }
    
    // 使用猜你喜歡的食品類型搜索食譜
    private func fetchGuessYouLikeRecipes(foodType: String) {
        let apiKey = "YOUR_API_KEY_HERE"
        let formattedQuery = foodType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.spoonacular.com/recipes/complexSearch?query=\(formattedQuery)&sort=popularity&number=5&apiKey=\(apiKey)"
        
        print("Fetching Guess You Like recipes with URL: \(urlString)")
        
        guard let url = URL(string: urlString) else { 
            print("Invalid URL for Guess You Like")
            self.isLoadingGuessYouLike = false
            self.isLoadingRecipeSection = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Network error for Guess You Like: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingGuessYouLike = false
                    self.isLoadingRecipeSection = false
                }
                return
            }
            
            if let data = data {
                do {
                    let decodedData = try JSONDecoder().decode(RecipeResponse.self, from: data)
                    print("Retrieved \(decodedData.results.count) recipes for Guess You Like")
                    
                    DispatchQueue.main.async {
                        self.guessYouLikeRecipes = decodedData.results
                        self.isLoadingGuessYouLike = false
                        self.isLoadingRecipeSection = false
                    }
                } catch {
                    print("Decoding error for Guess You Like: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingGuessYouLike = false
                        self.isLoadingRecipeSection = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingGuessYouLike = false
                    self.isLoadingRecipeSection = false
                }
            }
        }.resume()
    }
}

// MARK: - RecipeSearchResultView
struct RecipeSearchResultView: View {
    let recipes: [Recipe]
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    @State private var nutritionMatchRecipes: [Recipe] = []
    @State private var relevantSearchRecipes: [Recipe] = []
    @State private var isLoadingNutritionMatch = false
    @State private var isLoadingRelevantSearch = false
    @State private var searchQuery: String = ""
    @AppStorage("userUID") private var userUID: String = ""
    @EnvironmentObject var userSettings: UserSettings  // 添加環境對象引用
    
    // 保存每個分頁的AI篩選請求內容
    @State private var nutritionFilterContext: String = ""
    @State private var relevanceFilterContext: String = ""

    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // 計算可用的分頁選項
    private var availableTabs: [String] {
        if userSettings.isLoggedIn && !userUID.isEmpty {
            return ["All Results", "Nutrition Match", "Search Relevance"]
        } else {
            return ["All Results", "Search Relevance"]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 改進後的導航欄 - 使標題居中顯示
            ZStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.orange)
                    }
                    Spacer()
                }
                
                Text("Search Results")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.white)
            
            // 改進後的分頁選擇器 - 確保文字不會超出邊界
            ZStack {
                // 分頁背景
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                    .frame(height: 50)
                    .padding(.horizontal, 15)
                
                // 可捲動的分頁容器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<availableTabs.count, id: \.self) { index in
                            Button(action: {
                                withAnimation {
                                    selectedTab = index
                                    printFilterContext(forTab: index)
                                }
                            }) {
                                Text(availableTabs[index])
                                    .font(.system(size: 13, weight: selectedTab == index ? .semibold : .regular))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedTab == index ? Color.orange : Color.clear)
                                    )
                                    .foregroundColor(selectedTab == index ? .white : .black)
                                    .lineLimit(1)
                                    .fixedSize()  // 確保按鈕大小正好容納文本
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 50)
                }
            }
            .padding(.vertical, 8)
            .background(Color.white)
            
            // Tab content
            TabView(selection: $selectedTab) {
                // Tab 1: Original search results
                originalSearchResultsView
                    .tag(0)
                
                // 根據登入狀態條件顯示不同的分頁
                if userSettings.isLoggedIn && !userUID.isEmpty {
                    // Tab 2: Best for Current Intake (僅限登入用戶)
                    nutritionMatchView
                        .tag(1)
                    
                    // Tab 3: Most Relevant to Search
                    relevantSearchView
                        .tag(2)
                } else {
                    // Tab 2: Most Relevant to Search (非登入用戶)
                    relevantSearchView
                        .tag(1)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: selectedTab) { newTab in
                // This will help update the tab visually as the user swipes through content
                withAnimation {
                    selectedTab = newTab
                }
                // 在控制台顯示當前選中分頁的AI篩選條件
                printFilterContext(forTab: newTab)
            }
        }
        .navigationBarHidden(true)
        .background(Color(.systemGray6).opacity(0.3))
        .onAppear {
            // Extract search query from the original search
            if let firstRecipe = recipes.first {
                searchQuery = firstRecipe.title.components(separatedBy: " ").prefix(2).joined(separator: " ")
            }
            
            // 根據登入狀態載入對應的分頁數據
            fetchRelevantSearchRecipes()
            
            // 只有登入用戶才獲取營養匹配數據
            if userSettings.isLoggedIn && !userUID.isEmpty {
                fetchNutritionMatchRecipes()
            }
        }
    }
    
    // 顯示篩選條件的函數
    private func printFilterContext(forTab tab: Int) {
        print("========== AI FILTER CONTEXT ==========")
        print("Selected Tab: \(availableTabs[tab])")
        
        // 根據當前選擇的分頁名稱而非索引來決定顯示什麼
        switch availableTabs[tab] {
        case "All Results":
            print("All Results - No AI filtering applied")
        case "Nutrition Match":
            print("NUTRITION MATCH FILTER CONTEXT:")
            print(nutritionFilterContext)
        case "Search Relevance":
            print("SEARCH RELEVANCE FILTER CONTEXT:")
            print(relevanceFilterContext)
        default:
            break
        }
        print("=======================================")
    }
    
    // Original search results tab
    private var originalSearchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Found \(recipes.count) Recipes")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.black)
                    
                    Text("Explore and find your favorite recipe")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                recipeGrid(recipes: recipes)
            }
        }
    }
    
    // Best for Current Intake tab
    private var nutritionMatchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Best for Your Current Nutrition Needs")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.black)
                    
                    Text("Recipes that best complement your daily nutritional targets")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                if isLoadingNutritionMatch {
                    loadingView(message: "Analyzing nutritional compatibility...")
                } else if nutritionMatchRecipes.isEmpty {
                    emptyStateView(message: "No matching recipes for your current nutritional needs")
                } else {
                    recipeGrid(recipes: nutritionMatchRecipes)
                }
            }
        }
    }
    
    // Most Relevant to Search tab
    private var relevantSearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most Relevant to Your Search")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.black)
                    
                    Text("Recipes that match your search criteria")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                if isLoadingRelevantSearch {
                    loadingView(message: "Finding the most relevant matches...")
                } else if relevantSearchRecipes.isEmpty {
                    emptyStateView(message: "No highly relevant recipes found")
                } else {
                    recipeGrid(recipes: relevantSearchRecipes)
                }
            }
        }
    }
    
    // Helper view for recipe grid
    private func recipeGrid(recipes: [Recipe]) -> some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(recipes) { recipe in
                NavigationLink(destination: DetailOfRecipeView(recipeId: recipe.id)) {
                    VStack(spacing: 0) {
                        // Image area
                        if let imageUrl = URL(string: recipe.image) {
                            AsyncImage(url: imageUrl) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: UIScreen.main.bounds.width/2 - 25, height: 160)
                                    .clipped()
                            } placeholder: {
                                ProgressView()
                                    .frame(width: UIScreen.main.bounds.width/2 - 25, height: 160)
                                    .background(Color(.systemGray6))
                            }
                        }
                        

                        Text(recipe.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color.white)
                    }
                    .frame(width: UIScreen.main.bounds.width/2 - 25)
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // Loading state view
    private func loadingView(message: String) -> some View {
        VStack(spacing: 15) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text(message)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // Empty state view
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 15) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
                .padding()
            Text(message)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // Fetch recipes that match user's nutritional needs
    private func fetchNutritionMatchRecipes() {
        guard !userUID.isEmpty else { return }
        
        isLoadingNutritionMatch = true
        
        // Get all recipes for initial processing
        let recipesToProcess = recipes.map { recipe in
            return recipe
        }
        
        if recipesToProcess.isEmpty {
            isLoadingNutritionMatch = false
            return
        }
        
        // Get user's nutritional targets from Firestore
        let db = Firestore.firestore()
        db.collection("User").document(userUID).collection("target").document("current").getDocument { snapshot, error in
            if let error = error {
                print("Error fetching nutritional targets: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.nutritionMatchRecipes = Array(recipesToProcess)
                    self.isLoadingNutritionMatch = false
                }
                return
            }
            
            guard let data = snapshot?.data() else {
                print("No nutritional target data found")
                DispatchQueue.main.async {
                    self.nutritionMatchRecipes = Array(recipesToProcess)
                    self.isLoadingNutritionMatch = false
                }
                return
            }
            
            // Extract nutritional values
            let targetCalories = data["ingestion"] as? Double ?? 0
            let targetCarbs = data["Carbs"] as? Double ?? 0
            let targetProtein = data["Protein"] as? Double ?? 0
            let targetFat = data["Fat"] as? Double ?? 0
            
            let ingestedCalories = data["Ingested"] as? Double ?? 0
            let ingestedCarbs = data["CarbsIngested"] as? Double ?? 0
            let ingestedProtein = data["ProteinIngested"] as? Double ?? 0
            let ingestedFat = data["FatIngested"] as? Double ?? 0
            
            // Prepare message for AI
            let nutritionContext = """
            User's daily nutritional targets:
            - Calories: \(targetCalories) kcal (consumed: \(ingestedCalories) kcal)
            - Carbs: \(targetCarbs) g (consumed: \(ingestedCarbs) g)
            - Protein: \(targetProtein) g (consumed: \(ingestedProtein) g)
            - Fat: \(targetFat) g (consumed: \(ingestedFat) g)
            
            Here are some recipes. Analyze which ones would best complement the user's remaining nutritional needs for the day. Even if the user hasn't consumed much yet, recommend recipes that would provide a balanced nutritional profile:
            
            \(recipesToProcess.map { "Recipe ID: \($0.id), Title: \($0.title)" }.joined(separator: "\n"))
            
            Return JSON format with recipe IDs sorted by how well they meet nutritional needs:
            {"recipeIds": [123, 456, 789]}
            """
            

            self.nutritionFilterContext = nutritionContext
            
            print("===== SENDING NUTRITION FILTER REQUEST =====")
            print(nutritionContext)
            
            // Send to AI for analysis
            Task {
                do {
                    let aiResponse = try await chatService.sendMessage(nutritionContext, provider: .mixrai)
                    print("===== AI RESPONSE FOR NUTRITION MATCH =====")
                    print(aiResponse)
                    
                    // Extract recipe IDs from AI response
                    let jsonString = extractJSONFromResponse(aiResponse)
                    print("Extracted JSON: \(jsonString)")
                    
                    if let jsonData = jsonString.data(using: .utf8),
                       let responseDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let recipeIds = responseDict["recipeIds"] as? [Int], !recipeIds.isEmpty {
                        
                        print("Valid recipeIds found: \(recipeIds)")
                        
                        // Filter and sort recipes based on AI recommendation
                        let filteredRecipes = recipeIds.compactMap { id in
                            recipes.first { $0.id == id }
                        }
                        
                        DispatchQueue.main.async {
                            if filteredRecipes.isEmpty {
                                print("No matching recipes found after filtering - falling back to all recipes")
                                self.nutritionMatchRecipes = Array(recipesToProcess)
                            } else {
                                print("Found \(filteredRecipes.count) nutrition-matched recipes")
                                self.nutritionMatchRecipes = filteredRecipes
                            }
                            self.isLoadingNutritionMatch = false
                        }
                    } else {
                        // Fallback if AI response parsing fails
                        print("JSON parsing failed or no recipeIds - falling back to all recipes")
                        DispatchQueue.main.async {
                            self.nutritionMatchRecipes = Array(recipesToProcess)
                            self.isLoadingNutritionMatch = false
                        }
                    }
                } catch {
                    print("Error getting AI recommendation: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.nutritionMatchRecipes = Array(recipesToProcess)
                        self.isLoadingNutritionMatch = false
                    }
                }
            }
        }
    }
    
    // Helper function to extract JSON from AI response with improved extraction
    private func extractJSONFromResponse(_ response: String) -> String {
        // First try to find a JSON object with recipeIds
        let jsonObjectPattern = try? NSRegularExpression(pattern: "\\{\\s*\"recipeIds\"\\s*:\\s*\\[[0-9, ]*\\]\\s*\\}", options: [])
        let range = NSRange(location: 0, length: response.utf16.count)
        
        if let match = jsonObjectPattern?.firstMatch(in: response, options: [], range: range),
           let matchRange = Range(match.range, in: response) {
            return String(response[matchRange])
        }
        
        // If not found, try to find any JSON object
        let anyJsonPattern = try? NSRegularExpression(pattern: "\\{[^\\{\\}]*\\}", options: [])
        
        if let match = anyJsonPattern?.firstMatch(in: response, options: [], range: range),
           let matchRange = Range(match.range, in: response) {
            return String(response[matchRange])
        }
        
        // If no JSON found, try to extract just the IDs as a last resort
        let idsPattern = try? NSRegularExpression(pattern: "\\[(\\d+(?:,\\s*\\d+)*)\\]", options: [])
        
        if let match = idsPattern?.firstMatch(in: response, options: [], range: range),
           let matchRange = Range(match.range, in: response) {
            let idsArray = String(response[matchRange])
            return "{\"recipeIds\": \(idsArray)}"
        }
        
        // Absolute fallback: create a valid JSON with all recipe IDs
        let recipesJson = recipes.map { "\($0.id)" }.joined(separator: ", ")
        return "{\"recipeIds\": [" + recipesJson + "]}"
    }

    // Fetch recipes most relevant to the search query
    private func fetchRelevantSearchRecipes() {
        guard !searchQuery.isEmpty else { return }
        
        isLoadingRelevantSearch = true
        let recipesToProcess = recipes
        
        if recipesToProcess.isEmpty {
            isLoadingRelevantSearch = false
            return
        }
        
        // Prepare message for AI
        let searchContext = """
        User search query: "\(searchQuery)"
        
        Analyze these recipes and determine which ones are most relevant to the search query:
        
        \(recipesToProcess.map { "Recipe ID: \($0.id), Title: \($0.title)" }.joined(separator: "\n"))
        
        Return JSON format with recipe IDs sorted by relevance to the search query:
        {"recipeIds": [123, 456, 789]}
        """
        
        // 保存篩選條件以便顯示
        self.relevanceFilterContext = searchContext
        
        // Send to AI for analysis
        Task {
            do {
                let aiResponse = try await chatService.sendMessage(searchContext, provider: .mixrai)
                print("AI response for search relevance: \(aiResponse)")
                
                // Extract recipe IDs from AI response
                if let jsonData = extractJSONFromResponse(aiResponse).data(using: .utf8),
                   let responseDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let recipeIds = responseDict["recipeIds"] as? [Int] {
                    
                    // Filter and sort recipes based on AI recommendation
                    let filteredRecipes = recipeIds.compactMap { id in
                        recipes.first { $0.id == id }
                    }
                    
                    DispatchQueue.main.async {
                        relevantSearchRecipes = filteredRecipes
                        isLoadingRelevantSearch = false
                    }
                } else {
                    // Fallback if AI response parsing fails
                    DispatchQueue.main.async {
                        relevantSearchRecipes = Array(recipesToProcess)
                        isLoadingRelevantSearch = false
                    }
                }
            } catch {
                print("Error getting AI recommendation: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    relevantSearchRecipes = Array(recipesToProcess)
                    isLoadingRelevantSearch = false
                }
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}

// MARK: - Explore View
struct ExploreView: View {
    var body: some View {
        Text("Explore Recipes")
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding()
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView() 
    }
}

extension Color {
    static let customOrange = Color(red: 253/255, green: 159/255, blue: 0/255)
}

// 添加 ImagePicker 結構體
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("Image picker did finish picking")
            if let image = info[.originalImage] as? UIImage {
                print("Image selected successfully")
                parent.image = image
            } else {
                print("Failed to get image from picker")
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("Image picker cancelled")
            parent.isPresented = false
        }
    }
}
