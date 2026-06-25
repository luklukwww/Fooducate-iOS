import SwiftUI
import FirebaseFirestore

import PhotosUI
import Vision


enum RecipeFoodType: String, CaseIterable, Identifiable {
    case chinese = "Chinese"
    case italian = "Italian"
    case japanese = "Japanese"
    case mexican = "Mexican"
    case american = "American"
    case middleEastern = "Middle Eastern"
    case indian = "Indian"
    case other = "Other"
    
    var id: String { self.rawValue }
    

    static var unselected: RecipeFoodType { .other }
}

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSettings: UserSettings
    @State private var recipeName: String
    @State private var description: String
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedCategory: RecipeFoodType
    @State private var hasSelectedCategory: Bool = false
    @State private var ingredients: [Ingredient]
    @State private var steps: [String]
    @State private var requiredNutritions: [Nutrition]
    @State private var optionalNutritions: [Nutrition] = []
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @AppStorage("userUID") private var userUID: String = ""
    
    // AI Ingredient Recognition
    @State private var showingIngredientScanner = false
    @State private var ingredientImage: UIImage? = nil
    @State private var ingredientScannerImage: PhotosPickerItem? = nil
    @State private var ingredientScannerImageData: Data? = nil
    @State private var isAnalyzingIngredient = false
    @State private var analyzedIngredients: String = ""
    private let foodDetector = MockFoodDetector()
    
    // 添加ChatService實例
    private let chatService = ChatService(
        mixraiKey: "YOUR_AI_HERE",
        deepseekKey: "YOUR_AI_HERE"
    )
    
    private let imgurClientId = "YOUR_AC_KEY_HERE"
    private let imgurUploadURL = "https://api.imgur.com/3/image"
    
    @State private var newNutritionName: String = ""
    @State private var showingAddNutritionSheet = false
    
    struct Ingredient: Identifiable {
        let id = UUID()
        var name: String
        var value: String
    }
    
    struct Nutrition: Identifiable {
        let id = UUID()
        var name: String
        var value: String
        var daily: String = ""
    }
    
    struct RecipeData {
        let recipeName: String
        let description: String
        let ingredients: [Ingredient]
        let steps: [String]
        let requiredNutritions: [Nutrition]
    }
    
    // 初始化
    init(recipeName: String = "", 
         description: String = "", 
         ingredients: [Ingredient] = [Ingredient(name: "", value: "")],
         steps: [String] = [""],
         requiredNutritions: [Nutrition] = [
            Nutrition(name: "Calories", value: ""),
            Nutrition(name: "Carbohydrates", value: ""),
            Nutrition(name: "Protein", value: ""),
            Nutrition(name: "Fat", value: "")
         ]) {
        _recipeName = State(initialValue: recipeName)
        _description = State(initialValue: description)
        _ingredients = State(initialValue: ingredients)
        _steps = State(initialValue: steps)
        _requiredNutritions = State(initialValue: requiredNutritions)
        _selectedCategory = State(initialValue: RecipeFoodType.unselected)
        _hasSelectedCategory = State(initialValue: false)
        

        UINavigationBar.appearance().tintColor = .systemOrange
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 图片选择器
                Section(header: Text("Recipe Image").foregroundColor(Color.orange.opacity(0.8))) {
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        if let selectedImageData,
                           let uiImage = UIImage(data: selectedImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                        } else {
                            ContentUnavailableView("Tap to select a photo", systemImage: "photo.badge.plus")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // 基本信息
                Section(header: Text("Basic Information").foregroundColor(Color.orange.opacity(0.8))) {
                    TextField("Recipe Name", text: $recipeName)
                    

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                        
                        Menu {
                            ForEach(RecipeFoodType.allCases) { foodType in
                                Button {
                                    selectedCategory = foodType
                                    hasSelectedCategory = true
                                } label: {
                                    Text(foodType.rawValue)
                                }
                            }
                        } label: {
                            HStack {
                                Text(!hasSelectedCategory ? "Select Recipe Type" : selectedCategory.rawValue)
                                    .foregroundColor(!hasSelectedCategory ? .gray : .orange)
                                    .fontWeight(!hasSelectedCategory ? .regular : .semibold)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .accentColor(.orange)
                    }
                    .padding(.bottom, 4)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // 配料
                Section(header: HStack {
                    Text("Ingredients").foregroundColor(Color.orange.opacity(0.8))
                    Spacer()
                    Button(action: {
                        showingIngredientScanner = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                            Text("AI Detection")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange)
                        )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }) {
                    ForEach(ingredients.indices, id: \.self) { index in
                        HStack {
                            TextField("Name", text: $ingredients[index].name)
                                .foregroundColor(.black)
                            TextField("Amount", text: $ingredients[index].value)
                                .foregroundColor(.black)
                            if ingredients.count > 1 {
                                Button(action: { ingredients.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    Button(action: {
                        ingredients.append(Ingredient(name: "", value: ""))
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Ingredient")
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 8)
                        .foregroundColor(.orange)
                    }
                    .foregroundColor(.orange)
                }
                
                // 必填营养成分
                Section(header: HStack {
                    Text("Required Nutrition Facts").foregroundColor(Color.orange.opacity(0.8))
                    Spacer()
                    Button(action: {
                        analyzeNutrition()
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text("AI Analysis")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange)
                        )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }) {
                    ForEach($requiredNutritions) { $nutrition in
                        VStack(alignment: .leading) {
                            Text(nutrition.name)
                                .font(.headline)
                                .foregroundColor(Color.orange.opacity(0.8))
                            TextField("Value", text: $nutrition.value)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                
                // 选填营养成分
                Section(header: Text("Optional Nutrition Facts").foregroundColor(Color.orange.opacity(0.8))) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Name")
                                .foregroundColor(.gray)
                                .frame(width: 150, alignment: .leading)
                            Text("Value")
                                .foregroundColor(.gray)
                                .frame(width: 100, alignment: .leading)
                            Spacer()
                        }
                        .padding(.bottom, 5)
                        
                        ForEach(optionalNutritions.indices, id: \.self) { index in
                            HStack {
                                TextField("Name", text: $optionalNutritions[index].name)
                                    .frame(width: 150)
                                TextField("Value", text: $optionalNutritions[index].value)
                                    .frame(width: 100)
                                Spacer()
                                if optionalNutritions.count > 0 {
                                    Button(action: { optionalNutritions.remove(at: index) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        optionalNutritions.append(Nutrition(name: "", value: ""))
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Nutrition")
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 8)
                        .foregroundColor(.orange)
                    }
                    .foregroundColor(.orange)
                }
                
                // 步骤
                Section(header: Text("Steps").foregroundColor(Color.orange.opacity(0.8))) {
                    ForEach(steps.indices, id: \.self) { index in
                        HStack {
                            TextField("Step \(index + 1)", text: $steps[index], axis: .vertical)
                                .lineLimit(2...4)
                            if steps.count > 1 {
                                Button(action: { steps.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    Button(action: {
                        steps.append("")
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Step")
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 8)
                        .foregroundColor(.orange)
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
          
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.orange)
                        }
                        
     
                        Spacer().frame(width: 18)
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    let isDisabled = isLoading || recipeName.isEmpty || selectedImageData == nil || !hasSelectedCategory
                    
                    Button("Post") {
                        uploadRecipe()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(isDisabled ? .gray : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDisabled ? Color.orange.opacity(0.2) : Color.orange)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isDisabled ? Color.gray.opacity(0.3) : Color.orange, lineWidth: 1)
                    )
                    .shadow(color: isDisabled ? .clear : Color.orange.opacity(0.3), radius: isDisabled ? 0 : 2, x: 0, y: 1)
                    .disabled(isDisabled)
                    .padding(.trailing, 4)
                }
            }
            .onAppear {

                UINavigationBar.appearance().tintColor = .systemOrange
            }
            .onChange(of: selectedImage) { _ in
                Task {
                    if let data = try? await selectedImage?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
            .alert("Notice", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if alertMessage.contains("login") || alertMessage.contains("sign in") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .sheet(isPresented: $showingIngredientScanner) {
                IngredientScannerView(
                    isPresented: $showingIngredientScanner,
                    ingredients: $ingredients
                )
            }
        }
        .tint(.orange)
        .accentColor(.orange)
    }
    

    private func analyzeNutrition() {

        if ingredients.isEmpty || ingredients.allSatisfy({ $0.name.isEmpty }) {
            alertMessage = "Please add ingredients before analyzing nutrition"
            showAlert = true
            return
        }
        
        if steps.isEmpty || steps.allSatisfy({ $0.isEmpty }) {
            alertMessage = "Please add cooking steps before analyzing nutrition"
            showAlert = true
            return
        }
        
   
        isLoading = true
        
     
        let ingredientsText = ingredients.map { "\($0.name): \($0.value)" }.joined(separator: "\n")
        let stepsText = steps.enumerated().map { "Step \($0 + 1): \($1)" }.joined(separator: "\n")
        
  
        let contextMessage = """
        Analyze the nutritional content of the following recipe.
        Return ONLY a JSON object with nutrition values, no explanations.
        
        Required fields that MUST be included: Calories, Carbohydrates, Protein, Fat
        Optional fields you can include if appropriate: Fiber, Sugar, Sodium, Cholesterol, Vitamin A, Vitamin C, Calcium, Iron
        
        Format each value with appropriate units (e.g., "350 kcal", "45 g").
        
        Recipe:
        \(recipeName.isEmpty ? "Untitled Recipe" : recipeName)
        
        Ingredients:
        \(ingredientsText)
        
        Steps:
        \(stepsText)
        
        Return ONLY the JSON with NO explanation text.
        Example format:
        {
          "Calories": "350 kcal",
          "Carbohydrates": "45 g",
          "Protein": "12 g",
          "Fat": "10 g",
          "Fiber": "5 g"
        }
        """
        
   
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                

                await MainActor.run {
                    isLoading = false
                    
                    //提取JSON
                    if let jsonData = extractJSONFromResponse(response) {
                        // 解析JSON並更新營養信息
                        updateNutritionsFromJSON(jsonData)
                        alertMessage = "Nutrition analysis completed!"
                    } else {
                        // 如果無法提取JSON，直接使用整個回應
                        alertMessage = "Received non-JSON response from AI. Please try again."
                    }
                    
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Error analyzing nutrition: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    

    private func extractJSONFromResponse(_ response: String) -> [String: String]? {

        let pattern = "\\{[\\s\\S]*?\\}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: response, options: [], range: NSRange(location: 0, length: response.utf16.count)) {
            let jsonString = (response as NSString).substring(with: match.range)
            
            // 嘗試解析JSON
            if let jsonData = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                
                // 將JSON轉換為 [String: String] 格式
                var result: [String: String] = [:]
                for (key, value) in json {
                    if let stringValue = value as? String {
                        result[key] = stringValue
                    } else {
                        result[key] = "\(value)"
                    }
                }
                return result
            }
        }
        

        let lines = response.components(separatedBy: .newlines)
        var result: [String: String] = [:]
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.contains(":") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count >= 2 {
                    let key = components[0].trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    
                    let value = components[1].trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    
                    if !key.isEmpty && !value.isEmpty {
                        result[key] = value
                    }
                }
            }
        }
        
        return result.isEmpty ? nil : result
    }
    

    private func updateNutritionsFromJSON(_ json: [String: String]) {
        for index in 0..<requiredNutritions.count {
            let nutritionName = requiredNutritions[index].name
            if let value = json[nutritionName] {
                requiredNutritions[index].value = value
            }
        }
        
        // 更新或添加可選營養成分
        for (name, value) in json {
         
            if !requiredNutritions.contains(where: { $0.name == name }) {
            
                if let index = optionalNutritions.firstIndex(where: { $0.name == name }) {
                    optionalNutritions[index].value = value
                } else {
        
                    optionalNutritions.append(Nutrition(name: name, value: value))
                }
            }
        }
    }
    
    private func uploadRecipe() {
        // 檢查用戶是否已登入
        if !userSettings.isLoggedIn {
            alertMessage = "Please login to upload recipes"
            showAlert = true
            return
        }
        
 
        if !validateRequiredFields() {
            return
        }
        
        guard let imageData = selectedImageData,
              let uiImage = UIImage(data: imageData),
              let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            alertMessage = "Please select an image for the recipe"
            showAlert = true
            return
        }
        
        isLoading = true
        
        // 首先上传图片到 Imgur
        var request = URLRequest(url: URL(string: imgurUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(imgurClientId)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 将图片转换为 base64 并进行 URL 编码
        let base64Image = jpegData.base64EncodedString()
        let encodedImage = base64Image.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? base64Image
        let bodyString = "image=\(encodedImage)"
        
        request.httpBody = bodyString.data(using: .utf8)
        
        print("Uploading image to Imgur...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
            }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.alertMessage = "Failed to upload image: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isLoading = false
                    return
                }
                
                guard let data = data,
                      let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataDict = jsonResponse["data"] as? [String: Any],
                      let imageUrl = dataDict["link"] as? String else {
                    self.alertMessage = "Failed to get image URL from response"
                    self.showAlert = true
                    self.isLoading = false
                    return
                }
                
                //保存食谱数据到 Firestore
                let db = Firestore.firestore()
                let allNutritions = self.requiredNutritions + self.optionalNutritions
                
                let recipeData: [String: Any] = [
                    "Category": self.selectedCategory.rawValue,
                    "CreateDate": FieldValue.serverTimestamp(),
                    "RecipeImg": imageUrl,
                    "Rname": self.recipeName,
                    "UID": self.userUID,
                    "description": self.description,
                    "ingredients": self.ingredients.map { [
                        "name": $0.name,
                        "value": $0.value
                    ] },
                    "like": 0,
                    "nutritions": allNutritions.map { [
                        "name": $0.name,
                        "value": $0.value
                    ] },
                    "steps": self.steps.filter { !$0.isEmpty },
                    "isVisible": false
                ]
                
                //创建新的食谱文档
                let recipeRef = db.collection("Recipe").document()
                recipeRef.setData(recipeData) { error in
                    if let error = error {
                        self.alertMessage = "Failed to save recipe: \(error.localizedDescription)"
                        self.showAlert = true
                        self.isLoading = false
                    } else {
                        // 创建评论子集合
                        let commentRef = recipeRef.collection("Comment")
                        // 评论集合已创建，但暂时为空
                        self.alertMessage = "Successfully uploaded! Waiting for admin approval."
                        self.showAlert = true
                        self.isLoading = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.dismiss()
                        }
                    }
                }
            }
        }.resume()
    }
    
    private func validateRequiredFields() -> Bool {
        // 檢查食譜名稱
        if recipeName.isEmpty {
            alertMessage = "Please enter a recipe name"
            showAlert = true
            return false
        }
        
        // 檢查食譜類型
        if !hasSelectedCategory {
            alertMessage = "Please select a recipe type"
            showAlert = true
            return false
        }
        
        // 檢查食譜圖片
        if selectedImageData == nil {
            alertMessage = "Please select an image for the recipe"
            showAlert = true
            return false
        }
        
        // 檢查食材
        if ingredients.isEmpty || ingredients.allSatisfy({ $0.name.isEmpty && $0.value.isEmpty }) {
            alertMessage = "Please add at least one ingredient"
            showAlert = true
            return false
        }
        
        // 檢查步驟
        if steps.isEmpty || steps.allSatisfy({ $0.isEmpty }) {
            alertMessage = "Please add at least one step"
            showAlert = true
            return false
        }
        
        // 檢查必填營養成分
        let requiredNutritionNames = ["Calories", "Carbohydrates", "Protein", "Fat"]
        for nutrition in requiredNutritions {
            if requiredNutritionNames.contains(nutrition.name) && nutrition.value.isEmpty {
                alertMessage = "Please fill in all required nutrition values (Calories, Carbohydrates, Protein, Fat)"
                showAlert = true
                return false
            }
        }
        
        return true
    }
}

#Preview {
    AddRecipeView()
        .environmentObject(UserSettings.shared)
} 
