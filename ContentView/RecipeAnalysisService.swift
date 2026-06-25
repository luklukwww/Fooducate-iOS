import Foundation
import FirebaseFirestore

class RecipeAnalysisService {
    private let mixraiApiKey = "YOUR_AI_HERE"
    
    // 單例模式
    static let shared = RecipeAnalysisService()
    private init() {}
    
    // 分析食譜並返回口味和類型
    func analyzeRecipe(recipeDetails: String, completion: @escaping (String?, String?, Error?) -> Void) {
        // 先使用主要模型
        analyzeRecipeWithModel(recipeDetails: recipeDetails, model: "mixtral-8x7b-instruct") { flavor, foodType, error in
            if let flavor = flavor, let foodType = foodType {
                // 主要模型成功
                completion(flavor, foodType, nil)
            } else {
                // 主要模型失敗，嘗試備用模型
                print("主要模型失敗，嘗試備用模型...")
                self.analyzeRecipeWithModel(recipeDetails: recipeDetails, model: "gpt-3.5-turbo") { flavor, foodType, error in
                    completion(flavor, foodType, error)
                }
            }
        }
    }
    
    // 使用指定模型分析食譜
    private func analyzeRecipeWithModel(recipeDetails: String, model: String, completion: @escaping (String?, String?, Error?) -> Void) {
        // 準備API請求
        let url = URL(string: "https://api.mixrai.com/llm/v1/llm/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(mixraiApiKey)", forHTTPHeaderField: "Authorization")
        
        // 構建提示詞
        let prompt = """
        Based on the recipe details below, determine:
        1. The primary flavor profile (must be exactly one of: Spicy, Sweet, Sour, Savory, Bitter)
        2. The cuisine type (must be exactly one of: Chinese, Italian, Japanese, Mexican, American, Middle Eastern, Indian, Other)
        
        Reply ONLY with two lines:
        Flavor: [one flavor]
        Type: [one cuisine type]
        
        Recipe details:
        \(recipeDetails)
        """
        
        // 請求體
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.2
        ]
        
