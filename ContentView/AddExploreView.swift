import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

struct AddExploreView: View {
    private let imgurClientId = "YOUR_API_KEY_HERE"
    private let imgurUploadURL = "https://api.imgur.com/3/image"
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettings.shared
    @State private var description: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @AppStorage("userUID") private var userUID: String = ""
    
    var body: some View {
        if userSettings.isLoggedIn && !userUID.isEmpty {
            NavigationView {
                Form {
                    Section {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            if let selectedImageData,
                               let uiImage = UIImage(data: selectedImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                            } else {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("Select Image")
                                }
                            }
                        }
                        .onChange(of: selectedItem) { _ in
                            Task {
                                if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                    }

                    Section {
                        TextField("Add description", text: $description)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .navigationTitle("New Post")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Post") {
                            uploadPost(userId: userUID)
                        }
                        .disabled(isUploading || selectedImageData == nil || description.isEmpty)
                    }
                }
                .alert("Notice", isPresented: $showAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(alertMessage)
                }
            }
        } else {
            //logged in
            VStack(alignment: .leading) {
                Text("Please login in profile page first")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                NavigationLink(destination: ProfileView()) {
                    Text("Login")
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
        }
    }
    
    private func uploadPost(userId: String) {
        guard let imageData = selectedImageData else { return }
        isUploading = true
        
        print("Starting upload to Imgur...")
        
        // Create URL request
        var request = URLRequest(url: URL(string: imgurUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(imgurClientId)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Send request
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print(" Imgur upload error: \(error.localizedDescription)")
                    alertMessage = "Upload failed: \(error.localizedDescription)"
                    showAlert = true
                    isUploading = false
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print(" HTTP response code: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print(" No data received")
                    alertMessage = "No data received"
                    showAlert = true
                    isUploading = false
                    return
                }
                
                do {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print(" Imgur API response: \(jsonString)")
                    }
                    
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print(" Parsed JSON data: \(json)")
                        
                        if let success = json["success"] as? Bool,
                           success,
                           let data = json["data"] as? [String: Any],
                           let imageUrl = data["link"] as? String {
                            print(" Image upload successful!")
                            print(" Image URL: \(imageUrl)")
                            
                            saveToFirestore(imageUrl: imageUrl)
                        } else {
                            print(" Image upload failed: Invalid response format")
                            alertMessage = "Upload failed"
                            showAlert = true
                            isUploading = false
                        }
                    }
                } catch {
                    print(" JSON parsing error: \(error.localizedDescription)")
                    alertMessage = "Data parsing failed: \(error.localizedDescription)"
                    showAlert = true
                    isUploading = false
                }
            }
        }.resume()
    }
    
    private func saveToFirestore(imageUrl: String) {
        print(" Starting save to Firestore...")
        print(" Using image URL: \(imageUrl)")
        
        let recipeId = "R\(UUID().uuidString.prefix(6))"
        print(" Generated Recipe ID: \(recipeId)")
        
        let db = Firestore.firestore()
        let recipeData: [String: Any] = [
            "description": description,
            "rimg": imageUrl,
            "uid": userUID,
            "like": 0,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        print("📋 Data to save: \(recipeData)")
        
        db.collection("Recipe").document(recipeId).setData(recipeData) { error in
            DispatchQueue.main.async {
                isUploading = false
                if let error = error {
                    print(" Firestore save failed: \(error.localizedDescription)")
                    alertMessage = "Save failed: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    print(" Data saved to Firestore!")
                    print(" Process completed!")
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    AddExploreView()
}
