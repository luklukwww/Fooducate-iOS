import SwiftUI

struct NavigationTestView: View {
    @State private var selectedRecipe: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Navigation Test Page")
                    .font(.title)
                    .padding()
                
                // 直接導航按鈕
                Button("Go to Recipe 1") {
                    print("Direct navigation button tapped")
                    selectedRecipe = "test1"
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                // 帶圖片的導航
                NavigationLink(destination: Text("Recipe 2 Detail Page")) {
                    ZStack {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 150, height: 150)
                            .cornerRadius(10)
                        
                        Text("Recipe 2")
                            .foregroundColor(.white)
                            .bold()
                    }
                }
                

                NavigationLink(
                    destination: 
                        VStack {
                            Text("Test Recipe Detail View")
                                .font(.title)
                            Text("Recipe ID: test3")
                                .padding()
                        }
                        .onAppear {
                            print("Test Recipe Detail View appeared with ID: test3")
                        },
                    tag: "test3",
                    selection: $selectedRecipe
                ) {
                    Text("Go to Recipe 3")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // 生成一個測試用的 NavigationLink 到 ExploreDetailView
                NavigationLink(
                    destination: ExploreDetailView(recipeId: "test4"),
                    tag: "test4",
                    selection: $selectedRecipe
                ) {
                    Text("Go to Recipe 4 (ExploreDetailView)")
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
                
                Button("Debug: Print Navigation Stack") {
                    print("Current selected recipe: \(selectedRecipe ?? "none")")
                }
                .padding()
            }
            .navigationTitle("Navigation Test")
        }
    }
}

struct NavigationTestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationTestView()
    }
} 
