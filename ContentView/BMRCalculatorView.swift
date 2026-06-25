import SwiftUI
import FirebaseFirestore

struct BMRCalculatorView: View {
    let userUID: String
    
    @State private var gender: String = "Male"
    @State private var age: String = ""
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var activityLevel: String = "Sedentary - Desk job, minimal exercise"
    @State private var goal: String = "Maintain"
    
    @State private var bmr: Double = 0
    @State private var tdee: Double = 0
    @State private var targetCalories: Double = 0
    @State private var targetCarbs: Int = 0
    @State private var targetProtein: Int = 0
    @State private var targetFat: Int = 0
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showResult = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var hasExistingData = false
    @State private var showOverwriteAlert = false
    @State private var showInitialAlert = false
    
    // Custom macro distribution
    @State private var showCustomMacros: Bool = false
    @State private var carbsPercentage: Double = 40
    @State private var proteinPercentage: Double = 30
    @State private var fatPercentage: Double = 30
    
    let activityLevels = [
        "Sedentary - Desk job, minimal exercise", 
        "Lightly Active - 1-3 days/week", 
        "Moderately Active - 3-5 days/week", 
        "Very Active - 6-7 days/week, 10+ km", 
        "Extra Active - Intense daily exercise",
        "Athlete - Competitive training, 2x daily"
    ]
    let goals = ["Lose Weight", "Maintain", "Gain Weight"]
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Calculate Your Daily Nutrition Needs")
                    .font(.title2).bold()
                    .padding(.bottom, 10)

                personalInfoSection
                activityGoalsSection
                customMacrosSection
                calculateButton

