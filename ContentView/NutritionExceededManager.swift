import SwiftUI
import FirebaseFirestore

class NutritionExceededManager: ObservableObject {
    static let shared = NutritionExceededManager()
    
    private init() {}
    
    // 檢查營養素是否超標並更新計數器
    func checkAndUpdateExceededCounts(userUID: String) {
        let db = Firestore.firestore()
        
        // 獲取當前日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        let currentMonth = dateFormatter.string(from: Date())
        
        // 獲取用戶的營養目標和攝入數據
        db.collection("User")
            .document(userUID)
            .collection("target")
            .document("current")
            .getDocument { [weak self] document, error in
                guard let self = self, let document = document, document.exists,
                      let data = document.data() else {
                    print("Error fetching nutrition data: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // 檢查是否需要重置計數器（月份變更）
                let storedMonth = data["month"] as? String ?? ""
                let shouldResetCounters = !storedMonth.isEmpty && storedMonth != currentMonth
                
                // 獲取目標值和已攝入值
                let targetCalories = data["Ingestion"] as? Double ?? 0
                let ingestedCalories = data["Ingested"] as? Double ?? 0
                let targetCarbs = data["Carbs"] as? Int ?? 0
                let ingestedCarbs = data["CarbsIngested"] as? Int ?? 0
                let targetProtein = data["Protein"] as? Int ?? 0
                let ingestedProtein = data["ProteinIngested"] as? Int ?? 0
                let targetFat = data["Fat"] as? Int ?? 0
                let ingestedFat = data["FatIngested"] as? Int ?? 0
                
                // 獲取當前計數器值
                var carbsExceededCount = data["CarbsExceededCount"] as? Int ?? 0
                var fatExceededCount = data["FatExceededCount"] as? Int ?? 0
                var proteinExceededCount = data["ProteinExceededCount"] as? Int ?? 0
                var totalIngestedExceededCount = data["TotalIngestedExceededCount"] as? Int ?? 0
                
                // 如果月份變更，重置計數器
                if shouldResetCounters {
                    carbsExceededCount = 0
                    fatExceededCount = 0
                    proteinExceededCount = 0
                    totalIngestedExceededCount = 0
                }
                
                // 檢查是否超標並更新計數器
                var updateData: [String: Any] = [:]
                var hasChanges = false
                
                // 檢查卡路里是否超標
                if ingestedCalories > targetCalories && totalIngestedExceededCount == 0 {
                    totalIngestedExceededCount += 1
                    updateData["TotalIngestedExceededCount"] = totalIngestedExceededCount
                    hasChanges = true
                }
                
                // 檢查碳水化合物是否超標
                if ingestedCarbs > targetCarbs && carbsExceededCount == 0 {
                    carbsExceededCount += 1
                    updateData["CarbsExceededCount"] = carbsExceededCount
                    hasChanges = true
                }
                
                // 檢查蛋白質是否超標
                if ingestedProtein > targetProtein && proteinExceededCount == 0 {
                    proteinExceededCount += 1
                    updateData["ProteinExceededCount"] = proteinExceededCount
                    hasChanges = true
                }
                
                // 檢查脂肪是否超標
                if ingestedFat > targetFat && fatExceededCount == 0 {
                    fatExceededCount += 1
                    updateData["FatExceededCount"] = fatExceededCount
                    hasChanges = true
                }
                
                // 如果月份變更或計數器有更新，則更新數據庫
                if shouldResetCounters || hasChanges {
                    // 更新月份
                    updateData["month"] = currentMonth
                    
                    // 更新數據庫
                    db.collection("User")
                        .document(userUID)
                        .collection("target")
                        .document("current")
                        .updateData(updateData) { error in
                            if let error = error {
                                print("Error updating exceeded counts: \(error.localizedDescription)")
                            } else {
                                print("Successfully updated exceeded counts")
                            }
                        }
                }
            }
    }
} 