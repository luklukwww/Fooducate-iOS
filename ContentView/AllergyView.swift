import SwiftUI
import FirebaseFirestore
import UIKit

struct BackButtonModifier: ViewModifier {
    @Environment(\.presentationMode) var presentationMode
    @State private var backButtonColor: UIColor = .systemOrange
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.async {
                    let backButtonAppearance = UIBarButtonItemAppearance()
                    backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
                    
                    // Create a new appearance
                    let navigationBarAppearance = UINavigationBarAppearance()
                    navigationBarAppearance.configureWithDefaultBackground()
                    navigationBarAppearance.backButtonAppearance = backButtonAppearance
                    
                    // Set navigation bar back button tint to orange
                    UINavigationBar.appearance().tintColor = backButtonColor
                    UINavigationBar.appearance().standardAppearance = navigationBarAppearance
                    UINavigationBar.appearance().compactAppearance = navigationBarAppearance
                    UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
                }
            }
    }
}

struct AllergyView: View {
    let userUID: String
    @State private var allergies: [AllergyItem] = []
    @State private var newAllergy: String = ""
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var searchText = ""
    @State private var isAddingNew = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    // Animation properties
    @State private var animateAdded = false
    
    struct AllergyItem: Identifiable {
        let id: String
        let allergen: String
    }
    
    var filteredAllergies: [AllergyItem] {
        if searchText.isEmpty {
            return allergies
        } else {
            return allergies.filter { $0.allergen.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color.gray.opacity(0.05)
                .edgesIgnoringSafeArea(.all)
            
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Loading your allergies...")
                        .foregroundColor(.gray)
                        .padding()
                }
            } else {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                            .padding(.top, 20)
                        
                        Text("Manage Your Allergies")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Add any food allergies or sensitivities here to help us customize your experience.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                        
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search allergies", text: $searchText)
                                .autocapitalization(.none)
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                    .padding(.bottom, 10)
                    .background(Color.white)
                    
                    // Divider to separate header from content
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.2))
                    
                    ScrollView {
                        // Main content
                        VStack(spacing: 15) {
                            if filteredAllergies.isEmpty {
                                emptyStateView
                            } else {
                                allergyList
                            }
                        }
                        .padding(.top, 15)
                        .padding(.bottom, 85) // Extra space for bottom input
                    }
                    
                    Spacer()
                }
                
                // Floating input field at bottom
                VStack {
                    Spacer()
                    
                    inputField
                }
            }
        }
        .navigationTitle("Allergies")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            fetchAllergies()
        }
        .alert("Notice", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.top, 40)
            
            Text(searchText.isEmpty ? "No Allergies Added Yet" : "No Matching Allergies")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? 
                 "Add your food allergies to help us customize recommendations for you." : 
                 "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if searchText.isEmpty {
                Button(action: {
                    withAnimation {
                        isAddingNew = true
                    }
                }) {
                    Text("Add Your First Allergy")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // Allergy list view
    private var allergyList: some View {
        VStack(spacing: 12) {
            ForEach(filteredAllergies) { item in
                allergyCard(item: item)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 15)
    }
    
    // Individual allergy card
    private func allergyCard(item: AllergyItem) -> some View {
        HStack {
            HStack(spacing: 12) {
                // Allergy icon
                Image(systemName: "allergens")
                    .font(.system(size: 22))
                    .foregroundColor(.orange)
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                
                Text(item.allergen)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Delete button
            Button(action: {
                withAnimation {
                    deleteAllergy(id: item.id)
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
                    .font(.system(size: 15))
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    // Input field at bottom
    private var inputField: some View {
        VStack {
            HStack(spacing: 12) {
                TextField("Enter allergy (e.g., peanuts, milk)", text: $newAllergy, onCommit: {
                    if !newAllergy.isEmpty {
                        addAllergy()
                    }
                })
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                Button(action: addAllergy) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 46, height: 46)
                        .background(
                            newAllergy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                Color.gray :
                                Color.orange
                        )
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                .disabled(newAllergy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
            .padding(.horizontal, 15)
            .padding(.bottom, 15)
        }
    }
    
    private func fetchAllergies() {
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("User")
            .document(userUID)
            .collection("allergy")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting allergies: \(error)")
                    isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    isLoading = false
                    return
                }
                
                self.allergies = documents.compactMap { doc in
                    guard let allergen = doc.data()["allergen"] as? String else {
                        return nil
                    }
                    return AllergyItem(id: doc.documentID, allergen: allergen)
                }
                
                isLoading = false
            }
    }
    
    private func addAllergy() {
        let allergyText = newAllergy.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if allergyText.isEmpty {
            return
        }
        
        // Check for duplicates
        if allergies.contains(where: { $0.allergen.lowercased() == allergyText.lowercased() }) {
            alertMessage = "This allergy is already in your list."
            showAlert = true
            return
        }
        
        let db = Firestore.firestore()
        let allergyData: [String: Any] = [
            "allergen": allergyText
        ]
        
        db.collection("User")
            .document(userUID)
            .collection("allergy")
            .addDocument(data: allergyData) { error in
                if let error = error {
                    alertMessage = "Error adding allergy: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    // Refresh the list
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        // Create a temporary item for smoother UI
                        let tempID = UUID().uuidString
                        allergies.append(AllergyItem(id: tempID, allergen: allergyText))
                        fetchAllergies() // Refreshes with actual IDs
                    }
                    newAllergy = ""
                    isAddingNew = false
                }
            }
    }
    
    private func deleteAllergy(id: String) {
        let db = Firestore.firestore()
        
        db.collection("User")
            .document(userUID)
            .collection("allergy")
            .document(id)
            .delete { error in
                if let error = error {
                    alertMessage = "Error deleting allergy: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    // Remove from local array with animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        allergies.removeAll { $0.id == id }
                    }
                }
            }
    }
    
    private func deleteAllergyAtOffsets(offsets: IndexSet) {
        for index in offsets {
            let allergy = allergies[index]
            deleteAllergy(id: allergy.id)
        }
    }
}

struct AllergyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AllergyView(userUID: "testUID")
                .accentColor(.orange) // Make preview consistent
        }
        .accentColor(.orange) // Apply to the NavigationView itself
    }
} 
