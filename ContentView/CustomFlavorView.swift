import SwiftUI

struct CustomFlavorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFlavor: String
    @State private var customInput: String = ""
    @State private var tempSelectedFlavor: String
    
    // 預定義的口味選項
    let flavorOptions = ["Spicy", "Sweet", "Sour", "Savory", "Bitter"]
    
    init(selectedFlavor: Binding<String>) {
        self._selectedFlavor = selectedFlavor
        self._tempSelectedFlavor = State(initialValue: selectedFlavor.wrappedValue)
        
        // 如果選擇的不是標準口味，則設置為自定義輸入
        if !["Spicy", "Sweet", "Sour", "Savory", "Bitter", ""].contains(selectedFlavor.wrappedValue) {
            self._customInput = State(initialValue: selectedFlavor.wrappedValue)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 標題和說明
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Your Preferred Flavor")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose from common options or create your own custom flavor")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 預定義口味選項
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(flavorOptions, id: \.self) { flavor in
                            Button(action: {
                                tempSelectedFlavor = flavor
                                customInput = ""
                            }) {
                                HStack {
                                    Text(flavor)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if tempSelectedFlavor == flavor {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(tempSelectedFlavor == flavor ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(tempSelectedFlavor == flavor ? Color.orange : Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // 自定義口味輸入欄位
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Can't find your preferred flavor?")
                                .font(.headline)
                                .padding(.top, 10)
                            
                            HStack {
                                TextField("Enter your custom flavor", text: $customInput)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                    .onChange(of: customInput) { newValue in
                                        if !newValue.isEmpty {
                                            tempSelectedFlavor = newValue
                                        } else if customInput.isEmpty && tempSelectedFlavor == customInput {
                                            tempSelectedFlavor = ""
                                        }
                                    }
                                
                                if !customInput.isEmpty {
                                    Button(action: {
                                        customInput = ""
                                        if !flavorOptions.contains(tempSelectedFlavor) {
                                            tempSelectedFlavor = ""
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.trailing, 8)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(!flavorOptions.contains(tempSelectedFlavor) && !tempSelectedFlavor.isEmpty ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(!flavorOptions.contains(tempSelectedFlavor) && !tempSelectedFlavor.isEmpty ? Color.orange : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding()
                }
                
                // 確認按鈕
                Button(action: {
                    selectedFlavor = tempSelectedFlavor
                    dismiss()
                }) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(tempSelectedFlavor.isEmpty && customInput.isEmpty)
                .opacity((tempSelectedFlavor.isEmpty && customInput.isEmpty) ? 0.5 : 1)
            }
            .navigationBarTitle("Flavor Preferences", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .padding(.bottom, 20)
        }
    }
}

struct CustomFlavorView_Previews: PreviewProvider {
    static var previews: some View {
        CustomFlavorView(selectedFlavor: .constant("Sweet"))
    }
} 