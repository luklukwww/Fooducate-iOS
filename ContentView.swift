import SwiftUI

struct ContentView: View {
    @State private var showNutritionStatus = false
    @EnvironmentObject var tabBarManager: TabBarManager
    
    var body: some View {
        ZStack {
            MainTabView()
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    // 懸浮球
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(TabBarManager())
    }
} 