                if showResult {
                    resultsSection
                }
            }
            .padding()
        }
        .navigationTitle("Nutrition Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.orange)
                }
            }
        }
        .alert("Notice", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Existing Nutrition Data", isPresented: $showInitialAlert) {
            Button("Cancel", role: .cancel) {
                // Return to profile page
                dismiss()
            }
            Button("Continue", role: .none) {
                // Continue with the calculator without immediate changes
            }
        } message: {
            Text("You already have nutrition data. Do you want to recalculate your nutrition needs?")
        }
        .alert("Overwrite Existing Data", isPresented: $showOverwriteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Proceed", role: .destructive) {
                saveTargets()
            }
        } message: {
            Text("You already have nutrition data. If you proceed, your existing data will be overwritten.")
        }
        .onAppear {
            checkExistingData()
        }
    }

    // MARK: - UI Sections (Computed Properties)
    
    private var personalInfoSection: some View {
        GroupBox("Personal Information") {
            VStack(spacing: 15) {
                // Gender selection
                VStack(alignment: .leading) {
                    Text("Gender")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                InputTextField(title: "Age", placeholder: "Enter your age", text: $age, keyboardType: .numberPad, systemImageName: "calendar")
                InputTextField(title: "Weight (kg)", placeholder: "Enter your weight", text: $weight, keyboardType: .decimalPad, systemImageName: "scalemass")
                InputTextField(title: "Height (cm)", placeholder: "Enter your height", text: $height, keyboardType: .decimalPad, systemImageName: "ruler")
            }
            .padding(.vertical, 5)
        }
        .groupBoxStyle(OrangeBorderGroupBoxStyle())
    }
    
    private var activityGoalsSection: some View {
        GroupBox("Activity & Goals") {
            VStack(spacing: 15) {
                // Activity level selection
                VStack(alignment: .leading) {
                    Text("Activity Level")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(activityLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10))
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .accentColor(.orange)
                
                // Goal selection
                VStack(alignment: .leading) {
                    Text("Goal")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    
                    Picker("Goal", selection: $goal) {
                        ForEach(goals, id: \.self) { goal in
                            Text(goal).tag(goal)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding(.vertical, 5)
        }
        .groupBoxStyle(OrangeBorderGroupBoxStyle())
    }
    
    private var customMacrosSection: some View {
        GroupBox("Macronutrient Distribution (Optional)") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Customize Macros", isOn: $showCustomMacros.animation())
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                if showCustomMacros {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Adjust your macronutrient distribution (%)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.bottom, 5)
                        
                        MacroSlider(label: "Carbs", percentage: $carbsPercentage, range: 20...60) {
                            balanceMacros(changedMacro: "carbs")
                        }
                        MacroSlider(label: "Protein", percentage: $proteinPercentage, range: 10...50) {
                            balanceMacros(changedMacro: "protein")
                        }
                        MacroSlider(label: "Fat", percentage: $fatPercentage, range: 10...50) {
                            balanceMacros(changedMacro: "fat")
                        }
                        
                        HStack {
                            Text("Total:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(carbsPercentage + proteinPercentage + fatPercentage))%")
                                .font(.subheadline.bold())
                                .foregroundColor(isMacrosSumValid ? .orange : .red)
                        }
                        .padding(.top, 5)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.vertical, 5)
        }
        .groupBoxStyle(OrangeBorderGroupBoxStyle())
    }
    
    private var calculateButton: some View {
        Button(action: {
            if validateInputs() && (!showCustomMacros || isMacrosSumValid) {
                calculateBMR()
                calculateTDEE()
                calculateTargets()
                withAnimation {
                   showResult = true
                }
            } else if showCustomMacros && !isMacrosSumValid {
                alertMessage = "Macronutrient percentages must total 100%"
                showAlert = true
            }
        }) {
            Text("Calculate")
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.orange]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(10)
                .shadow(color: Color.orange.opacity(0.3), radius: 5, y: 3)
        }
        .padding(.top)
    }
    
    private var resultsSection: some View {
        GroupBox("Your Results") {
             VStack(alignment: .leading, spacing: 12) {
                 ResultRow(label: "BMR:", value: "\(Int(bmr)) calories/day")
                 ResultRow(label: "TDEE:", value: "\(Int(tdee)) calories/day")
                 ResultRow(label: "Target Calories:", value: "\(Int(targetCalories)) calories/day") // Removed isHighlighted as it's handled in ResultRow now
                 
                 Divider().padding(.vertical, 5)
                 
                 ResultRow(label: "Target Carbs:", value: "\(targetCarbs) g")
                 ResultRow(label: "Target Protein:", value: "\(targetProtein) g")
                 ResultRow(label: "Target Fat:", value: "\(targetFat) g")
                 
                 // Save Targets Button inside results
                 Button(action: {
                     if hasExistingData {
                         showOverwriteAlert = true
                     } else {
                         saveTargets()
                     }
                 }) {
                     Text("Save Targets")
                         .fontWeight(.semibold)
                         .foregroundColor(.white)
                         .frame(maxWidth: .infinity)
                         .padding()
                         .background(LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.orange]), startPoint: .leading, endPoint: .trailing))
                         .cornerRadius(10)
                         .shadow(color: Color.orange.opacity(0.3), radius: 5, y: 3)
                 }
                 .padding(.top)
             }
             .padding(.vertical, 5)
         }
         .groupBoxStyle(OrangeBorderGroupBoxStyle())
         .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Helper Functions
    
    // Computed property to check if macros sum to 100%
    private var isMacrosSumValid: Bool {
        let sum = carbsPercentage + proteinPercentage + fatPercentage
        return sum == 100
    }
    
    // Function to balance macros when one changes
    private func balanceMacros(changedMacro: String) {
        let total = carbsPercentage + proteinPercentage + fatPercentage
        
        if total != 100 {
            // Determine which macros to adjust (the ones that weren't changed)
            switch changedMacro {
            case "carbs":
                // Adjust protein and fat
                let excess = total - 100
                let adjustment = excess / 2
                
                proteinPercentage = max(10, min(50, proteinPercentage - adjustment))
                fatPercentage = 100 - carbsPercentage - proteinPercentage
                
                // Ensure fat is within bounds
                if fatPercentage < 10 {
                    fatPercentage = 10
                    proteinPercentage = 100 - carbsPercentage - fatPercentage
                } else if fatPercentage > 50 {
                    fatPercentage = 50
                    proteinPercentage = 100 - carbsPercentage - fatPercentage
                }
                
            case "protein":
                // Adjust carbs and fat
                let excess = total - 100
                let adjustment = excess / 2
                
                carbsPercentage = max(20, min(60, carbsPercentage - adjustment))
                fatPercentage = 100 - carbsPercentage - proteinPercentage
                
                // Ensure fat is within bounds
                if fatPercentage < 10 {
                    fatPercentage = 10
                    carbsPercentage = 100 - proteinPercentage - fatPercentage
                } else if fatPercentage > 50 {
                    fatPercentage = 50
                    carbsPercentage = 100 - proteinPercentage - fatPercentage
                }
                
            case "fat":
                // Adjust carbs and protein
                let excess = total - 100
                let adjustment = excess / 2
                
                carbsPercentage = max(20, min(60, carbsPercentage - adjustment))
                proteinPercentage = 100 - carbsPercentage - fatPercentage
                
                // Ensure protein is within bounds
                if proteinPercentage < 10 {
                    proteinPercentage = 10
                    carbsPercentage = 100 - proteinPercentage - fatPercentage
                } else if proteinPercentage > 50 {
                    proteinPercentage = 50
                    carbsPercentage = 100 - proteinPercentage - fatPercentage
                }
                
            default:
                break
            }
        }
    }
    
    private func checkExistingData() {
        let db = Firestore.firestore()
        db.collection("User")
            .document(userUID)
            .collection("target")
            .document("current")
            .getDocument { document, error in
                if let document = document, document.exists {
                    if let data = document.data(),
                       let ingestion = data["Ingestion"] as? Double,
                       ingestion > 0 {
                        hasExistingData = true
                        
                        // Show the initial alert when entering the view
                        showInitialAlert = true
                    }
                }
            }
    }
    
    private func validateInputs() -> Bool {
        guard let ageValue = Int(age), ageValue > 0, ageValue < 120 else {
            alertMessage = "Please enter a valid age (1-120)"
            showAlert = true
            return false
        }
        
        guard let weightValue = Double(weight), weightValue > 0, weightValue < 500 else {
            alertMessage = "Please enter a valid weight"
            showAlert = true
            return false
        }
        
        guard let heightValue = Double(height), heightValue > 0, heightValue < 300 else {
            alertMessage = "Please enter a valid height"
            showAlert = true
            return false
        }
        
        return true
    }
    
    private func calculateBMR() {
        let ageValue = Double(age) ?? 0
        let weightValue = Double(weight) ?? 0
        let heightValue = Double(height) ?? 0
        
        if gender == "Male" {
            bmr = 10 * weightValue + 6.25 * heightValue - 5 * ageValue + 5
        } else {
            bmr = 10 * weightValue + 6.25 * heightValue - 5 * ageValue - 161
        }
    }
    
    private func calculateTDEE() {
        let activityMultiplier: Double
        
        switch activityLevel {
        case "Sedentary - Desk job, minimal exercise":
            activityMultiplier = 1.2
        case "Lightly Active - 1-3 days/week":
            activityMultiplier = 1.375
        case "Moderately Active - 3-5 days/week":
            activityMultiplier = 1.55
        case "Very Active - 6-7 days/week, 10+ km":
            activityMultiplier = 1.725
        case "Extra Active - Intense daily exercise":
            activityMultiplier = 1.9
        case "Athlete - Competitive training, 2x daily":
            activityMultiplier = 2.1
        default:
            activityMultiplier = 1.2
        }
        
        tdee = bmr * activityMultiplier
    }
    
    private func calculateTargets() {
        switch goal {
        case "Lose Weight":
            targetCalories = tdee * 0.8
        case "Gain Weight":
            targetCalories = tdee * 1.15
        default:
            targetCalories = tdee
        }
        
        if showCustomMacros {
            // Use custom macronutrient distribution
            targetCarbs = Int((targetCalories * (carbsPercentage / 100)) / 4) // 4 calories per gram of carbs
            targetProtein = Int((targetCalories * (proteinPercentage / 100)) / 4) // 4 calories per gram of protein
            targetFat = Int((targetCalories * (fatPercentage / 100)) / 9) // 9 calories per gram of fat
        } else {
            // Default macronutrient distribution
            targetCarbs = Int((targetCalories * 0.4) / 4) // 40% carbs, 4 calories per gram
            
            // Calculate protein based on body weight
            let weightValue = Double(weight) ?? 0
            let isAthlete = activityLevel == "Athlete - Competitive training, 2x daily"
            let proteinMultiplier = isAthlete ? 2.0 : 1.5 // 1.5g per kg for normal, 2.0g for athletes
            let proteinByWeight = weightValue * proteinMultiplier
            
            // Calculate how many calories that would be (4 calories per gram of protein)
            let proteinCalories = proteinByWeight * 4
            
            // Check if protein would exceed 35% of total calories
            let maxProteinCalories = targetCalories * 0.35
            let finalProteinCalories = min(proteinCalories, maxProteinCalories)
            
            targetProtein = Int(proteinByWeight)
            
            // Adjust carbs and fat based on remaining calories
            let remainingCalories = targetCalories - finalProteinCalories
            targetCarbs = Int((remainingCalories * 0.6) / 4) // 60% of remaining calories to carbs
            targetFat = Int((remainingCalories * 0.4) / 9) // 40% of remaining calories to fat
        }
    }
    
    private func saveTargets() {
        let db = Firestore.firestore()
        
   
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDate = dateFormatter.string(from: Date())
        
        let targetData: [String: Any] = [
            "Ingestion": targetCalories,
            "Ingested": 0.0,
            "Carbs": targetCarbs,
            "CarbsIngested": 0,
            "Protein": targetProtein,
            "ProteinIngested": 0,
            "Fat": targetFat,
            "FatIngested": 0,
            "CarbsExceededCount": 0,
            "FatExceededCount": 0,
            "ProteinExceededCount": 0,
            "TotalIngestedExceededCount": 0,
            "month": currentDate
        ]
        
        db.collection("User")
            .document(userUID)
            .collection("target")
            .document("current")
            .setData(targetData) { error in
                if let error = error {
                    alertMessage = "Error saving targets: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    alertMessage = "Nutrition targets saved successfully!"
                    showAlert = true
                    
                    // Dismiss the view after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
    }
}

// Custom GroupBox Style for Orange Border
struct OrangeBorderGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
                .font(.headline)
                .padding(.bottom, 5)
            configuration.content
        }
        .padding()
        .background(.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, lineWidth: 1)
        )
    }
}

// Helper View for Input Text Fields
struct InputTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let systemImageName: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.gray)
            HStack {
                Image(systemName: systemImageName)
                    .foregroundColor(.gray)
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
            .padding(EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10))
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .overlay( // Add a visible border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1) // Slightly visible grey border
            )
        }
    }
}

// Helper View for Macro Sliders
struct MacroSlider: View {
    let label: String
    @Binding var percentage: Double
    let range: ClosedRange<Double>
    var onEditingChanged: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(label):")
                    .font(.caption)
                    .frame(width: 60, alignment: .leading)
                Slider(value: $percentage, in: range, step: 5, onEditingChanged: { _ in onEditingChanged() })
                    .accentColor(.orange)
                Text("\(Int(percentage))%")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

// Helper View for Result Rows
struct ResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.bold) // Always bold
                .foregroundColor(.orange) // Always orange
        }
        .font(.subheadline)
    }
}

struct BMRCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BMRCalculatorView(userUID: "testUID")
        }
    }
}
