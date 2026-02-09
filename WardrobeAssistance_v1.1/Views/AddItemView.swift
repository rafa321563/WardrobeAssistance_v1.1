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
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Form State

    @State private var name = ""
    @State private var selectedCategory: ClothingCategory = .tops
    @State private var selectedColor: ClothingColor = .black
    @State private var selectedSeason: Season = .allSeason
    @State private var selectedStyle: Style? = .casual       // nil = custom
    @State private var customStyleText = ""
    @State private var selectedSize: String? = nil       // nil = no size / custom
    @State private var customSizeText = ""
    @State private var selectedMaterial: String? = MaterialPreset.presets[0]  // nil = custom
    @State private var customMaterialText = ""
    @State private var brand = ""
    @State private var tags = ""

    // MARK: - Image Pipeline State

    @State private var rawPickedImage: UIImage?       // untouched photo from picker
    @State private var standardImage: UIImage?         // after remove.bg (beforeImage)
    @State private var magicImage: UIImage?            // after Photoroom  (afterImage)
    @State private var activeImage: UIImage?           // currently displayed image

    // MARK: - Processing State

    @State private var isProcessingStandard = false
    @State private var isProcessingMagic = false
    @State private var isAnalyzing = false
    @State private var processingError: String?
    @State private var isSaving = false

    // MARK: - UI State

    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isComparingBeforeAfter = false  // long-press active
    @State private var showComparisonTooltip = false
    @State private var processingStartTime: Date?

    // MARK: - Computed

    private var isStandardDone: Bool { standardImage != nil }
    private var isMagicDone: Bool { magicImage != nil }
    private var hasTransparency: Bool { standardImage != nil }
    private var showMagicButton: Bool { isStandardDone && !isMagicDone && !isProcessingStandard }
    private var isBusy: Bool { isSaving || isProcessingStandard || isProcessingMagic }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                imageHeroSection
                ScrollView {
                    VStack(spacing: AppDesign.Spacing.l) {
                        fieldsSection
                    }
                    .padding(.horizontal, AppDesign.Spacing.m)
                    .padding(.top, AppDesign.Spacing.l)
                    .padding(.bottom, AppDesign.Spacing.xxl)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("add_item.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(NSLocalizedString("add_item.save", comment: "")) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            saveItem()
                        }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || isBusy)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $rawPickedImage, sourceType: imagePickerSourceType)
            }
            .onChange(of: selectedCategory) { _ in
                if let current = selectedSize, current != "__custom__" {
                    let newPresets = SizePreset.presets(for: selectedCategory)
                    if !newPresets.contains(current) {
                        selectedSize = nil
                        customSizeText = ""
                    }
                }
            }
            .onChange(of: rawPickedImage) { newImage in
                guard let newImage = newImage else { return }
                resetPipeline()
                activeImage = newImage
                runStandardProcessing(newImage)
                runClothingAnalysis(newImage)
            }
            .confirmationDialog(
                NSLocalizedString("add_item.select_photo", comment: ""),
                isPresented: $showingImagePicker,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("add_item.camera", comment: "")) {
                    imagePickerSourceType = .camera
                    showingCamera = true
                }
                Button(NSLocalizedString("add_item.photo_library", comment: "")) {
                    imagePickerSourceType = .photoLibrary
                    showingCamera = true
                }
                Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
            }
        }
    }

    // MARK: - Hero Image

    private var imageHeroSection: some View {
        ZStack {
            // Background — light gray so white Photoroom studio result stands out
            Color(white: 0.97)

            // The displayed image (swaps on long-press for comparison)
            if let displayImage = isComparingBeforeAfter ? standardImage : activeImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(AppDesign.Spacing.l)
                    .animation(.easeInOut(duration: 0.15), value: isComparingBeforeAfter)
            } else {
                // Empty state
                VStack(spacing: AppDesign.Spacing.m) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text(NSLocalizedString("add_item.tap_to_add_photo", comment: ""))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }

            // Processing overlay
            if isProcessingStandard || isProcessingMagic {
                Color.black.opacity(0.35)
                ProcessingProgressOverlay(startTime: processingStartTime ?? Date())
            }

            // "Before" label during long-press
            if isComparingBeforeAfter {
                VStack {
                    Text(NSLocalizedString("image.processing.before", comment: "Before"))
                        .font(AppDesign.Typography.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppDesign.Spacing.s)
                        .padding(.vertical, AppDesign.Spacing.xs)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.top, AppDesign.Spacing.s)
                    Spacer()
                }
            }

            // Overlaid buttons (camera + magic)
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Camera / retake
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingImagePicker = true
                    } label: {
                        Image(systemName: activeImage == nil ? "camera.fill" : "arrow.triangle.2.circlepath.camera.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppDesign.Colors.textPrimary(colorScheme))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.medium))
                    }

                    Spacer()

                    // Magic enhance button
                    if showMagicButton {
                        ShimmerMagicButton {
                            runMagicProcessing()
                        }
                        .disabled(isProcessingMagic)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(AppDesign.Spacing.m)
            }

            // Comparison tooltip
            if showComparisonTooltip {
                VStack {
                    Spacer()
                    Text(NSLocalizedString("image.processing.compare_hint", comment: ""))
                        .font(AppDesign.Typography.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppDesign.Spacing.m)
                        .padding(.vertical, AppDesign.Spacing.s)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(.bottom, 64)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            // Error badge
            if let error = processingError {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppDesign.Colors.warning)
                        Text(error)
                            .font(AppDesign.Typography.caption)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, AppDesign.Spacing.m)
                    .padding(.vertical, AppDesign.Spacing.s)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.small))
                    .padding(.horizontal, AppDesign.Spacing.m)
                    Spacer()
                }
                .padding(.top, AppDesign.Spacing.s)
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.45)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if activeImage == nil {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingImagePicker = true
            }
        }
        .simultaneousGesture(
            isMagicDone
                ? LongPressGesture(minimumDuration: 0.15)
                    .onChanged { _ in
                        if !isComparingBeforeAfter {
                            isComparingBeforeAfter = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                    .onEnded { _ in }
                : nil
        )
        .simultaneousGesture(
            isMagicDone
                ? DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        if isComparingBeforeAfter {
                            isComparingBeforeAfter = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                : nil
        )
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        VStack(spacing: 0) {
            fieldRow(label: NSLocalizedString("add_item.category", comment: "")) {
                Picker("", selection: $selectedCategory) {
                    ForEach(ClothingCategory.allCases, id: \.self) { cat in
                        HStack { Image(systemName: cat.icon); Text(cat.rawValue) }.tag(cat)
                    }
                }
                .tint(AppDesign.Colors.textPrimary(colorScheme))
            }
            Divider().padding(.leading, AppDesign.Spacing.m)

            fieldRow(label: NSLocalizedString("add_item.brand", comment: "")) {
                TextField("", text: $brand)
                    .multilineTextAlignment(.trailing)
            }
            Divider().padding(.leading, AppDesign.Spacing.m)

            fieldRow(label: NSLocalizedString("add_item.name", comment: "")) {
                TextField("", text: $name)
                    .multilineTextAlignment(.trailing)
            }
            Divider().padding(.leading, AppDesign.Spacing.m)

            fieldRow(label: NSLocalizedString("add_item.color", comment: "")) {
                Picker("", selection: $selectedColor) {
                    ForEach(ClothingColor.allCases, id: \.self) { color in
                        HStack {
                            Circle().fill(color.color).frame(width: 16, height: 16)
                            Text(color.rawValue)
                        }.tag(color)
                    }
                }
                .tint(AppDesign.Colors.textPrimary(colorScheme))
            }
            Divider().padding(.leading, AppDesign.Spacing.m)

            fieldRow(label: NSLocalizedString("add_item.size", comment: "")) {
                Picker("", selection: $selectedSize) {
                    Text("—").tag(String?.none)
                    ForEach(sizePresets, id: \.self) { s in
                        Text(s).tag(String?.some(s))
                    }
                    Text(NSLocalizedString("add_item.custom_option", comment: ""))
                        .tag(String?.some("__custom__"))
                }
                .tint(AppDesign.Colors.textPrimary(colorScheme))
            }
            if selectedSize == "__custom__" {
                fieldRow(label: "") {
                    TextField(NSLocalizedString("add_item.custom_placeholder", comment: ""), text: $customSizeText)
                        .multilineTextAlignment(.trailing)
                }
            }
            Divider().padding(.leading, AppDesign.Spacing.m)

            fieldRow(label: NSLocalizedString("add_item.season", comment: "")) {
                Picker("", selection: $selectedSeason) {
                    ForEach(Season.allCases, id: \.self) { s in Text(s.rawValue).tag(s) }
                }
                .tint(AppDesign.Colors.textPrimary(colorScheme))
            }
            Divider().padding(.leading, AppDesign.Spacing.m)

            fieldRow(label: NSLocalizedString("add_item.style", comment: "")) {
                Picker("", selection: $selectedStyle) {
                    ForEach(Style.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(Style?.some(s))
                    }
                    Text(NSLocalizedString("add_item.custom_option", comment: ""))
                        .tag(Style?.none)
                }
                .tint(AppDesign.Colors.textPrimary(colorScheme))
            }
            if selectedStyle == nil {
                fieldRow(label: "") {
                    TextField(NSLocalizedString("add_item.custom_placeholder", comment: ""), text: $customStyleText)
                        .multilineTextAlignment(.trailing)
                }
            }
            Divider().padding(.leading, AppDesign.Spacing.m)

            fieldRow(label: NSLocalizedString("add_item.material", comment: "")) {
                Picker("", selection: $selectedMaterial) {
                    ForEach(MaterialPreset.presets, id: \.self) { m in
                        Text(m).tag(String?.some(m))
                    }
                    Text(NSLocalizedString("add_item.custom_option", comment: ""))
                        .tag(String?.none)
                }
                .tint(AppDesign.Colors.textPrimary(colorScheme))
            }
            if selectedMaterial == nil {
                fieldRow(label: "") {
                    TextField(NSLocalizedString("add_item.custom_placeholder", comment: ""), text: $customMaterialText)
                        .multilineTextAlignment(.trailing)
                }
            }
            Divider().padding(.leading, AppDesign.Spacing.m)

            fieldRow(label: NSLocalizedString("add_item.tags", comment: "")) {
                TextField(NSLocalizedString("add_item.tags_placeholder", comment: ""), text: $tags)
                    .multilineTextAlignment(.trailing)
            }
        }
        .background(AppDesign.Colors.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.large))
    }

    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            if !label.isEmpty {
                Text(label)
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(AppDesign.Colors.textSecondary(colorScheme))
                    .fixedSize()
            }
            content()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, AppDesign.Spacing.m)
        .frame(minHeight: 48)
    }

    // MARK: - Actions

    private func resetPipeline() {
        standardImage = nil
        magicImage = nil
        processingError = nil
        showComparisonTooltip = false
        isComparingBeforeAfter = false
    }

    private var sizePresets: [String] {
        SizePreset.presets(for: selectedCategory)
    }

    private var resolvedSize: String? {
        if let preset = selectedSize, preset != "__custom__" {
            return preset
        }
        return customSizeText.isEmpty ? nil : customSizeText
    }

    private var resolvedMaterial: String? {
        if let preset = selectedMaterial {
            return preset
        }
        return customMaterialText.isEmpty ? nil : customMaterialText
    }

    private func saveItem() {
        isSaving = true
        let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let styleOverride: String? = (selectedStyle == nil && !customStyleText.isEmpty) ? customStyleText : nil

        Task {
            await viewModel.addItem(
                name: name,
                category: selectedCategory,
                color: selectedColor,
                season: selectedSeason,
                style: selectedStyle ?? .casual,
                styleOverride: styleOverride,
                image: activeImage,
                material: resolvedMaterial,
                brand: brand.isEmpty ? nil : brand,
                size: resolvedSize,
                tags: Array(tagArray),
                hasTransparency: hasTransparency
            )
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }

    private func runStandardProcessing(_ image: UIImage) {
        isProcessingStandard = true
        processingStartTime = Date()
        processingError = nil

        Task {
            do {
                let result = try await ImageProcessingService.shared.processImage(image, mode: .standard)
                await MainActor.run {
                    standardImage = result.image
                    activeImage = result.image
                    isProcessingStandard = false
                    processingStartTime = nil
                }
            } catch {
                await MainActor.run {
                    processingError = error.localizedDescription
                    isProcessingStandard = false
                    processingStartTime = nil
                }
            }
        }
    }

    private func runMagicProcessing() {
        guard let source = rawPickedImage else { return }
        isProcessingMagic = true
        processingStartTime = Date()
        processingError = nil

        Task {
            do {
                let result = try await ImageProcessingService.shared.processImage(source, mode: .magic)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        magicImage = result.image
                        activeImage = result.image
                    }
                    isProcessingMagic = false
                    processingStartTime = nil
                    showTooltip()
                }
            } catch {
                await MainActor.run {
                    processingError = error.localizedDescription
                    isProcessingMagic = false
                    processingStartTime = nil
                }
            }
        }
    }

    private func runClothingAnalysis(_ image: UIImage) {
        isAnalyzing = true

        Task {
            do {
                let result = try await ClothingAnalysisService.shared.analyzeImage(image)
                await MainActor.run {
                    applyAnalysisResult(result)
                    isAnalyzing = false
                    print("[ClothingAnalysis] Success: \(result)")
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    print("[ClothingAnalysis] Error: \(error)")
                }
            }
        }
    }

    private func applyAnalysisResult(_ result: ClothingAnalysisResult) {
        if name.isEmpty, let aiName = result.name {
            name = aiName
        }
        if brand.isEmpty, let aiBrand = result.brand {
            brand = aiBrand
        }
        if let aiMaterial = result.material, !aiMaterial.isEmpty {
            if let matchedPreset = MaterialPreset.presets.first(where: {
                $0.caseInsensitiveCompare(aiMaterial) == .orderedSame
            }) {
                selectedMaterial = matchedPreset
            } else {
                selectedMaterial = nil
                customMaterialText = aiMaterial
            }
        }
        if tags.isEmpty, let aiTags = result.tags, !aiTags.isEmpty {
            tags = aiTags.joined(separator: ", ")
        }
        if let aiCategory = result.category {
            selectedCategory = aiCategory
        }
        if let aiColor = result.color {
            selectedColor = aiColor
        }
        if let aiSeason = result.season {
            selectedSeason = aiSeason
        }
        if let aiStyle = result.style {
            selectedStyle = aiStyle
        }
        if let aiSize = result.size, !aiSize.isEmpty {
            let presets = SizePreset.presets(for: selectedCategory)
            if presets.contains(where: { $0.caseInsensitiveCompare(aiSize) == .orderedSame }) {
                selectedSize = presets.first { $0.caseInsensitiveCompare(aiSize) == .orderedSame }
            } else {
                selectedSize = "__custom__"
                customSizeText = aiSize
            }
        }
    }

    private func showTooltip() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showComparisonTooltip = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showComparisonTooltip = false
            }
        }
    }
}

