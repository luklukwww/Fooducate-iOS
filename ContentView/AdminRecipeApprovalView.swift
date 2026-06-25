import SwiftUI
import FirebaseFirestore

struct AdminRecipeApprovalView: View {
    @State private var recipes: [RecipeItem] = []
    @State private var isLoading = true
    @StateObject private var adminManager = AdminManager.shared
    @State private var showAlert = false
    @State private var selectedFilter: FilterOption = .all
    @State private var showDetail: String? = nil
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    enum FilterOption {
        case all, visible, hidden
        
        var title: String {
            switch self {
            case .all: return "All"
            case .visible: return "Visible"
            case .hidden: return "Hidden"
            }
        }
    }
    
    struct RecipeItem: Identifiable {
        let id: String
        let name: String
        let imageURL: String
        let authorName: String
        let authorUID: String
        var isVisible: Bool
        let category: String
    }
    
    var filteredRecipes: [RecipeItem] {
        let filtered = switch selectedFilter {
        case .all:
            recipes
        case .visible:
            recipes.filter { $0.isVisible }
        case .hidden:
            recipes.filter { !$0.isVisible }
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.authorName.localizedCaseInsensitiveContains(searchText) ||
                recipe.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索欄
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search recipes...", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // 分類選擇器
            Picker("Filter", selection: $selectedFilter) {
                ForEach([FilterOption.all, .visible, .hidden], id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // 食譜列表
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                } else if filteredRecipes.isEmpty {
                    Text("No recipes found")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredRecipes) { recipe in
                        RecipeManageRow(
                            recipe: recipe,
                            onVisibilityToggle: { newVisibility in
                                toggleRecipeVisibility(recipe: recipe, isVisible: newVisibility)
                            },
                            onTap: {
                                showDetail = recipe.id
                            }
                        )
                    }
                }
            }
            .listStyle(PlainListStyle())
            .refreshable {
                await fetchAllRecipes()
            }
        }
        .navigationTitle("Manage Recipes")
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
        .sheet(item: Binding(
            get: { showDetail.map { RecipeDetailWrapper(id: $0) } },
            set: { showDetail = $0?.id }
        )) { wrapper in
            if let recipe = recipes.first(where: { $0.id == wrapper.id }) {
                AdminRecipeDetailView(recipe: recipe, onVisibilityToggle: { newVisibility in
                    toggleRecipeVisibility(recipe: recipe, isVisible: newVisibility)
                })
                .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            fetchAllRecipes()
        }
    }
    
    private func fetchAllRecipes() {
        let db = Firestore.firestore()
        db.collection("Recipe").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching recipes: \(error)")
                isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                isLoading = false
                return
            }
            
            let group = DispatchGroup()
            var tempRecipes: [RecipeItem] = []
            
            for doc in documents {
                group.enter()
                let data = doc.data()
                let authorUID = data["UID"] as? String ?? ""
                
                db.collection("User").document(authorUID).getDocument { userDoc, _ in
                    let authorName = userDoc?.data()?["uname"] as? String ?? "Unknown"
                    let isVisible = data["isVisible"] as? Bool ?? false
                    let category = data["Category"] as? String ?? "Other"
                    
                    tempRecipes.append(RecipeItem(
                        id: doc.documentID,
                        name: data["Rname"] as? String ?? "",
                        imageURL: data["RecipeImg"] as? String ?? "",
                        authorName: authorName,
                        authorUID: authorUID,
                        isVisible: isVisible,
                        category: category
                    ))
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.recipes = tempRecipes.sorted { $0.name < $1.name }
                isLoading = false
            }
        }
    }
    
    private func toggleRecipeVisibility(recipe: RecipeItem, isVisible: Bool) {
        let db = Firestore.firestore()
        
        // Update Firestore document
        db.collection("Recipe").document(recipe.id).updateData([
            "isVisible": isVisible
        ]) { error in
            if let error = error {
                print("Error updating recipe visibility: \(error.localizedDescription)")
            } else {
                // Update local state once Firestore update is successful
                DispatchQueue.main.async {
                    if let index = self.recipes.firstIndex(where: { $0.id == recipe.id }) {
                        self.recipes[index].isVisible = isVisible
                    }
                }
            }
        }
    }
}

// Sheet顯示
struct RecipeDetailWrapper: Identifiable {
    let id: String
}