        // 序列化請求體
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("請求體序列化錯誤: \(error.localizedDescription)")
            completion(nil, nil, error)
            return
        }
        
        // 新增 - 輸出請求詳情用於調試
        print("發送API請求到: \(url.absoluteString)")
        print("API請求標頭: \(request.allHTTPHeaderFields ?? [:])")
        print("使用模型: \(model)")
        
        // 發送請求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 新增 - 記錄HTTP響應狀態
            if let httpResponse = response as? HTTPURLResponse {
                print("API響應狀態碼: \(httpResponse.statusCode)")
            }
            
            if let error = error {
                print("API請求網絡錯誤: \(error.localizedDescription)")
                completion(nil, nil, error)
                return
            }
            
            guard let data = data else {
                print("API未返回數據")
                completion(nil, nil, NSError(domain: "RecipeAnalysisService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            // 新增 - 輸出原始響應數據
            if let responseString = String(data: data, encoding: .utf8) {
                print("API原始響應: \(responseString)")
            }
            
            // 處理響應
            do {
                // 嘗試解析JSON
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // 新增 - 詳細檢查各個層級的數據
                guard let jsonDict = json else {
                    print("無法將響應解析為JSON字典")
                    completion(nil, nil, NSError(domain: "RecipeAnalysisService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Response is not a valid JSON dictionary"]))
                    return
                }
                
                guard let choices = jsonDict["choices"] as? [[String: Any]] else {
                    print("JSON中沒有'choices'鍵或值不是數組")
                    completion(nil, nil, NSError(domain: "RecipeAnalysisService", code: 5, userInfo: [NSLocalizedDescriptionKey: "No 'choices' key found in response"]))
                    return
                }
                
                guard let firstChoice = choices.first else {
                    print("'choices'數組為空")
                    completion(nil, nil, NSError(domain: "RecipeAnalysisService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Choices array is empty"]))
                    return
                }
                
                guard let message = firstChoice["message"] as? [String: Any] else {
                    print("第一個choice中沒有'message'鍵或值不是字典")
                    completion(nil, nil, NSError(domain: "RecipeAnalysisService", code: 7, userInfo: [NSLocalizedDescriptionKey: "No 'message' key in first choice"]))
                    return
                }
                
                guard let content = message["content"] as? String else {
                    print("message中沒有'content'鍵或值不是字符串")
                    completion(nil, nil, NSError(domain: "RecipeAnalysisService", code: 8, userInfo: [NSLocalizedDescriptionKey: "No 'content' key in message"]))
                    return
                }
                
                print("AI回复內容: \(content)")
                    
                // 解析AI回復
                let lines = content.components(separatedBy: "\n")
                var flavor: String?
                var foodType: String?
                
                for line in lines {
                    if line.starts(with: "Flavor:") {
                        flavor = line.replacingOccurrences(of: "Flavor:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        print("提取的口味: \(flavor ?? "nil")")
                    } else if line.starts(with: "Type:") {
                        foodType = line.replacingOccurrences(of: "Type:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        print("提取的類型: \(foodType ?? "nil")")
                    }
                }
                
                // 驗證結果
                let validFlavors = ["Spicy", "Sweet", "Sour", "Savory", "Bitter"]
                let validTypes = ["Chinese", "Italian", "Japanese", "Mexican", "American", "Middle Eastern", "Indian", "Other"]
                
                if let flavor = flavor, validFlavors.contains(flavor),
                   let foodType = foodType, validTypes.contains(foodType) {
                    print("分析成功 - 口味: \(flavor), 類型: \(foodType)")
                    completion(flavor, foodType, nil)
                } else {
                    print("提取的值無效 - 口味: \(flavor ?? "nil"), 類型: \(foodType ?? "nil")")
                    
                    // 嘗試更寬鬆的匹配
                    var matchedFlavor: String?
                    var matchedType: String?
                    
                    // 嘗試尋找內容中的任何有效口味和類型
                    for validFlavor in validFlavors {
                        if content.contains(validFlavor) {
                            matchedFlavor = validFlavor
                            break
                        }
                    }
                    
                    for validType in validTypes {
                        if content.contains(validType) {
                            matchedType = validType
                            break
                        }
                    }
                    
                    if let matchedFlavor = matchedFlavor, let matchedType = matchedType {
                        print("通過寬鬆匹配成功提取 - 口味: \(matchedFlavor), 類型: \(matchedType)")
                        completion(matchedFlavor, matchedType, nil)
                    } else {
                        completion(nil, nil, NSError(domain: "RecipeAnalysisService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid AI response format"]))
                    }
                }
            } catch {
                print("JSON解析錯誤: \(error.localizedDescription)")
                
                // 嘗試使用更簡單的方法提取數據
                if let responseString = String(data: data, encoding: .utf8) {
                    print("嘗試從文本響應中提取信息...")
                    
                    // 簡單的文本解析嘗試
                    let lines = responseString.components(separatedBy: "\n")
                    var flavor: String?
                    var foodType: String?
                    
                    for line in lines {
                        if line.contains("Flavor:") {
                            let components = line.components(separatedBy: "Flavor:")
                            if components.count > 1 {
                                flavor = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                print("從文本提取的口味: \(flavor ?? "nil")")
                            }
                        } else if line.contains("Type:") {
                            let components = line.components(separatedBy: "Type:")
                            if components.count > 1 {
                                foodType = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                print("從文本提取的類型: \(foodType ?? "nil")")
                            }
                        }
                    }
                    
                    let validFlavors = ["Spicy", "Sweet", "Sour", "Savory", "Bitter"]
                    let validTypes = ["Chinese", "Italian", "Japanese", "Mexican", "American", "Middle Eastern", "Indian", "Other"]
                    
                    if let flavor = flavor, validFlavors.contains(flavor),
                       let foodType = foodType, validTypes.contains(foodType) {
                        print("文本解析成功 - 口味: \(flavor), 類型: \(foodType)")
                        completion(flavor, foodType, nil)
                        return
                    }
                    
                    // 嘗試更寬鬆的匹配
                    var matchedFlavor: String?
                    var matchedType: String?
                    
                    // 嘗試尋找內容中的任何有效口味和類型
                    for validFlavor in validFlavors {
                        if responseString.contains(validFlavor) {
                            matchedFlavor = validFlavor
                            break
                        }
                    }
                    
                    for validType in validTypes {
                        if responseString.contains(validType) {
                            matchedType = validType
                            break
                        }
                    }
                    
                    if let matchedFlavor = matchedFlavor, let matchedType = matchedType {
                        print("通過寬鬆匹配成功提取 - 口味: \(matchedFlavor), 類型: \(matchedType)")
                        completion(matchedFlavor, matchedType, nil)
                        return
                    }
                }
                
                completion(nil, nil, error)
            }
        }.resume()
    }
    
    // 更新用戶的口味趨勢
    func updateFlavorTrend(userUID: String, flavor: String, isLiked: Bool = false) {
        let db = Firestore.firestore()
        let flavorRef = db.collection("User").document(userUID).collection("FlavorTrend").document(flavor)
        
        flavorRef.getDocument { document, error in
            if let document = document, document.exists {
                // 文檔已存在，更新頻率和最後瀏覽時間
                var updates: [String: Any] = [
                    "Frequency": FieldValue.increment(Int64(1)),
                    "LastViewed": Date()
                ]
                
                // 如果按了喜歡按鈕，更新喜歡計數
                if isLiked {
                    updates["like_count"] = FieldValue.increment(Int64(1))
                }
                
                flavorRef.updateData(updates)
                print("已更新用戶 \(userUID) 的口味趨勢: \(flavor)")
            } else {
                // 文檔不存在，創建新記錄
                var data: [String: Any] = [
                    "User.UID": userUID,
                    "inferred_Flavor": flavor,
                    "Frequency": 1,
                    "like_count": isLiked ? 1 : 0,
                    "LastViewed": Date()
                ]
                
                flavorRef.setData(data)
                print("已創建用戶 \(userUID) 的口味趨勢: \(flavor)")
            }
        }
    }
    
    // 更新用戶的食物類型歷史
    func updateFoodTypeHistory(userUID: String, foodType: String, isLiked: Bool = false) {
        let db = Firestore.firestore()
        let foodTypeRef = db.collection("User").document(userUID).collection("FoodTypeHistory").document(foodType)
        
        foodTypeRef.getDocument { document, error in
            if let document = document, document.exists {
                // 文檔已存在，更新頻率和最後瀏覽時間
                var updates: [String: Any] = [
                    "Frequency": FieldValue.increment(Int64(1)),
                    "LastViewed": Date()
                ]
                
                // 如果按了喜歡按鈕，更新喜歡計數
                if isLiked {
                    updates["like_count"] = FieldValue.increment(Int64(1))
                }
                
                foodTypeRef.updateData(updates)
                print("已更新用戶 \(userUID) 的食物類型歷史: \(foodType)")
            } else {
                // 文檔不存在，創建新記錄
                var data: [String: Any] = [
                    "User.UID": userUID,
                    "inferred_FoodType": foodType,
                    "Frequency": 1,
                    "like_count": isLiked ? 1 : 0,
                    "LastViewed": Date()
                ]
                
                foodTypeRef.setData(data)
                print("已創建用戶 \(userUID) 的食物類型歷史: \(foodType)")
            }
        }
    }
} 
