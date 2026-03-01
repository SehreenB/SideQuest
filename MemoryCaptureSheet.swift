import SwiftUI
import CoreLocation
import PhotosUI
import UIKit

struct MemoryCaptureSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss

    let spot: Spot

    @State private var caption: String = ""
    @State private var visibility: MemoryVisibility = .private
    @State private var suggestedCaption: String?
    @State private var suggestedTags: [String] = []
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoLibraryPicker = false
    @State private var isAnalyzing = false
    @State private var suggestionErrorText: String?
    @State private var showFriendsSignInAlert = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Capture this moment")
                    .font(ThemeFont.sectionTitle)
                    .foregroundStyle(Theme.text)

                Text(spot.name)
                    .font(ThemeFont.bodySmallStrong)
                    .foregroundStyle(Theme.terracotta)

                Button {
                    showSourcePicker = true
                } label: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.5))
                        .frame(height: 180)
                        .overlay {
                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(Theme.terracotta)
                                    Text("Tap to add photo")
                                        .font(ThemeFont.caption)
                                        .foregroundStyle(Theme.text.opacity(0.6))
                                }
                            }
                        }
                }
                .buttonStyle(.plain)

                Text("What made this moment special?")
                    .font(ThemeFont.bodySmallStrong)
                    .foregroundStyle(Theme.text.opacity(0.7))

                TextField("Caption", text: $caption, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(12)
                    .background(.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                if let suggested = suggestedCaption {
                    Button {
                        caption = suggested
                    } label: {
                        Text("Use: \"\(suggested)\"")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.text.opacity(0.78))
                    }
                }

                Button {
                    Task {
                        await suggestCaptionAndTags()
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(isAnalyzing ? "Generating suggestions..." : "Suggest caption & tags")
                    }
                    .font(ThemeFont.bodySmallStrong)
                    .foregroundStyle(Theme.terracotta)
                }
                .disabled(isAnalyzing)

                if !suggestedTags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(suggestedTags, id: \.self) { tag in
                            Text(tag)
                                .font(ThemeFont.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.sage.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(Theme.sage)
                        }
                    }
                }

                if let suggestionErrorText {
                    Text(suggestionErrorText)
                        .font(ThemeFont.micro)
                        .foregroundStyle(Theme.text.opacity(0.64))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Visibility")
                        .font(ThemeFont.caption)
                        .foregroundStyle(Theme.text.opacity(0.68))

                    HStack(spacing: 10) {
                        visibilityPill(
                            title: "Just for me",
                            subtitle: "+25 pts",
                            option: .private
                        )
                        visibilityPill(
                            title: "Friends only",
                            subtitle: "+40 pts",
                            option: .friends
                        )
                        visibilityPill(
                            title: "Share with explorers",
                            subtitle: "+60 pts",
                            option: .public
                        )
                    }
                }

                Spacer()

                Button {
                    let memory = MemoryItem(
                        id: UUID(),
                        userId: app.user.id,
                        spotId: spot.id,
                        caption: caption.isEmpty ? "A SideQuest moment." : caption,
                        tags: suggestedTags,
                        visibility: visibility,
                        createdAt: Date(),
                        googlePlaceID: spot.googlePlaceID
                    )
                    app.saveMemory(memory)

                    // Save to Vultr backend
                    Task {
                        _ = await APIService.shared.saveMemory(
                            userId: app.user.id.uuidString,
                            caption: memory.caption,
                            tags: memory.tags,
                            lat: spot.coordinate.latitude,
                            lng: spot.coordinate.longitude,
                            visibility: {
                                switch memory.visibility {
                                case .public: return "public"
                                case .friends: return "friends"
                                case .private: return "private"
                                }
                            }(),
                            photoData: selectedImageData
                        )
                    }

                    dismiss()
                } label: {
                    HStack(spacing: 7) {
                        Text("Save memory")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Theme.terracotta)
                    .underline(true, color: Theme.terracotta.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .onAppear {
            visibility = app.user.defaultPublicPosting ? .public : .private
        }
        .confirmationDialog("Add Photo", isPresented: $showSourcePicker, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { showCamera = true }
            }
            Button("Photo Library") { showPhotoLibraryPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker { image in
                selectedImage = image
                selectedImageData = image.jpegData(compressionQuality: 0.85)
            }
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showPhotoLibraryPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                        selectedImageData = data
                    }
                }
            }
        }
        .alert("Sign in required", isPresented: $showFriendsSignInAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sign in to add to friends.")
        }
    }

    @MainActor
    private func suggestCaptionAndTags() async {
        isAnalyzing = true
        suggestionErrorText = nil
        defer { isAnalyzing = false }

        do {
            let service = GeminiService()
            let analysis: GeminiPhotoAnalysis
            if let selectedImageData {
                analysis = try await service.analyzePhoto(imageData: selectedImageData)
            } else {
                analysis = try await service.analyzePhoto(base64JPEG: "")
            }
            suggestedCaption = analysis.suggestedCaption
            suggestedTags = analysis.tags
        } catch {
            let fallback = fallbackSuggestions()
            suggestedCaption = fallback.suggestedCaption
            suggestedTags = fallback.tags
            suggestionErrorText = "Smart suggestions were unavailable. Showing quick local suggestions."
        }
    }

    private func fallbackSuggestions() -> GeminiPhotoAnalysis {
        let baseTags: [String]
        switch spot.category {
        case .mural:
            baseTags = ["street art", "colorful", "urban", "creative", "local"]
        case .cafe, .restaurant:
            baseTags = ["cozy", "foodie", "local favorite", "warm", "city vibes"]
        case .park, .viewpoint:
            baseTags = ["scenic", "calm", "nature", "fresh air", "wander"]
        case .gallery, .bookstore:
            baseTags = ["culture", "inspiring", "quiet", "curated", "explore"]
        case .market, .patio:
            baseTags = ["lively", "community", "hidden gem", "weekend", "city life"]
        }

        let defaultCaption = "A memorable SideQuest moment at \(spot.name) worth coming back to."
        return GeminiPhotoAnalysis(tags: baseTags, suggestedCaption: caption.isEmpty ? defaultCaption : caption)
    }

    private func visibilityPill(title: String, subtitle: String, option: MemoryVisibility) -> some View {
        let selected = visibility == option
        return Button {
            if option == .friends && !app.isSignedIn {
                showFriendsSignInAlert = true
                return
            }
            visibility = option
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Theme.terracotta : Theme.text.opacity(0.80))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Theme.sage : Theme.text.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selected ? Theme.terracotta.opacity(0.10) : .white.opacity(0.50))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Theme.terracotta.opacity(0.45) : Theme.text.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPicked: (UIImage) -> Void
        let dismissAction: DismissAction

        init(onPicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onPicked = onPicked
            self.dismissAction = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onPicked(image)
            }
            dismissAction()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismissAction()
        }
    }
}