// MARK: - Processing Progress Overlay

struct ProcessingProgressOverlay: View {
    let startTime: Date

    private let expectedDuration: TimeInterval = 8
    private let slowThreshold: TimeInterval = 3

    private func elapsed(at date: Date) -> TimeInterval {
        date.timeIntervalSince(startTime)
    }

    private func progress(at date: Date) -> Double {
        let t = elapsed(at: date)
        return min(1.0 - exp(-t / expectedDuration), 0.95)
    }

    var body: some View {
        TimelineView(.periodic(from: startTime, by: 0.15)) { context in
            let t = elapsed(at: context.date)
            let p = progress(at: context.date)
            let isSlow = t >= slowThreshold

            VStack(spacing: AppDesign.Spacing.m) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * p)
                            .animation(.easeOut(duration: 0.3), value: p)
                    }
                }
                .frame(width: 200, height: 4)

                if !isSlow {
                    Text(NSLocalizedString("image.processing.ai_processing", comment: ""))
                        .font(AppDesign.Typography.caption)
                        .foregroundColor(.white)
                }

                if isSlow {
                    VStack(spacing: AppDesign.Spacing.xs) {
                        Text(NSLocalizedString("image.processing.taking_longer", comment: ""))
                            .font(AppDesign.Typography.caption)
                            .foregroundColor(.white)
                        Text(NSLocalizedString("image.processing.taking_longer_hint", comment: ""))
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isSlow)
        }
    }
}

