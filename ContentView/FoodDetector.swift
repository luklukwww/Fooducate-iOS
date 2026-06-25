import UIKit

class MockFoodDetector {
    private var model: MockSeeFood?
    
    init() {
        do {
            let configuration = MockMLModelConfiguration()
            model = try MockSeeFood(configuration: configuration)
        } catch {
            print("Model initialization failed: \(error)")
        }
    }
    
    func detectFood(from image: UIImage, completion: @escaping (String?) -> Void) {
        print("Starting food detection...")
        

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            completion("Mixed Ingredients - 98.00%")
        }
    }
    
    private func convertToCVPixelBuffer(image: UIImage) -> CVPixelBuffer? {
        return nil
    }
} 
