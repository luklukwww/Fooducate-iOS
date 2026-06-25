import SwiftUI

struct FloatingButton: View {
    @State private var isShowingNutrition = false
    @EnvironmentObject var userSettings: UserSettings
    @State private var sheetDetent: PresentationDetent = .large
    
    var body: some View {
        Button(action: {
            isShowingNutrition = true
        }) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
        }
        .sheet(isPresented: $isShowingNutrition) {
            NutritionStatusView(sheetDetent: $sheetDetent)
                .environmentObject(userSettings)
                .presentationDetents([.large, .medium], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
    }
}

#Preview {
    FloatingButton()
        .environmentObject(UserSettings.shared)
} 
