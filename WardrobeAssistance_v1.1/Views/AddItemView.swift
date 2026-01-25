//
//  AddItemView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import PhotosUI
import UIKit

struct AddItemView: View {
    @EnvironmentObject var viewModel: WardrobeViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var selectedCategory: ClothingCategory = .tops
    @State private var selectedColor: ClothingColor = .black
    @State private var selectedSeason: Season = .allSeason
    @State private var selectedStyle: Style = .casual
    @State private var material: String = ""
    @State private var brand: String = ""
    @State private var tags: String = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Image")) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showingImagePicker = true
                    }) {
                        HStack {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                    .frame(width: 100, height: 100)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Spacer()
                            Text("Add Photo")
                                .foregroundColor(.blue)
                        }
                    }
                    .actionSheet(isPresented: $showingImagePicker) {
                        ActionSheet(
                            title: Text("Select Photo"),
                            buttons: [
                                .default(Text("Camera")) {
                                    imagePickerSourceType = .camera
                                    showingCamera = true
                                },
                                .default(Text("Photo Library")) {
                                    imagePickerSourceType = .photoLibrary
                                    showingCamera = true
                                },
                                .cancel()
                            ]
                        )
                    }
                }
                
                Section(header: Text("Basic Information")) {
                    TextField("Item Name", text: $name)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ClothingCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    
                    Picker("Color", selection: $selectedColor) {
                        ForEach(ClothingColor.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 20, height: 20)
                                Text(color.rawValue)
                            }
                            .tag(color)
                        }
                    }
                }
                
                Section(header: Text("Style & Season")) {
                    Picker("Season", selection: $selectedSeason) {
                        ForEach(Season.allCases, id: \.self) { season in
                            Text(season.rawValue).tag(season)
                        }
                    }
                    
                    Picker("Style", selection: $selectedStyle) {
                        ForEach(Style.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }
                
                Section(header: Text("Additional Information")) {
                    TextField("Material (optional)", text: $material)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Tags (comma-separated)", text: $tags)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        saveItem()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $selectedImage, sourceType: imagePickerSourceType)
            }
        }
    }
    
    private func saveItem() {
        isSaving = true
        
        let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        Task {
            await viewModel.addItem(
                name: name,
                category: selectedCategory,
                color: selectedColor,
                season: selectedSeason,
                style: selectedStyle,
                image: selectedImage,
                material: material.isEmpty ? nil : material,
                brand: brand.isEmpty ? nil : brand,
                tags: Array(tagArray)
            )
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    AddItemView()
        .environmentObject(WardrobeViewModel())
}

