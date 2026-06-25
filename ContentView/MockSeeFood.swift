import Foundation
import UIKit


class MockSeeFood {
    init(configuration: MockMLModelConfiguration) throws {

    }
    
    func prediction(image: CVPixelBuffer) throws -> MockSeeFood.Output {
        return Output(classLabel: "Mixed Ingredients", foodConfidence: ["Mixed Ingredients": 0.98])
    }
    
    class Output {
        let classLabel: String
        let foodConfidence: [String: Double]
        
        init(classLabel: String, foodConfidence: [String: Double]) {
            self.classLabel = classLabel
            self.foodConfidence = foodConfidence
        }
    }
}


class MockMLModelConfiguration {

} 
