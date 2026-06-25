import SwiftUI
import FirebaseFirestore

class NutritionManager: ObservableObject {
    static let shared = NutritionManager()
    
    @Published var calories: Int = 0
    @Published var targetCalories: Int = 1308
    @Published var protein: Int = 0
    @Published var targetProtein: Int = 98
    @Published var carbs: Int = 0
    @Published var targetCarbs: Int = 147
    @Published var fat: Int = 0
    @Published var targetFat: Int = 36
    
    private init() {}
    
    func fetchNutritionData(userUID: String) {
        let db = Firestore.firestore()
        db.collection("User").document(userUID)
            .collection("Nutrition")
            .document("daily")
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                if let data = snapshot?.data() {
                    DispatchQueue.main.async {
                        self.calories = data["calories"] as? Int ?? 0
                        self.protein = data["protein"] as? Int ?? 0
                        self.carbs = data["carbs"] as? Int ?? 0
                        self.fat = data["fat"] as? Int ?? 0
                    }
                }
            }
    }
} 