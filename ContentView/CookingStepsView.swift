import SwiftUI
import AVFoundation
import FirebaseFirestore
import AudioToolbox

// Add ChatService definition
private let chatService = ChatService(
    mixraiKey: "YOUR_AI_HERE",
    deepseekKey: "YOUR_AI_HERE"
)

// Use RecipeTimerDisplayMode enum from TimerDisplayMode.swift

// 定义食材详情结构体
struct IngredientDetail {
    var name: String
    var value: String
}

// 重新定義 NutritionDetail
struct NutritionDetail: Identifiable {
    var id: String { name }
    var name: String
    var value: String
}

struct CookingSteps {
    let ingredients: [IngredientDetail]
    let steps: [String]
    let nutritions: [NutritionDetail]
    let isUserLoggedIn: Bool // Add login status
}

// 添加計時器選擇視圖
struct TimerSelectionView: View {
    @Binding var isPresented: Bool
    let onTimerSet: (Int) -> Void
    @State private var selectedMinutes: Int = 1
    @State private var selectedSeconds: Int = 0

    // 預設時間選項（分鐘）
    private let presetMinutes = [1, 2, 3, 5, 10, 15, 20, 30]
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                        .padding(8)
                }
                
                Spacer()
                
                Text("Set Timer")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    let totalSeconds = (selectedMinutes * 60) + selectedSeconds
                    onTimerSet(totalSeconds)
                    isPresented = false
                }) {
                    Text("Set")
                        .foregroundColor(.orange)
                        .fontWeight(.bold)
                        .padding(8)
                }
            }
            .padding(.horizontal)
            
            // 顯示選擇的時間
            HStack(spacing: 10) {
                Spacer()
                
                // 分鐘控制
                VStack(spacing: 8) {
                    Button(action: {
                        selectedMinutes = min(99, selectedMinutes + 1)
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Text("\(selectedMinutes)")
                        .font(.system(size: 48, design: .monospaced))
                        .fontWeight(.semibold)
                        .frame(width: 80)
                    
                    Button(action: {
                        selectedMinutes = max(0, selectedMinutes - 1)
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                
                Text(":")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                
                // 秒數控制
                VStack(spacing: 8) {
                    Button(action: {
                        if selectedSeconds >= 50 {
                            selectedSeconds = 0
                            selectedMinutes += 1
                        } else {
                            selectedSeconds += 10
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Text(String(format: "%02d", selectedSeconds))
                        .font(.system(size: 48, design: .monospaced))
                        .fontWeight(.semibold)
                        .frame(width: 80)
                    
                    Button(action: {
                        if selectedSeconds < 10 && selectedMinutes > 0 {
                            selectedSeconds = 50
                            selectedMinutes -= 1
                        } else {
                            selectedSeconds = max(0, selectedSeconds - 10)
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 20)
            
            // 預設時間選項
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presetMinutes, id: \.self) { minutes in
                        Button(action: {
                            selectedMinutes = minutes
                            selectedSeconds = 0
                        }) {
                            Text("\(minutes) min")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedMinutes == minutes && selectedSeconds == 0 ? 
                                            Color.orange : Color.orange.opacity(0.1))
                                )
                                .foregroundColor(selectedMinutes == minutes && selectedSeconds == 0 ? 
                                            Color.white : Color.orange)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 12)
            
            // 自訂按鈕
            HStack(spacing: 20) {
                Button(action: {
                    selectedMinutes = 0
                    selectedSeconds = 30
                }) {
                    Text("30 sec")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedMinutes == 0 && selectedSeconds == 30 ? 
                                    Color.orange : Color.orange.opacity(0.1))
                        )
                        .foregroundColor(selectedMinutes == 0 && selectedSeconds == 30 ? 
                                    Color.white : Color.orange)
                }
                
                Button(action: {
                    selectedMinutes = 0
                    selectedSeconds = 0
                }) {
                    Text("Reset")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.2))
                        )
                        .foregroundColor(.primary)
                }
            }
            .padding(.top, 12)
            
            Spacer()
        }
        .padding(.top, 20)
        .background(Color(UIColor.systemBackground))
    }
}

struct CookingStepsView: View {
    @Environment(\.dismiss) private var dismiss
    let cookingSteps: CookingSteps
    @State private var currentPage = 0
    @State private var isHandDetectionEnabled = false
    @State private var isFlavorGuideEnabled = false
    @State private var showSettings = false
    @State private var synthesizer = AVSpeechSynthesizer()
    @AppStorage("userUID") private var userUID: String = ""
    @State private var aiCookingTip: String = ""
    @State private var userType: String = "beginner"
    @State private var showLoginAlert = false
    @State private var isLoadingTip = false
    @State private var isTimerRunning = false
    @State private var remainingSeconds: Int = 0
    @State private var totalSeconds: Int = 0
    @State private var showTimerAlert = false
    @State private var timerDisplayMode: RecipeTimerDisplayMode = .hidden
    @State private var timer: Timer?
    @State private var showTimerSelection = false // 添加計時器選擇視圖開關
    @State private var showCancelTimerConfirm = false
    @State private var showGestureGuide = false
    @State private var isHandDetected = false
    @State private var isUpSwipeDetected = false
    @State private var isDownSwipeDetected = false
    @State private var isContinuousInputActive = false
    @State private var lastGestureTime = Date()
    @State private var statusMessageTimer: Timer?
    
    // Function to fetch user type from Firestore
    private func fetchUserType() {
        // Only fetch user type if logged in
        guard cookingSteps.isUserLoggedIn && !userUID.isEmpty else { return }
        
        let db = Firestore.firestore()
        db.collection("User").document(userUID).getDocument { document, error in
            if let document = document, document.exists {
                userType = document.data()?["user_type"] as? String ?? "beginner"
            }
        }
    }
    
    // Function to get AI cooking tips
    private func getAICookingTip(step: String) {
        guard cookingSteps.isUserLoggedIn else {
            print("User not logged in - skipping AI tips")
            return
        }
        
        let contextMessage = """
        User type: \(userType)
        Cooking step: \(step)
        
        Please provide a short cooking tip (max 20 words) based on user type.
        For beginner users, focus on food safety and basic timing.
        For advanced users, focus on taste and texture.
        """
        
        isLoadingTip = true
        
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                await MainActor.run {
                    aiCookingTip = response
                    isLoadingTip = false
                }
            } catch {
                print("Error getting AI cooking tip: \(error)")
                await MainActor.run {
                    isLoadingTip = false
                }
            }
        }
    }
    
    // 添加一個函數來更新用戶的營養攝入
    private func updateNutritionIntake() {
        // Only update nutrition if user is logged in
        guard cookingSteps.isUserLoggedIn && !userUID.isEmpty else {
            print("User not logged in - skipping nutrition update")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("User").document(userUID).collection("target").document("current")
        
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                var currentIngested = document.data()?["Ingested"] as? Double ?? 0
                var currentCarbsIngested = document.data()?["CarbsIngested"] as? Double ?? 0
                var currentFatIngested = document.data()?["FatIngested"] as? Double ?? 0
                var currentProteinIngested = document.data()?["ProteinIngested"] as? Double ?? 0
                
                for nutrition in cookingSteps.nutritions {
                   
                    let cleanValue = nutrition.value.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                    let value = Double(cleanValue) ?? 0
                    
                    switch nutrition.name {
                    case "Calories":
                        currentIngested += value
                    case "Carbohydrates":
                        currentCarbsIngested += value
                    case "Fat":
                        currentFatIngested += value
                    case "Protein":
                        currentProteinIngested += value
                    default:
                        break
                    }
                }
                
                // 更新數據庫
                let updates: [String: Any] = [
                    "Ingested": currentIngested,
                    "CarbsIngested": currentCarbsIngested,
                    "FatIngested": currentFatIngested,
                    "ProteinIngested": currentProteinIngested
                ]
                
                userRef.updateData(updates) { error in
                    if let error = error {
                        print("Error updating nutrition intake: \(error)")
                    } else {
                        print("Successfully updated nutrition intake")
                    }
                }
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.orange)
                            .font(.system(size: 20, weight: .medium))
                    }
                    
                    Spacer()
                    
                    // 添加熟悉度指示器
                    HStack(spacing: 5) {
                        Image(systemName: "person.fill.checkmark")
                            .foregroundColor(.orange)
                        Text("Familiar")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // Enhanced Timer Display
                    if timerDisplayMode != .hidden {
                        HStack(spacing: 8) {
                            if timerDisplayMode == .editing {
                                // Timer editing mode with up/down buttons
                                VStack {
                                    HStack {
                                        VStack {
                                            Button(action: { addMinute() }) {
                                                Image(systemName: "chevron.up")
                                                    .foregroundColor(.orange)
                                            }
                                            
                                            Text("\(remainingSeconds / 60)")
                                                .font(.system(.headline, design: .monospaced))
                                                .foregroundColor(.orange)
                                                .frame(width: 30)
                                            
                                            Button(action: { removeMinute() }) {
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        
                                        Text(":")
                                            .foregroundColor(.orange)
                                            .font(.system(.headline, design: .monospaced))
                                        
                                        VStack {
                                            Button(action: { addSecond() }) {
                                                Image(systemName: "chevron.up")
                                                    .foregroundColor(.orange)
                                            }
                                            
                                            Text("\(remainingSeconds % 60)")
                                                .font(.system(.headline, design: .monospaced))
                                                .foregroundColor(.orange)
                                                .frame(width: 30)
                                            
                                            Button(action: { removeSecond() }) {
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                    }
                                    
                                    Button(action: { confirmTimer() }) {
                                        Text("Start")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.orange)
                                            .cornerRadius(8)
                                    }
                                }
                            } else {
                                Button(action: {
                                    if isTimerRunning {
                                        pauseTimer()
                                    } else if remainingSeconds > 0 {
                                        startTimer()
                                    }
                                }) {
                                    Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                                        .foregroundColor(.white)
                                        .padding(5)
                                        .background(Circle().fill(Color.orange))
                                }
                                
                                if timerDisplayMode == .visible {
                                    Text(timeString(from: remainingSeconds))
                                        .font(.system(.headline, design: .monospaced))
                                        .foregroundColor(.orange)
                                        .frame(width: 70, alignment: .leading)
                                        .onTapGesture {
                                            showTimerSelection = true
                                        }
                                } else {
                                    Button(action: {
                                        timerDisplayMode = .visible
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "timer")
                                                .foregroundColor(.orange)
                                            Text(timeString(from: remainingSeconds))
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                        .onTapGesture {
                                            showTimerSelection = true
                                        }
                                    }
                                }
                                
                                // 修改刷新按鈕為刪除按鈕
                                Button(action: {
                                    cancelTimer()
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.orange.opacity(0.15))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                    }
                    
                    Spacer()
                    
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.orange)
                            .font(.system(size: 20, weight: .medium))
                    }
                }
                .padding()
                
                // 主要内容
                TabView(selection: $currentPage) {
                    // 材料准备页
                    IngredientsPreparationView(ingredients: cookingSteps.ingredients)
                        .tag(0)
                    
                    // 烹饪步骤页
                    ForEach(Array(cookingSteps.steps.enumerated()), id: \.offset) { index, step in
                        StepView(step: step, 
                                 stepNumber: index + 1, 
                                 aiTip: aiCookingTip,
                                 isUserLoggedIn: cookingSteps.isUserLoggedIn)
                            .tag(index + 1)
                            .onAppear {
                                getAICookingTip(step: step)
                            }
                    }
                    
                    // 完成页 - Different completion view based on login status
                    if cookingSteps.isUserLoggedIn {
                        CompletionView {
                            updateNutritionIntake()
                            dismiss()
                        }
                        .tag(totalPages - 1)
                    } else {
                        GuestCompletionView {
                            dismiss()
                        }
                        .tag(totalPages - 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .gesture(DragGesture().onEnded { value in
                    handleSwipe(value: value, viewWidth: geometry.size.width)
                })
                
                Text("← Swipe to change steps →")
                    .foregroundColor(.gray)
                    .font(.caption)
                    .padding(.bottom)
            }
            // Add Background Hand Gesture Detector for navigation
            .overlay(
                ZStack {
                    BackgroundHandGestureDetector(
                        isEnabled: $isHandDetectionEnabled,
                        onUpSwipe: {
                            if currentPage > 0 {
                                currentPage -= 1
                            }
                            // Update swipe status
                            isUpSwipeDetected = true
                            isDownSwipeDetected = false
                            lastGestureTime = Date()
                            resetGestureStatusAfterDelay()
                        },
                        onDownSwipe: {
                            if currentPage < cookingSteps.steps.count - 1 {
                                currentPage += 1
                            }
                            // Update swipe status
                            isDownSwipeDetected = true
                            isUpSwipeDetected = false
                            lastGestureTime = Date()
                            resetGestureStatusAfterDelay()
                        }
                    )
                    
                    if isHandDetectionEnabled {
                        VStack(alignment: .center, spacing: 4) {
                            // Always show the enabled status
                            HStack(spacing: 4) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(.white)
                                Text("Flavour Gesture Enabled")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(15)
                            
                            // Only show hand detection message when relevant
                            if isHandDetected && !isUpSwipeDetected && !isDownSwipeDetected && !isContinuousInputActive {
                                HStack {
                                    Image(systemName: "hand.draw.fill")
                                        .foregroundColor(.white)
                                    Text("Hand Detected")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.7))
                                .cornerRadius(15)
                                .transition(.opacity)
                            }
                            
                            // Only show up swipe when detected
                            if isUpSwipeDetected {
                                HStack {
                                    Image(systemName: "arrow.up")
                                        .foregroundColor(.white)
                                    Text("Previous Step")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.7))
                                .cornerRadius(15)
                                .transition(.opacity)
                            }
                            
                            // Only show down swipe when detected
                            if isDownSwipeDetected {
                                HStack {
                                    Image(systemName: "arrow.down")
                                        .foregroundColor(.white)
                                    Text("Next Step")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.7))
                                .cornerRadius(15)
                                .transition(.opacity)
                            }
                            
                            // Only show continuous input when active
                            if isContinuousInputActive {
                                HStack {
                                    Image(systemName: "hand.point.up.left.fill")
                                        .foregroundColor(.white)
                                    Text("Continuous Input Active")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.7))
                                .cornerRadius(15)
                                .transition(.opacity)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .opacity(0.9)
                        .animation(.easeInOut(duration: 0.3), value: isHandDetected)
                        .animation(.easeInOut(duration: 0.3), value: isUpSwipeDetected)
                        .animation(.easeInOut(duration: 0.3), value: isDownSwipeDetected)
                        .animation(.easeInOut(duration: 0.3), value: isContinuousInputActive)
                    }
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                VStack {
                    Text("Flavour Assist")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    VStack(spacing: 0) {

                        
                        // Flavour Gesture 選項
                        HStack(spacing: 15) {
                            Image(systemName: isHandDetectionEnabled ? "hand.raised.fill" : "hand.raised")
                                .font(.system(size: 22))
                                .foregroundColor(.black)
                            
                            Text("Flavour Gesture")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Button(action: {
                                showGestureGuide = true
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 18))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $isHandDetectionEnabled)
                                .labelsHidden()
                                .tint(.orange)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.white)
                        .sheet(isPresented: $showGestureGuide) {
                            GestureGuideView(isPresented: $showGestureGuide)
                                .presentationDetents([.height(500)])
                        }
                        
                        Divider()
                            .padding(.leading, 20)
                        
                        // Flavor Guide 選項
                        HStack(spacing: 15) {
                            Image(systemName: isFlavorGuideEnabled ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: 22))
                                .foregroundColor(.black)
                            
                            Text("Flavor Guide")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Toggle("", isOn: $isFlavorGuideEnabled)
                                .labelsHidden()
                                .tint(.orange)
                                .onChange(of: isFlavorGuideEnabled) { newValue in
                                    if newValue {
                                        speakCurrentContent()
                                    } else {
                                        synthesizer.stopSpeaking(at: .immediate)
                                    }
                                }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.white)
                        
                        Divider()
                            .padding(.leading, 20)
                        
                        // Set Timer 選項 - 更新為打開計時器選擇視圖
                        HStack(spacing: 15) {
                            Image(systemName: "timer")
                                .font(.system(size: 22))
                                .foregroundColor(.orange)
                            
                            Text("Set Timer")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.white)
                        .onTapGesture {
                            showSettings = false
                            showTimerSelection = true
                        }
                        
                        // 顯示當前計時器
                        if timerDisplayMode != .hidden && remainingSeconds > 0 {
                            HStack {
                                Text("Current Timer: \(timeString(from: remainingSeconds))")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                Spacer()
                                Button(action: {
                                    cancelTimer()
                                }) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.orange.opacity(0.1))
                        }
                    }
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showSettings = false
                        }
                        .font(.headline)
                        .foregroundColor(.orange)
                    }
                }
            }
            .presentationDetents([.height(timerDisplayMode == .hidden ? 270 : 330)])
        }
        // 添加計時器選擇視圖 sheet
        .sheet(isPresented: $showTimerSelection) {
            TimerSelectionView(isPresented: $showTimerSelection) { seconds in
                remainingSeconds = seconds
                totalSeconds = seconds
                if seconds > 0 {
                    timerDisplayMode = .visible
                    // 不自動開始，等用戶按下開始按鈕
                }
            }
            .presentationDetents([.height(400)])
        }
        .onChange(of: currentPage) { _, newValue in
            if isFlavorGuideEnabled {
                speakCurrentContent()
            }
        }
        .onAppear {
            fetchUserType()
            // Get AI cooking tip for the first step if there are steps
            if !cookingSteps.steps.isEmpty {
                getAICookingTip(step: cookingSteps.steps[0])
            }
            
            // 設置手勢檢測模擬
            setupHandDetectionSimulation()
            simulateContinuousInput()
        }
        .alert("Login Required", isPresented: $showLoginAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please login to track your nutrition data.")
        }
        .alert("Timer Complete!", isPresented: $showTimerAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your cooking timer has finished.")
        }
    }
    
    private var totalPages: Int {
        // 材料页 + 步骤页 + 完成页
        return cookingSteps.steps.count + 2
    }
    
    private func handleSwipe(value: DragGesture.Value, viewWidth: CGFloat) {
        let horizontalAmount = value.translation.width
        let threshold: CGFloat = 50
        
        if horizontalAmount > threshold && currentPage > 0 {
            withAnimation {
                currentPage -= 1
            }
        } else if horizontalAmount < -threshold && currentPage < totalPages - 1 {
            withAnimation {
                currentPage += 1
            }
        }
    }
    
    private func speakCurrentContent() {
        guard isFlavorGuideEnabled else { return }
        
        let textToSpeak: String
        
        if currentPage == 0 {
            // Ingredients preparation stage with improved phrasing
            var ingredientsText = "Let's start cooking. First, please prepare these ingredients: "
            
            // Create a more conversational list with pauses
            let ingredientsList = cookingSteps.ingredients.map { "\($0.name), \($0.value)" }
            if ingredientsList.count > 1 {
                let lastIngredient = ingredientsList.last!
                let otherIngredients = ingredientsList.dropLast().joined(separator: "; ")
                ingredientsText += "\(otherIngredients); and finally, \(lastIngredient)."
            } else if !ingredientsList.isEmpty {
                ingredientsText += "\(ingredientsList[0])."
            }
            
            textToSpeak = ingredientsText
        } else if currentPage < cookingSteps.steps.count + 1 {
            // Cooking step stage with better conversational flow
            let stepNumber = currentPage - 1
            let stepContent = cookingSteps.steps[stepNumber]
            
            // Add pauses with commas and improve flow
            var cleanedContent = stepContent
                .replacingOccurrences(of: ". ", with: ", ")
                .replacingOccurrences(of: ".", with: ",")
            
            // Ensure the text ends properly
            if !cleanedContent.hasSuffix(".") && !cleanedContent.hasSuffix(",") {
                cleanedContent += "."
            }
            
            // Add AI tip if available
            if !aiCookingTip.isEmpty {
                textToSpeak = "Step \(stepNumber + 1). \(cleanedContent) Here's a tip: \(aiCookingTip)"
            } else {
                textToSpeak = "Step \(stepNumber + 1). \(cleanedContent)"
            }
        } else {
            // Completion stage with more natural celebratory tone
            textToSpeak = "Congratulations! You've completed all the cooking steps. Your dish is now ready to be enjoyed! Well done!"
        }
        
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func showTimerSetup() {
        remainingSeconds = 0
        totalSeconds = 0
        timerDisplayMode = .editing

        showSettings = false

    }
    
    // Make the timer display editable when clicked
    func handleTimerTap() {
        if timerDisplayMode == .visible || timerDisplayMode == .minimized {
            // Only allow editing if timer is not running
            if !isTimerRunning {
                timerDisplayMode = .editing
                // Reset to 0 when starting a new edit
                remainingSeconds = 0
                totalSeconds = 0
            }
        }
    }
    
    // Add minutes to the current timer
    func addMinute() {
        remainingSeconds += 60
        totalSeconds = remainingSeconds
    }
    
    // Remove minutes from the current timer
    func removeMinute() {
        if remainingSeconds >= 60 {
            remainingSeconds -= 60
            totalSeconds = remainingSeconds
        }
    }
    
    // Add seconds to the current timer
    func addSecond() {
        remainingSeconds += 1
        totalSeconds = remainingSeconds
    }
    
    // Remove seconds from the current timer
    func removeSecond() {
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            totalSeconds = remainingSeconds
        }
    }
    
    // Confirm the timer settings and start the timer
    func confirmTimer() {
        if remainingSeconds > 0 {
            timerDisplayMode = .visible
            startTimer()
            
            // Add haptic feedback when timer is set
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } else {
            // If timer is 0, hide it
            timerDisplayMode = .hidden
        }
    }
    
    private func startTimer() {
        guard remainingSeconds > 0, timer == nil else { return }
        
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            }
            
            if self.remainingSeconds == 0 {
                self.timerComplete()
            }
        }
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
    }
    
    private func cancelTimer() {
        pauseTimer()
        remainingSeconds = 0
        totalSeconds = 0
        if timerDisplayMode != .hidden {
            timerDisplayMode = .hidden
        }
    }
    
    private func timerComplete() {
        pauseTimer()
        
        // Play multiple sounds for better notification
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.7) {
                // Use a more noticeable system sound
                let soundID = SystemSoundID(1007) // System sound ID
                AudioServicesPlaySystemSound(soundID)
                
                // Vibration
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
        
        // Show alert
        showTimerAlert = true
    }
    
    private func resetGestureStatusAfterDelay() {
        statusMessageTimer?.invalidate()
        // 創建新的計時器，在2秒後重置手勢狀態
        statusMessageTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            DispatchQueue.main.async {
                self.isUpSwipeDetected = false
                self.isDownSwipeDetected = false
            }
        }
    }
    
    // 模擬手部檢測的方法 - 在真實環境中這會由HandDetectionView觸發
    private func setupHandDetectionSimulation() {
        // 當啟用手勢檢測時，模擬手的檢測
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            guard self.isHandDetectionEnabled else { return }
            // 模擬手部被檢測到的狀態
            self.isHandDetected = true
            
            // 3秒後自動重置
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.isHandDetected = false
            }
        }
    }
    
    private func simulateContinuousInput() {
        // 在實際應用中，這將由BackgroundHandGestureDetector觸發
        Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
            guard self.isHandDetectionEnabled else { return }
            self.isContinuousInputActive = true
            
            // 3秒後結束連續輸入
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.isContinuousInputActive = false
            }
        }
    }
}

