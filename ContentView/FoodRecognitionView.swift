import SwiftUI
import PhotosUI
import FirebaseFirestore



// Add ChatService definition
private let chatService = ChatService(
    mixraiKey: "YOUR_AI_HERE",
    deepseekKey: "YOUR_AI_HERE"
)

// Add extension for String
extension String {
    func nilIfEmpty() -> String? {
        return self.isEmpty ? nil : self
    }
}

struct RecognizedFood: Identifiable {
    let id = UUID()
    var name: String
    var quantity: Int
    var servingSize: String
    var calories: Double = 0
    var carbs: Double = 0
    var protein: Double = 0
    var fat: Double = 0
}

struct FoodRecognitionView: View {
    let userUID: String
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var recognizedFoods: [RecognizedFood] = []
    @State private var isAnalyzing = false
    @State private var showingResults = false
    @State private var isCalculatingNutrition = false
    @State private var showNutritionSummary = false
    
    // Nutrition summary
    @State private var totalCalories: Double = 0
    @State private var totalCarbs: Double = 0
    @State private var totalProtein: Double = 0
    @State private var totalFat: Double = 0
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertAction: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            if selectedImageData == nil {
                uploadSection
            } else if isAnalyzing {
                loadingView
            } else if showingResults {
                if showNutritionSummary {
                    nutritionSummaryView
                } else {
                    recognizedFoodsListView
                }
            } else {
                imagePreviewSection
            }
        }
        .navigationTitle("Flavour Mirror")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if showNutritionSummary {
                        showNutritionSummary = false
                    } else if showingResults {
                        showingResults = false
                    } else if selectedImageData != nil {
                        selectedImageData = nil
                        selectedItem = nil
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.orange)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            if alertMessage == "Are you sure you want to delete all food items?" {
                return Alert(
                    title: Text("Confirm Deletion"),
                    message: Text(alertMessage),
                    primaryButton: .destructive(Text("Delete")) {
                        withAnimation {
                            recognizedFoods.removeAll()
                        }
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            } else {
                return Alert(
                    title: Text("Notice"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Upload section
    private var uploadSection: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 70))
                .foregroundColor(.orange.opacity(0.8))
                .padding()
            
            Text("Upload a food image to recognize ingredients and calculate nutrition")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("Select Photo")
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // Image preview with analyze button
    private var imagePreviewSection: some View {
        VStack(spacing: 20) {
            if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .padding()
                
                // Back to photo selection button
                Button(action: {
                    // Reset the image data to return to selection screen
                    selectedImageData = nil
                    selectedItem = nil
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.orange)
                        Text("Back to selection")
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 5)
                
                // Analyze button (existing)
                Button(action: analyzeImage) {
                    HStack {
                        Image(systemName: "brain")
                        Text("Analyze with AI")
                    }
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
                }
                .padding(.bottom)
            }
        }
    }
    
    // Loading view shown during analysis
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(2)
                .padding()
            
            Text("Analyzing image...")
                .font(.headline)
                .padding()
        }
    }
    
    // List of recognized foods for editing
    private var recognizedFoodsListView: some View {
        VStack {
            if recognizedFoods.isEmpty {
                Text("No foods detected. Try another image.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(alignment: .leading) {
                    HStack {
                        Text("DETECTED FOODS")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        Spacer()
                        
                        if !recognizedFoods.isEmpty {
                            Button(action: {
                                withAnimation {
                                    alertMessage = "Are you sure you want to delete all food items?"
                                    showAlert = true
                                }
                            }) {
                                Text("Clear All")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                            }
                        }
                        
                        Button(action: addFoodItem) {
                            Text("ADD")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach($recognizedFoods) { $food in
                                VStack(spacing: 0) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            TextField("Food name", text: $food.name)
                                                .font(.headline)
                                            TextField("Serving size", text: $food.servingSize)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            if let index = recognizedFoods.firstIndex(where: { $0.id == food.id }) {
                                                withAnimation {
                                                    recognizedFoods.remove(at: index)
                                                }
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.orange.opacity(0.8))
                                                .padding(.trailing, 8)
                                        }
                                        
                                        HStack(spacing: 0) {
                                            Button(action: {
                                                if food.quantity > 1 {
                                                    food.quantity -= 1
                                                }
                                            }) {
                                                Image(systemName: "minus")
                                                    .padding()
                                                    .background(Color.gray.opacity(0.1))
                                                    .clipShape(Rectangle())
                                                    .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                                            }
                                            
                                            Text("\(food.quantity)")
                                                .frame(width: 40)
                                                .padding(.vertical)
                                            
                                            Button(action: {
                                                food.quantity += 1
                                            }) {
                                                Image(systemName: "plus")
                                                    .padding()
                                                    .background(Color.gray.opacity(0.1))
                                                    .clipShape(Rectangle())
                                                    .cornerRadius(8, corners: [.topRight, .bottomRight])
                                            }
                                        }
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    
                                    Divider()
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        if let index = recognizedFoods.firstIndex(where: { $0.id == food.id }) {
                                            recognizedFoods.remove(at: index)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                
                Button(action: calculateNutrition) {
                    if isCalculatingNutrition {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.horizontal, 10)
                            Text("Calculating...")
                                .foregroundColor(.white)
                        }
                    } else {
                        HStack {
                            Text("Calculate Nutrition")
                                .foregroundColor(.white)
                            Image(systemName: "chart.pie")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(10)
                .padding()
                .disabled(isCalculatingNutrition || recognizedFoods.isEmpty)
            }
        }
    }
    
    // Nutrition summary view with visualization
    private var nutritionSummaryView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Nutrition Summary")
                    .font(.title2)
                    .bold()
                    .padding(.top)
                
                // Calories visualization - more prominent
                VStack(spacing: 5) {
                    Text("Calories")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(totalCalories))")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text("kcal")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.leading, 2)
                    }
                    
                    // Simple progress bar
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 10)
                            .foregroundColor(Color.gray.opacity(0.2))
                            .cornerRadius(5)
                        
                        Rectangle()
                            .frame(width: min(CGFloat(totalCalories) / 2000 * UIScreen.main.bounds.width * 0.8, UIScreen.main.bounds.width * 0.8), height: 10)
                            .foregroundColor(.orange)
                            .cornerRadius(5)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.8)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Macronutrient pie chart and details
                VStack(spacing: 10) {
                    Text("Macronutrient Distribution")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    HStack(alignment: .center, spacing: 30) {
                        // Calculate total macros here so it's in scope for both pie chart and rows
                        let total = totalCarbs + totalProtein + totalFat
                        let carbsAngle = total > 0 ? totalCarbs / total * 360 : 0
                        let proteinAngle = total > 0 ? totalProtein / total * 360 : 0
                        
                        // Pie chart
                        ZStack {
                            // Draw each segment if total is greater than 0
                            if total > 0 {
                                // Create the pie segments
                                // Carbs slice (orange)
                                Circle()
                                    .trim(from: 0, to: carbsAngle / 360)
                                    .stroke(Color.orange, lineWidth: 25)
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))
                                
                                // Protein slice (orange with medium opacity)
                                Circle()
                                    .trim(from: 0, to: proteinAngle / 360)
                                    .stroke(Color.orange.opacity(0.7), lineWidth: 25)
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90 + carbsAngle))
                                
                                // Fat slice (orange with low opacity)
                                Circle()
                                    .trim(from: 0, to: 1 - ((carbsAngle + proteinAngle) / 360))
                                    .stroke(Color.orange.opacity(0.4), lineWidth: 25)
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90 + carbsAngle + proteinAngle))
                            } else {
                                // If no data, show empty circle
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 25)
                                    .frame(width: 120, height: 120)
                            }
                            
                            // Add center circle for better appearance
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                        }
                        .frame(width: 130, height: 130)
                        .padding(.vertical, 10)
                        
                        // Legend and values
                        VStack(alignment: .leading, spacing: 15) {
                            MacroNutrientRow(
                                label: "Carbs",
                                value: Int(totalCarbs),
                                color: .orange,
                                percentage: total > 0 ? Int((totalCarbs / total) * 100) : 0
                            )
                            
                            MacroNutrientRow(
                                label: "Protein",
                                value: Int(totalProtein),
                                color: Color.orange.opacity(0.7),
                                percentage: total > 0 ? Int((totalProtein / total) * 100) : 0
                            )
                            
                            MacroNutrientRow(
                                label: "Fat",
                                value: Int(totalFat),
                                color: Color.orange.opacity(0.4),
                                percentage: total > 0 ? Int((totalFat / total) * 100) : 0
                            )
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Additional nutrition details
                VStack(alignment: .leading, spacing: 15) {
                    Text("Additional Nutrition Details")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    nutritionDetailRow(label: "Vitamins", value: "A, B, C")
                    nutritionDetailRow(label: "Minerals", value: "Ca, Fe, Mg")
                    nutritionDetailRow(label: "Water Content", value: "High")
                    nutritionDetailRow(label: "Fiber", value: "\(Int(totalCarbs * 0.1)) g")
                }
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Action buttons
                HStack(spacing: 15) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    
                    Button(action: addToNutritionIntake) {
                        Text("Add to Daily Intake")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.top)
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
    }
    
    // Helper struct for the macronutrient rows in the chart legend
    private struct MacroNutrientRow: View {
        let label: String
        let value: Int
        let color: Color
        let percentage: Int
        
        var body: some View {
            HStack(spacing: 10) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(label)
                    .font(.callout)
                
                Spacer()
                
                Text("\(value)g")
                    .font(.callout)
                    .bold()
                
                Text("(\(percentage)%)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Helper views
    private func nutritionDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .bold()
        }
    }
    
    // Logic methods
    private func analyzeImage() {
        isAnalyzing = true
        
        guard let imageData = selectedImageData, let uiImage = UIImage(data: imageData) else {
            alertMessage = "Failed to process image. The image data appears to be corrupted."
            showAlert = true
            isAnalyzing = false
            return
        }
        
        // Resize image to reduce API payload size
        let resizedImage = resizeImage(uiImage, targetSize: CGSize(width: 800, height: 800))
        
        // Convert the resized image to base64
        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.7),
              let base64Image = jpegData.base64EncodedString().nilIfEmpty() else {
            alertMessage = "Failed to process image. Unable to convert image to required format."
            showAlert = true
            isAnalyzing = false
            return
        }
        
        // Prepare the message to send to GPT-4o
        let contextMessage = """
        This is a food image. Please analyze it and identify the foods present.
        For each food item, provide:
        1. Name of the food
        2. Estimated quantity (as a number)
        3. Serving size (e.g., "medium-sized", "cup, cooked", etc.)

        Respond in the following JSON format only:
        {
          "foods": [
            {
              "name": "Food name",
              "quantity": 1,
              "servingSize": "serving description"
            },
            ...
          ]
        }
        
        If you can't identify any food items in the image, return an empty foods array.
        Keep your response focused on the JSON only, with no additional text.
        """
        
        Task {
            do {
                // Send the message to GPT-4o with the image
                let response = try await chatService.sendMessageWithImage(contextMessage, base64Image: base64Image, provider: .mixrai)
                print("AI Response: \(response)")
                
                // Extract JSON from the response
                if let jsonData = extractJSONFromResponse(response).data(using: .utf8) {
                    do {
                        let decodedResponse = try JSONDecoder().decode(RecognizedFoodsResponse.self, from: jsonData)
                        await MainActor.run {
                            self.recognizedFoods = decodedResponse.foods.map { food in
                                RecognizedFood(
                                    name: food.name,
                                    quantity: food.quantity,
                                    servingSize: food.servingSize
                                )
                            }
                            
                            if self.recognizedFoods.isEmpty {
                                self.alertMessage = "No foods detected in this image. Please try another image or make sure food items are clearly visible."
                                self.showAlert = true
                            }
                            
                            self.isAnalyzing = false
                            self.showingResults = true
                        }
                    } catch {
                        print("Error decoding JSON: \(error)")
                        await handleAnalysisError("Failed to interpret food information from the AI response. Please try again with a clearer image.")
                    }
                } else {
                    await handleAnalysisError("Failed to extract food information from the AI response. The AI might not have provided a valid JSON format.")
                }
            } catch {
                print("Error getting AI response: \(error)")
                let errorMessage: String
                if let chatError = error as? ChatError {
                    switch chatError {
                    case .httpError(let code):
                        errorMessage = "Network error (code: \(code)). Please check your internet connection and try again."
                    case .apiError(let message):
                        errorMessage = "AI service error: \(message)"
                    case .missingAPIKey:
                        errorMessage = "API configuration error. Please contact support."
                    default:
                        errorMessage = "Failed to analyze image: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "Failed to analyze image: \(error.localizedDescription)"
                }
                await handleAnalysisError(errorMessage)
            }
        }
    }
    
    private func extractJSONFromResponse(_ response: String) -> String {
        // Find JSON content between curly braces
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            return String(response[startIndex...endIndex])
        }
        
        return "{\"foods\": []}"
    }
    
    private func handleAnalysisError(_ message: String) async {
        await MainActor.run {
            self.alertMessage = message
            self.showAlert = true
            self.isAnalyzing = false
        }
    }
    
    private func addFoodItem() {
        recognizedFoods.append(RecognizedFood(name: "", quantity: 1, servingSize: ""))
    }
    
    private func calculateNutrition() {
        isCalculatingNutrition = true
        
        // Reset nutrition totals
        totalCalories = 0
        totalCarbs = 0
        totalProtein = 0
        totalFat = 0
        
        // Prepare food items for nutrition lookup
        let foodItems = recognizedFoods.map { food in
            return "\(food.name) - Quantity: \(food.quantity), Serving size: \(food.servingSize)"
        }.joined(separator: "\n")
        
        // Prepare prompt for AI
        let contextMessage = """
        Please provide nutritional information for the following food items:
        
        \(foodItems)
        
        Respond in JSON format only:
        {
          "foods": [
            {
              "name": "Food name",
              "quantity": 1,
              "servingSize": "serving description",
              "calories": 100,
              "carbs": 10,
              "protein": 5,
              "fat": 2
            },
            ...
          ]
        }
        
        All nutritional values should be numerical only - calories in kcal, and carbs/protein/fat in grams.
        Use realistic nutritional values based on standard food databases.
        """
        
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                print("Nutrition AI Response: \(response)")
                
                // Extract JSON from the response
                if let jsonData = extractJSONFromResponse(response).data(using: .utf8) {
                    do {
                        let nutritionResponse = try JSONDecoder().decode(NutritionResponse.self, from: jsonData)
                        
                        await MainActor.run {
                            // Calculate total nutrition values with validation
                            for foodNutrition in nutritionResponse.foods {
                                // Validate that values are positive
                                let validCalories = max(0, foodNutrition.calories)
                                let validCarbs = max(0, foodNutrition.carbs)
                                let validProtein = max(0, foodNutrition.protein)
                                let validFat = max(0, foodNutrition.fat)
                                
                                // Add to totals
                                totalCalories += validCalories
                                totalCarbs += validCarbs
                                totalProtein += validProtein
                                totalFat += validFat
                                
                                print("Food: \(foodNutrition.name), Calories: \(validCalories), Carbs: \(validCarbs)g, Protein: \(validProtein)g, Fat: \(validFat)g")
                                
                                // Update the recognized food with nutrition info
                                if let index = recognizedFoods.firstIndex(where: { $0.name.lowercased() == foodNutrition.name.lowercased() }) {
                                    recognizedFoods[index].calories = validCalories
                                    recognizedFoods[index].carbs = validCarbs
                                    recognizedFoods[index].protein = validProtein
                                    recognizedFoods[index].fat = validFat
                                }
                            }
                            
                            // Round totals to 2 decimal places to avoid floating-point precision issues
                            totalCalories = round(totalCalories * 100) / 100
                            totalCarbs = round(totalCarbs * 100) / 100
                            totalProtein = round(totalProtein * 100) / 100
                            totalFat = round(totalFat * 100) / 100
                            
                            print("Final nutrition totals: Calories: \(totalCalories), Carbs: \(totalCarbs)g, Protein: \(totalProtein)g, Fat: \(totalFat)g")
                            
                            isCalculatingNutrition = false
                            showNutritionSummary = true
                        }
                    } catch {
                        print("Error decoding nutrition JSON: \(error)")
                        await handleNutritionError()
                    }
                } else {
                    print("Failed to extract valid JSON from AI response")
                    await handleNutritionError()
                }
            } catch {
                print("Error getting nutrition from AI: \(error)")
                await handleNutritionError()
            }
        }
    }
    
    private func handleNutritionError() async {
        await MainActor.run {
            // Show alert about using estimated values
            alertMessage = "Could not get precise nutritional data. Using estimated values instead."
            showAlert = true
            
            // Fallback to basic calculation if AI fails
            for food in recognizedFoods {
                // Basic nutritional estimates based on food category
                let foodName = food.name.lowercased()
                let quantity = Double(food.quantity)
                
                var foodCalories: Double = 0
                var foodCarbs: Double = 0
                var foodProtein: Double = 0
                var foodFat: Double = 0
                
                if foodName.contains("apple") || foodName.contains("orange") || foodName.contains("banana") || 
                   foodName.contains("fruit") {
                    // Fruit category
                    foodCalories = quantity * 80
                    foodCarbs = quantity * 20
                    foodProtein = quantity * 1
                    foodFat = quantity * 0.3
                } else if foodName.contains("chicken") || foodName.contains("beef") || foodName.contains("fish") ||
                          foodName.contains("pork") || foodName.contains("meat") || foodName.contains("protein") {
                    // Meat/protein category
                    foodCalories = quantity * 150
                    foodCarbs = quantity * 0
                    foodProtein = quantity * 25
                    foodFat = quantity * 8
                } else if foodName.contains("rice") || foodName.contains("pasta") || foodName.contains("bread") ||
                          foodName.contains("grain") || foodName.contains("carb") {
                    // Grain/carb category
                    foodCalories = quantity * 200
                    foodCarbs = quantity * 40
                    foodProtein = quantity * 4
                    foodFat = quantity * 1
                } else if foodName.contains("vegetable") || foodName.contains("broccoli") || 
                          foodName.contains("carrot") || foodName.contains("salad") {
                    // Vegetable category
                    foodCalories = quantity * 50
                    foodCarbs = quantity * 10
                    foodProtein = quantity * 2
                    foodFat = quantity * 0.3
                } else {
                    // Default category for unknown foods
                    foodCalories = quantity * 100
                    foodCarbs = quantity * 15
                    foodProtein = quantity * 5
                    foodFat = quantity * 3
                }
                
                // Ensure values are non-negative
                foodCalories = max(0, foodCalories)
                foodCarbs = max(0, foodCarbs)
                foodProtein = max(0, foodProtein)
                foodFat = max(0, foodFat)
                
                // Update the recognized food with estimated nutrition info
                if let index = recognizedFoods.firstIndex(where: { $0.name == food.name }) {
                    recognizedFoods[index].calories = foodCalories
                    recognizedFoods[index].carbs = foodCarbs
                    recognizedFoods[index].protein = foodProtein
                    recognizedFoods[index].fat = foodFat
                }
                
                // Add to totals
                totalCalories += foodCalories
                totalCarbs += foodCarbs
                totalProtein += foodProtein
                totalFat += foodFat
                
                print("Estimated - Food: \(food.name), Calories: \(foodCalories), Carbs: \(foodCarbs)g, Protein: \(foodProtein)g, Fat: \(foodFat)g")
            }
            
            // Round totals to 2 decimal places to avoid floating-point precision issues
            totalCalories = round(totalCalories * 100) / 100
            totalCarbs = round(totalCarbs * 100) / 100
            totalProtein = round(totalProtein * 100) / 100
            totalFat = round(totalFat * 100) / 100
            
            print("Final estimated nutrition totals: Calories: \(totalCalories), Carbs: \(totalCarbs)g, Protein: \(totalProtein)g, Fat: \(totalFat)g")
            
            isCalculatingNutrition = false
            showNutritionSummary = true
        }
    }
    
    private func addToNutritionIntake() {
        let db = Firestore.firestore()
        
        // Log the current nutrition totals 
        print("Current totals before database update:")
        print("Calories: \(totalCalories), Carbs: \(totalCarbs), Protein: \(totalProtein), Fat: \(totalFat)")
        
        // Reference to user's nutrition data
        let userRef = db.collection("User").document(userUID)
            .collection("target").document("current")
        
        // Get current nutrition data
        userRef.getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user nutrition data: \(error.localizedDescription)")
                alertMessage = "Error: \(error.localizedDescription)"
                showAlert = true
                return
            }
            
            guard let data = snapshot?.data() else {
                print("No nutrition data found for user \(userUID)")
                alertMessage = "No nutrition data found. Please set up your nutrition goals first."
                showAlert = true
                return
            }
            
            // Log the retrieved data to help diagnose issues
            print("Retrieved nutrition data from database:")
            print("Ingested: \(data["Ingested"] ?? "nil"), Type: \(type(of: data["Ingested"] ?? "nil"))")
            print("CarbsIngested: \(data["CarbsIngested"] ?? "nil"), Type: \(type(of: data["CarbsIngested"] ?? "nil"))")
            print("ProteinIngested: \(data["ProteinIngested"] ?? "nil"), Type: \(type(of: data["ProteinIngested"] ?? "nil"))")
            print("FatIngested: \(data["FatIngested"] ?? "nil"), Type: \(type(of: data["FatIngested"] ?? "nil"))")
            
            // Get current ingested values with careful type handling
            // First try as Double, then as Int (which could be stored in Firestore)
            var currentCalories: Double = 0
            if let value = data["Ingested"] as? Double {
                currentCalories = value
            } else if let value = data["Ingested"] as? Int {
                currentCalories = Double(value)
            } else {
                print("Could not parse Ingested value from database, using 0")
            }
            
            var currentCarbs: Double = 0
            if let value = data["CarbsIngested"] as? Double {
                currentCarbs = value
            } else if let value = data["CarbsIngested"] as? Int {
                currentCarbs = Double(value)
            } else {
                print("Could not parse CarbsIngested value from database, using 0")
            }
            
            var currentProtein: Double = 0
            if let value = data["ProteinIngested"] as? Double {
                currentProtein = value
            } else if let value = data["ProteinIngested"] as? Int {
                currentProtein = Double(value)
            } else {
                print("Could not parse ProteinIngested value from database, using 0")
            }
            
            var currentFat: Double = 0
            if let value = data["FatIngested"] as? Double {
                currentFat = value
            } else if let value = data["FatIngested"] as? Int {
                currentFat = Double(value)
            } else {
                print("Could not parse FatIngested value from database, using 0")
            }
            
            // Round values to 2 decimal places to avoid floating-point precision issues
            let caloriesValue = round(totalCalories * 100) / 100
            let carbsValue = round(totalCarbs * 100) / 100
            let proteinValue = round(totalProtein * 100) / 100
            let fatValue = round(totalFat * 100) / 100
            
            // Update values
            currentCalories += caloriesValue
            currentCarbs += carbsValue
            currentProtein += proteinValue
            currentFat += fatValue
            
            print("Updating nutrition in database:")
            print("Calories: \(currentCalories), Carbs: \(currentCarbs), Protein: \(currentProtein), Fat: \(currentFat)")
            
            // Ensure we only update the 4 key nutrition fields
            let updatedData: [String: Any] = [
                "Ingested": currentCalories,
                "CarbsIngested": currentCarbs,
                "ProteinIngested": currentProtein,
                "FatIngested": currentFat
            ]
            
            // Update in Firestore
            userRef.updateData(updatedData) { error in
                if let error = error {
                    print("Error updating nutrition in database: \(error.localizedDescription)")
                    alertMessage = "Failed to update nutrition intake: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    print("Successfully updated nutrition in database")
                    alertMessage = "Added to your daily nutrition intake!"
                    showAlert = true
                    
                    // Dismiss the view after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Helper function to resize images
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}

// Add struct to decode JSON response
struct RecognizedFoodsResponse: Decodable {
    let foods: [FoodItem]
}

struct FoodItem: Decodable {
    let name: String
    let quantity: Int
    let servingSize: String
}

// Add struct to decode nutrition response
struct NutritionResponse: Decodable {
    let foods: [FoodNutrition]
}

struct FoodNutrition: Decodable {
    let name: String
    let quantity: Int
    let servingSize: String
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double
}

struct FoodRecognitionView_Previews: PreviewProvider {
    static var previews: some View {
        FoodRecognitionView(userUID: "testUID")
    }
} 
