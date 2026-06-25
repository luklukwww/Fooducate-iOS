import SwiftUI
import FirebaseFirestore
import Network

struct Exploreview: View {
    @StateObject private var userSettings = UserSettings.shared
    @State private var imageURLs: [(id: String, url: String, recipeName: String, authorName: String, authorImage: String, likes: Int, comments: Int, category: String, ingredients: [String])] = []
    @State private var isLoading = true
    @State private var isOffline = false
    @State private var lastTapTime: Date? = nil
    @State private var sortOption: SortOption = .none
    @State private var selectedCategory: String? = nil
    @State private var showMenu = false
    @State private var showAddPost = false
    @StateObject private var adminManager = AdminManager.shared
    @State private var showDeleteAlert = false
    @State private var recipeToDelete: String? = nil
    @State private var isRefreshing = false
    @State private var searchText = ""
    @State private var isSearching = false
    private let monitor = NWPathMonitor()
    
    private var columns: [GridItem] {
        return [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }
    
    private var imageSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 10
        let spacing: CGFloat = 10
        let availableWidth = screenWidth - (padding * 2) - spacing
        return (availableWidth / 2) - spacing
    }
    
    private let spacing: CGFloat = 10
    private let doubleTapInterval: TimeInterval = 0.3 
    
    // 所有可用的分類
    private let categories = ["Chinese", "Italian", "Japanese", "Mexican", "American", "Middle Eastern", "Indian", "Other"]
    
    enum SortOption {
        case none, likes, comments, hotness
    }
    
    var sortedAndFilteredImageURLs: [(id: String, url: String, recipeName: String, authorName: String, authorImage: String, likes: Int, comments: Int, category: String, ingredients: [String])] {
        // 先按照分類篩選
        let filteredByCategory = selectedCategory == nil 
            ? imageURLs
            : imageURLs.filter { $0.category == selectedCategory }
        
        // 按照搜索文本篩選
        let filteredBySearch: [(id: String, url: String, recipeName: String, authorName: String, authorImage: String, likes: Int, comments: Int, category: String, ingredients: [String])]
        
        if searchText.isEmpty {
            filteredBySearch = filteredByCategory
        } else {
            let searchTerms = searchText.lowercased().split(separator: " ")
            
            filteredBySearch = filteredByCategory.filter { recipe in
                // 檢查食譜名稱是否包含搜索詞
                let nameMatch = recipe.recipeName.lowercased().contains(searchText.lowercased())
                
                // 檢查食譜類別是否包含搜索詞
                let categoryMatch = recipe.category.lowercased().contains(searchText.lowercased())
                
                // 檢查食譜食材是否包含搜索詞
                let ingredientMatch = recipe.ingredients.contains(where: { ingredient in
                    ingredient.lowercased().contains(searchText.lowercased())
                })
                
                // 檢查是否匹配所有搜索詞
                let termsMatch = searchTerms.allSatisfy { term in
                    recipe.recipeName.lowercased().contains(term) || 
                    recipe.category.lowercased().contains(term) ||
                    recipe.ingredients.contains(where: { $0.lowercased().contains(term) })
                }
                
                return nameMatch || categoryMatch || ingredientMatch || termsMatch
            }
        }
        
        // 再按選擇的排序選項排序
        switch sortOption {
        case .likes:
            return filteredBySearch.sorted { $0.likes > $1.likes }
        case .comments:
            return filteredBySearch.sorted { $0.comments > $1.comments }
        case .hotness:
            return filteredBySearch.sorted { $0.likes + $0.comments > $1.likes + $1.comments }
        case .none:
            return filteredBySearch
        }
    }
    
