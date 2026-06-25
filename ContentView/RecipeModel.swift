//
//  RecipeModel.swift
//  ContentView
//
//  Created by honman luk on 19/10/2024.
//

import Foundation

struct RecipeResponse: Codable {
    let results: [Recipe]
}

struct Recipe: Codable, Identifiable {
    let id: Int
    let title: String
    let image: String
}
