import SwiftUI
import FirebaseFirestore

struct CheckUserRecipe: View {
    let recipeId: String
    
    @State private var recipeImage: String = ""
    @State private var recipeName: String = ""
    @State private var description: String = ""
    @State private var ingredients: [IngredientDetail] = []
    @State private var steps: [String] = []
    @State private var nutritions: [NutritionDetail] = []
    @State private var category: String = ""
    @State private var createDate: Date?
    @State private var username: String = ""
    @State private var authorUID: String = ""
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    struct IngredientDetail: Identifiable {
        let id = UUID()
        var name: String
        var value: String
    }
    
    struct NutritionDetail: Identifiable {
        let id = UUID()
        var name: String
        var value: String
    }
    
    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Loading recipe details...")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Recipe Image
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
                    
                    // Recipe Content
                    VStack(alignment: .leading, spacing: 20) {
                        // Title and Author
                        VStack(alignment: .leading, spacing: 12) {
                            Text(recipeName)
                                .font(.title)
                                .bold()
                                .padding(.horizontal)
                            
                            HStack {
                                Text("By: \(username)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        
                        // Category and Date
                        HStack {
                            CategoryPill(text: category)
                            if let date = createDate {
                                Text("•")
                                    .foregroundColor(.gray)
                                Text(date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Description
                        if !description.isEmpty {
                            Text(description)
                                .padding(.horizontal)
                        }
                        
                        // Ingredients
                        RecipeSection(title: "Ingredients") {
                            ForEach(ingredients) { ingredient in
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
                        
                        // Nutrition Facts
                        if !nutritions.isEmpty {
                            RecipeSection(title: "Nutrition Facts") {
                                ForEach(nutritions) { nutrition in
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
                        }
                        
                        // Steps
                        RecipeSection(title: "Steps") {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
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
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Recipe Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            fetchRecipeDetails()
        }
    }
    
    private func fetchRecipeDetails() {
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("Recipe").document(recipeId).getDocument { document, error in
            if let error = error {
                errorMessage = "Error fetching recipe: \(error.localizedDescription)"
                showError = true
                isLoading = false
                return
            }
            
            guard let document = document, document.exists else {
                errorMessage = "Recipe not found"
                showError = true
                isLoading = false
                return
            }
            
            // Extract recipe data
            let data = document.data() ?? [:]
            
            // Basic recipe info - using field names that match the database
            self.recipeName = data["Rname"] as? String ?? "Untitled Recipe"
            self.recipeImage = data["RecipeImg"] as? String ?? ""
            self.description = data["description"] as? String ?? ""
            self.category = data["Category"] as? String ?? "Other"
            self.authorUID = data["UID"] as? String ?? ""
            
            // Date handling
            if let timestamp = data["CreateDate"] as? Timestamp {
                self.createDate = timestamp.dateValue()
            }
            
            // Fetch author username
            if !self.authorUID.isEmpty {
                fetchUsername(uid: self.authorUID)
            }
            
            // Handle ingredients
            if let ingredientsArray = data["ingredients"] as? [[String: Any]] {
                self.ingredients = []
                for ingredientDict in ingredientsArray {
                    if let name = ingredientDict["name"] as? String,
                       let value = ingredientDict["value"] as? String {
                        self.ingredients.append(IngredientDetail(name: name, value: value))
                    }
                }
            }
            
            // Handle nutrition
            if let nutritionsArray = data["nutritions"] as? [[String: Any]] {
                self.nutritions = []
                for nutritionDict in nutritionsArray {
                    if let name = nutritionDict["name"] as? String,
                       let value = nutritionDict["value"] as? String {
                        self.nutritions.append(NutritionDetail(name: name, value: value))
                    }
                }
            }
            
            // Handle steps
            if let stepsArray = data["steps"] as? [String] {
                self.steps = stepsArray
            }
            
            isLoading = false
        }
    }
    
    private func fetchUsername(uid: String) {
        let db = Firestore.firestore()
        db.collection("User").document(uid).getDocument { document, error in
            if let document = document, document.exists,
               let username = document.data()?["uname"] as? String {
                self.username = username
            }
        }
    }
}

struct CheckUserRecipe_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CheckUserRecipe(recipeId: "previewRecipeId")
        }
    }
} 