    private func recipeCard(id: String, url: String, recipeName: String, authorName: String, authorImage: String, likes: Int, comments: Int, category: String, ingredients: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                NavigationLink(destination: ExploreDetailView(recipeId: id)) {
                    AsyncImage(url: URL(string: url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imageSize, height: imageSize * 1.1)
                            .cornerRadius(12)
                            .clipped()
                            .overlay(
                                // Add gradient overlay at bottom for text visibility
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, Color.black.opacity(0.5)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .cornerRadius(12)
                            )
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: imageSize, height: imageSize * 1.1)
                            .cornerRadius(12)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            )
                    }
                }
                
                // 排名標記 - 右上角位置
                if let rank = getRankBadge(id: id) {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(getRankColor(rank: rank))
                                    .frame(width: 36, height: 36)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                                
                                Text("\(rank)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }
                
                // 管理員刪除按鈕
                if adminManager.isAdmin {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                recipeToDelete = id
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }
                
                // Recipe name on the image - full width background
                VStack {
                    Spacer()
                    Text(recipeName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.7)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(width: imageSize)
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            
            // Author info and engagement metrics
            HStack(alignment: .center) {
                // Author avatar with orange border
                if !authorImage.isEmpty {
                    AsyncImage(url: URL(string: authorImage.replacingOccurrences(of: "@", with: ""))) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.orange, lineWidth: 1.5))
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.orange, lineWidth: 1.5))
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.orange, lineWidth: 1.5))
                }
                
                // Author name
                Text(authorName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Spacer()
                
                // Engagement metrics in orange
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(getLikesHighlight(likes: likes))
                        Text("\(likes)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    HStack(spacing: 3) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 12))
                            .foregroundColor(getCommentsHighlight(comments: comments))
                        Text("\(comments)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
    }
    
    // 獲取食譜的排名標誌（如果是前三名）
    private func getRankBadge(id: String) -> Int? {
        // 先按照分類篩選
        let filteredByCategory = selectedCategory == nil 
            ? imageURLs
            : imageURLs.filter { $0.category == selectedCategory }
        
        switch sortOption {
        case .likes:
            // 找出讚數最多的前三名 (從已篩選的列表中)
            let topLikedRecipes = filteredByCategory.sorted { $0.likes > $1.likes }.prefix(3)
            if let index = topLikedRecipes.firstIndex(where: { $0.id == id }) {
                return index + 1 // 返回1、2或3
            }
        case .comments:
            // 找出評論最多的前三名 (從已篩選的列表中)
            let topCommentedRecipes = filteredByCategory.sorted { $0.comments > $1.comments }.prefix(3)
            if let index = topCommentedRecipes.firstIndex(where: { $0.id == id }) {
                return index + 1 // 返回1、2或3
            }
        case .hotness:
            // 找出熱門度最高的食譜 (從已篩選的列表中)
            let topHotRecipes = filteredByCategory.sorted { $0.likes + $0.comments > $1.likes + $1.comments }.prefix(3)
            if let index = topHotRecipes.firstIndex(where: { $0.id == id }) {
                return index + 1 // 返回1、2或3
            }
        case .none:
            return nil // 沒有進行排序時不顯示排名
        }
        return nil
    }
    
    // 根據排名獲取徽章顏色
    private func getRankColor(rank: Int) -> Color {
        switch rank {
        case 1:
            return Color.yellow // 金牌
        case 2:
            return Color(red: 192/255, green: 192/255, blue: 192/255) // 銀牌
        case 3:
            return Color(red: 205/255, green: 127/255, blue: 50/255) // 銅牌
        default:
            return Color.gray
        }
    }
    
    // 根據讚數量獲取高亮顏色
    private func getLikesHighlight(likes: Int) -> Color {
        // 讚數超過閾值時給予特別顏色顯示
        if likes >= 20 {
            return Color.red
        } else if likes >= 10 {
            return Color.orange
        } else {
            return Color.orange.opacity(0.8)
        }
    }
    
    // 根據評論數量獲取高亮顏色
    private func getCommentsHighlight(comments: Int) -> Color {
        // 評論數超過閾值時給予特別顏色顯示
        if comments >= 10 {
            return Color.blue
        } else if comments >= 5 {
            return Color.orange
        } else {
            return Color.orange.opacity(0.8)
        }
    }
    
    // 獲取排序選項的顯示名稱
    private func getSortOptionName(_ option: SortOption) -> String {
        switch option {
        case .likes:
            return "Most Liked"
        case .comments:
            return "Most Commented"
        case .hotness:
            return "Hottest"
        case .none:
            return ""
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // 顯示篩選和排序標籤 (橫向排列)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // 分類篩選標籤
                            if let category = selectedCategory {
                                HStack(spacing: 4) {
                                    Button(action: {
                                        selectedCategory = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14))
                                    }
                                    
                                    Text("Filtering: \(category)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.orange)
                                )
                            }
                            
                            // 排序標籤
                            if sortOption != .none {
                                HStack(spacing: 4) {
                                    Button(action: {
                                        sortOption = .none
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14))
                                    }
                                    
                                    Text("Sorting: \(getSortOptionName(sortOption))")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.orange)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                    
                    // Search bar
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.orange)
                                .padding(.leading, 8)
                            
                            TextField("Search recipes or ingredients...", text: $searchText)
                                .padding(.vertical, 10)
                                .foregroundColor(.primary)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.orange)
                                        .padding(.trailing, 8)
                                }
                            }
                        }
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange, lineWidth: 1.5)
                        )
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                    
                    ScrollView {
                        // Pull to refresh control
                        RefreshControl(isRefreshing: $isRefreshing, coordinateSpaceName: "pullToRefresh") {
                            Task {
                                await refreshData()
                            }
                        }
                        
                        if isOffline {
                            Text("No Internet Connection")
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        if isLoading && !isRefreshing {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(sortedAndFilteredImageURLs, id: \.id) { item in
                                    recipeCard(id: item.id, url: item.url, recipeName: item.recipeName, authorName: item.authorName, authorImage: item.authorImage, likes: item.likes, comments: item.comments, category: item.category, ingredients: item.ingredients)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                        }
                    }
                    .coordinateSpace(name: "pullToRefresh")
                    .navigationTitle("Flavour Community")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            // Only show the "+" button if the user is logged in
                            if userSettings.isLoggedIn {
                                Button(action: {
                                    showAddPost = true
                                }) {
                                    Image(systemName: "plus")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 24))
                                }
                            }
                        }
                        
                        // 添加篩選按鈕
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Section(header: Text("Filter by Category")) {
                                    ForEach(categories, id: \.self) { category in
                                        Button(action: {
                                            selectedCategory = category
                                        }) {
                                            HStack {
                                                Text(category)
                                                if selectedCategory == category {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                    
                                    if selectedCategory != nil {
                                        Button(action: {
                                            selectedCategory = nil
                                        }) {
                                            HStack {
                                                Text("Clear Filter")
                                                Spacer()
                                                Image(systemName: "xmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .foregroundColor(selectedCategory != nil ? .orange : .orange.opacity(0.8))
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button(action: {
                                    isRefreshing = true
                                    Task {
                                        await refreshData()
                                    }
                                }) {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                
                                Button(action: {
                                    sortOption = .likes
                                }) {
                                    Label("Sort by Likes", systemImage: "heart.fill")
                                }
                                
                                Button(action: {
                                    sortOption = .comments
                                }) {
                                    Label("Sort by Comments", systemImage: "message.fill")
                                }
                                
                                Button(action: {
                                    sortOption = .hotness
                                }) {
                                    Label("Sort by Hotness", systemImage: "flame.fill")
                                }
                                
                                if sortOption != .none {
                                    Button(action: {
                                        sortOption = .none
                                    }) {
                                        Label("Clear Sort", systemImage: "arrow.up.arrow.down")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                        }
                    }
                    .navigationDestination(isPresented: $showAddPost) {
                        AddRecipeView()
                    }
                }
                
                Color.clear
                    .frame(height: 50)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleTabBarTap()
                    }
            }
        }
        .alert("Delete Recipe", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = recipeToDelete {
                    adminManager.deleteRecipe(recipeId: id) { success in
                        if success {
                            // 從列表中移除食譜
                            imageURLs.removeAll { $0.id == id }
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this recipe?")
        }
        .onAppear {
            setupNetworkMonitoring()
            if let uid = UserDefaults.standard.string(forKey: "userUID") {
                adminManager.checkAdminStatus(uid: uid)
            }
            fetchRecipeData()
        }
    }
    
    private func handleTabBarTap() {
        let now = Date()
        if let lastTap = lastTapTime,
           now.timeIntervalSince(lastTap) < doubleTapInterval {
            print("Double tap detected - refreshing...")
            fetchRecipeData()
            lastTapTime = nil
        } else {
            lastTapTime = now
        }
    }
    
    func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isOffline = path.status != .satisfied
                if !self.isOffline {
                    self.fetchRecipeData()
                }
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
    
    func fetchRecipeData() {
        isLoading = true
        print("Starting to fetch data...")
        
        let db = Firestore.firestore()
        var newImageURLs: [(id: String, url: String, recipeName: String, authorName: String, authorImage: String, likes: Int, comments: Int, category: String, ingredients: [String])] = []
        
        // 創建查詢
        var query: Query = db.collection("Recipe")
        if !adminManager.isAdmin {
            // 普通用戶只能看到可見的食譜
            query = query.whereField("isVisible", isEqualTo: true)
        }
        
        // 執行查詢
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error getting documents: \(error)")
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.isLoading = false
                return
            }
            
            let group = DispatchGroup()
            
            for document in documents {
                if let imageURL = document.data()["RecipeImg"] as? String {
                    group.enter()
                    let likes = document.data()["like"] as? Int ?? 0
                    let recipeName = document.data()["Rname"] as? String ?? "Untitled Recipe"
                    let authorUID = document.data()["UID"] as? String ?? ""
                    let category = document.data()["Category"] as? String ?? "Other" // 獲取食譜類別
                    
                    // Extract ingredients from the recipe
                    var ingredients: [String] = []
                    if let ingredientsList = document.data()["ingredients"] as? [[String: Any]] {
                        for item in ingredientsList {
                            if let name = item["name"] as? String {
                                ingredients.append(name)
                            }
                        }
                    } else if let ingredientString = document.data()["ingredients"] as? String {
                        let parts = ingredientString.split(separator: ",")
                        ingredients = parts.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                    
                    // First get comment count
                    document.reference.collection("Comment").getDocuments { (commentSnapshot, _) in
                        let commentCount = commentSnapshot?.documents.count ?? 0
                        
                        // Then get author info if we have an author UID
                        if !authorUID.isEmpty {
                            db.collection("User").document(authorUID).getDocument { (userDoc, _) in
                                defer { group.leave() }
                                
                                var authorName = "Unknown"
                                var authorImage = ""
                                
                                if let userDoc = userDoc, userDoc.exists {
                                    authorName = userDoc.data()?["uname"] as? String ?? "Unknown"
                                    authorImage = userDoc.data()?["uimg"] as? String ?? ""
                                }
                                
                                DispatchQueue.main.async {
                                    newImageURLs.append((
                                        id: document.documentID,
                                        url: imageURL,
                                        recipeName: recipeName,
                                        authorName: authorName,
                                        authorImage: authorImage,
                                        likes: likes,
                                        comments: commentCount,
                                        category: category,
                                        ingredients: ingredients
                                    ))
                                }
                            }
                        } else {
                            // No author UID, just add with default values
                            defer { group.leave() }
                            DispatchQueue.main.async {
                                newImageURLs.append((
                                    id: document.documentID,
                                    url: imageURL,
                                    recipeName: recipeName,
                                    authorName: "Unknown",
                                    authorImage: "",
                                    likes: likes,
                                    comments: commentCount,
                                    category: category,
                                    ingredients: ingredients
                                ))
                            }
                        }
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.imageURLs = newImageURLs
                self.isLoading = false
                print("Total documents loaded: \(self.imageURLs.count)")
            }
        }
    }
    
    private func refreshData() async {
        // Set refreshing state
        isRefreshing = true
        
        // Perform data fetch on background thread
        await MainActor.run {
            fetchRecipeData()
        }
        
        // Add a small delay to ensure the refresh animation is visible
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Reset refreshing state
        await MainActor.run {
            isRefreshing = false
        }
    }
}

// Custom RefreshControl view
struct RefreshControl: View {
    @Binding var isRefreshing: Bool
    let coordinateSpaceName: String
    let onRefresh: () async -> Void
    
    @State private var refreshOffset: CGFloat = 0
    @State private var refreshThreshold: CGFloat = 80
    @State private var isRefreshIndicatorShowing = false
    
    var body: some View {
        GeometryReader { geometry in
            if refreshOffset > 0 {
                ZStack(alignment: .center) {
                    Color.clear
                    
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                            .rotationEffect(.degrees(refreshOffset > refreshThreshold ? 180 : 0))
                            .animation(.easeInOut, value: refreshOffset > refreshThreshold)
                    }
                }
                .frame(height: refreshOffset)
            }
        }
        .frame(height: 0)
        .offset(y: -7) // Adjust to position the refresh indicator correctly
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named(coordinateSpaceName)).origin.y
                )
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            refreshOffset = offset > 0 ? offset : 0
            
            if refreshOffset > refreshThreshold && !isRefreshing && !isRefreshIndicatorShowing {
                isRefreshIndicatorShowing = true
                
                Task {
                    await onRefresh()
                    isRefreshIndicatorShowing = false
                }
            }
        }
    }
}

// Preference key to track scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    Exploreview()
}
