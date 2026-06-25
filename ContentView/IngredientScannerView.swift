import SwiftUI
import PhotosUI
import Vision

struct IngredientScannerView: View {
    @Binding var isPresented: Bool
    @Binding var ingredients: [AddRecipeView.Ingredient]
    @State private var imagePickerItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var analyzeIngredientImage: UIImage? = nil
    @State private var isAnalyzing = false
    @State private var analyzedText: String = ""
    @State private var parsedIngredients: [String] = []
    @State private var showAnalysisAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Add ChatService for GPT-4o image analysis
    private let chatService = ChatService(
        mixraiKey: "YOUR_AI_HERE",
        deepseekKey: "YOUR_AI_HERE"
    )
    
    var body: some View {
        NavigationView {
            VStack {
                if let selectedImage = analyzeIngredientImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .padding()
                } else {
                    ContentUnavailableView("Upload an ingredient image", systemImage: "camera.fill")
                        .foregroundColor(.orange)
                        .frame(height: 200)
                        .padding()
                }
                
                PhotosPicker(selection: $imagePickerItem, matching: .images) {
                    Text("Select Image")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                if !parsedIngredients.isEmpty {
                    VStack(alignment: .leading) {
                        Text("AI Detection Result:")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .padding(.top)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(parsedIngredients.indices, id: \.self) { index in
                                    Text("\(index + 1). \(parsedIngredients[index])")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.horizontal)
                }
                
                Button(action: {
                    analyzeImageWithGPT4o()
                }) {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Analyzing...")
                                .foregroundColor(.white)
                        } else {
                            Text("Analyze Ingredients")
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(analyzeIngredientImage == nil || isAnalyzing ? Color.gray : Color.orange)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .disabled(analyzeIngredientImage == nil || isAnalyzing)
                .padding(.top)
                
                Button(action: {
                    if !parsedIngredients.isEmpty {
                        addAnalyzedIngredientsToRecipe()
                    }
                    isPresented = false
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!parsedIngredients.isEmpty ? Color.orange : Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(parsedIngredients.isEmpty)
                .padding(.top, 8)
                
                Spacer()
            }
            .navigationTitle("Ingredient Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.orange)
                    }
                }
            }
            .onChange(of: imagePickerItem) { _ in
                Task {
                    if let data = try? await imagePickerItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        if let uiImage = UIImage(data: data) {
                            analyzeIngredientImage = uiImage
                            parsedIngredients = []
                        }
                    }
                }
            }
            .alert("Analysis Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func analyzeImageWithGPT4o() {
        guard let imageData = selectedImageData, let _ = analyzeIngredientImage else { return }
        
        isAnalyzing = true
        parsedIngredients = []
        
        // Convert image data to base64
        let base64Image = imageData.base64EncodedString()
        
        // Prepare prompt for GPT-4o with strict instructions
        let prompt = """
        Analyze this food image and list ONLY the ingredients with quantities.
        
        FORMAT:
        1. [Ingredient Name]: [Quantity]
        2. [Ingredient Name]: [Quantity]
        
        RULES:
        - List ONLY ingredients visible in the image
        - DO NOT include explanatory text before or after the list
        - DO NOT ask questions or add suggestions
        - DO NOT include emoji or decorative elements
        - DO NOT offer meal ideas or recipes
        - Return NOTHING except the numbered list of ingredients with quantities
        
        If you can't identify ingredients clearly, just list the ones you can see with your best guess of quantities.
        """
        
        // Send to GPT-4o for analysis
        Task {
            do {
                let response = try await chatService.sendMessageWithImage(prompt, base64Image: base64Image, provider: .mixrai)
                
                // Parse the response into individual ingredient items
                await MainActor.run {
                    analyzedText = response
                    parsedIngredients = parseIngredientsFromResponse(response)
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error analyzing image: \(error.localizedDescription)"
                    showErrorAlert = true
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func parseIngredientsFromResponse(_ response: String) -> [String] {
        var ingredients: [String] = []
        
        // Split the response by new lines
        let lines = response.components(separatedBy: .newlines)
        
        // Process each line
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmedLine.isEmpty {
                continue
            }
            
            // Skip lines that are likely not ingredients (questions, explanations, etc.)
            if trimmedLine.contains("?") ||
               trimmedLine.contains("!") ||
               trimmedLine.hasSuffix(".") ||
               trimmedLine.contains("would") ||
               trimmedLine.contains("could") ||
               trimmedLine.contains("should") ||
               trimmedLine.contains("please") ||
               trimmedLine.contains("thank") ||
               trimmedLine.contains("hope") ||
               trimmedLine.contains("sorry") ||
               trimmedLine.contains("unable") ||
               trimmedLine.contains("can't") ||
               trimmedLine.contains("cannot") ||
               trimmedLine.contains("difficult") {
                continue
            }
            
            // Process numbered list format
            if let _ = trimmedLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                if let range = trimmedLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                    let ingredient = trimmedLine[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !ingredient.isEmpty {
                        ingredients.append(ingredient)
                    }
                }
            } 
            // Process dash list format
            else if trimmedLine.hasPrefix("- ") {
                let ingredient = trimmedLine.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                if !ingredient.isEmpty {
                    ingredients.append(ingredient)
                }
            }
            // Include other valid lines that might contain ingredient information
            else if trimmedLine.rangeOfCharacter(from: .letters) != nil {
                // Additional check: only include if it looks like an ingredient
                // (doesn't start with common words used in explanations)
                let lowerLine = trimmedLine.lowercased()
                if !lowerLine.hasPrefix("here") &&
                   !lowerLine.hasPrefix("this") &&
                   !lowerLine.hasPrefix("these") &&
                   !lowerLine.hasPrefix("the") &&
                   !lowerLine.hasPrefix("i") &&
                   !lowerLine.hasPrefix("there") &&
                   !lowerLine.hasPrefix("from") {
                    ingredients.append(trimmedLine)
                }
            }
        }
        
        return ingredients
    }
    
    private func addAnalyzedIngredientsToRecipe() {
        // Add each ingredient from parsedIngredients to the recipe
        for ingredientText in parsedIngredients {
            let trimmedText = ingredientText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip if the ingredient text is empty
            if trimmedText.isEmpty {
                continue
            }
            
            // Handle both formats: with colon (Tomato: 2 medium) and without (Tomato 2 medium)
            if trimmedText.contains(":") {
                let parts = trimmedText.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let ingredientName = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let quantity = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Add to ingredients list only if name is not empty
                    if !ingredientName.isEmpty {
                        ingredients.append(AddRecipeView.Ingredient(name: ingredientName, value: quantity))
                    }
                } else {
                    // For cases where there is a colon but the split doesn't result in two parts
                    ingredients.append(AddRecipeView.Ingredient(name: trimmedText, value: ""))
                }
            } else {
                // For ingredients without a colon, try to intelligently separate name and quantity
                let words = trimmedText.components(separatedBy: .whitespaces)
                
                // Look for quantity patterns like numbers or measurements
                if words.count > 1 && (words[0].rangeOfCharacter(from: .decimalDigits) != nil || 
                                       ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                                        "half", "quarter", "small", "medium", "large"].contains(words[0].lowercased())) {
                    // First word is likely a quantity, try to separate it from the name
                    var quantityEndIndex = 1
                    
                    // Check if the second word is a unit of measure or size
                    if words.count > 2 && ["cup", "cups", "tablespoon", "tablespoons", "teaspoon", "teaspoons", 
                                          "ounce", "ounces", "gram", "grams", "pound", "pounds", 
                                          "small", "medium", "large", "whole", "slice", "slices", "piece", "pieces"].contains(words[1].lowercased()) {
                        quantityEndIndex = 2
                        
                        // Handle cases like "2 large red onions" where there's a size and then the ingredient
                        if words.count > 3 && ["red", "green", "yellow", "white", "black", "purple", "dark", "light"].contains(words[2].lowercased()) {
                            quantityEndIndex = 3
                        }
                    }
                    
                    let quantity = words[..<quantityEndIndex].joined(separator: " ")
                    let name = words[quantityEndIndex...].joined(separator: " ")
                    
                    if !name.isEmpty {
                        ingredients.append(AddRecipeView.Ingredient(name: name, value: quantity))
                    }
                } else if words.count > 0 {
                    // If we can't reliably identify the quantity but have valid text, add it as name only
                    ingredients.append(AddRecipeView.Ingredient(name: trimmedText, value: ""))
                }
            }
        }
        
        // Remove any empty ingredients that might have been in the original list
        ingredients = ingredients.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
} 
