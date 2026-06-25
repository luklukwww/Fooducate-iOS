import SwiftUI
import FirebaseFirestore

struct RecipeFamiliaritySelectionView: View {
    @Binding var recipeKnowledge: Bool
    @Binding var useDefaultFlavor: Bool
    @State private var localUseDefaultFlavor: Bool
    @State private var isGenerating = false
    @State private var userFlavorPreference: String = ""
    // New state properties for Guess You Like feature
    @State private var guessedFlavor: String = ""
    @State private var hasFlavorTrend: Bool = false
    @State private var useGuessedFlavor: Bool = false
    // New state properties for custom flavor
    @State private var customFlavor: String = ""
    @State private var showFlavorSelectionSheet = false
    @State private var isCustomFlavor = false
    
    let onSelection: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userUID") private var userUID: String = ""
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    
    // New properties for enhanced functionality
    var originalRecipeSteps: [String] = []
    var onCompletion: (([String]) -> Void)?
    @Binding var isShowing: Bool
    
    // Original initializer for backward compatibility
    init(recipeKnowledge: Binding<Bool>, useDefaultFlavor: Binding<Bool>, onSelection: @escaping () -> Void) {
        self._recipeKnowledge = recipeKnowledge
        self._useDefaultFlavor = useDefaultFlavor
        self._localUseDefaultFlavor = State(initialValue: useDefaultFlavor.wrappedValue)
        self.onSelection = onSelection
        self._isShowing = .constant(false) // Dummy binding for backward compatibility
    }
    
    // New initializer with support for originalRecipeSteps and onCompletion, default recipeKnowledge
    init(originalRecipeSteps: [String], useDefaultFlavor: Binding<Bool>, isShowing: Binding<Bool>, onCompletion: @escaping ([String]) -> Void) {
        self._recipeKnowledge = .constant(true) // Default to true if not provided
        self._useDefaultFlavor = useDefaultFlavor
        self._localUseDefaultFlavor = State(initialValue: useDefaultFlavor.wrappedValue)
        self.onSelection = {} // Empty onSelection as we're using onCompletion instead
        self.originalRecipeSteps = originalRecipeSteps
        self.onCompletion = onCompletion
        self._isShowing = isShowing
    }
    
