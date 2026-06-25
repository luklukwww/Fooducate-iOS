import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var tabBarManager: TabBarManager
    @State private var showNutritionStatus = false
    
    var body: some View {
        ZStack {
            TabView {
                // ... 現有的 TabView 內容 ...
            }
            
            // 添加懸浮球
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showNutritionStatus.toggle()
                    } label: {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 100)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showNutritionStatus) {
            NutritionStatusView()
                .presentationDetents([.medium])
        }
    }
} 