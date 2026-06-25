import SwiftUI

struct FlavorSelectionSheet: View {
    @Binding var selectedFlavor: String
    @State private var customFlavor: String = ""
    @Environment(\.dismiss) private var dismiss
    
    // 預定義的口味選項
    private let predefinedFlavors = ["Spicy", "Sweet", "Sour", "Savory", "Bitter"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 標題和說明
                    VStack(spacing: 8) {
                        Text("Select Flavor")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose a flavor that matches your preference")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    // 預定義口味選項
                    VStack(spacing: 12) {
                        ForEach(predefinedFlavors, id: \.self) { flavor in
                            Button(action: {
                                selectedFlavor = flavor
                                dismiss()
                            }) {
                                HStack {
                                    Text(flavor)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedFlavor == flavor {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedFlavor == flavor ? Color.orange.opacity(0.1) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedFlavor == flavor ? Color.orange : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    // 自定義口味輸入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Flavor")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextField("Enter your own flavor preference", text: $customFlavor)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        Button(action: {
                            if !customFlavor.isEmpty {
                                selectedFlavor = customFlavor
                                dismiss()
                            }
                        }) {
                            Text("Use Custom Flavor")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(customFlavor.isEmpty ? Color.gray : Color.orange)
                                .cornerRadius(10)
                        }
                        .disabled(customFlavor.isEmpty)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitle("Flavor Options", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.orange))
        }
    }
}

struct FlavorSelectionSheet_Previews: PreviewProvider {
    static var previews: some View {
        FlavorSelectionSheet(selectedFlavor: .constant("Sweet"))
    }
} 