// MARK: - Material Presets

enum MaterialPreset {
    static let presets: [String] = [
        "Cotton",
        "Polyester",
        "Denim",
        "Leather",
        "Wool",
        "Silk",
        "Linen",
        "Nylon",
        "Cashmere",
        "Suede",
        "Velvet",
        "Synthetic",
    ]
}

// MARK: - Shimmer Magic Button

struct ShimmerMagicButton: View {
    let action: () -> Void

    @State private var shimmerOffset: CGFloat = -1.0
    @State private var sparkleScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppDesign.Spacing.s) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .scaleEffect(sparkleScale)
                Text(NSLocalizedString("image.processing.enhance", comment: ""))
                    .font(AppDesign.Typography.captionBold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, AppDesign.Spacing.m)
            .padding(.vertical, AppDesign.Spacing.s + 2)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "7B2FF7"), Color(hex: "C13BFE")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    // Shimmer sweep
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.35), location: 0.5),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .scaleEffect(x: 0.4, y: 1)
                    .offset(x: shimmerOffset * 100)
                }
            )
            .clipShape(Capsule())
            .shadow(color: Color(hex: "7B2FF7").opacity(0.4), radius: 8, y: 4)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.0
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                sparkleScale = 1.25
            }
        }
    }
}

// MARK: - Checkerboard Background

struct CheckerboardBackground: View {
    let tileSize: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let rows = Int(ceil(size.height / tileSize))
            let cols = Int(ceil(size.width / tileSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? Color(.systemGray6) : Color(.systemGray5))
                    )
                }
            }
        }
    }
}

// MARK: - Image Picker

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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

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