    // Most complete initializer with all parameters
    init(recipeKnowledge: Binding<Bool>, originalRecipeSteps: [String], useDefaultFlavor: Binding<Bool>, isShowing: Binding<Bool>, onCompletion: @escaping ([String]) -> Void) {
        self._recipeKnowledge = recipeKnowledge
        self._useDefaultFlavor = useDefaultFlavor
        self._localUseDefaultFlavor = State(initialValue: useDefaultFlavor.wrappedValue)
        self.onSelection = {} // Empty onSelection as we're using onCompletion instead
        self.originalRecipeSteps = originalRecipeSteps
        self.onCompletion = onCompletion
        self._isShowing = isShowing
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.orange)
                            .font(.system(size: 20, weight: .medium))
                    }
                    
                    Spacer()
                    
                    Text("Recipe Customization")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    // Empty view for balance
                    Image(systemName: "xmark")
                        .foregroundColor(.clear)
                        .font(.system(size: 20, weight: .medium))
                }
                .padding()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        Text("How familiar are you with this recipe?")
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                        
                        VStack(spacing: 16) {
                            // Familiar option
                            Button(action: {
                                recipeKnowledge = true
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "person.fill.checkmark")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                        .frame(width: 64, height: 64)
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Familiar")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("I've made this recipe before or similar recipes. I'm comfortable with the cooking techniques.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(recipeKnowledge ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(recipeKnowledge ? Color.orange : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Unfamiliar option
                            Button(action: {
                                recipeKnowledge = false
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "person.fill.questionmark")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                        .frame(width: 64, height: 64)
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Unfamiliar")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("I haven't made this recipe before. I'd like detailed instructions and more guidance.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(!recipeKnowledge ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(!recipeKnowledge ? Color.orange : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.vertical)
                        
                        Text("Flavor Preference")
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                        
                        VStack(spacing: 16) {
                            // Default Flavor option
                            Button(action: {
                                print("Default Flavor tapped, current localUseDefaultFlavor: \(localUseDefaultFlavor)")
                                withAnimation {
                                    localUseDefaultFlavor = true
                                    useDefaultFlavor = true
                                    useGuessedFlavor = false
                                    isCustomFlavor = false
                                }
                                print("After tap, localUseDefaultFlavor: \(localUseDefaultFlavor), binding: \(useDefaultFlavor)")
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                        .frame(width: 64, height: 64)
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Default Flavor")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Follow the original recipe with standard flavoring.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(localUseDefaultFlavor ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(localUseDefaultFlavor ? Color.orange : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Personalized Flavor option
                            Button(action: {
                                print("Personalized Flavor tapped, current localUseDefaultFlavor: \(localUseDefaultFlavor)")
                                withAnimation {
                                    localUseDefaultFlavor = false
                                    useDefaultFlavor = false
                                    useGuessedFlavor = false
                                    isCustomFlavor = false
                                }
                                print("After tap, localUseDefaultFlavor: \(localUseDefaultFlavor), binding: \(useDefaultFlavor)")
                                
                                if isLoggedIn && userFlavorPreference.isEmpty {
                                    fetchFlavorPreference()
                                }
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                        .frame(width: 64, height: 64)
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Personalized Flavor")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        if userFlavorPreference.isEmpty {
                                            Text("Adapt the recipe to your personal flavor preferences.")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        } else {
                                            Text("Adapt the recipe for \(userFlavorPreference) flavors.")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(!localUseDefaultFlavor && !useGuessedFlavor && !isCustomFlavor ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(!localUseDefaultFlavor && !useGuessedFlavor && !isCustomFlavor ? Color.orange : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!isLoggedIn)
                            .opacity(isLoggedIn ? 1.0 : 0.5)
                            .overlay(
                                Group {
                                    if !isLoggedIn {
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
                            
                            // New: Guess You Like option
                            if hasFlavorTrend && !guessedFlavor.isEmpty && isLoggedIn {
                                Button(action: {
                                    print("Guess You Like tapped with flavor: \(guessedFlavor)")
                                    withAnimation {
                                        localUseDefaultFlavor = false
                                        useDefaultFlavor = false
                                        useGuessedFlavor = true
                                        isCustomFlavor = false
                                    }
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(.white)
                                            .frame(width: 64, height: 64)
                                            .background(Color.orange)
                                            .cornerRadius(12)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Guess You Like")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("Try \(guessedFlavor) flavor based on your food preferences.")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(useGuessedFlavor ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(useGuessedFlavor ? Color.orange : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // New: Custom Flavor option
                            if isCustomFlavor && !customFlavor.isEmpty {
                                Button(action: {
                                    showFlavorSelectionSheet = true
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 36))
                                            .foregroundColor(.white)
                                            .frame(width: 64, height: 64)
                                            .background(Color.orange)
                                            .cornerRadius(12)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Custom Flavor")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("Selected: \(customFlavor)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(isCustomFlavor ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(isCustomFlavor ? Color.orange : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // New: More Options button
                            Button(action: {
                                showFlavorSelectionSheet = true
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                        .frame(width: 64, height: 64)
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("More Options")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Choose from predefined flavors or create your own.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            isGenerating = true
                            // Add loading animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if let completion = onCompletion {
                                    // If we have a completion handler, use it with processed steps
                                    if recipeKnowledge {
                                        // For familiar scenario, just pass the original steps
                                        completion(originalRecipeSteps)
                                    } else {
                                        // For unfamiliar, ideally we'd process the steps to be more detailed
                                        // Since we can't directly call the LikesView's processing method,
                                        // we'll add some simple processing as a placeholder
                                        var detailedSteps: [String] = []
                                        for step in originalRecipeSteps {
                                            // Just a simple example of how we might break down steps
                                            // In a real implementation, this would use AI or a more sophisticated algorithm
                                            detailedSteps.append(step)
                                            if step.contains("heat") || step.contains("preheat") {
                                                detailedSteps.append("Make sure the temperature is set correctly.")
                                            }
                                            if step.contains("mix") || step.contains("stir") {
                                                detailedSteps.append("Continue mixing until ingredients are well combined.")
                                            }
                                        }
                                        completion(detailedSteps.isEmpty ? originalRecipeSteps : detailedSteps)
                                    }
                                    isShowing = false
                                } else {
                                    // Use the original onSelection for backward compatibility
                                    
                                    // New: Log the flavor provided to the AI
                                    if isCustomFlavor && !customFlavor.isEmpty {
                                        print("Processing recipe with custom flavor: \(customFlavor)")
                                    } else if useGuessedFlavor && !guessedFlavor.isEmpty {
                                        print("Processing recipe with guessed flavor: \(guessedFlavor)")
                                    } else if !localUseDefaultFlavor && !userFlavorPreference.isEmpty {
                                        print("Processing recipe with user's preferred flavor: \(userFlavorPreference)")
                                    } else {
                                        print("Processing recipe with default flavor")
                                    }
                                    
                                    onSelection()
                                }
                                isGenerating = false
                            }
                        }) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 8)
                                    Text("Generating Recipe...")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                } else {
                                    Text("Generate Recipe")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isGenerating ? Color.orange.opacity(0.7) : Color.orange)
                            .cornerRadius(16)
                            .overlay(
                                Group {
                                    if isGenerating {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.white.opacity(0.9))
                                                .frame(width: 8, height: 8)
                                                .scaleEffect(isGenerating ? 1.0 : 0.5)
                                                .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.0), value: isGenerating)
                                            
                                            Circle()
                                                .fill(Color.white.opacity(0.9))
                                                .frame(width: 8, height: 8)
                                                .scaleEffect(isGenerating ? 1.0 : 0.5)
                                                .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: isGenerating)
                                            
                                            Circle()
                                                .fill(Color.white.opacity(0.9))
                                                .frame(width: 8, height: 8)
                                                .scaleEffect(isGenerating ? 1.0 : 0.5)
                                                .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4), value: isGenerating)
                                        }
                                        .padding(.top, 6)
                                    }
                                }, alignment: .bottom
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .disabled(isGenerating)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            print("RecipeFamiliaritySelectionView appeared, useDefaultFlavor binding: \(useDefaultFlavor), local: \(localUseDefaultFlavor)")
            localUseDefaultFlavor = useDefaultFlavor
            if isLoggedIn {
                if !localUseDefaultFlavor {
                    fetchFlavorPreference()
                }
                fetchFlavorTrend() // Always check for flavor trends
            }
        }
        .onChange(of: useDefaultFlavor) { newValue in
            print("Binding useDefaultFlavor changed to: \(newValue), updating local state")
            localUseDefaultFlavor = newValue
        }
        // Add flavor selection sheet
        .sheet(isPresented: $showFlavorSelectionSheet) {
            FlavorSelectionSheet(selectedFlavor: $customFlavor)
                .onDisappear {
                    if !customFlavor.isEmpty {
                        withAnimation {
                            localUseDefaultFlavor = false
                            useDefaultFlavor = false
                            useGuessedFlavor = false
                            isCustomFlavor = true
                        }
                    }
                }
        }
    }
    
    private func fetchFlavorPreference() {
        guard isLoggedIn, !userUID.isEmpty else {
            print("User not logged in or UID missing")
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
                self.userFlavorPreference = flavorPref
                print("Fetched flavor preference: \(flavorPref)")
            } else {
                self.userFlavorPreference = "balanced"
                print("No specific flavor preference found, using default")
            }
        }
    }
    
    // New function to fetch flavor trend data
    private func fetchFlavorTrend() {
        guard isLoggedIn, !userUID.isEmpty else {
            print("User not logged in or UID missing for flavor trend")
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
}

struct RecipeFamiliaritySelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeFamiliaritySelectionView(
            recipeKnowledge: .constant(true),
            useDefaultFlavor: .constant(true),
            onSelection: {}
        )
    }
} 