struct RecipeManageRow: View {
    let recipe: AdminRecipeApprovalView.RecipeItem
    let onVisibilityToggle: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 縮小的圖片
            AsyncImage(url: URL(string: recipe.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
            }
            .clipped()
            
            // 食譜信息
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("By: \(recipe.authorName)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Text("Category: \(recipe.category)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                // 快速操作按鈕
                HStack {
                    Spacer()
                    
                    Button(action: {
                        // When button is clicked, toggle recipe visibility to the opposite state
                        onVisibilityToggle(!recipe.isVisible)
                    }) {
                        Text(recipe.isVisible ? "Hide" : "Show")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(recipe.isVisible ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                            .cornerRadius(4)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                // Same toggle logic for swipe action
                onVisibilityToggle(!recipe.isVisible)
            } label: {
                Label(recipe.isVisible ? "Hide" : "Show", systemImage: recipe.isVisible ? "eye.slash" : "eye")
            }
            .tint(recipe.isVisible ? .red : .green)
        }
        .padding(.vertical, 6)
    }
}

struct AdminRecipeDetailView: View {
    let recipe: AdminRecipeApprovalView.RecipeItem
    let onVisibilityToggle: (Bool) -> Void
    @State private var isLoadingDetails = false
    @State private var showFullRecipeDetails = false
    @State private var fullRecipeData: FullRecipeData? = nil
    @State private var isVisible: Bool
    
    init(recipe: AdminRecipeApprovalView.RecipeItem, onVisibilityToggle: @escaping (Bool) -> Void) {
        self.recipe = recipe
        self.onVisibilityToggle = onVisibilityToggle
        _isVisible = State(initialValue: recipe.isVisible)
    }
    
    // 定義完整食譜數據結構
    struct FullRecipeData {
        let id: String
        let name: String
        let description: String
        let imageURL: String
        let category: String
        let ingredients: [Ingredient]
        let steps: [String]
        let nutritions: [Nutrition]
        
        struct Ingredient: Identifiable {
            let id = UUID()
            let name: String
            let value: String
        }
        
        struct Nutrition: Identifiable {
            let id = UUID()
            let name: String
            let value: String
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 食譜圖片
                AsyncImage(url: URL(string: recipe.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .cornerRadius(12)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .cornerRadius(12)
                }
                
                // 食譜信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label(recipe.authorName, systemImage: "person")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Label(recipe.category, systemImage: "tag")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Divider()
                    
                    // 可見性控制 - 只保留按鈕
                    Button(action: {
                        // Toggle the visibility and call the callback with the new value
                        let newVisibility = !isVisible
                        isVisible = newVisibility
                        onVisibilityToggle(newVisibility)
                    }) {
                        HStack {
                            Image(systemName: isVisible ? "eye.slash" : "eye")
                            Text(isVisible ? "Hide Recipe" : "Show Recipe")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isVisible ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.top, 4)
                    
                    Divider()
                    
                    // 添加查看詳情按鈕
                    Button(action: {
                        loadFullRecipeDetails()
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text("View Full Recipe Details")
                            Spacer()
                            if isLoadingDetails {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    .disabled(isLoadingDetails)
                }
                .padding(.horizontal)
            }
            .sheet(isPresented: $showFullRecipeDetails) {
                if let recipeData = fullRecipeData {
                    FullRecipeDetailView(recipeData: recipeData)
                }
            }
        }
        .navigationTitle("Recipe Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // 獲取完整食譜數據
    private func loadFullRecipeDetails() {
        isLoadingDetails = true
        
        // 從Firestore獲取完整的食譜數據
        let db = Firestore.firestore()
        db.collection("Recipe").document(recipe.id).getDocument { document, error in
            if let error = error {
                print("Error fetching recipe details: \(error)")
                isLoadingDetails = false
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                isLoadingDetails = false
                return
            }
            
            // 解析食材
            var ingredients: [FullRecipeData.Ingredient] = []
            if let ingredientsData = data["ingredients"] as? [[String: Any]] {
                for ingredient in ingredientsData {
                    let name = ingredient["name"] as? String ?? ""
                    let value = ingredient["value"] as? String ?? ""
                    ingredients.append(FullRecipeData.Ingredient(name: name, value: value))
                }
            }
            
            // 解析步驟
            var steps: [String] = []
            if let stepsData = data["steps"] as? [String] {
                steps = stepsData
            }
            
            // 解析營養成分
            var nutritions: [FullRecipeData.Nutrition] = []
            if let nutritionsData = data["nutritions"] as? [[String: Any]] {
                for nutrition in nutritionsData {
                    let name = nutrition["name"] as? String ?? ""
                    let value = nutrition["value"] as? String ?? ""
                    nutritions.append(FullRecipeData.Nutrition(name: name, value: value))
                }
            }
            
            // 創建完整食譜數據
            let fullRecipe = FullRecipeData(
                id: document.documentID,
                name: data["Rname"] as? String ?? "",
                description: data["description"] as? String ?? "",
                imageURL: data["RecipeImg"] as? String ?? "",
                category: data["Category"] as? String ?? "Other",
                ingredients: ingredients,
                steps: steps,
                nutritions: nutritions
            )
            
            DispatchQueue.main.async {
                self.fullRecipeData = fullRecipe
                self.isLoadingDetails = false
                self.showFullRecipeDetails = true
            }
        }
    }
}

// 完整食譜詳情視圖
struct FullRecipeDetailView: View {
    let recipeData: AdminRecipeDetailView.FullRecipeData
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 食譜圖片
                    AsyncImage(url: URL(string: recipeData.imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // 食譜標題和分類
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recipeData.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Category: \(recipeData.category)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // 食譜描述
                        if !recipeData.description.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                
                                Text(recipeData.description)
                                    .font(.body)
                            }
                            .padding(.top, 8)
                        }
                        
                        // 食材列表
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ingredients")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            ForEach(recipeData.ingredients) { ingredient in
                                HStack {
                                    Text("•")
                                        .foregroundColor(.orange)
                                    Text(ingredient.name)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(ingredient.value)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 8)
                        
                        // 營養成分 
                        if !recipeData.nutritions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Nutrition Facts")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                
                                VStack(spacing: 15) {
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 16) {
                                        ForEach(recipeData.nutritions) { nutrition in
                                            VStack(alignment: .center) {
                                                Text(nutrition.name)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                Text(nutrition.value)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.black)
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        }
                        
                        // 烹飪步驟
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Steps")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            ForEach(Array(recipeData.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1).")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                        .frame(width: 25, alignment: .leading)
                                    
                                    Text(step)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Recipe Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
} 
