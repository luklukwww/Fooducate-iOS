import SwiftUI
import Foundation
import FirebaseFirestore
import PhotosUI
import UIKit

// 從AddRecipeView引入RecipeFoodType
// 不再定義重複的枚舉

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let isUser: Bool
    let text: String
    var image: UIImage? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, isUser, text
        // 圖片不編碼
    }
}

struct NutritionStatusView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userSettings: UserSettings
    @StateObject private var nutritionManager = NutritionManager.shared
    @State private var selectedTab = 0  // 0 for AI Chat, 1 for Nutrition
    @State private var messageText = ""
    @State private var chatMessages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var selectedProvider: APIProvider = .mixrai
    @State private var showLoginAlert = false
    @State private var nutritionData: TargetData?
    @AppStorage("userUID") private var userUID: String = ""
    @State private var considerPersonalInfo = false // 合併考慮營養和過敏
    @State private var showNutritionAlert = false
    @State private var alertMessage = ""
    @State private var showNutritionStatus = true // 控制營養狀態顯示
    @Binding var sheetDetent: PresentationDetent
    @State private var allergyData: [String] = [] // 存儲用戶的過敏原
    @State private var showPersonalInfoPanel = false // 控制個人信息面板顯示
    @State private var hasTargetData = false
    @State private var hasAllergyData = false
    @State private var showAddRecipe = false
    @State private var recipeToShare: AddRecipeView.RecipeData?
    @State private var showCookingSteps = false
    @State private var cookingRecipeData: (ingredients: [AddRecipeView.Ingredient], steps: [String], nutritions: [AddRecipeView.Nutrition])?
    @State private var isEditing = false // 控制編輯狀態
    @State private var editingMessage = "" // 存儲正在編輯的消息
    @State private var editingIndex: Int? // 存儲正在編輯的消息索引
    @State private var showRegenerateOptions = false // 控制重新生成選項的顯示
    @State private var regeneratePrompt = "" // 存儲重新生成的提示
    @State private var selectedItem: PhotosPickerItem? // State for image selection
    @State private var selectedImage: Image? // State for displaying selected image
    @State private var uiImage: UIImage? // State for UIImage
    @State private var detectionResults: String = "" // State for storing detection results
    @State private var isAnalyzing: Bool = false // State for analyzing status
    @State private var showThumbnail: Bool = false // State to control thumbnail display
    @State private var analysisMessage: String = "" // State for analysis message
    @State private var acceptedResults: [String] = [] // State to store accepted results
    @State private var showDetailedResults: Bool = false // State to control showing detailed results
    @State private var filteredResults: [String] = [] // State to store filtered results for editing
    @State private var isResultsAccepted: Bool = false // State to track if results are accepted
    @State private var messageImage: UIImage? = nil // To store the image for the current message
    @State private var apiRetryCount = 0 // Track API retry attempts
    @State private var maxRetryAttempts = 5 // Maximum number of retry attempts
    @State private var lastUserMessage = "" // Store the last user message for retries
    @State private var lastContextMessage = "" // Store the last context message for retries
    @State private var editingRecipeName = ""
    @State private var editingDescription = ""
    @State private var editingIngredients: [(String, String)] = []
    @State private var editingSteps: [String] = []
    @State private var editingNutritions: [(String, String)] = []
    @State private var showRecipeKnowledgeAlert = false // To show recipe familiarity alert
    @State private var recipeKnowledge = true // Default to "Familiar"
    @State private var isProcessingRecipeSteps = false // Show loading state
    @State private var optimizedSteps: [String] = [] // Store AI optimized steps
    @State private var originalSteps: [String] = [] // Store original steps for AI processing
    @State private var showRecipeFamiliaritySelection = false // Add a new state variable for the familiarity selection sheet
    @State private var showSaveFavoriteAlert = false // Add state for save favorite confirmation
    @State private var favoriteRecipeName = "" // Store the name of the recipe to save as favorite
    @State private var recipeMessageToSave = "" // Store the message content to save as favorite
    @AppStorage("showSegmentInLikesView") private var showSegmentInLikesView: Bool = false // Control segment view in Likes
    
    // 營養數據過濾相關狀態
    @State private var hideCalories = false
    @State private var hideCarbs = false
    @State private var hideProtein = false
    @State private var hideFat = false
    @State private var hideCarbsExceeded = false
    @State private var hideProteinExceeded = false
    @State private var hideFatExceeded = false
    @State private var hideTotalExceeded = false
    @State private var hideAllergies = false
    @State private var showFilterAlert = false
    @State private var filterAlertMessage = ""
    
    @State private var showScrollToBottomButton = false // 控制向下捲動按鈕顯示
    @State private var scrollViewHeight: CGFloat = 0 // 存儲ScrollView高度
    @State private var scrollContentHeight: CGFloat = 0 // 存儲內容高度
    @State private var scrollOffset: CGFloat = 0 // 存儲目前捲動位置
    @State private var showAnalysisCard: Bool = true // State to control showing/hiding the analysis card
    @State private var isEditingMessage: Bool = false // Track if we're currently editing a user message
    @State private var isTextFieldExpanded: Bool = false // Track if the text input field is expanded
    @State private var areIconsCollapsed: Bool = false // Track if the input field icons are collapsed
    
    private let chatService = ChatService(
        mixraiKey: "YOUR_AI_HERE",
        deepseekKey: "YOUR_AI_HERE"
    )
    
    // Add a new function to check if a message is a default or error response
    private func isDefaultOrErrorResponse(_ message: String) -> Bool {
        // Check for error messages
        if message.starts(with: "Error:") || 
           message.contains("API request failed") ||
           message.contains("I'm sorry") ||
           message.contains("I cannot") {
            return true
        }
        
        // Check if the message doesn't contain recipe formatting
        if !message.contains("Recipe Name:") && 
           !message.contains("Ingredients:") && 
           !message.contains("Steps:") {
            // Exception: Welcome message should NOT be considered a default response
            // that needs a refresh button
            if message.contains("Hello! I'm Flavour Chef. How can I help you with recipes today?") {
                return false
            }
            return true
        }
        
        return false
    }
    
    // Add a function to check if a message is the welcome message
    private func isWelcomeMessage(_ message: String) -> Bool {
        return message.contains("Hello! I'm Flavour Chef. How can I help you with recipes today?")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部控制欄
                HStack {
                    Button {
                        withAnimation(.spring()) {
                            sheetDetent = sheetDetent == .medium ? .large : .medium
                        }
                    } label: {
                        Image(systemName: sheetDetent == .medium ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                    
                    // 添加清理按钮
                    Button {
                        resetChat()
                    } label: {
                        Image(systemName: "eraser")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                    .padding(.leading, 4)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 分段選擇器
                Picker("Mode", selection: $selectedTab) {
                    Text("Flavour Chef").tag(0)
                    Text("Nutrition").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if selectedTab == 1 {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Daily Nutrition Intake")
                                .font(.title2)
                                .bold()
                                .padding(.horizontal)
                            
                            if !userSettings.isLoggedIn {
                                Text("Please login to view your nutrition data")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else if !hasTargetData {
                                VStack(spacing: 10) {
                                    Text("No nutrition goals set")
                                        .foregroundColor(.gray)
                                    
                                    NavigationLink(destination: BMRCalculatorView(userUID: userUID)) {
                                        Text("Set Nutrition Goals")
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.orange)
                                            .cornerRadius(10)
                                    }
                                }
                                .padding()
                            } else if let data = nutritionData {
                                NutritionDataView(data: data)
                                    .padding()
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .padding(.top)
                    }
                } else {
                    // AI Chat 視圖內容
                    ZStack(alignment: .bottomTrailing) {
                        VStack {
                            // 聊天記錄
                            ScrollViewReader { proxy in
                                ScrollView {
                                    // 用於檢測滾動位置
                                    GeometryReader { geo in
                                        Color.clear
                                            .preference(key: ScrollViewOffsetKey.self,
                                                      value: geo.frame(in: .named("scrollView")).minY)
                                    }
                                    .frame(height: 0)
                                    
                                    LazyVStack(spacing: 10) {
                                        ForEach(chatMessages) { message in
                                            if message.isUser {
                                                HStack {
                                                    Spacer()
                                                    VStack(alignment: .trailing, spacing: 8) {
                                                        if let image = message.image {
                                                            Image(uiImage: image)
                                                                .resizable()
                                                                .scaledToFit()
                                                                .frame(maxWidth: 200, maxHeight: 200)
                                                                .cornerRadius(10)
                                                        }
                                                        
                                                        Text(message.text)
                                                        .padding()
                                                        .background(Color.orange.opacity(0.2))
                                                        .cornerRadius(15)
                                                        
                                                        // Edit button for user messages
                                                        Button(action: {
                                                            // Store the message text and index for editing
                                                            messageText = message.text 
                                                            // Set editing state to true
                                                            isEditingMessage = true
                                                            
                                                            // Find the index of this message and the response that follows it
                                                            if let userIndex = chatMessages.firstIndex(where: { $0.id == message.id }) {
                                                                // Look for ingredient detection in the original message
                                                                if message.text.contains("ingredients:") || message.text.lowercased().contains("recipe") {
                                                                    // Check if we should restore any previous analysis results
                                                                    if let responseIndex = userIndex + 1 < chatMessages.count ? userIndex + 1 : nil,
                                                                       !chatMessages[responseIndex].isUser {
                                                                        // If this message used ingredient analysis, keep those results available
                                                                        // for regeneration after editing
                                                                        if !acceptedResults.isEmpty {
                                                                            isResultsAccepted = true
                                                                        } else if message.image != nil {
                                                                            // If the message has an image, we'll want to re-analyze it
                                                                            messageImage = message.image
                                                                            // Will automatically analyze in sendMessageWithContext
                                                                        }
                                                                    }
                                                                }
                                                                
                                                                // Remove this message and any AI response that follows it
                                                                if userIndex < chatMessages.count - 1 && !chatMessages[userIndex + 1].isUser {
                                                                    chatMessages.remove(at: userIndex + 1) // Remove AI response
                                                                }
                                                                chatMessages.remove(at: userIndex) // Remove user message
                                                                
                                                                // Keep the image if it exists for regeneration
                                                                messageImage = message.image
                                                            }
                                                            
                                                            // Place cursor in the text field for editing
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                                UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                                                            }
                                                            
                                                            // Add haptic feedback
                                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                                            generator.impactOccurred()
                                                        }) {
                                                            HStack(spacing: 4) {
                                                                Image(systemName: "pencil")
                                                                    .font(.system(size: 12))
                                                                Text("Edit")
                                                                    .font(.caption)
                                                            }
                                                            .foregroundColor(.orange)
                                                            .padding(.vertical, 4)
                                                            .padding(.horizontal, 8)
                                                            .background(Color.orange.opacity(0.1))
                                                            .cornerRadius(10)
                                                        }
                                                    }
                                                    .padding(.leading, 60)
                                                }
                                            } else {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        Text(message.text)
                                                            .padding()
                                                            .background(Color.gray.opacity(0.2))
                                                            .cornerRadius(15)
                                                        
                                                        // Check if it's the welcome message (no buttons at all)
                                                        if isWelcomeMessage(message.text) {
                                                            // Don't show any buttons
                                                        } 
                                                        // Check if the message is a default/error response (only refresh button)
                                                        else if isDefaultOrErrorResponse(message.text) {
                                                            // Only show refresh button for default/error responses
                                                            HStack {
                                                                Button(action: {
                                                                    // If there's a previous user message, resend it
                                                                    if let lastUserMessageIndex = chatMessages.lastIndex(where: { $0.isUser }),
                                                                       let aiResponseIndex = chatMessages.firstIndex(where: { $0.id == message.id }) {
                                                                        
                                                                        // Remove this AI response
                                                                        if aiResponseIndex < chatMessages.count {
                                                                            let _ = chatMessages.remove(at: aiResponseIndex)
                                                                        }
                                                                        
                                                                        // Get the last user message and resend it
                                                                        let userMessage = chatMessages[lastUserMessageIndex].text
                                                                        messageText = userMessage
                                                                        sendMessageWithContext()
                                                                    } else {
                                                                        // If no user message found, just clear this response and show welcome
                                                                        if let index = chatMessages.firstIndex(where: { $0.id == message.id }) {
                                                                            chatMessages.remove(at: index)
                                                                            resetChat()
                                                                        }
                                                                    }
                                                                }) {
                                                                    Circle()
                                                                        .fill(Color.orange)
                                                                        .frame(width: 32, height: 32)
                                                                        .overlay(
                                                                            Image(systemName: "arrow.clockwise")
                                                                                .foregroundColor(.white)
                                                                                .font(.system(size: 16, weight: .bold))
                                                                        )
                                                                }
                                                            }
                                                            .padding(.leading)
                                                        } else {
                                                            // Show all action buttons for recipe responses
                                                            HStack(spacing: 12) {
                                                                Menu {
                                                                    Button(action: {
                                                                        shareToAddRecipe(message: message.text)
                                                                    }) {
                                                                        Label("Share as Recipe", systemImage: "square.and.arrow.up")
                                                                    }
                                                                    
                                                                    Button(action: {
                                                                        startCooking(message: message.text)
                                                                    }) {
                                                                        Label("Start Cooking", systemImage: "fork.knife")
                                                                    }
                                                                } label: {
                                                                    Circle()
                                                                        .fill(Color.orange)
                                                                        .frame(width: 32, height: 32)
                                                                        .overlay(
                                                                            Image(systemName: "arrow.up.forward")
                                                                                .foregroundColor(.white)
                                                                                .font(.system(size: 16, weight: .bold))
                                                                        )
                                                                }
                                                                
                                                                // Add a favorite button
                                                                Button(action: {
                                                                    if !userSettings.isLoggedIn {
                                                                        showLoginAlert = true
                                                                    } else {
                                                                        // Get recipe name from the message
                                                                        if let recipeName = extractRecipeName(from: message.text) {
                                                                            favoriteRecipeName = recipeName
                                                                            recipeMessageToSave = message.text
                                                                            showSaveFavoriteAlert = true
                                                                        } else {
                                                                            favoriteRecipeName = "Saved Recipe"
                                                                            recipeMessageToSave = message.text
                                                                            showSaveFavoriteAlert = true
                                                                        }
                                                                    }
                                                                }) {
                                                                    Circle()
                                                                        .fill(Color.orange)
                                                                        .frame(width: 32, height: 32)
                                                                        .overlay(
                                                                            Image(systemName: "star")
                                                                                .foregroundColor(.white)
                                                                                .font(.system(size: 16, weight: .bold))
                                                                        )
                                                                }
                                                                
                                                                // 編輯按鈕
                                                                Button(action: {
                                                                    editingMessage = message.text
                                                                    editingIndex = chatMessages.firstIndex(where: { $0.id == message.id })
                                                                    parseMessageForEditing(message.text) // 在打開編輯界面前解析消息
                                                                    isEditing = true
                                                                }) {
                                                                    Circle()
                                                                        .fill(Color.orange)
                                                                        .frame(width: 32, height: 32)
                                                                        .overlay(
                                                                            Image(systemName: "pencil")
                                                                                .foregroundColor(.white)
                                                                                .font(.system(size: 16, weight: .bold))
                                                                        )
                                                                }
                                                                
                                                                // 重新生成按鈕
                                                                Button(action: {
                                                                    editingIndex = chatMessages.firstIndex(where: { $0.id == message.id })
                                                                    showRegenerateOptions = true
                                                                }) {
                                                                    Circle()
                                                                        .fill(Color.orange)
                                                                        .frame(width: 32, height: 32)
                                                                        .overlay(
                                                                            Image(systemName: "arrow.clockwise")
                                                                                .foregroundColor(.white)
                                                                                .font(.system(size: 16, weight: .bold))
                                                                        )
                                                                }
                                                            }
                                                            .padding(.leading)
                                                        }
                                                    }
                                                    Spacer()
                                                }
                                            }
                                        }
                                        
                                        if isLoading {
                                            HStack {
                                                ProgressView()
                                                    .padding()
                                                Spacer()
                                            }
                                        }
                                        
                                        // 添加底部標記用於滾動
                                        Color.clear.frame(height: 1).id("bottom")
                                    }
                                }
                                .coordinateSpace(name: "scrollView")
                                .onPreferenceChange(ScrollViewOffsetKey.self) { offset in
                                    // 如果不在底部，顯示向下按鈕
                                    showScrollToBottomButton = offset < -20
                                }
                                .onChange(of: chatMessages.count) { _ in
                                    // 訊息數量變化時，滾動到底部
                                    withAnimation {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("scrollToBottom"))) { _ in
                                    // 收到通知時滾動到底部
                                    withAnimation {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                                .padding()
                            }
                            
                            // 輸入區域和狀態面板
                            VStack(spacing: 12) {
                                // 快捷食譜按鈕
                                HStack(spacing: 12) {
                                    Button(action: {
                                        sendQuickRecipe(prompt: "Give me a recipe")
                                    }) {
                                        Text("Recipe")
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.orange, lineWidth: 1)
                                                    .background(Color.white.cornerRadius(20)))
                                    }
                                    
                                    Button(action: {
                                        sendQuickRecipe(prompt: "Give me a healthy recipe")
                                    }) {
                                        Text("Healthy Recipe")
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.orange, lineWidth: 1)
                                                    .background(Color.white.cornerRadius(20)))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                // 輸入欄
                                VStack {
                                    // Loading animation
                                    if isAnalyzing {
                                        ProgressView("Analyzing...")
                                            .padding(.bottom, 8)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        // Toggle for collapsing all icons
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                areIconsCollapsed.toggle()
                                            }
                                            // If collapsing, dismiss keyboard
                                            if areIconsCollapsed {
                                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                            }
                                        }) {
                                            Image(systemName: areIconsCollapsed ? "chevron.right.circle.fill" : "chevron.left.circle.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 20))
                                        }
                                        
                                        if !areIconsCollapsed {
                                            // Heart button for personalized nutrition
                                            Button(action: {
                                                if !userSettings.isLoggedIn {
                                                    showNutritionAlert = true
                                                    alertMessage = "Please login to use personalized nutrition features."
                                                } else {
                                                    considerPersonalInfo.toggle()
                                                }
                                            }) {
                                                Image(systemName: considerPersonalInfo ? "heart.fill" : "heart")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 20))
                                            }
                                            .transition(.scale.combined(with: .opacity))
                                            
                                            // Image upload button
                                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                                Image(systemName: "plus")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 20))
                                            }
                                            .transition(.scale.combined(with: .opacity))
                                            
                                            // Scroll to bottom button
                                            Button(action: {
                                                NotificationCenter.default.post(name: Notification.Name("scrollToBottom"), object: nil)
                                            }) {
                                                Image(systemName: "arrow.down.to.line")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 20))
                                            }
                                            .transition(.scale.combined(with: .opacity))
                                            
                                            // Text field expansion button
                                            Button(action: {
                                                isTextFieldExpanded.toggle()
                                                if !isTextFieldExpanded {
                                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                                }
                                            }) {
                                                Image(systemName: isTextFieldExpanded ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 20))
                                            }
                                            .transition(.scale.combined(with: .opacity))
                                            
                                            // Cancel button for analysis
                                            if isAnalyzing {
                                                Button(action: {
                                                    isAnalyzing = false
                                                }) {
                                                    Image(systemName: "xmark")
                                                        .foregroundColor(.red)
                                                        .font(.system(size: 20))
                                                }
                                                .transition(.scale.combined(with: .opacity))
                                            }
                                            
                                            // Eye button for personal info panel
                                            if considerPersonalInfo && userSettings.isLoggedIn {
                                                Button(action: {
                                                    showPersonalInfoPanel.toggle()
                                                }) {
                                                    Image(systemName: showPersonalInfoPanel ? "eye.fill" : "eye")
                                                        .foregroundColor(.orange)
                                                        .font(.system(size: 20))
                                                }
                                                .transition(.scale.combined(with: .opacity))
                                            }
                                        }
                                        
                                        // Editing badge
                                        if isEditingMessage {
                                            Text("Editing")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.orange)
                                                .cornerRadius(10)
                                        }
                                        
                                        // Text input field - expanded or normal
                                        if isTextFieldExpanded {
                                            TextEditor(text: $messageText)
                                                .frame(height: 100)
                                                .padding(4)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                                .disabled(isAnalyzing)
                                        } else {
                                            TextField(isEditingMessage ? "Edit message..." : "Ask about nutrition...", text: $messageText)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .disabled(isAnalyzing)
                                        }
                                        
                                        // Send button
                                        Button(action: sendMessageWithContext) {
                                            Image(systemName: "paperplane.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 20))
                                                .overlay(
                                                    Group {
                                                        if isEditingMessage {
                                                            Image(systemName: "arrow.clockwise")
                                                                .foregroundColor(.white)
                                                                .font(.system(size: 12))
                                                                .background(
                                                                    Circle()
                                                                        .fill(Color.orange)
                                                                        .frame(width: 18, height: 18)
                                                                )
                                                                .offset(x: 10, y: -10)
                                                        } else {
                                                            EmptyView()
                                                        }
                                                    }
                                                )
                                        }
                                        .disabled(isLoading || messageText.isEmpty || isAnalyzing)
                                    }
                                    .padding(.horizontal)
                                    
                                    // Show analysis results options if analysis is complete
                                    if !detectionResults.isEmpty {
                                        VStack(alignment: .leading, spacing: 12) {
                                            // Animated card container
                                            VStack(alignment: .leading, spacing: 10) {
                                                // Header row with buttons
                                                HStack(spacing: 8) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.orange)
                                                        .font(.system(size: 20))
                                                    
                                                    Text("Analysis Complete!")
                                                        .font(.headline)
                                                        .foregroundColor(.orange)
                                                    
                                                    Spacer()
                                                    
                                                    // Refresh button
                                                    Button(action: {
                                                        // Trigger re-analysis of the current image
                                                        if let currentImage = uiImage {
                                                            self.uiImage = currentImage
                                                            Task {
                                                                await analyzeImage()
                                                            }
                                                            
                                                            // Add haptic feedback on refresh
                                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                                            generator.impactOccurred()
                                                        }
                                                    }) {
                                                        Image(systemName: "arrow.clockwise.circle.fill")
                                                            .foregroundColor(.orange)
                                                            .font(.system(size: 20))
                                                    }
                                                    .padding(.horizontal, 4)
                                                    
                                                    // Toggle button to show/hide the card content
                                                    Button(action: {
                                                        withAnimation(.spring()) {
                                                            showAnalysisCard.toggle()
                                                        }
                                                        
                                                        // Add haptic feedback when toggled
                                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                                        generator.impactOccurred()
                                                    }) {
                                                        Image(systemName: showAnalysisCard ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                                            .foregroundColor(.orange)
                                                            .font(.system(size: 20))
                                                    }
                                                    .padding(.horizontal, 4)
                                                    
                                                    // Close/Dismiss button
                                                    Button(action: {
                                                        withAnimation(.easeOut) {
                                                            // Clear detection results to dismiss the card
                                                            detectionResults = ""
                                                            acceptedResults = []
                                                            isResultsAccepted = false
                                                        }
                                                        
                                                        // Add haptic feedback for delete action
                                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                                        generator.impactOccurred()
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.orange)
                                                            .font(.system(size: 20))
                                                    }
                                                    .padding(.horizontal, 4)
                                                    
                                                    // Items counter
                                                    Text("\(detectionResults.components(separatedBy: "\n").filter { !$0.isEmpty }.count) items")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3)
                                                        .background(Color.orange.opacity(0.1))
                                                        .cornerRadius(10)
                                                }
                                                
                                                // Collapsible content
                                                if showAnalysisCard {
                                                    VStack(alignment: .leading, spacing: 10) {
                                                        Text("We've analyzed your ingredients. You can view the details or accept the results.")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                            .padding(.bottom, 4)
                                                        
                                                        HStack(spacing: 15) {
                                                            Button(action: {
                                                                // Show detailed results for editing
                                                                filteredResults = detectionResults.components(separatedBy: "\n").filter { !$0.isEmpty }
                                                                showDetailedResults = true
                                                            }) {
                                                                HStack {
                                                                    Image(systemName: "list.bullet.rectangle")
                                                                        .font(.system(size: 14))
                                                                    Text("View Details")
                                                                }
                                                                .foregroundColor(.orange)
                                                                .padding(.horizontal, 16)
                                                                .padding(.vertical, 8)
                                                                .background(Color.orange.opacity(0.1))
                                                                .cornerRadius(8)
                                                            }
                                                            
                                                            Spacer()
                                                            
                                                            if isResultsAccepted {
                                                                Button(action: {
                                                                    // Navigate to the edit view
                                                                    showDetailedResults = true
                                                                }) {
                                                                    HStack {
                                                                        Image(systemName: "pencil")
                                                                            .font(.system(size: 14))
                                                                        Text("Modify")
                                                                    }
                                                                    .foregroundColor(.orange)
                                                                    .padding(.horizontal, 16)
                                                                    .padding(.vertical, 8)
                                                                    .background(Color.orange.opacity(0.1))
                                                                    .cornerRadius(8)
                                                                }
                                                            } else {
                                                                Button(action: {
                                                                    // Accept the results
                                                                    acceptedResults = detectionResults.components(separatedBy: "\n").filter { !$0.isEmpty }
                                                                    isResultsAccepted = true // Set results as accepted
                                                                    
                                                                    // Add a subtle haptic feedback
                                                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                                                    generator.impactOccurred()
                                                                }) {
                                                                    HStack {
                                                                        Image(systemName: "checkmark")
                                                                            .font(.system(size: 14))
                                                                        Text("Accept")
                                                                    }
                                                                    .foregroundColor(.white)
                                                                    .padding(.horizontal, 16)
                                                                    .padding(.vertical, 8)
                                                                    .background(Color.orange)
                                                                    .cornerRadius(8)
                                                                }
                                                            }
                                                        }
                                                    }
                                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                                }
                                            }
                                            .padding(16)
                                            .background(Color(UIColor.systemBackground))
                                            .cornerRadius(12)
                                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                            )
                                            .padding(.horizontal)
                                            .padding(.top, 12)
                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: !detectionResults.isEmpty)
                                        }
                                    }
                                }
                                
                                // 個人信息面板 (合併營養和過敏)
                                if considerPersonalInfo && showPersonalInfoPanel && userSettings.isLoggedIn {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Personal Information")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            
                                            // 感嘆號按鈕（提示信息）
                                            Button(action: { 
                                                filterAlertMessage = "Filters only affect current view, not your actual data. Use the red minus buttons to hide specific data, or use the refresh button to reset all filters."
                                                showFilterAlert = true
                                            }) {
                                                Image(systemName: "info.circle")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.trailing, 8)
                                            
                                            // 刷新按鈕
                                            Button(action: { 
                                                resetAllFilters()
                                            }) {
                                                Image(systemName: "arrow.clockwise")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.trailing, 8)
                                            
                                            Button(action: { showPersonalInfoPanel.toggle() }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        // 添加說明文字
                                        Text("Filters only affect current view, not your actual data.")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                            .padding(.bottom, 4)
                                        
                                        if let data = nutritionData {
                                            HStack {
                                                Text("Nutrition Status:")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                Spacer()
                                                
                                                // 整部分刪除按鈕
                                                Button(action: {
                                                    hideCalories = true
                                                    hideCarbs = true
                                                    hideProtein = true
                                                    hideFat = true
                                                }) {
                                                    Image(systemName: "minus.circle")
                                                        .foregroundColor(.red)
                                                        .font(.caption)
                                                }
                                            }
                                            
                                            if !hideCalories {
                                                HStack {
                                                    Text("Calories: \(Int(data.ingested))/\(Int(data.ingestion)) kcal")
                                                        .font(.caption)
                                                    Spacer()
                                                    Button(action: {
                                                        hideCalories = true
                                                    }) {
                                                        Image(systemName: "minus.circle")
                                                            .foregroundColor(.red)
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                            
                                            if !hideCarbs {
                                                HStack {
                                                    Text("Carbs: \(data.carbsIngested)/\(data.carbs)g")
                                                        .font(.caption)
                                                    Spacer()
                                                    Button(action: {
                                                        hideCarbs = true
                                                    }) {
                                                        Image(systemName: "minus.circle")
                                                            .foregroundColor(.red)
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                            
                                            if !hideProtein {
                                                HStack {
                                                    Text("Protein: \(data.proteinIngested)/\(data.protein)g")
                                                        .font(.caption)
                                                    Spacer()
                                                    Button(action: {
                                                        hideProtein = true
                                                    }) {
                                                        Image(systemName: "minus.circle")
                                                            .foregroundColor(.red)
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                            
                                            if !hideFat {
                                                HStack {
                                                    Text("Fat: \(data.fatIngested)/\(data.fat)g")
                                                        .font(.caption)
                                                    Spacer()
                                                    Button(action: {
                                                        hideFat = true
                                                    }) {
                                                        Image(systemName: "minus.circle")
                                                            .foregroundColor(.red)
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                            
                                            HStack {
                                                Text("Monthly Exceeded Counts:")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                    .padding(.top, 4)
                                                Spacer()
                                                
                                                // 整部分刪除按鈕
                                                Button(action: {
                                                    hideCarbsExceeded = true
                                                    hideProteinExceeded = true
                                                    hideFatExceeded = true
                                                    hideTotalExceeded = true
                                                }) {
                                                    Image(systemName: "minus.circle")
                                                        .foregroundColor(.red)
                                                        .font(.caption)
                                                }
                                                .padding(.top, 4)
                                            }
                                            
                                            if !hideCarbsExceeded {
                                                HStack {
                                                    Text("Carbs exceeded: \(data.carbsExceededCount) times")
                                                        .font(.caption)
                                                    Spacer()
                                                    Button(action: {
                                                        hideCarbsExceeded = true
                                                    }) {
                                                        Image(systemName: "minus.circle")
                                                            .foregroundColor(.red)
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                            
                                            if !hideProteinExceeded {
                                                HStack {
                                                    Text("Protein exceeded: \(data.proteinExceededCount) times")
                                                        .font(.caption)
                                                    Spacer()
                                                    Button(action: {
                                                        hideProteinExceeded = true
                                                    }) {
                                                        Image(systemName: "minus.circle")
                                                            .foregroundColor(.red)
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                            
                                            if !hideFatExceeded {
                                                HStack {
                                                    Text("Fat exceeded: \(data.fatExceededCount) times")
                                                        .font(.caption)
                                                    Spacer()
                                                    Button(action: {
                                                        hideFatExceeded = true
                                                    }) {
                                                        Image(systemName: "minus.circle")
                                                            .foregroundColor(.red)
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                            
                                            if !hideTotalExceeded {
                                                HStack {
                                                    Text("Total calories exceeded: \(data.totalIngestedExceededCount) times")
                                                        .font(.caption)
                                                    Spacer()
                                                    Button(action: {
                                                        hideTotalExceeded = true
                                                    }) {
                                                        Image(systemName: "minus.circle")
                                                            .foregroundColor(.red)
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        if !allergyData.isEmpty && !hideAllergies {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text("Allergies:")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .padding(.top, 4)
                                                    
                                                    Text(allergyData.joined(separator: ", "))
                                                        .font(.caption)
                                                }
                                                Spacer()
                                                Button(action: {
                                                    hideAllergies = true
                                                }) {
                                                    Image(systemName: "minus.circle")
                                                        .foregroundColor(.red)
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .padding(.vertical)
                        }
                        
                        // 向下滾動按鈕
                        if showScrollToBottomButton {
                            Button(action: {
                                // 發送滾動通知
                                NotificationCenter.default.post(name: Notification.Name("scrollToBottom"), object: nil)
                            }) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                    )
                                    .shadow(radius: 2)
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 80)
                            .transition(.opacity)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("scrollToBottom"))) { _ in
                // Find scrollProxy and scroll
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        // This is a workaround using NotificationCenter since we can't directly access scrollProxy
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showFilterAlert) {
                Alert(
                    title: Text("Data Filter Notice"),
                    message: Text("\(filterAlertMessage)\n\nNote: This operation only temporarily removes data from AI consideration and does not delete your actual data."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showAddRecipe) {
                if let data = recipeToShare {
                    AddRecipeView(
                        recipeName: data.recipeName,
                        description: data.description,
                        ingredients: data.ingredients,
                        steps: data.steps,
                        requiredNutritions: data.requiredNutritions
                    )
                    .environmentObject(userSettings)
                }
            }
            .sheet(isPresented: $showCookingSteps) {
                if let data = cookingRecipeData {
                    CookingStepsForAIChat(
                        ingredients: data.ingredients,
                        steps: data.steps,
                        nutritions: data.nutritions,
                        aiResponse: chatMessages.last?.text ?? "",
                        recipeKnowledgeForKnowledge: recipeKnowledge,
                        customStepsForKnowledge: optimizedSteps.isEmpty ? nil : optimizedSteps
                    )
                }
            }
            .sheet(isPresented: $isEditing) {
                NavigationView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // 食譜名稱
                            VStack(alignment: .leading) {
                                Text("Recipe Name")
                                    .font(.headline)
                                    .foregroundColor(Color.orange.opacity(0.8))
                                
                                TextField("Recipe Name", text: $editingRecipeName)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            
                            // 說明
                            VStack(alignment: .leading) {
                                Text("Description")
                                    .font(.headline)
                                    .foregroundColor(Color.orange.opacity(0.8))
                                
                                TextEditor(text: $editingDescription)
                                    .frame(height: 100)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            
                            // 食材
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Ingredients")
                                        .font(.headline)
                                        .foregroundColor(Color.orange.opacity(0.8))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        editingIngredients.append(("", ""))
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                ForEach(editingIngredients.indices, id: \.self) { index in
                                    HStack {
                                        TextField("Ingredient Name", text: Binding(
                                            get: { editingIngredients[index].0 },
                                            set: { editingIngredients[index].0 = $0 }
                                        ))
                                        .padding(10)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        
                                        Text(":")
                                        
                                        TextField("Quantity (e.g. 2 tbsp)", text: Binding(
                                            get: { editingIngredients[index].1 },
                                            set: { editingIngredients[index].1 = $0 }
                                        ))
                                        .padding(10)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        
                                        Button(action: {
                                            editingIngredients.remove(at: index)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // 步驟
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Steps")
                                        .font(.headline)
                                        .foregroundColor(Color.orange.opacity(0.8))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        editingSteps.append("")
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                ForEach(editingSteps.indices, id: \.self) { index in
                                    HStack(alignment: .top) {
                                        Text("\(index + 1).")
                                            .padding(.top, 10)
                                        
                                        TextEditor(text: Binding(
                                            get: { editingSteps[index] },
                                            set: { editingSteps[index] = $0 }
                                        ))
                                        .frame(height: 80)
                                        .padding(10)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        
                                        Button(action: {
                                            editingSteps.remove(at: index)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.top, 10)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // 營養
                            VStack(alignment: .leading) {
                                Text("Nutrition Facts")
                                    .font(.headline)
                                    .foregroundColor(Color.orange.opacity(0.8))
                                
                                ForEach(editingNutritions.indices, id: \.self) { index in
                                    HStack {
                                        Text(editingNutritions[index].0)
                                            .frame(width: 150, alignment: .leading)
                                            .foregroundColor(Color.orange.opacity(0.7))
                                        
                                        TextField("Value", text: Binding(
                                            get: { editingNutritions[index].1 },
                                            set: { editingNutritions[index].1 = $0 }
                                        ))
                                        .padding(10)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    .navigationTitle("Edit Recipe")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                isEditing = false
                            }
                            .foregroundColor(.orange)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                if let index = editingIndex {
                                    // 構建更新後的食譜文本，使用更標準的格式
                                    var updatedText = "Recipe Name: \(editingRecipeName)\n\n"
                                    updatedText += "Description: \(editingDescription)\n\n"
                                    
                                    updatedText += "Ingredients:\n"
                                    for (name, amount) in editingIngredients {
                                        if !name.isEmpty {
                                            // 如果有數量信息，正確格式化顯示
                                            if !amount.isEmpty {
                                                updatedText += "- \(amount) \(name)\n"
                                            } else {
                                                updatedText += "- \(name)\n"
                                            }
                                        }
                                    }
                                    
                                    updatedText += "\nSteps:\n"
                                    for (index, step) in editingSteps.enumerated() {
                                        if !step.isEmpty {
                                            updatedText += "\(index + 1). \(step)\n"
                                        }
                                    }
                                    
                                    updatedText += "\nNutrition:\n"
                                    for (name, value) in editingNutritions {
                                        // 只添加有值的營養信息
                                        if !value.isEmpty {
                                            updatedText += "- \(name): \(value)\n"
                                        }
                                    }
                                    
                                    // 更新聊天消息
                                    chatMessages[index] = ChatMessage(isUser: false, text: updatedText)
                                }
                                isEditing = false
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
                .accentColor(.orange)  // Add accent color to NavigationView
            }
            .sheet(isPresented: $showRegenerateOptions) {
                NavigationView {
                    VStack {
                        TextField("Enter your preferences (e.g., more spicy)", text: $regeneratePrompt)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                        
                        Button(action: {
                            if let index = editingIndex {
                                let originalMessage = chatMessages[index].text
                                regenerateRecipe(originalMessage: originalMessage, preferences: regeneratePrompt)
                            }
                            showRegenerateOptions = false
                        }) {
                            Text("Regenerate")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                        .padding()
                        
                        Button(action: {
                            if let index = editingIndex {
                                regenerateRecipe(originalMessage: chatMessages[index].text, preferences: "")
                            }
                            showRegenerateOptions = false
                        }) {
                            Text("Just Regenerate")
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.orange, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .navigationTitle("Regenerate Recipe")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showRegenerateOptions = false
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
                .accentColor(.orange)  // Add accent color to NavigationView
            }
            .sheet(isPresented: $showDetailedResults) {
                // View for editing detailed results
                NavigationView {
                    VStack {
                        HStack {
                            Text("Filtered Results")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                // Add a new empty row
                                filteredResults.append("")
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 24))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        
                        List {
                            // First item is the header, make it non-editable
                            if !filteredResults.isEmpty {
                                Text(filteredResults[0])
                                    .foregroundColor(.gray)
                                    .listRowBackground(Color(.systemGray6))
                            }
                            
                            // The rest are editable items with delete buttons
                            ForEach(filteredResults.indices.dropFirst(), id: \.self) { index in
                                HStack {
                                    // Create a binding separately for each TextField
                                    let binding = Binding<String>(
                                        get: { self.filteredResults[index] },
                                        set: { self.filteredResults[index] = $0 }
                                    )
                                    
                                    // Use the binding with the TextField
                                    TextField("Result", text: binding)
                                    
                                    Spacer()
                                    
                                    // Delete button
                                    Button(action: {
                                        // Remove this item
                                        filteredResults.remove(at: index)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 20))
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                // Skip the first item (header) when deleting
                                let adjustedIndexSet = IndexSet(indexSet.map { $0 })
                                filteredResults.remove(atOffsets: adjustedIndexSet)
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                        
                        Button("Save") {
                            // Logic to save the edited results
                            detectionResults = filteredResults.joined(separator: "\n")
                            showDetailedResults = false
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                    }
                    .navigationTitle("Edit Results")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showDetailedResults = false
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
                .accentColor(.orange)  // Add accent color to NavigationView
            }
            .alert("Save as Favorite", isPresented: $showSaveFavoriteAlert) {
                TextField("Recipe Name", text: $favoriteRecipeName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    saveAsFavorite(recipeName: favoriteRecipeName, message: recipeMessageToSave)
                }
            } message: {
                Text("This recipe will be saved to your favorites and can be accessed from the Likes tab.")
            }
            .alert("Login Required", isPresented: $showLoginAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Login") {
                    // Navigate to login screen (we'll use the existing ProfileView for login)
                    selectedTab = 1  // Switch to the Nutrition tab which has a login prompt
                }
            } message: {
                Text("Please login to save favorites.")
            }
            .overlay {
                if isProcessingRecipeSteps {
                    ZStack {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text(recipeKnowledge ? "Optimizing recipe steps..." : "Creating detailed instructions...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(20)
                        .background(Color.secondary.opacity(0.8))
                        .cornerRadius(10)
                    }
                }
            }
            .sheet(isPresented: $showRecipeFamiliaritySelection) {
                RecipeFamiliaritySelectionView(
                    recipeKnowledge: $recipeKnowledge,
                    originalRecipeSteps: originalSteps,
                    useDefaultFlavor: .constant(true), // Default to true, since we don't have a state for it yet
                    isShowing: $showRecipeFamiliaritySelection,
                    onCompletion: { processedSteps in
                        guard let data = cookingRecipeData else { return }
                        
                        // Update the steps with the processed ones
                        cookingRecipeData = (
                            ingredients: data.ingredients,
                            steps: processedSteps,
                            nutritions: data.nutritions
                        )
                        
                        // Now show the cooking view
                        showCookingSteps = true
                    }
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            sheetDetent = .large
            if userSettings.isLoggedIn {
                fetchNutritionData()
                fetchAllergyData()
            }
            
            // 從 UserDefaults 讀取聊天記錄
            loadChatHistory()
        }
        .onDisappear {
            // 保存聊天記錄到 UserDefaults
            saveChatHistory()
        }
        .alert("Notice", isPresented: $showNutritionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    self.uiImage = uiImage
                    self.messageImage = uiImage // Store the image for the current message
                    selectedImage = Image(uiImage: uiImage)
                    showThumbnail = false // Remove thumbnail display
                    await analyzeImage() // Call the analyze function
                }
            }
        }
    }
    
    // 保存聊天記錄到 UserDefaults
    private func saveChatHistory() {
        do {
            // 創建不包含圖片的聊天消息副本
            let messagesToSave = chatMessages.map { message -> ChatMessage in
                // 創建新的消息對象，但不包含圖片
                return ChatMessage(isUser: message.isUser, text: message.text)
            }
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(messagesToSave)
            
            // 如果用戶已登入，使用UID作為key，否則使用通用key
            let storageKey = userSettings.isLoggedIn ? "chatHistory_\(userUID)" : "chatHistory_guest"
            UserDefaults.standard.set(data, forKey: storageKey)
            print("聊天記錄已保存")
        } catch {
            print("無法保存聊天記錄: \(error)")
        }
    }
    
    // 從 UserDefaults 讀取聊天記錄
    private func loadChatHistory() {
        // 如果用戶已登入，使用UID作為key，否則使用通用key
        let storageKey = userSettings.isLoggedIn ? "chatHistory_\(userUID)" : "chatHistory_guest"
        
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                chatMessages = try decoder.decode([ChatMessage].self, from: data)
                print("已加載 \(chatMessages.count) 條聊天記錄")
            } catch {
                print("無法讀取聊天記錄: \(error)")
            }
        }
    }
    
    // 重置所有過濾器
    private func resetAllFilters() {
        hideCalories = false
        hideCarbs = false
        hideProtein = false
        hideFat = false
        hideCarbsExceeded = false
        hideProteinExceeded = false
        hideFatExceeded = false
        hideTotalExceeded = false
        hideAllergies = false
    }
    
    private func sendMessageWithContext() {
        // Check if user is trying to use personalized features without login
        if considerPersonalInfo && !userSettings.isLoggedIn {
            showNutritionAlert = true
            alertMessage = "Please login to use personalized nutrition features."
            considerPersonalInfo = false // Reset the heart icon
            return
        }
        
        // For logged-in users who want to use personalized features
        if considerPersonalInfo && userSettings.isLoggedIn {
            if !hasTargetData && !hasAllergyData {
                showNutritionAlert = true
                alertMessage = "Please set your nutrition goals or allergy information in Profile first."
                return
            }
        }

        // Log accepted results if any
        if isResultsAccepted {
            print("Accepted Results: \(acceptedResults.joined(separator: ", "))")
        }

        // Log user input
        print("User Input: \(messageText)")
        
        // Combine detection results with user input but do not display detection results in UI
        let combinedMessage: String
        if isResultsAccepted && !acceptedResults.isEmpty {
            combinedMessage = "\(messageText)\n\nPlease ensure the recipe contains at least 80% of these ingredients:\n\(acceptedResults.joined(separator: ", "))"
        } else {
            combinedMessage = messageText
        }
        
        // Log the combined message to the console
        print("Sending message to AI: \(combinedMessage)")
        
        var contextMessage = """
        Please provide a recipe in the following format:
        
        Recipe Name:
        Description:
        
        Ingredients:
        - [quantity with unit] [ingredient name]: [additional description if needed]
        (Examples:
        - 2 tbsp olive oil
        - 1 cup milk
        - 3 cloves garlic, minced
        - 1/2 tsp salt)
        
        Steps:
        1. step1
        2. step2
        
        Nutrition:
        - Calories: xxx kcal
        - Carbohydrates: xxx g
        - Protein: xxx g
        - Fat: xxx g
        
        """
        
        // 如果有接受的食材分析結果，添加特殊指示
        if isResultsAccepted && !acceptedResults.isEmpty {
            contextMessage += """
            Important Requirements:
            1. The recipe MUST use at least 80% of these ingredients: \(acceptedResults.joined(separator: ", "))
            2. If any of these ingredients cannot be used, please explain why in the description.
            3. You may add additional ingredients as needed, but the focus should be on using the detected ingredients.
            
            """
        }
        
        contextMessage += "User's question: \(combinedMessage)\n"
        
        // Only add personal information if user is logged in and has enabled it
        if considerPersonalInfo && userSettings.isLoggedIn {
            if hasTargetData, let data = nutritionData {
                var nutritionText = "\n\nUser's current nutrition status:\n"
                var hasNutritionData = false
                
                if !hideCalories {
                    nutritionText += "Calories: \(Int(data.ingested))/\(Int(data.ingestion)) kcal\n"
                    hasNutritionData = true
                }
                
                if !hideCarbs {
                    nutritionText += "Carbs: \(data.carbsIngested)/\(data.carbs)g\n"
                    hasNutritionData = true
                }
                
                if !hideProtein {
                    nutritionText += "Protein: \(data.proteinIngested)/\(data.protein)g\n"
                    hasNutritionData = true
                }
                
                if !hideFat {
                    nutritionText += "Fat: \(data.fatIngested)/\(data.fat)g\n"
                    hasNutritionData = true
                }
                
                if hasNutritionData {
                    contextMessage += nutritionText
                }
                
                var exceededText = "\nMonthly exceeded counts:\n"
                var hasExceededData = false
                
                if !hideCarbsExceeded {
                    exceededText += "Carbs exceeded: \(data.carbsExceededCount) times\n"
                    hasExceededData = true
                }
                
                if !hideProteinExceeded {
                    exceededText += "Protein exceeded: \(data.proteinExceededCount) times\n"
                    hasExceededData = true
                }
                
                if !hideFatExceeded {
                    exceededText += "Fat exceeded: \(data.fatExceededCount) times\n"
                    hasExceededData = true
                }
                
                if !hideTotalExceeded {
                    exceededText += "Total calories exceeded: \(data.totalIngestedExceededCount) times\n"
                    hasExceededData = true
                }
                
                if hasExceededData {
                    contextMessage += exceededText
                    contextMessage += "\nPlease consider these exceeded counts when suggesting recipes. If a nutrient has been exceeded frequently, suggest recipes with lower amounts of that nutrient.\n"
                }
            }
            
            if hasAllergyData && !allergyData.isEmpty && !hideAllergies {
                contextMessage += """
                
                User's allergy information:
                Allergic to: \(allergyData.joined(separator: ", "))
                Please avoid these ingredients in the recipe.
                """
            }
        }
        
        // Store the messages for potential retries
        lastUserMessage = messageText
        lastContextMessage = contextMessage
        
        // Reset retry count for new message
        apiRetryCount = 0
        
        // Send message with image if available
        chatMessages.append(ChatMessage(isUser: true, text: messageText, image: messageImage))
        messageText = ""
        isLoading = true
        
        // Clear the message image after sending
        let currentImage = messageImage
        messageImage = nil
        
        // Reset editing mode
        isEditingMessage = false
        
        // Call the sendMessageToAI function with retry logic
        sendMessageToAI(contextMessage: contextMessage)
        
        // Clear image analysis results after sending the message
        // This ensures the next message won't use the same analysis results
        detectionResults = ""
        acceptedResults = []
        isResultsAccepted = false
        
        // After adding the message, post notification to scroll to bottom
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: Notification.Name("scrollToBottom"), object: nil)
        }
    }
    
    private func sendMessageToAI(contextMessage: String) {
        Task {
            isLoading = true
            lastContextMessage = contextMessage
            
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: selectedProvider)
                await MainActor.run {
                    chatMessages.append(ChatMessage(isUser: false, text: response))
                    print("AI response: \(response)")
                    isLoading = false
                    // Reset retry count on success
                    apiRetryCount = 0
                    
                    // 添加滾動到底部的功能
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: Notification.Name("scrollToBottom"), object: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = error.localizedDescription
                    
                    // Check if it's an API error
                    if errorMessage.contains("API error") {
                        print("Error: \(errorMessage)")
                        
                        // Increment retry count
                        apiRetryCount += 1
                        
                        if apiRetryCount < maxRetryAttempts {
                            // Retry the API call
                            print("Retrying API call (Attempt \(apiRetryCount) of \(maxRetryAttempts))...")
                            sendMessageToAI(contextMessage: lastContextMessage)
                        } else {
                            // Max retries reached, show error to user
                            print("Max retries reached. Showing error to user.")
                            chatMessages.append(ChatMessage(isUser: false, text: "Error: API request failed after multiple attempts. Please try again later."))
                            isLoading = false
                            apiRetryCount = 0
                            
                            // 添加滾動到底部的功能
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: Notification.Name("scrollToBottom"), object: nil)
                            }
                        }
                    } else {
                        // For other errors, show immediately
                        chatMessages.append(ChatMessage(isUser: false, text: "Error: " + errorMessage))
                        isLoading = false
                        
                        // 添加滾動到底部的功能
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: Notification.Name("scrollToBottom"), object: nil)
                        }
                    }
                }
            }
        }
    }
    
    private func fetchNutritionData() {
        let db = Firestore.firestore()
        db.collection("User").document(userUID)
            .collection("target").document("current")
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching target data: \(error?.localizedDescription ?? "Unknown error")")
                    self.hasTargetData = false
                    return
                }
                
                if let data = document.data() {
                    // 檢查是否有有效的目標值
                    let ingestion = data["Ingestion"] as? Double ?? 0
                    self.hasTargetData = ingestion > 0
                    
                    if self.hasTargetData {
                        self.nutritionData = TargetData(
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
                    self.hasTargetData = false
                }
            }
    }
    
    private func fetchAllergyData() {
        let db = Firestore.firestore()
        db.collection("User").document(userUID)
            .collection("allergy")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching allergy data: \(error)")
                    self.hasAllergyData = false
                    return
                }
                
                self.allergyData = snapshot?.documents.compactMap { doc in
                    doc.data()["allergen"] as? String
                } ?? []
                
                self.hasAllergyData = !self.allergyData.isEmpty
            }
    }
    
    // 修改分享函數
    private func shareToAddRecipe(message: String) {
        // 移除 "Assistant: " 前綴
        let content = message.replacingOccurrences(of: "Assistant: ", with: "")
        
        // 解析食譜內容
        var recipeName = ""
        var description = ""
        var ingredients: [AddRecipeView.Ingredient] = []
        var steps: [String] = []
        var allNutritions: [AddRecipeView.Nutrition] = []
        
        // 分析內容並提取信息
        let lines = content.components(separatedBy: .newlines)
        var currentSection = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty { continue }
            
            // 檢測段落
            if trimmedLine.lowercased().contains("recipe:") || trimmedLine.lowercased().contains("recipe name:") {
                currentSection = "name"
                recipeName = trimmedLine.replacingOccurrences(of: "Recipe:", with: "")
                    .replacingOccurrences(of: "Recipe Name:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                continue
            } else if trimmedLine.lowercased().contains("description:") {
                currentSection = "description"
                continue
            } else if trimmedLine.lowercased().contains("ingredients:") {
                currentSection = "ingredients"
                continue
            } else if trimmedLine.lowercased().contains("instructions:") || trimmedLine.lowercased().contains("steps:") {
                currentSection = "steps"
                continue
            } else if trimmedLine.lowercased().contains("nutrition:") || trimmedLine.lowercased().contains("nutritional information:") {
                currentSection = "nutrition"
                continue
            }
            
            // 根據當前段落處理內容
            switch currentSection {
            case "description":
                description += trimmedLine + " "
                
            case "ingredients":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    
                    // 首先檢查是否按冒號分隔 (例如 "橄欖油: 2 湯匙")
                    if cleanLine.contains(":") {
                    let parts = cleanLine.split(separator: ":", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                            let name = parts[0].trimmingCharacters(in: .whitespaces)
                            let value = parts[1].trimmingCharacters(in: .whitespaces)
                            ingredients.append(AddRecipeView.Ingredient(name: name, value: value))
                        }
                    } else {
                        // 嘗試匹配常見的食材格式如 "2 tbsp olive oil" -> 將 "olive oil" 作為名稱，"2 tbsp" 作為數量
                        let pattern = "^([0-9¼½¾⅓⅔⅛⅜⅝⅞.]+\\s*(?:cup|cups|tbsp|tsp|tablespoon|tablespoons|teaspoon|teaspoons|oz|ounce|ounces|pound|pounds|lb|lbs|g|kg|ml|l|pinch|dash|to taste|bunch|bunches))\\s+(.+)$"
                        
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                            let nsString = cleanLine as NSString
                            let matches = regex.matches(in: cleanLine, options: [], range: NSRange(location: 0, length: nsString.length))
                            
                            if let match = matches.first {
                                let amountRange = match.range(at: 1)
                                let nameRange = match.range(at: 2)
                                
                                if amountRange.location != NSNotFound && nameRange.location != NSNotFound {
                                    let amount = nsString.substring(with: amountRange).trimmingCharacters(in: .whitespaces)
                                    let name = nsString.substring(with: nameRange).trimmingCharacters(in: .whitespaces)
                                    ingredients.append(AddRecipeView.Ingredient(name: name, value: amount))
                                } else {
                                    // 如果正則表達式匹配失敗，視為沒有明確數量的食材
                                    ingredients.append(AddRecipeView.Ingredient(name: cleanLine, value: "1"))
                                }
                            } else {
                                // 如果沒有匹配到標準格式，嘗試分割數量和名稱
                                let components = cleanLine.components(separatedBy: " ")
                                if components.count > 1, let first = components.first, first.rangeOfCharacter(from: .decimalDigits) != nil {
                                    // 假設第一個單詞是數量
                                    var amount = first
                                    var nameStartIndex = 1
                                    
                                    // 檢查第二個單詞是否是單位 (tbsp, cup 等)
                                    if components.count > 2 {
                                        let units = ["cup", "cups", "tbsp", "tsp", "tablespoon", "tablespoons", "teaspoon", "teaspoons", "oz", "ounce", "ounces", "pound", "pounds", "lb", "lbs", "g", "kg", "ml", "l"]
                                        if units.contains(components[1].lowercased()) {
                                            amount += " " + components[1]
                                            nameStartIndex = 2
                                        }
                                    }
                                    
                                    let name = components[nameStartIndex...].joined(separator: " ")
                                    ingredients.append(AddRecipeView.Ingredient(name: name, value: amount))
                                } else {
                                    // 無法識別數量，整行作為名稱，默認數量為 "1"
                                    ingredients.append(AddRecipeView.Ingredient(name: cleanLine, value: "1"))
                                }
                            }
                        } else {
                            // 正則表達式失敗，將整行作為名稱
                            ingredients.append(AddRecipeView.Ingredient(name: cleanLine, value: "1"))
                        }
                    }
                }
                
            case "steps":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    steps.append(cleanLine)
                } else if let number = trimmedLine.first, number.isNumber {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^\\d+\\.?\\s*", with: "", options: .regularExpression)
                    steps.append(cleanLine)
                } else {
                    // 如果沒有標號，但在步驟部分，視為步驟
                    steps.append(trimmedLine)
                }
                
            case "nutrition":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    let parts = cleanLine.split(separator: ":", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        let nutritionName = parts[0].trimmingCharacters(in: .whitespaces)
                        var nutritionValue = parts[1].trimmingCharacters(in: .whitespaces)
                        
                        // 清理營養值中的單位
                        nutritionValue = nutritionValue
                            .replacingOccurrences(of: "kcal", with: "")
                            .replacingOccurrences(of: "g", with: "")
                            .replacingOccurrences(of: "mg", with: "")
                            .replacingOccurrences(of: "mcg", with: "")
                            .replacingOccurrences(of: "IU", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        
                        allNutritions.append(AddRecipeView.Nutrition(name: nutritionName, value: nutritionValue))
                    }
                }
                
            default:
                break
            }
        }
        
        // 如果沒有找到步驟，嘗試將整個內容作為步驟
        if steps.isEmpty {
            steps = [content]
        }
        
        // 確保至少包含基本營養成分
        let basicNutritions = ["Calories", "Carbohydrates", "Protein", "Fat"]
        for nutrition in basicNutritions {
            if !allNutritions.contains(where: { $0.name == nutrition }) {
                allNutritions.append(AddRecipeView.Nutrition(name: nutrition, value: ""))
            }
        }
        
        // 打印調試信息
        print("解析的食譜數據:")
        print("名稱: \(recipeName)")
        print("描述: \(description)")
        print("食材數量: \(ingredients.count)")
        ingredients.forEach { ingredient in
            print("- 食材名稱: \(ingredient.name), 數量: \(ingredient.value)")
        }
        print("步驟數量: \(steps.count)")
        print("營養成分數量: \(allNutritions.count)")
        
        // 設置要分享的食譜數據，確保食材元素有正確的名稱和數量
        recipeToShare = AddRecipeView.RecipeData(
            recipeName: recipeName,
            description: description,
            ingredients: ingredients.isEmpty ? [AddRecipeView.Ingredient(name: "", value: "")] : ingredients,
            steps: steps,
            requiredNutritions: allNutritions
        )
        
        // 直接設置 showAddRecipe 為 true
        showAddRecipe = true
    }
    
    private func startCooking(message: String) {
        // Save original steps for AI processing
        originalSteps = []
        optimizedSteps = []
        
        // Use existing parsing logic to get recipe data
        let content = message.replacingOccurrences(of: "Assistant: ", with: "")
        
        var recipeName = ""
        var description = ""
        var ingredients: [AddRecipeView.Ingredient] = []
        var steps: [String] = []
        var allNutritions: [AddRecipeView.Nutrition] = []
        
        // Analyze content and extract information
        let lines = content.components(separatedBy: .newlines)
        var currentSection = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty { continue }
            
            // Detect sections
            if trimmedLine.lowercased().contains("recipe:") || trimmedLine.lowercased().contains("recipe name:") {
                currentSection = "name"
                recipeName = trimmedLine.replacingOccurrences(of: "Recipe:", with: "")
                    .replacingOccurrences(of: "Recipe Name:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                continue
            } else if trimmedLine.lowercased().contains("description:") {
                currentSection = "description"
                continue
            } else if trimmedLine.lowercased().contains("ingredients:") {
                currentSection = "ingredients"
                continue
            } else if trimmedLine.lowercased().contains("instructions:") || trimmedLine.lowercased().contains("steps:") {
                currentSection = "steps"
                continue
            } else if trimmedLine.lowercased().contains("nutrition:") || trimmedLine.lowercased().contains("nutritional information:") {
                currentSection = "nutrition"
                continue
            }
            
            // Process content based on current section
            switch currentSection {
            case "description":
                description += trimmedLine + " "
                
            case "ingredients":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    let parts = cleanLine.split(separator: ":", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        ingredients.append(AddRecipeView.Ingredient(name: parts[0].trimmingCharacters(in: .whitespaces),
                                                                 value: parts[1].trimmingCharacters(in: .whitespaces)))
                    } else {
                        ingredients.append(AddRecipeView.Ingredient(name: cleanLine.trimmingCharacters(in: .whitespaces),
                                                                 value: ""))
                    }
                }
                
            case "steps":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    steps.append(cleanLine)
                    originalSteps.append(cleanLine) // Save original step
                } else if let number = trimmedLine.first, number.isNumber {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^\\d+\\.?\\s*", with: "", options: .regularExpression)
                    steps.append(cleanLine)
                    originalSteps.append(cleanLine) // Save original step
                }
                
            case "nutrition":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    let parts = cleanLine.split(separator: ":", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        let nutritionName = parts[0].trimmingCharacters(in: .whitespaces)
                        var nutritionValue = parts[1].trimmingCharacters(in: .whitespaces)
                        
                        // Clean units from nutrition values
                        nutritionValue = nutritionValue
                            .replacingOccurrences(of: "kcal", with: "")
                            .replacingOccurrences(of: "g", with: "")
                            .replacingOccurrences(of: "mg", with: "")
                            .replacingOccurrences(of: "mcg", with: "")
                            .replacingOccurrences(of: "IU", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        
                        allNutritions.append(AddRecipeView.Nutrition(name: nutritionName, value: nutritionValue))
                    }
                }
                
            default:
                break
            }
        }
        
        // If no steps were found, use the entire content as a step
        if steps.isEmpty {
            steps = [content]
            originalSteps = [content]
        }
        
        // Ensure basic nutrition components are included
        let basicNutritions = ["Calories", "Carbohydrates", "Protein", "Fat"]
        for nutrition in basicNutritions {
            if !allNutritions.contains(where: { $0.name == nutrition }) {
                allNutritions.append(AddRecipeView.Nutrition(name: nutrition, value: ""))
            }
        }
        
        // Store data for later use
        cookingRecipeData = (ingredients: ingredients, steps: steps, nutritions: allNutritions)
        
        // Show the familiarity selection view instead of directly processing recipe steps
        showRecipeFamiliaritySelection = true
    }
    
    private func processRecipeStepsForKnowledge() {
        guard let data = cookingRecipeData else { return }
        
        // Set loading state
        isProcessingRecipeSteps = true
        
        // Get recipe context
        let recipeName = data.ingredients.first?.name ?? "Recipe"
        let stepsText = originalSteps.enumerated().map { index, step in
            "Step \(index + 1): \(step)"
        }.joined(separator: "\n")
        
        // Prepare context message based on user's familiarity
        let contextMessage: String
        
        if recipeKnowledge {
            // User is familiar with the recipe - request optimized steps
            contextMessage = """
            Recipe: \(recipeName)
            
            Original steps:
            \(stepsText)
            
            I'm FAMILIAR with this recipe. Please optimize these steps by:
            1. Fixing any errors or typos
            2. Ensuring each step is clear but concise
            3. Maintaining the original flow of the recipe
            
            Please respond with ONLY the optimized steps in this exact format:
            Step 1: [optimized step]
            Step 2: [optimized step]
            ...and so on.
            """
        } else {
            // User is unfamiliar with the recipe - request detailed steps broken down extensively
            contextMessage = """
            Recipe: \(recipeName)
            
            Original steps:
            \(stepsText)
            
            I'm UNFAMILIAR with this recipe. Please break down the steps into much more detailed instructions by:
            1. Breaking down each original step into multiple, smaller sub-steps
            2. Creating separate steps for preparations (e.g., "Preheat oven to 350°F" becomes its own step)
            3. Adding specific details about cooking techniques (e.g., what "sauté until translucent" looks like)
            4. Including visual cues and timing information (e.g., "bake for 10 minutes or until golden brown")
            5. Explaining each action in detail assuming the user has minimal cooking experience
            
            For example, an original step like:
            "Heat oil in a pan, add chicken and vegetables, cook for 5 minutes, then add sauce."
            
            Should be broken down into:
            Step 1: Place a large skillet on the stovetop.
            Step 2: Turn the heat to medium-high.
            Step 3: Add 2 tablespoons of oil to the skillet.
            Step 4: Wait until the oil is hot (it will shimmer slightly).
            Step 5: Carefully add the chicken pieces to the hot oil.
            Step 6: Cook the chicken for 2-3 minutes, stirring occasionally.
            Step 7: Add the vegetables to the skillet with the chicken.
            Step 8: Continue cooking for another 2-3 minutes until vegetables begin to soften.
            Step 9: Pour the sauce over the chicken and vegetables.
            
            Please respond with ONLY the detailed steps in this exact format:
            Step 1: [detailed sub-step]
            Step 2: [detailed sub-step]
            ...and so on.
            
            Important: The goal is to give me at least twice as many steps as the original recipe, with each step being a single, simple action.
            """
        }
        
        // Send to AI for processing
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: .mixrai)
                
                // Process AI response
                let responseLines = response.components(separatedBy: "\n")
                var processedSteps: [String] = []
                
                for line in responseLines {
                    if line.contains("Step") {
                        let components = line.components(separatedBy: ":")
                        if components.count > 1 {
                            let stepContent = components[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                            processedSteps.append(stepContent)
                        }
                    }
                }
                
                // Update UI on main thread
                await MainActor.run {
                    optimizedSteps = processedSteps
                    
                    // If AI provided valid steps, use them
                    if !optimizedSteps.isEmpty {
                        if let data = cookingRecipeData {
                            cookingRecipeData = (
                                ingredients: data.ingredients,
                                steps: optimizedSteps,
                                nutritions: data.nutritions
                            )
                        }
                    }
                    
                    isProcessingRecipeSteps = false
        showCookingSteps = true
                }
            } catch {
                // Handle error and fall back to original steps
                await MainActor.run {
                    print("Error getting AI processing for steps: \(error.localizedDescription)")
                    isProcessingRecipeSteps = false
                    showCookingSteps = true // Still show cooking steps with original instructions
                }
            }
        }
    }
    
    // Restore regenerateRecipe function
    private func regenerateRecipe(originalMessage: String, preferences: String) {
        let content = originalMessage.replacingOccurrences(of: "Assistant: ", with: "")
        var contextMessage = """
        Please regenerate the following recipe with these requirements:
        
        Original Recipe:
        \(content)
        
        Format Requirements:
        Recipe Name:
        Description:
        
        Ingredients:
        - ingredient1: amount1
        - ingredient2: amount2
        
        Steps:
        1. step1
        2. step2
        
        Nutrition:
        - Calories: xxx kcal
        - Carbohydrates: xxx g
        - Protein: xxx g
        - Fat: xxx g
        
        """
        
        // Add user's new preferences
        if !preferences.isEmpty {
            contextMessage += """
            
            Additional Requirements:
            - \(preferences)
            """
        }
        
        // If there are accepted ingredients analysis results
        if isResultsAccepted && !acceptedResults.isEmpty {
            contextMessage += """
            
            Important Ingredient Requirements:
            1. The recipe MUST use at least 80% of these ingredients: \(acceptedResults.joined(separator: ", "))
            2. If any of these ingredients cannot be used, please explain why in the description.
            3. You may add additional ingredients as needed, but the focus should be on using the detected ingredients.
            """
        }
        
        // Add personal information (if enabled)
        if considerPersonalInfo {
            if hasTargetData, let data = nutritionData {
                var nutritionText = "\n\nUser's current nutrition status:\n"
                var hasNutritionData = false
                
                if !hideCalories {
                    nutritionText += "Calories: \(Int(data.ingested))/\(Int(data.ingestion)) kcal\n"
                    hasNutritionData = true
                }
                
                if !hideCarbs {
                    nutritionText += "Carbs: \(data.carbsIngested)/\(data.carbs)g\n"
                    hasNutritionData = true
                }
                
                if !hideProtein {
                    nutritionText += "Protein: \(data.proteinIngested)/\(data.protein)g\n"
                    hasNutritionData = true
                }
                
                if !hideFat {
                    nutritionText += "Fat: \(data.fatIngested)/\(data.fat)g\n"
                    hasNutritionData = true
                }
                
                if hasNutritionData {
                    contextMessage += nutritionText
                }
                
                var exceededText = "\nMonthly exceeded counts:\n"
                var hasExceededData = false
                
                if !hideCarbsExceeded {
                    exceededText += "Carbs exceeded: \(data.carbsExceededCount) times\n"
                    hasExceededData = true
                }
                
                if !hideProteinExceeded {
                    exceededText += "Protein exceeded: \(data.proteinExceededCount) times\n"
                    hasExceededData = true
                }
                
                if !hideFatExceeded {
                    exceededText += "Fat exceeded: \(data.fatExceededCount) times\n"
                    hasExceededData = true
                }
                
                if !hideTotalExceeded {
                    exceededText += "Total calories exceeded: \(data.totalIngestedExceededCount) times\n"
                    hasExceededData = true
                }
                
                if hasExceededData {
                    contextMessage += exceededText
                    contextMessage += "\nPlease consider these exceeded counts when suggesting recipes. If a nutrient has been exceeded frequently, suggest recipes with lower amounts of that nutrient.\n"
                }
            }
            
            if hasAllergyData && !allergyData.isEmpty && !hideAllergies {
                contextMessage += """
                
                User's allergy information:
                Allergic to: \(allergyData.joined(separator: ", "))
                Please avoid these ingredients in the recipe.
                """
            }
        }
        
        contextMessage += "\n\nPlease maintain the same format but adjust the recipe according to all the requirements above."
        
        // Store context for potential retries
        lastContextMessage = contextMessage
        
        // Reset retry count for new regeneration
        apiRetryCount = 0
        
        isLoading = true
        
        // Use the retry-enabled function
        regenerateRecipeWithRetry(contextMessage: contextMessage)
    }
    
    private func regenerateRecipeWithRetry(contextMessage: String) {
        Task {
            do {
                let response = try await chatService.sendMessage(contextMessage, provider: selectedProvider)
                await MainActor.run {
                    if let index = editingIndex {
                        chatMessages[index] = ChatMessage(isUser: false, text: response)
                    }
                    isLoading = false
                    // Reset retry count on success
                    apiRetryCount = 0
                }
            } catch {
                await MainActor.run {
                    let errorMessage = error.localizedDescription
                    
                    // Check if it's an API error
                    if errorMessage.contains("API error") {
                        print("Error: \(errorMessage)")
                        
                        // Increment retry count
                        apiRetryCount += 1
                        
                        if apiRetryCount < maxRetryAttempts {
                            // Retry the API call
                            print("Retrying API call for regeneration (Attempt \(apiRetryCount) of \(maxRetryAttempts))...")
                            regenerateRecipeWithRetry(contextMessage: lastContextMessage)
                        } else {
                            // Max retries reached, show error to user
                            alertMessage = "API request failed after multiple attempts. Please try again later."
                    showNutritionAlert = true
                    isLoading = false
                        }
                    } else {
                        // For other errors, show immediately
                        alertMessage = errorMessage
                        showNutritionAlert = true
                        isLoading = false
                    }
                }
            }
        }
    }
    
    private func analyzeImage() async {
        guard let uiImage = uiImage,
              let imageData = uiImage.jpegData(compressionQuality: 0.8) else { return }
        
        isAnalyzing = true
        
        // Clear previous analysis results when starting a new analysis
        detectionResults = ""
        acceptedResults = []
        isResultsAccepted = false
        
        print("開始分析圖片...")
        
        // Google Cloud Vision API endpoint
        let url = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=AIzaSyA4UwvFQU4vgCTbfG87C_pAI4egMsFfzVg")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 準備請求數據
        let base64Image = imageData.base64EncodedString()
        let requestData: [String: Any] = [
            "requests": [
                [
                    "image": ["content": base64Image],
                    "features": [["type": "LABEL_DETECTION", "maxResults": 30]]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            print("\n=== API 原始返回結果 ===")
            if let jsonData = try? JSONSerialization.data(withJSONObject: json ?? [:], options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
            
            // 解析返回結果
            if let responses = json?["responses"] as? [[String: Any]],
               let labels = responses.first?["labelAnnotations"] as? [[String: Any]] {
                
                print("\n=== 所有標籤（包含被過濾的） ===")
                labels.forEach { label in
                    if let description = label["description"] as? String {
                        print(description)
                    }
                }
                
                let formattedResults = labels.compactMap { label -> String? in
                    guard let description = label["description"] as? String,
                          let score = label["score"] as? Double else { return nil }
                    
                    // 過濾掉非食物相關的關鍵詞
                    let nonFoodKeywords = [
                        "Recipe", "Cuisine", "Dish", "Meal", "Food", "Cooking",
                        "Ingredient", "Produce", "Natural Foods", "Grocery",
                        "Restaurant", "Dining", "Menu", "Snack", "Breakfast",
                        "Lunch", "Dinner", "Nutrition", "Diet", "Edible",
                        "Plate", "Bowl", "Serving", "Portion", "Takeout",
                        "Delivery", "Kitchen", "Cook", "Chef", "Recipe","Vegetable","Fruit","Mixture","Seasoning","Condiment"
                    ]
                    
                    let lowercaseDescription = description.lowercased()
                    let containsNonFoodKeyword = nonFoodKeywords.contains { keyword in
                        lowercaseDescription.contains(keyword.lowercased())
                    }
                    
                    guard !containsNonFoodKeyword else { return nil }
                    
                    // 只返回描述，不包含百分比
                    return description
                }
                
                print("\n=== 過濾後的結果 ===")
                formattedResults.forEach { print($0) }
                
                detectionResults = "detection result：\n\n" + formattedResults.joined(separator: "\n")
                
                // Ensure the card is shown when new results are available
                showAnalysisCard = true
            }
        } catch {
            let errorMessage = "分析錯誤: \(error.localizedDescription)"
            print("\n=== 錯誤 ===")
            print(errorMessage)
            detectionResults = errorMessage
            
            // Also show the card when there's an error to see the error message
            showAnalysisCard = true
        }
        
        print("\n=== 分析完成 ===\n")
        isAnalyzing = false
    }
    
    // Add a function to handle the quick recipe buttons that also clears previous analysis
    private func sendQuickRecipe(prompt: String) {
        // Set the message text
        messageText = prompt
        
        // Keep the current image analysis if available, but send the message
        sendMessageWithContext()
        
        // 添加滾動到底部的功能
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: Notification.Name("scrollToBottom"), object: nil)
        }
    }
    
    private func parseMessageForEditing(_ message: String) {
        // 初始化默認值
        editingRecipeName = ""
        editingDescription = ""
        editingIngredients = []
        editingSteps = []
        editingNutritions = [
            ("Calories", ""),
            ("Carbohydrates", ""),
            ("Protein", ""),
            ("Fat", "")
        ]
        
        // 分析內容
        let lines = message.components(separatedBy: .newlines)
        var currentSection = ""
        var descriptionLines: [String] = []
        var hasExplicitDescriptionTag = false
        
        // 首先尋找是否有明確的描述標籤
        for line in lines {
            if line.lowercased().contains("description:") {
                hasExplicitDescriptionTag = true
                break
            }
        }
        
        // 重置描述收集變數
        descriptionLines = []
        
        // 直接提取食譜名稱和描述部分（如果沒有明確的描述標籤）
        var isWithinInitialDescription = false
        var foundFirstSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty { continue }
            
            // 檢測段落標記
            if trimmedLine.lowercased().contains("recipe:") || trimmedLine.lowercased().contains("recipe name:") {
                currentSection = "name"
                let nameContent = trimmedLine.replacingOccurrences(of: "Recipe:", with: "")
                    .replacingOccurrences(of: "Recipe Name:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                editingRecipeName = nameContent
                
                // 如果沒有明確的描述標籤，接下來的文本可能是描述
                if !hasExplicitDescriptionTag {
                    isWithinInitialDescription = true
                }
                continue
            } else if trimmedLine.lowercased().contains("description:") {
                currentSection = "description"
                isWithinInitialDescription = false // 已找到明確的描述標籤
                continue
            } else if trimmedLine.lowercased().contains("ingredients:") {
                currentSection = "ingredients"
                isWithinInitialDescription = false
                foundFirstSection = true
                continue
            } else if trimmedLine.lowercased().contains("instructions:") || trimmedLine.lowercased().contains("steps:") {
                currentSection = "steps"
                isWithinInitialDescription = false
                foundFirstSection = true
                continue
            } else if trimmedLine.lowercased().contains("nutrition:") || trimmedLine.lowercased().contains("nutritional information:") {
                currentSection = "nutrition"
                isWithinInitialDescription = false
                foundFirstSection = true
                continue
            }
            
            // 處理不明確的描述部分 - 如果在食譜名稱之後但在第一個明確的部分（如食材）之前
            if isWithinInitialDescription && !foundFirstSection {
                // 檢查行是否像是描述，而不是其他部分的標題
                if !trimmedLine.contains(":") && !trimmedLine.starts(with: "-") && !trimmedLine.starts(with: "•") {
                    descriptionLines.append(trimmedLine)
                } else {
                    // 如果遇到可能是其他部分開始的行，停止收集描述
                    isWithinInitialDescription = false
                }
                continue
            }
            
            // 根據當前段落處理內容
            switch currentSection {
            case "description":
                descriptionLines.append(trimmedLine)
                
            case "ingredients":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    
                    // 檢查是否有冒號來分隔食材名稱和數量
                    if cleanLine.contains(":") {
                        let parts = cleanLine.split(separator: ":", maxSplits: 1).map(String.init)
                        if parts.count == 2 {
                            let name = parts[0].trimmingCharacters(in: .whitespaces)
                            var amount = parts[1].trimmingCharacters(in: .whitespaces)
                            
                            // 如果數量為空，設置為 "1"
                            if amount.isEmpty {
                                amount = "1"
                            }
                            
                            editingIngredients.append((name, amount))
                        }
                    } else {
                        // 如果沒有冒號，嘗試匹配常見的食材格式如 "2 tbsp olive oil" -> ("olive oil", "2 tbsp")
                        let pattern = "^([0-9¼½¾⅓⅔⅛⅜⅝⅞.]+\\s*(?:cup|cups|tbsp|tsp|tablespoon|tablespoons|teaspoon|teaspoons|oz|ounce|ounces|pound|pounds|lb|lbs|g|kg|ml|l|pinch|dash|to taste|bunch|bunches))\\s+(.+)$"
                        
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                            let nsString = cleanLine as NSString
                            let matches = regex.matches(in: cleanLine, options: [], range: NSRange(location: 0, length: nsString.length))
                            
                            if let match = matches.first {
                                let amountRange = match.range(at: 1)
                                let nameRange = match.range(at: 2)
                                
                                if amountRange.location != NSNotFound && nameRange.location != NSNotFound {
                                    let amount = nsString.substring(with: amountRange).trimmingCharacters(in: .whitespaces)
                                    let name = nsString.substring(with: nameRange).trimmingCharacters(in: .whitespaces)
                                    editingIngredients.append((name, amount))
                                } else {
                                    // 如果正則表達式匹配失敗，將整行作為名稱，數量設為 "1"
                                    editingIngredients.append((cleanLine, "1"))
                                }
                            } else {
                                // 如果沒有匹配，嘗試更簡單的分割方式，假設數量在前面
                                let components = cleanLine.components(separatedBy: " ")
                                if components.count > 1, let first = components.first, first.rangeOfCharacter(from: .decimalDigits) != nil {
                                    // 假設第一個單詞是數量
                                    var amount = first
                                    var nameStartIndex = 1
                                    
                                    // 檢查第二個單詞是否是單位 (tbsp, cup, etc.)
                                    if components.count > 2 {
                                        let units = ["cup", "cups", "tbsp", "tsp", "tablespoon", "tablespoons", 
                                                    "teaspoon", "teaspoons", "oz", "ounce", "ounces", "pound", 
                                                    "pounds", "lb", "lbs", "g", "kg", "ml", "l"]
                                        if units.contains(components[1].lowercased()) {
                                            amount += " " + components[1]
                                            nameStartIndex = 2
                                        }
                                    }
                                    
                                    let name = components[nameStartIndex...].joined(separator: " ")
                                    editingIngredients.append((name, amount))
                                } else {
                                    // 如果沒有明確的數量，將整行作為名稱，數量設為 "1"
                                    editingIngredients.append((cleanLine, "1"))
                                }
                            }
                        } else {
                            // 如果正則表達式創建失敗，將整行作為名稱，數量設為 "1"
                            editingIngredients.append((cleanLine, "1"))
                        }
                    }
                }
                
            case "steps":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    editingSteps.append(cleanLine)
                } else if let number = trimmedLine.first, number.isNumber {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^\\d+\\.?\\s*", with: "", options: .regularExpression)
                    editingSteps.append(cleanLine)
                } else {
                    // 如果行不以數字或列表符號開始，但在步驟部分中，將其作為步驟添加
                    editingSteps.append(trimmedLine)
                }
                
            case "nutrition":
                if trimmedLine.starts(with: "-") || trimmedLine.starts(with: "•") {
                    let cleanLine = trimmedLine.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    let parts = cleanLine.split(separator: ":", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        let name = parts[0].trimmingCharacters(in: .whitespaces)
                        let value = parts[1].trimmingCharacters(in: .whitespaces)
                        
                        // 更新現有項目或添加新項目
                        if let index = editingNutritions.firstIndex(where: { $0.0.lowercased() == name.lowercased() }) {
                            editingNutritions[index].1 = value
                        } else {
                            editingNutritions.append((name, value))
                        }
                    }
                }
                
            default:
                break
            }
        }
        
        // 將收集到的描述行合併為一個字符串，使用空格分隔
        editingDescription = descriptionLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果描述為空但有食譜名稱，嘗試從原始消息中提取描述
        if editingDescription.isEmpty && !editingRecipeName.isEmpty {
            // 嘗試尋找在食譜名稱之後但在食材之前的部分作為描述
            let startMarker = "Recipe Name: \(editingRecipeName)"
            let endMarker = "Ingredients:"
            
            if message.contains(startMarker) && message.contains(endMarker) {
                if let range = message.range(of: startMarker)?.upperBound,
                   let endRange = message.range(of: endMarker, range: range..<message.endIndex)?.lowerBound {
                    let extractedText = message[range..<endRange].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extractedText.isEmpty {
                        editingDescription = extractedText
                    }
                }
            }
        }
        
        // 確保至少有一個食材和步驟，且食材的數量默認為 "1"
        if editingIngredients.isEmpty {
            editingIngredients.append(("", "1"))
        } else {
            // 確保所有食材都有數量，如果沒有則設為 "1"
            for (index, ingredient) in editingIngredients.enumerated() {
                if ingredient.1.isEmpty {
                    editingIngredients[index] = (ingredient.0, "1")
                }
            }
        }
        
        if editingSteps.isEmpty {
            editingSteps.append("")
        }
        
        // 輸出解析結果以便調試
        print("解析結果:")
        print("名稱: \(editingRecipeName)")
        print("描述: \(editingDescription)")
        print("食材: \(editingIngredients)")
        print("步驟數: \(editingSteps.count)")
        print("營養數: \(editingNutritions.count)")
    }
    
    // Extract recipe name from AI message
    private func extractRecipeName(from message: String) -> String? {
        // Look for "Recipe Name:" or just "Recipe:" in the message
        if let nameRange = message.range(of: "Recipe Name:", options: .caseInsensitive) {
            let startIndex = message.index(nameRange.upperBound, offsetBy: 1)
            if let endIndex = message[startIndex...].firstIndex(of: "\n") {
                return String(message[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if let nameRange = message.range(of: "Recipe:", options: .caseInsensitive) {
            let startIndex = message.index(nameRange.upperBound, offsetBy: 1)
            if let endIndex = message[startIndex...].firstIndex(of: "\n") {
                return String(message[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    // Save the recipe as a favorite
    private func saveAsFavorite(recipeName: String, message: String) {
        guard !userUID.isEmpty else { return }
        
        // Create a new AIRecipeFavorite instance
        let favoriteRecipe = AIRecipeFavorite(
            recipeName: recipeName,
            recipeMessage: message,
            timestamp: Date()
        )
        
        // Load existing favorites or create a new array
        var favorites: [AIRecipeFavorite] = []
        
        if let savedData = UserDefaults.standard.data(forKey: "savedAIRecipes_\(userUID)"),
           let decoded = try? JSONDecoder().decode([AIRecipeFavorite].self, from: savedData) {
            favorites = decoded
        }
        
        // Add the new favorite to the array
        favorites.append(favoriteRecipe)
        
        // Encode and save array to UserDefaults
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: "savedAIRecipes_\(userUID)")
            
            // For backward compatibility, also save the latest recipe in the old format
            UserDefaults.standard.set(try? JSONEncoder().encode(favoriteRecipe), forKey: "savedAIRecipe_\(userUID)")
            
            // Enable the segment view in LikesView
            showSegmentInLikesView = true
            
            // Show confirmation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        }
    }
    
    // 重置聊天功能 - 清除所有聊天记录并刷新界面
    private func resetChat() {
        chatMessages = []
        messageText = ""
        messageImage = nil
        isLoading = false
        apiRetryCount = 0
        
        // 添加欢迎消息
        chatMessages.append(ChatMessage(isUser: false, text: "Hello! I'm Flavour Chef. How can I help you with recipes today?"))
    }
}

struct NutritionRow: View {
    let title: String
    let value: String
    let target: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .bold()
            Text("/ \(target)")
                .foregroundColor(.gray)
        }
    }
}

struct NutritionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionStatusView(sheetDetent: .constant(.medium))
    }
}

// Add this helper view near the bottom of the file, before the NutritionRow struct
struct NutritionDataView: View {
    let data: TargetData
    
    var body: some View {
        VStack(spacing: 20) {
            // Daily intake section
            DailyNutritionView(data: data)
            
            Divider()
            
            // Monthly exceeded counts section
            MonthlyExceededView(data: data)
        }
    }
}

struct DailyNutritionView: View {
    let data: TargetData
    
    var body: some View {
        VStack(spacing: 20) {
            NutritionRow(
                title: "Protein",
                value: "\(Int(data.proteinIngested))g",
                target: "\(data.protein)g"
            )
            
            NutritionRow(
                title: "Carbs",
                value: "\(Int(data.carbsIngested))g",
                target: "\(data.carbs)g"
            )
            
            NutritionRow(
                title: "Fat",
                value: "\(Int(data.fatIngested))g",
                target: "\(data.fat)g"
            )
            
            NutritionRow(
                title: "Calories",
                value: "\(Int(data.ingested))",
                target: "\(Int(data.ingestion))"
            )
        }
    }
}

struct MonthlyExceededView: View {
    let data: TargetData
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Monthly Exceeded Counts")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            
            NutritionRow(
                title: "Protein Exceeded",
                value: "\(data.proteinExceededCount)",
                target: "times"
            )
            
            NutritionRow(
                title: "Carbs Exceeded",
                value: "\(data.carbsExceededCount)",
                target: "times"
            )
            
            NutritionRow(
                title: "Fat Exceeded",
                value: "\(data.fatExceededCount)",
                target: "times"
            )
            
            NutritionRow(
                title: "Total Calories Exceeded",
                value: "\(data.totalIngestedExceededCount)",
                target: "times"
            )
        }
    }
} 

// Add preference key for tracking scroll offset
struct ScrollViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
