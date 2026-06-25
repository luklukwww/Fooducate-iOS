import SwiftUI
import FirebaseFirestore

// 添加 Imgur 上傳服務 - 使用與 AddRecipeView 相同的方法
class ImgurUploadService {
    private let clientID = "YOUR_API_KEY_HERE"
    private let imgurUploadURL = "https://api.imgur.com/3/upload"
    
    func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // 將圖片轉換為 JPEG 數據
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "ImgurUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"])))
            return
        }
        
        // 創建 URL 請求
        var request = URLRequest(url: URL(string: imgurUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(clientID)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 將圖片轉換為 base64 並進行 URL 編碼
        let base64Image = jpegData.base64EncodedString()
        let encodedImage = base64Image.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? base64Image
        let bodyString = "image=\(encodedImage)"
        
        // 設置請求體
        request.httpBody = bodyString.data(using: .utf8)
        
        // 發送請求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 輸出 HTTP 狀態碼，用於調試
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            // 處理錯誤
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // 驗證響應數據
            guard let data = data else {
                print("No data received from server")
                completion(.failure(NSError(domain: "ImgurUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])))
                return
            }
            
            // 打印收到的數據
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            
            do {
                // 嘗試解析 JSON 響應
                guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataDict = jsonResponse["data"] as? [String: Any],
                      let link = dataDict["link"] as? String else {
                    completion(.failure(NSError(domain: "ImgurUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get image URL from response"])))
                    return
                }
                
                // 返回圖片 URL
                completion(.success(link))
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
}

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @Published var isLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        }
    }
    
    fileprivate init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
    }
}

// 在 struct ProfileView 前添加用戶階段枚舉
enum UserLevel: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

// 添加用戶偏好口味枚舉
enum FlavorPreference: String, CaseIterable {
    case spicy = "Spicy"
    case sweet = "Sweet"
    case sour = "Sour"
    case savory = "Savory"
    case bitter = "Bitter"
}

// 添加食物類型枚舉
enum FoodType: String, CaseIterable {
    case chinese = "Chinese"
    case italian = "Italian"
    case japanese = "Japanese"
    case mexican = "Mexican"
    case american = "American"
    case middleEastern = "Middle Eastern"
    case indian = "Indian"
    case other = "Other"
}

