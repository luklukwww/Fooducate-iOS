import SwiftUI

struct NavigationDebugView: View {
    // 預設測試食譜 ID
    let testRecipeId = "8MKHYd6GF9MdXyGbRf2N" // 使用一個實際存在的食譜ID
    let testUserId = "pYFESVzuQFEoSqWL8iZo" // 使用一個實際存在的用戶ID
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("測試直接導航")) {
                    NavigationLink("1. 直接導航到食譜詳情", destination: ExploreDetailView(recipeId: testRecipeId))
                    
                    NavigationLink("2. 導航到用戶的食譜列表", destination: UserRecipesView(userUID: testUserId))
                    
                    NavigationLink("3. 導航到 Following List", destination: UserFollowingView(userUID: testUserId))
                }
                
                Section(header: Text("測試嵌套導航")) {
                    NavigationLink("4. Following List (嵌套測試)", destination: 
                        NavigationStepView(message: "從 Following List 點擊用戶...", nextView:
                            UserFollowingView(userUID: testUserId)
                        )
                    )
                    
                    // 直接測試用戶食譜列表到食譜詳情的導航
                    NavigationLink("5. 用戶的食譜列表 (嵌套測試)", destination: 
                        NavigationStepView(message: "從用戶食譜列表點擊食譜...", nextView:
                            UserRecipesView(userUID: testUserId)
                        )
                    )
                }
                
                Section(header: Text("測試UI組件")) {
                    NavigationLink("6. 測試導航鏈接樣式", destination: NavigationTestView())
                }
            }
            .navigationTitle("導航診斷工具")
        }
    }
}

// 輔助視圖，用於嵌套導航時顯示提示
struct NavigationStepView<Content: View>: View {
    let message: String
    let nextView: Content
    
    var body: some View {
        VStack {
            Text(message)
                .font(.headline)
                .padding()
                .multilineTextAlignment(.center)
            
            nextView
        }
        .onAppear {
            print("Navigation step appeared: \(message)")
        }
    }
}

struct NavigationDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationDebugView()
    }
} 