// 材料准备视图
struct IngredientsPreparationView: View {
    let ingredients: [IngredientDetail]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Please prepare the ingredients:")
                .font(.title2)
                .bold()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(ingredients, id: \.name) { ingredient in
                        HStack {
                            Text("•")
                                .foregroundColor(.orange)
                            Text(ingredient.name)
                            Spacer()
                            Text(ingredient.value)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// 步骤视图
struct StepView: View {
    let step: String
    let stepNumber: Int
    let aiTip: String
    let isUserLoggedIn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Step \(stepNumber)")
                .font(.title2)
                .bold()
            
            Text(step)
                .font(.body)
                .lineSpacing(8)
            
            if !aiTip.isEmpty && isUserLoggedIn {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    
                    Text(aiTip)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                )
                .padding(.horizontal)
            }
        }
        .padding()
    }
}

// 完成视图
struct CompletionView: View {
    let onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Cooking Complete!")
                .font(.title)
                .bold()
            
            Button("Finish", action: onFinish)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(15)
                .padding(.horizontal)
        }
        .padding()
    }
}

// Guest completion view for non-logged-in users
struct GuestCompletionView: View {
    let onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Cooking Complete!")
                .font(.title)
                .bold()
            
            Text("Nutrition data is not tracked for guest users")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Finish", action: onFinish)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(15)
                .padding(.horizontal)
        }
        .padding()
    }
} 