struct ProfileView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var username: String = ""
    @State private var isRegistering: Bool = false
    @State private var errorMessage: String = ""
    @StateObject private var userSettings = UserSettings.shared
    @AppStorage("userUID") private var userUID: String = ""
    @AppStorage("userEmail") private var savedEmail: String = ""
    @AppStorage("userName") private var savedUsername: String = ""
    @AppStorage("userFlavorPreference") private var savedFlavorPreference: String = ""
    @AppStorage("userFoodType") private var savedFoodType: String = ""
    @AppStorage("userProfileImage") private var userProfileImage: String = "https://i.imgur.com/q0Y06YB.png"
    @StateObject private var adminManager = AdminManager.shared
    
    // 添加圖片選擇相關狀態
    @State private var isImagePickerPresented = false
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    
    @State private var selectedFlavorPreference: FlavorPreference = .savory
    @State private var selectedFoodType: FoodType = .other
    
    @State private var followingCount: Int = 0
    @State private var followersCount: Int = 0
    @State private var recipesCount: Int = 0
    
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showChangePassword = false
    @State private var newUsername = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @State private var selectedLevel: UserLevel = .beginner
    @AppStorage("userLevel") private var savedUserLevel: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                    .frame(height: 20)
                
                if userSettings.isLoggedIn {
                    // 包裹在ScrollView中使頁面可滾動
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 15) {
                            // 重新設計布局：頭像在左側，文字信息在右側
                            HStack(alignment: .center, spacing: 20) {
                                // 左側頭像部分
                                Button(action: {
                                    isImagePickerPresented = true
                                }) {
                                    ZStack(alignment: .bottomTrailing) {
                                        if let imageURL = URL(string: userProfileImage), !userProfileImage.isEmpty {
                                            AsyncImage(url: imageURL) { phase in
                                                switch phase {
                                                case .empty:
                                                    ZStack {
                                                        Circle()
                                                            .fill(Color.orange.opacity(0.2))
                                                            .frame(width: 90, height: 90)
                                                        ProgressView()
                                                    }
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 90, height: 90)
                                                        .clipShape(Circle())
                                                        .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                                                case .failure:
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 45))
                                                        .foregroundColor(.orange)
                                                        .frame(width: 90, height: 90)
                                                        .background(Circle().fill(Color.orange.opacity(0.2)))
                                                @unknown default:
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 45))
                                                        .foregroundColor(.orange)
                                                        .frame(width: 90, height: 90)
                                                        .background(Circle().fill(Color.orange.opacity(0.2)))
                                                }
                                            }
                                        } else {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 45))
                                                .foregroundColor(.orange)
                                                .frame(width: 90, height: 90)
                                                .background(Circle().fill(Color.orange.opacity(0.2)))
                                                .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                                        }
                                        
                                        if isUploading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .frame(width: 90, height: 90)
                                                .background(Color.black.opacity(0.5))
                                                .clipShape(Circle())
                                        }
                                        
                                        // 添加編輯圖標
                                        Image(systemName: "camera.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.orange)
                                            .background(Circle().fill(Color.white))
                                            .overlay(Circle().stroke(Color.orange, lineWidth: 1.5))
                                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                }
                                
                                // 右側文字信息
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome, \(savedUsername)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text("Email: \(savedEmail)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Text("User ID: \(userUID)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                            
                            // 添加数据统计行
                            HStack(spacing: 30) {
                                NavigationLink(destination: UserFollowingView(userUID: userUID)) {
                                    VStack {
                                        Text("\(followingCount)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                        Text("Following")
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                VStack {
                                    Text("\(followersCount)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("Followers")
                                        .foregroundColor(.gray)
                                }
                                
                                NavigationLink(destination: UserRecipesView(userUID: userUID)) {
                                    VStack {
                                        Text("\(recipesCount)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                        Text("My Posts")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.vertical)
                            
                            // 添加过敏源管理按钮和摄入计算按钮
                            HStack {
                                // 使用 GeometryReader 確保均勻分佈
                                GeometryReader { geometry in
                                    HStack(spacing: 0) {
                                        // 第一個按鈕：Allergy
                                        HStack {
                                            Spacer()
                                            NavigationLink(destination: AllergyView(userUID: userUID)) {
                                                VStack {
                                                    Image(systemName: "exclamationmark.shield.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.white)
                                                        .frame(width: 44, height: 44)
                                                        .background(Color.orange.opacity(0.8))
                                                        .cornerRadius(10)
                                                    
                                                    Text("Allergy")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .frame(width: geometry.size.width / 3)
                                        
                                        // 第二個按鈕：Ingestion
                                        HStack {
                                            Spacer()
                                            NavigationLink(destination: BMRCalculatorView(userUID: userUID)) {
                                                VStack {
                                                    Image(systemName: "chart.bar.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.white)
                                                        .frame(width: 44, height: 44)
                                                        .background(Color.orange.opacity(0.8))
                                                        .cornerRadius(10)
                                                    
                                                    Text("Ingestion")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .frame(width: geometry.size.width / 3)
                                        
                                        // 第三個按鈕：Food Scanner
                                        HStack {
                                            Spacer()
                                            NavigationLink(destination: FoodRecognitionView(userUID: userUID)) {
                                                VStack {
                                                    Image(systemName: "camera.viewfinder")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.white)
                                                        .frame(width: 44, height: 44)
                                                        .background(Color.orange.opacity(0.8))
                                                        .cornerRadius(10)
                                                    
                                                    Text("Flavour Mirror")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .frame(width: geometry.size.width / 3)
                                    }
                                }
                                // 設定適當的高度以包含圖標和文字
                                .frame(height: 80)
                            }
                            .padding(.horizontal)
                            
                            // 添加管理員按鈕 - 移動到營養詳情上方
                            if adminManager.isAdmin {
                                VStack(spacing: 10) {
                                    Text("Admin Tools")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 20) {
                                        Spacer()
                                        NavigationLink(destination: AdminUserListView()) {
                                            VStack {
                                                Image(systemName: "person.2.badge.gearshape")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                                    .frame(width: 44, height: 44)
                                                    .background(Color.orange.opacity(0.8))
                                                    .cornerRadius(10)
                                                
                                                Text("Manage Users")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        NavigationLink(destination: AdminRecipeApprovalView()) {
                                            VStack {
                                                Image(systemName: "list.clipboard.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                                    .frame(width: 44, height: 44)
                                                    .background(Color.orange.opacity(0.8))
                                                    .cornerRadius(10)
                                                
                                                Text("Recipe Approvals")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.bottom, 10)
                                }
                            }
                            
                            // 添加營養詳情標題和重設按鈕
                            HStack {
                                Text("Daily Nutrition Details")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Button(action: resetNutritionIntake) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 12))
                                        Text("Reset Intake")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.8))
                                    .cornerRadius(15)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 5)
                            
                            // 添加营养进度视图
                            NutritionProgressView(userUID: userUID)
                                .padding(.top, 5)
                                .padding(.bottom, 20) // 新增底部間距，確保在滾動時有足夠的空間
                        }
                    }
                } else {
                    if isRegistering {
                        registrationView
                    } else {
                        // 登入view
                        VStack {
                            Spacer()
                            
                            VStack(spacing: 25) {
                                Text("Login")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .padding(.bottom, 20)
                                
                                TextField("Email", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .padding(.horizontal, 20)
                                
                                SecureField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal, 20)
                                
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                
                                //登入和註冊
                                Button(action: login) {
                                    HStack {
                                        Image(systemName: "person.fill")
                                        Text("Login")
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange.opacity(0.8))
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                                
                                // 切換
                                Button(action: {
                                    isRegistering.toggle()
                                    errorMessage = ""
                                }) {
                                    Text("Don't have an account? Register")
                                        .foregroundColor(Color.orange.opacity(0.8))
                                        .padding(.top, 15)
                                }
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: 400)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(20)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
            .navigationBarItems(trailing: 
                Group {
                    if userSettings.isLoggedIn {
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 20))
                        }
                    }
                }
            )
            .sheet(isPresented: $showSettings) {
                VStack(spacing: 20) {
                    Text("Settings")
                        .font(.title2)
                        .bold()
                        .padding(.top, 20)
                    
                    VStack(spacing: 15) {
                        Button(action: { 
                            showSettings = false
                            showEditProfile = true 
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.orange)
                                Text("Edit Profile")
                                    .foregroundColor(.black)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        Button(action: { 
                            showSettings = false
                            showChangePassword = true 
                        }) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                Text("Change Password")
                                    .foregroundColor(.black)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            showSettings = false
                            logout()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.orange)
                                Text("Logout")
                                    .foregroundColor(.black)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationView {
                    ScrollView {
                        VStack {
                            Spacer()
                            
                            VStack(spacing: 25) {
                                Text("Edit Profile")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.bottom, 10)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Username")
                                        .font(.headline)
                                        .foregroundColor(Color.orange.opacity(0.8))
                                        .padding(.leading)
                                    
                                    TextField("Username", text: $newUsername)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .padding(.horizontal)
                                }
                                
                                // Add cooking level selector
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Cooking Level")
                                        .font(.headline)
                                        .foregroundColor(Color.orange.opacity(0.8))
                                        .padding(.leading)
                                    
                                    Picker("Cooking Level", selection: $selectedLevel) {
                                        ForEach(UserLevel.allCases, id: \.self) { level in
                                            Text(level.rawValue).tag(level)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .padding(.horizontal)
                                    .accentColor(.orange)
                                }
                                .padding(.top, 10)
                                
                                // Add flavor preference selector
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Flavor Preference")
                                        .font(.headline)
                                        .foregroundColor(Color.orange.opacity(0.8))
                                        .padding(.leading)
                                    
                                    Picker("Flavor Preference", selection: $selectedFlavorPreference) {
                                        ForEach(FlavorPreference.allCases, id: \.self) { preference in
                                            Text(preference.rawValue).tag(preference)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .padding(.horizontal)
                                    .accentColor(.orange)
                                }
                                .padding(.top, 10)
                                
                                // Add food type selector - 使用菜單樣式解決顯示不全的問題
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Food Type")
                                        .font(.headline)
                                        .foregroundColor(Color.orange.opacity(0.8))
                                        .padding(.leading)
                                    
                                    // 使用菜單式選擇器而非分段式選擇器
                                    HStack {
                                        Text("Select Food Type:")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        
                                        Picker("", selection: $selectedFoodType) {
                                            ForEach(FoodType.allCases, id: \.self) { type in
                                                Text(type.rawValue).tag(type)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .foregroundColor(.orange)
                                        .accentColor(.orange)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                }
                                .padding(.top, 10)
                            }
                            .padding(.vertical, 30)
                            .frame(maxWidth: 400)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                            
                            Spacer()
                        }
                        .padding()
                        .onAppear {
                            // Initialize with current values
                            newUsername = savedUsername
                            
                            // Set the selected level from saved user level
                            if let level = UserLevel.allCases.first(where: { $0.rawValue == savedUserLevel }) {
                                selectedLevel = level
                            }
                            
                            // Set the selected flavor preference from saved preference
                            if let preference = FlavorPreference.allCases.first(where: { $0.rawValue == savedFlavorPreference }) {
                                selectedFlavorPreference = preference
                            }
                            
                            // Set the selected food type from saved type
                            if let type = FoodType.allCases.first(where: { $0.rawValue == savedFoodType }) {
                                selectedFoodType = type
                            }
                        }
                        .navigationTitle("Edit Profile")
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarItems(
                            leading: Button("Cancel") { 
                                showEditProfile = false 
                            }
                            .foregroundColor(.orange),
                            trailing: Button("Save") { 
                                updateUserProfile()
                            }
                            .foregroundColor(.orange)
                        )
                    }
                }
                .accentColor(.orange)
            }
            .sheet(isPresented: $showChangePassword) {
                NavigationView {
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 25) {
                            Text("Change Password")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.bottom, 10)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current Password")
                                    .font(.headline)
                                    .foregroundColor(Color.orange.opacity(0.8))
                                    .padding(.leading)
                                
                                SecureField("Current Password", text: $currentPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("New Password")
                                    .font(.headline)
                                    .foregroundColor(Color.orange.opacity(0.8))
                                    .padding(.leading)
                                
                                SecureField("New Password", text: $newPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm New Password")
                                    .font(.headline)
                                    .foregroundColor(Color.orange.opacity(0.8))
                                    .padding(.leading)
                                
                                SecureField("Confirm New Password", text: $confirmPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 30)
                        .frame(maxWidth: 400)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Change Password")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(
                        leading: Button("Cancel") { 
                            showChangePassword = false
                            resetPasswordFields()
                        }
                        .foregroundColor(.orange),
                        trailing: Button("Save") { 
                            updatePassword()
                        }
                        .foregroundColor(.orange)
                    )
                }
                .accentColor(.orange)
            }
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(image: $selectedImage, isPresented: $isImagePickerPresented)
                    .onDisappear {
                        if let image = selectedImage {
                            uploadProfileImage(image)
                        }
                    }
            }
            .alert("Notice", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                if userSettings.isLoggedIn && !userUID.isEmpty {
                    username = savedUsername
                    adminManager.checkAdminStatus(uid: userUID)
                    fetchUserStats()
                    checkDailyReset()
                    fetchUserProfileImage()
                    
                    // 檢查營養素是否超標並更新計數器
                    NutritionExceededManager.shared.checkAndUpdateExceededCounts(userUID: userUID)
                }
            }
        }
    }
    
    private func login() {
        let db = Firestore.firestore()
        errorMessage = ""
        
        db.collection("User")
            .whereField("email", isEqualTo: email)
            .whereField("pw", isEqualTo: password)
            .getDocuments { snapshot, error in
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    let userData = documents[0]
                    userUID = userData.documentID
                    savedUsername = userData.data()["uname"] as? String ?? "User"
                    savedEmail = email
                    userSettings.isLoggedIn = true
                    errorMessage = ""
                    
                    // 登入成功後立即檢查管理員狀態
                    adminManager.checkAdminStatus(uid: userData.documentID)
                } else {
                    errorMessage = "Invalid email or password"
                }
            }
    }
    
    private func logout() {
        userSettings.isLoggedIn = false
        userUID = ""
        savedUsername = ""
        savedEmail = ""
        email = ""
        password = ""
        errorMessage = ""
        
        // 重置 AdminManager
        adminManager.reset()
        
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
    
    private func register() {
        let db = Firestore.firestore()
        errorMessage = ""

        // Check if required fields are empty
        if email.isEmpty || password.isEmpty || username.isEmpty {
            errorMessage = "Email, password, and username are required."
            return
        }

        db.collection("User")
            .whereField("email", isEqualTo: email)
            .getDocuments { snapshot, error in
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    errorMessage = "Email already exists"
                    return
                }
                
                let newUserRef = db.collection("User").document()
                let userData: [String: Any] = [
                    "email": email,
                    "pw": password,
                    "uname": username,
                    "user_type": selectedLevel.rawValue, // 添加用戶階段
                    "flavor_preference": selectedFlavorPreference.rawValue,
                    "food_type": selectedFoodType.rawValue,
                    "uimg": "https://i.imgur.com/luGJ8Ax.jpeg" // 設置默認頭像
                ]
                
                newUserRef.setData(userData) { error in
                    if let error = error {
                        errorMessage = "Registration failed: \(error.localizedDescription)"
                    } else {
                        // Auto login after successful registration
                        userUID = newUserRef.documentID
                        savedUsername = username
                        savedEmail = email
                        savedUserLevel = selectedLevel.rawValue
                        savedFlavorPreference = selectedFlavorPreference.rawValue
                        savedFoodType = selectedFoodType.rawValue
                        userProfileImage = "https://i.imgur.com/luGJ8Ax.jpeg" // 設置默認頭像
                        userSettings.isLoggedIn = true
                        errorMessage = ""
                    }
                }
            }
    }
    
    private func fetchUserStats() {
        let db = Firestore.firestore()
        
        // 获取关注数 - 从 Follow 子集合获取
        db.collection("User").document(userUID).collection("Follow")
            .getDocuments { snapshot, error in
                if let snapshot = snapshot {
                    DispatchQueue.main.async {
                        followingCount = snapshot.documents.count
                    }
                }
            }
        
        // 获取粉丝数 - 从用户文档的 follow 字段获取
        db.collection("User").document(userUID)
            .getDocument { snapshot, error in
                if let data = snapshot?.data(),
                   let followCount = data["follow"] as? Int {
                    DispatchQueue.main.async {
                        followersCount = followCount
                    }
                }
            }
        
        // 获取食谱数 - 从 Recipe 集合中获取
        db.collection("Recipe")
            .whereField("UID", isEqualTo: userUID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting recipes: \(error)")
                    return
                }
                
                if let snapshot = snapshot {
                    DispatchQueue.main.async {
                        recipesCount = snapshot.documents.count
                    }
                }
            }
    }
    
    private func updateUserProfile() {
        let db = Firestore.firestore()
        
        // Save the user level and preferences to AppStorage
        savedUserLevel = selectedLevel.rawValue
        savedFlavorPreference = selectedFlavorPreference.rawValue
        savedFoodType = selectedFoodType.rawValue
        
        // Update user profile fields in Firestore
        db.collection("User").document(userUID)
            .updateData([
                "uname": newUsername,
                "user_type": selectedLevel.rawValue,
                "flavor_preference": selectedFlavorPreference.rawValue,
                "food_type": selectedFoodType.rawValue
            ]) { error in
                if let error = error {
                    alertMessage = "Failed to update profile: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    savedUsername = newUsername
                    showEditProfile = false
                }
            }
    }
    
    private func updatePassword() {
        let db = Firestore.firestore()
        
        // 首先验证当前密码
        db.collection("User").document(userUID)
            .getDocument { snapshot, error in
                if let data = snapshot?.data(),
                   let storedPassword = data["pw"] as? String {
                    if storedPassword != currentPassword {
                        alertMessage = "Current password is incorrect"
                        showAlert = true
                        return
                    }
                    
                    // 验证新密码
                    if newPassword.isEmpty {
                        alertMessage = "New password cannot be empty"
                        showAlert = true
                        return
                    }
                    
                    if newPassword != confirmPassword {
                        alertMessage = "New passwords do not match"
                        showAlert = true
                        return
                    }
                    
                    // 更新密码
                    db.collection("User").document(userUID)
                        .updateData(["pw": newPassword]) { error in
                            if let error = error {
                                alertMessage = "Failed to update password: \(error.localizedDescription)"
                                showAlert = true
                            } else {
                                showChangePassword = false
                                resetPasswordFields()
                                alertMessage = "Password updated successfully"
                                showAlert = true
                            }
                        }
                }
            }
    }
    
    private func resetPasswordFields() {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
    }
    
    // 修改註冊視圖部分
    var registrationView: some View {
        ScrollView {
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    Text("Register")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 5)
                    
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                            
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding(.horizontal, 20)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 20)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                            
                            TextField("Username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .padding(.horizontal, 20)
                        }
                    }
                    
                    // 添加用戶階段選擇器
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cooking Level")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.leading, 20)
                        
                        Picker("Cooking Level", selection: $selectedLevel) {
                            ForEach(UserLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 20)
                    }
                    
                    // 添加用戶偏好口味選擇器 (必填項)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Flavor Preference")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("*")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                        .padding(.leading, 20)
                        
                        Picker("Flavor Preference", selection: $selectedFlavorPreference) {
                            ForEach(FlavorPreference.allCases, id: \.self) { preference in
                                Text(preference.rawValue).tag(preference)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 20)
                    }
                    
                    // 添加食物類型選擇器 (選填項) - 改用菜單樣式解決顯示不全的問題
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Food Type")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("(Optional)")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .padding(.leading, 20)
                        
                        // 使用菜單式選擇器而非分段式選擇器
                        HStack {
                            Text("Select Food Type:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Picker("", selection: $selectedFoodType) {
                                ForEach(FoodType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .foregroundColor(.orange)
                            .accentColor(.orange)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 5)
                    }
                    
                    Button(action: register) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Register")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Button(action: {
                        isRegistering.toggle()
                        errorMessage = ""
                    }) {
                        Text("Already have an account? Login")
                            .foregroundColor(Color.orange.opacity(0.8))
                            .padding(.top, 5)
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: 400)
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
    
    // 添加重設營養攝入的函數
    private func resetNutritionIntake() {
        let db = Firestore.firestore()
        let userRef = db.collection("User").document(userUID)
            .collection("target").document("current")
        
        // 只重設已攝入的值，保留攝入限制
        let resetData: [String: Any] = [
            "Ingested": 0,
            "CarbsIngested": 0,
            "ProteinIngested": 0,
            "FatIngested": 0
        ]
        
        userRef.updateData(resetData) { error in
            if let error = error {
                alertMessage = "Failed to reset nutrition intake: \(error.localizedDescription)"
                showAlert = true
            } else {
                alertMessage = "Nutrition intake has been reset"
                showAlert = true
            }
        }
    }
    
    // 添加每日重設檢查函數
    private func checkDailyReset() {
        let defaults = UserDefaults.standard
        let lastResetDateKey = "lastResetDate"
        
        // 獲取香港時區
        let hongKongTimeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        var calendar = Calendar.current
        calendar.timeZone = hongKongTimeZone
        
        // 獲取當前香港日期
        let now = Date()
        let currentDateComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let currentDateString = "\(currentDateComponents.year!)-\(currentDateComponents.month!)-\(currentDateComponents.day!)"
        
        // 獲取上次重設日期
        let lastResetDateString = defaults.string(forKey: lastResetDateKey) ?? ""
        
        // 如果日期不同，執行重設
        if currentDateString != lastResetDateString {
            resetNutritionIntake()
            defaults.set(currentDateString, forKey: lastResetDateKey)
            print("Daily reset performed at Hong Kong midnight. Current date: \(currentDateString)")
        }
    }
    
    // 添加獲取用戶頭像的方法
    private func fetchUserProfileImage() {
        let db = Firestore.firestore()
        db.collection("User").document(userUID).getDocument { document, error in
            if let document = document, document.exists,
               let data = document.data(),
               let imageUrl = data["uimg"] as? String,
               !imageUrl.isEmpty {
                userProfileImage = imageUrl
            }
        }
    }
    
    // 修改上傳頭像的方法，添加更多的日誌記錄
    private func uploadProfileImage(_ image: UIImage) {
        isUploading = true
        print("開始上傳頭像...")
        
        let imgurService = ImgurUploadService()
        imgurService.uploadImage(image) { result in
            DispatchQueue.main.async {
                isUploading = false
                
                switch result {
                case .success(let imageUrl):
                    print("頭像上傳成功: \(imageUrl)")
                    userProfileImage = imageUrl
                    // 更新 Firestore 中的頭像 URL
                    updateProfileImageInFirestore(imageUrl)
                case .failure(let error):
                    print("頭像上傳失敗: \(error.localizedDescription)")
                    alertMessage = "Failed to upload image: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    // 添加更新 Firestore 中頭像 URL 的方法
    private func updateProfileImageInFirestore(_ imageUrl: String) {
        let db = Firestore.firestore()
        db.collection("User").document(userUID).updateData([
            "uimg": imageUrl
        ]) { error in
            if let error = error {
                alertMessage = "Failed to update profile image: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .previewLayout(.sizeThatFits)
            .environmentObject(UserSettings.shared)
            .onAppear {
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                UserDefaults.standard.set("U001", forKey: "userUID")
                UserDefaults.standard.set("admin", forKey: "userEmail")
                
                UserDefaults.standard.set("admin", forKey: "userName")
            }
    }
} 
