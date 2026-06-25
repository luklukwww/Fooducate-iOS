import SwiftUI
import FirebaseFirestore

struct NutritionProgressView: View {
    let userUID: String
    @State private var targetData: TargetData?
    @State private var hasSetTarget: Bool = false
    
    var body: some View {
        VStack(spacing: 15) {
            if let data = targetData, hasSetTarget {
                ProgressBox(
                    title: "Calories",
                    current: Int(data.ingested),
                    target: Int(data.ingestion)
                )
                
                HStack(spacing: 10) {
                    ProgressBox(
                        title: "Carbs",
                        current: data.carbsIngested,
                        target: data.carbs,
                        unit: "g"
                    )
                    
                    ProgressBox(
                        title: "Protein",
                        current: data.proteinIngested,
                        target: data.protein,
                        unit: "g"
                    )
                    
                    ProgressBox(
                        title: "Fat",
                        current: data.fatIngested,
                        target: data.fat,
                        unit: "g"
                    )
                }
            } else {
                Text("Set your nutrition goals in Ingestion")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding()
        .onAppear {
            fetchTargetData()
        }
    }
    
    private func fetchTargetData() {
        let db = Firestore.firestore()
        db.collection("User").document(userUID).collection("target").document("current")
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching target data: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                if let data = document.data() {
                    // 检查是否有设置目标值
                    let ingestion = data["Ingestion"] as? Double ?? 0
                    hasSetTarget = ingestion > 0
                    
                    if hasSetTarget {
                        self.targetData = TargetData(
                            ingestion: ingestion,
                            ingested: data["Ingested"] as? Double ?? 0,
                            carbs: data["Carbs"] as? Int ?? 0,
                            carbsIngested: data["CarbsIngested"] as? Int ?? 0,
                            protein: data["Protein"] as? Int ?? 0,
                            proteinIngested: data["ProteinIngested"] as? Int ?? 0,
                            fat: data["Fat"] as? Int ?? 0,
                            fatIngested: data["FatIngested"] as? Int ?? 0,
                            carbsExceededCount: data["CarbsExceededCount"] as? Int ?? 0,
                            fatExceededCount: data["FatExceededCount"] as? Int ?? 0,
                            proteinExceededCount: data["ProteinExceededCount"] as? Int ?? 0,
                            totalIngestedExceededCount: data["TotalIngestedExceededCount"] as? Int ?? 0
                        )
                    }
                } else {
                    hasSetTarget = false
                    targetData = nil
                }
            }
    }
}

struct ProgressBox: View {
    let title: String
    let current: Int
    let target: Int
    var unit: String = "kcal"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text("\(current)/\(target)")
                .font(.system(size: 14, weight: .bold))
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.gray)
            
            ProgressBar(value: Double(current) / Double(target))
                .frame(height: 4)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ProgressBar: View {
    let value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.2))
                
                Rectangle()
                    .foregroundColor(Color.orange)
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width))
            }
            .cornerRadius(2)
        }
    }
} 