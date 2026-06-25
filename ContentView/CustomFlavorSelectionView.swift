import SwiftUI

struct CustomFlavorSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFlavor: String
    @State private var customFlavor: String = ""
    @State private var showCustomInput: Bool = false
    
    // 所有可用的口味選項
    private let flavors = ["Spicy", "Sweet", "Sour", "Savory", "Bitter"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 標題和說明
                VStack(spacing: 8) {
                    Text("Select Flavor")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose a flavor for your recipe or add a custom one")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // 預設口味選項列表
                VStack(spacing: 12) {
                    ForEach(flavors, id: \.self) { flavor in
                        Button(action: {
                            selectedFlavor = flavor
                            dismiss()
                        }) {
                            HStack {
                                Text(flavor)
                                    .foregroundColor(.primary)
                                    .font(.headline)
                                
                                Spacer()
                                
                                if selectedFlavor == flavor {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedFlavor == flavor ? Color.orange : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                    
                    // 自定義口味按鈕
                    Button(action: {
                        showCustomInput.toggle()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange)
                            
                            Text("Custom Flavor")
                                .foregroundColor(.primary)
                                .font(.headline)
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                    
                    // 自定義口味輸入區域
                    if showCustomInput {
                        VStack(spacing: 15) {
                            TextField("Enter custom flavor", text: $customFlavor)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            
                            Button(action: {
                                if !customFlavor.isEmpty {
                                    selectedFlavor = customFlavor
                                    dismiss()
                                }
                            }) {
                                Text("Done")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(height: 44)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .disabled(customFlavor.isEmpty)
                            .opacity(customFlavor.isEmpty ? 0.6 : 1)
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitle("Flavor Options", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.orange)
            )
        }
    }
}

struct CustomFlavorSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        CustomFlavorSelectionView(selectedFlavor: .constant("Sweet"))
    }
} 