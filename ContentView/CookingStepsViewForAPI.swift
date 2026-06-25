import SwiftUI
import AVFoundation
import FirebaseFirestore
import AudioToolbox


private let chatService = ChatService(
    mixraiKey: "YOUR_AI_HERE",
    deepseekKey: "YOUR_AI_HERE"
)

struct CookingStepsViewForAPI: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSettings: UserSettings
    let recipeDetails: RecipeDetails
    let nutritionInfo: NutritionInfo?
    @State private var currentPage = 0
    @State private var isHandDetectionEnabled = false
    @State private var isFlavorGuideEnabled = false
    @State private var showSettings = false
    @State private var synthesizer = AVSpeechSynthesizer()
    @AppStorage("userUID") private var userUID: String = ""
    @State private var aiCookingTip: String = ""
    @State private var userType: String = "beginner"
    @State private var cookingSteps: [String] = []
    @State private var showSuccessAlert = false
    @State private var showLoginAlert = false
    @State private var recipeKnowledgeForKnowledge: Bool = true
    var customStepsForKnowledge: [String]? = nil
    @State private var showTimer = false
    @State private var timerRunning = false
    @State private var remainingTime: TimeInterval = 0
    @State private var showTimerAlert = false
    @State private var timer: Timer?
    @State private var showCancelTimerAlert = false
    @State private var showTimerSelection = false
    @State private var timerDisplayMode: RecipeTimerDisplayMode = .hidden
    @State private var totalSeconds: TimeInterval = 0
    @State private var showGestureGuide = false
    
    // Hand gesture status tracking
    @State private var isHandDetected = false
    @State private var isUpSwipeDetected = false
    @State private var isDownSwipeDetected = false
    @State private var isContinuousInputActive = false
    @State private var lastGestureTime = Date()
    @State private var statusMessageTimer: Timer?
    

    init(recipeDetails: RecipeDetails, nutritionInfo: NutritionInfo?, recipeKnowledgeForKnowledge: Bool = true, customStepsForKnowledge: [String]? = nil) {
        self.recipeDetails = recipeDetails
        self.nutritionInfo = nutritionInfo
        self._recipeKnowledgeForKnowledge = State(initialValue: recipeKnowledgeForKnowledge)
        self.customStepsForKnowledge = customStepsForKnowledge
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 頂部工具欄
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.orange)
                            .font(.system(size: 20, weight: .medium))
                    }
                    
                    // 添加熟悉度
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Image(systemName: recipeKnowledgeForKnowledge ? "person.fill.checkmark" : "person.fill.questionmark")
                            .foregroundColor(.orange)
                        Text(recipeKnowledgeForKnowledge ? "Familiar" : "Unfamiliar")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // 更新計時器顯示
                    if remainingTime > 0 {
                        HStack(spacing: 6) {
                            // 播放/暫停按鈕
                            Button(action: {
                                if timerRunning {
                                    pauseTimer()
                                } else {
                                    startTimer(seconds: Int(remainingTime))
                                }
                            }) {
                                Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Circle().fill(Color.orange))
                                    .font(.system(size: 14))
                            }
                            
                            // 計時器顯示
                            Text(formatTimeRemaining())
                                .foregroundColor(.orange)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .onTapGesture {
                                    showTimerSelection = true
                                }
                            
                            // 重置按鈕
                            Button(action: {
                                cancelTimer()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(20)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.orange)
                            .font(.system(size: 20, weight: .medium))
                    }
                }
                .padding()
                .animation(.easeInOut, value: remainingTime)
                
                // 主要內容
                TabView(selection: $currentPage) {
                    // 材料準備頁
                    IngredientsPreparationViewForAPI(ingredients: recipeDetails.extendedIngredients)
                        .tag(0)
                    
                    // 烹飪步驟頁
                    ForEach(Array(cookingSteps.enumerated()), id: \.offset) { index, step in
                        StepViewForAPI(step: step, stepNumber: index + 1, aiTip: currentPage == index + 1 ? aiCookingTip : "")
                            .tag(index + 1)
                            .onAppear {
                                if userSettings.isLoggedIn {
                                    getAICookingTip(step: step)
                                }
                            }
                    }
                    
                    // 完成頁
                    CompletionViewForAPI(isLoggedIn: userSettings.isLoggedIn) {
                        if userSettings.isLoggedIn {
                            updateNutritionIntake()
                        } else {
                            showLoginAlert = true
                        }
                    } onFinish: {
                        dismiss()
                    }
                    .tag(totalPages - 1)
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
                    // Hand gesture detector (invisible)
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
                            if currentPage < totalPages - 1 {
                                currentPage += 1
                            }
                            // Update swipe status
                            isDownSwipeDetected = true
                            isUpSwipeDetected = false
                            lastGestureTime = Date()
                            resetGestureStatusAfterDelay()
                        }
                    )
                    
                    // Gesture status indicator
                    if isHandDetectionEnabled {
                        VStack(alignment: .center, spacing: 4) {
                            // Always show the enabled status
                            HStack(spacing: 4) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(.orange)
                                Text("Flavour Gesture Enabled")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(15)
                            
                            // Show up swipe only when recently detected
                            if isUpSwipeDetected {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up")
                                        .foregroundColor(.orange)
                                    Text("Previous Step")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(15)
                                .transition(.opacity)
                            }
                            
                            // Show down swipe only when recently detected
                            if isDownSwipeDetected {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down")
                                        .foregroundColor(.orange)
                                    Text("Next Step")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(15)
                                .transition(.opacity)
                            }
                            
                            // Show hand detection only when not showing swipes or continuous input
                            if isHandDetected && !isUpSwipeDetected && !isDownSwipeDetected && !isContinuousInputActive {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.wave.fill")
                                        .foregroundColor(.orange)
                                    Text("Hand Detected")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(15)
                                .transition(.opacity)
                            }
                            
                            // Show continuous input status when active
                            if isContinuousInputActive {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.3.trianglepath")
                                        .foregroundColor(.orange)
                                    Text("Continuous Input Active")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(15)
                                .transition(.opacity)
                            }
                        }
                        .padding(.bottom, 70)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: isHandDetectionEnabled)
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
                                .onChange(of: isFlavorGuideEnabled) { oldValue, newValue in
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
                        
                        // Set Timer
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
                        if remainingTime > 0 {
                            HStack {
                                Text("Current Timer: \(formatTimeRemaining())")
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
            .presentationDetents([.height(270)])
        }
        .onChange(of: currentPage) { oldValue, newValue in
            // Automatically speak content when page changes if feature is enabled
            if isFlavorGuideEnabled {
                speakCurrentContent()
            }
        }
        .onAppear {
            prepareCookingSteps()
            fetchUserType()
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { 
                dismiss()
            }
        } message: {
            Text("Nutrition intake has been recorded!")
        }
        .alert("Please Login", isPresented: $showLoginAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please login to record nutrition intake.")
        }
        .alert("Timer Finished!", isPresented: $showTimerAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your cooking timer has finished.")
        }
        .alert("Cancel Timer?", isPresented: $showCancelTimerAlert) {
            Button("Yes", role: .destructive) { cancelTimer() }
            Button("No", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel the timer?")
        }
        // 添加計時器選擇視圖
        .sheet(isPresented: $showTimerSelection) {
            TimerSelectionViewForAPI(
                isPresented: $showTimerSelection,
                onTimerSet: { seconds in
                    // 設置計時器,不自動啟動
                    remainingTime = TimeInterval(seconds)
                },
                currentStep: getCurrentStepText()
            )
            .presentationDetents([.height(400)])
        }
    }
    
    private var totalPages: Int {
        // 材料頁 + 步驟頁 + 完成頁
        return cookingSteps.count + 2
    }
    
    private func prepareCookingSteps() {
        // If custom steps were provided, use them
        if let customSteps = customStepsForKnowledge, !customSteps.isEmpty {
            cookingSteps = customSteps
            return
        }
        
        // Otherwise use the original recipe instructions
        if let instructions = recipeDetails.instructions {
            let cleanString = instructions.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            let steps = cleanString.components(separatedBy: ". ")
            cookingSteps = steps.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
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
        // Stop any previous speech
        synthesizer.stopSpeaking(at: .immediate)
        
        // Create more natural
        let textToSpeak: String
        
        if currentPage == 0 {
            var ingredientsText = "Let's start cooking. First, please prepare these ingredients: "
            

            let ingredientsList = recipeDetails.extendedIngredients.map { $0.original }
            if ingredientsList.count > 1 {
                let lastIngredient = ingredientsList.last!
                let otherIngredients = ingredientsList.dropLast().joined(separator: "; ")
                ingredientsText += "\(otherIngredients); and finally, \(lastIngredient)."
            } else if !ingredientsList.isEmpty {
                ingredientsText += "\(ingredientsList[0])."
            }
            
            textToSpeak = ingredientsText
        } else if currentPage < cookingSteps.count + 1 {
            let stepNumber = currentPage
            let stepContent = cookingSteps[currentPage - 1]
            
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
                textToSpeak = "Step \(stepNumber). \(cleanedContent) Here's a tip: \(aiCookingTip)"
            } else {
                textToSpeak = "Step \(stepNumber). \(cleanedContent)"
            }
        } else {
            textToSpeak = "Congratulations! You've completed all the cooking steps. Your dish is now ready to be enjoyed! Well done!"
        }

        guard isFlavorGuideEnabled else { return }
        
        let utterance = AVSpeechUtterance(string: textToSpeak)

        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    private func fetchUserType() {
        guard userSettings.isLoggedIn else { return }
        
        let db = Firestore.firestore()
        db.collection("User").document(userUID).getDocument { document, error in
            if let document = document, document.exists {
                userType = document.data()?["user_type"] as? String ?? "beginner"
                print("Fetched user type: \(userType)")
            }
        }
    }
    
    private func getAICookingTip(step: String) {
        guard userSettings.isLoggedIn else {
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
        
        print("Sending to AI: \(contextMessage)")
        
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                print("AI Response: \(response)")
                await MainActor.run {
                    aiCookingTip = response
                }
            } catch {
                print("Error getting AI tip: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateNutritionIntake() {
        guard userSettings.isLoggedIn else {
            showLoginAlert = true
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("User").document(userUID)
            .collection("target").document("current")
        
        // 獲取當前的營養數據
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                // 獲取當前值
                var currentIngested = document.data()?["Ingested"] as? Double ?? 0
                var currentCarbsIngested = document.data()?["CarbsIngested"] as? Double ?? 0
                var currentFatIngested = document.data()?["FatIngested"] as? Double ?? 0
                var currentProteinIngested = document.data()?["ProteinIngested"] as? Double ?? 0
                
                // 如果有營養信息，更新用戶的攝入量
                if let nutrition = nutritionInfo {
                    // 轉換字符串到數值
                    let calories = Double(nutrition.calories.replacingOccurrences(of: "k", with: "").replacingOccurrences(of: "cal", with: "")) ?? 0
                    let carbs = Double(nutrition.carbs.replacingOccurrences(of: "g", with: "")) ?? 0
                    let fat = Double(nutrition.fat.replacingOccurrences(of: "g", with: "")) ?? 0
                    let protein = Double(nutrition.protein.replacingOccurrences(of: "g", with: "")) ?? 0
                    
                    // 更新值（加法）
                    currentIngested += calories
                    currentCarbsIngested += carbs
                    currentFatIngested += fat
                    currentProteinIngested += protein
                    
                    // 更新數據庫
                    let updatedData: [String: Any] = [
                        "Ingested": currentIngested,
                        "CarbsIngested": currentCarbsIngested,
                        "FatIngested": currentFatIngested,
                        "ProteinIngested": currentProteinIngested
                    ]
                    
                    userRef.updateData(updatedData) { error in
                        if let error = error {
                            print("Error updating nutrition: \(error)")
                        } else {
                            DispatchQueue.main.async {
                                showSuccessAlert = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 添加定時器啟動功能
    private func startTimer(seconds: Int? = nil) {
        // 如果提供了新的秒數，則更新剩餘時間
        if let seconds = seconds {
            remainingTime = TimeInterval(seconds)
        }
        
        guard remainingTime > 0, timer == nil else { return }
        
        timerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                // 計時結束時
                timerComplete()
            }
        }
    }
    
    // 暫停計時器
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
    }
    
    // 取消計時器
    private func cancelTimer() {
        pauseTimer()
        remainingTime = 0
        totalSeconds = 0
        if timerDisplayMode != .hidden {
            timerDisplayMode = .hidden
        }
    }
    
    // 計時器完成
    private func timerComplete() {
        pauseTimer()
        
        // 播放提示音
        AudioServicesPlaySystemSound(SystemSoundID(1005))
        
        // 額外振動提示
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.7) {
                // 更醒目的系統聲音
                let soundID = SystemSoundID(1007)
                AudioServicesPlaySystemSound(soundID)
                
                // 振動
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
        
        // 顯示提示
        showTimerAlert = true
    }
    
    // 獲取當前步驟文本
    private func getCurrentStepText() -> String? {
        if currentPage > 0 && currentPage <= cookingSteps.count {
            return cookingSteps[currentPage - 1]
        }
        return nil
    }
    

    private func formatTimeRemaining() -> String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Reset gesture status after a delay
    private func resetGestureStatusAfterDelay() {
        let delay: TimeInterval = 1.0 // Adjust the delay as needed
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isUpSwipeDetected = false
            isDownSwipeDetected = false
            isContinuousInputActive = false
        }
    }
}

// 材料準備視圖
struct IngredientsPreparationViewForAPI: View {
    let ingredients: [Ingredient]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Please prepare the ingredients:")
                .font(.title2)
                .bold()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(ingredients, id: \.original) { ingredient in
                        HStack {
                            Text("•")
                                .foregroundColor(.orange)
                            Text(ingredient.original)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// 步驟視圖
struct StepViewForAPI: View {
    let step: String
    let stepNumber: Int
    let aiTip: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Step \(stepNumber)")
                .font(.title2)
                .bold()
            
            Text(step)
                .font(.body)
                .lineSpacing(8)
            
            if !aiTip.isEmpty {
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
            }
        }
        .padding()
    }
}

// 完成視圖
struct CompletionViewForAPI: View {
    let isLoggedIn: Bool
    let onRecord: () -> Void
    let onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Cooking Complete!")
                .font(.title)
                .bold()
            
            if isLoggedIn {
                Button(action: onRecord) {
                    Text("Record Nutrition Intake")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
            }
            
            Button(action: onFinish) {
                Text("Finish")
                    .font(.headline)
                    .foregroundColor(isLoggedIn ? .gray : .white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoggedIn ? Color.gray.opacity(0.2) : Color.orange)
                    .cornerRadius(15)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// 添加計時器選擇視圖 (如果尚未存在)
struct TimerSelectionViewForAPI: View {
    @Binding var isPresented: Bool
    let onTimerSet: (Int) -> Void
    @State private var selectedMinutes: Int = 1
    @State private var selectedSeconds: Int = 0
    let currentStep: String?

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
            
            // 如果當前步驟中有時間提示
            if let suggestedTime = detectTimeInStep() {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Time")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        selectedMinutes = suggestedTime
                        selectedSeconds = 0
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.orange)
                            
                            Text("Found '\(suggestedTime) minutes' in the current step")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.vertical, 2)
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle")
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            
            Spacer()
        }
        .padding(.top, 20)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            // 嘗試從當前步驟中檢測時間
            if let detected = detectTimeInStep() {
                selectedMinutes = detected
                selectedSeconds = 0
            }
        }
    }
    
   
    private func detectTimeInStep() -> Int? {
        guard let step = currentStep else { return nil }
        

        let patterns = [
            "(\\d+)\\s*minutes",
            "(\\d+)\\s*mins",
            "(\\d+)\\s*min",
            "for\\s*(\\d+)",
            "about\\s*(\\d+)\\s*minutes"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(step.startIndex..<step.endIndex, in: step)
                if let match = regex.firstMatch(in: step, options: [], range: range) {
                    if let matchRange = Range(match.range(at: 1), in: step),
                       let time = Int(step[matchRange]) {
                        return time
                    }
                }
            }
        }
        
        return nil
    }
} 
