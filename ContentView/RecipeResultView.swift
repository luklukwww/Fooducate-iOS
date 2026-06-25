import SwiftUI

struct RecipeResultView: View {
    let recipes: [Recipe]

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(recipes) { recipe in
                    NavigationLink(destination: DetailOfRecipeView(recipeId: recipe.id)) {
                        VStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white)
                                .shadow(radius: 2)
                                .overlay(
                                    VStack {
                                        if let imageUrl = URL(string: recipe.image) {
                                            AsyncImage(url: imageUrl) { image in
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(height: 100)
                                                    .cornerRadius(10)
                                            } placeholder: {
                                                ProgressView()
                                            }
                                        }
                                        Text(recipe.title)
                                            .font(.headline)
                                            .padding(.top, 5)
                                    }
                                    .padding()
                                )
                                .frame(height: 200)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Recipe Results")
    }
}

struct RecipeResultView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeResultView(recipes: [])
    }
}
