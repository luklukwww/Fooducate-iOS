import SwiftUI

struct GestureGuideView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("How to Use Gesture Control")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 24))
                }
            }
            .padding(.bottom, 8)
            
            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    gestureInstructionRow(
                        icon: "hand.point.up.fill",
                        title: "Previous Step",
                        description: "Point your finger upward to go to the previous cooking step"
                    )
                    
                    gestureInstructionRow(
                        icon: "hand.point.down.fill",
                        title: "Next Step",
                        description: "Point your finger downward to advance to the next cooking step"
                    )
                    
                    // Additional tip
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pro Tip")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("Hold your hand gesture steady to continuously navigate through steps. The gesture will be recognized as long as your hand remains in position.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 相機權限提示
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Camera Access Required")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("This feature requires camera access to detect your hand gestures. If the feature doesn't work, please check your camera permission settings.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Open Settings")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Add some space at the bottom of scroll content
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 10)
            }
            
            // Confirmation button - Always visible at the bottom
            Button(action: {
                isPresented = false
            }) {
                Text("Got it!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    private func gestureInstructionRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.orange)
                .frame(width: 50, height: 50)
                .background(Color.orange.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
} 