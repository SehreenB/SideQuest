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
                            .foregroundStyle(Theme.sage)
                    }
                }

                Button {
                    let service = GeminiService()
                    Task {
                        isAnalyzing = true
                        defer { isAnalyzing = false }
                        do {
                            if let selectedImageData {
                                let analysis = try await service.analyzePhoto(imageData: selectedImageData)
                                suggestedCaption = analysis.suggestedCaption
                                suggestedTags = analysis.tags
                            } else {
                                let analysis = try await service.analyzePhoto(base64JPEG: "")
                                suggestedCaption = analysis.suggestedCaption
                                suggestedTags = analysis.tags
                            }
                        } catch {
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(isAnalyzing ? "Analyzing..." : "Suggest caption & tags")
                    }
                    .font(ThemeFont.bodySmallStrong)
                    .foregroundStyle(Theme.gold)
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

                Picker("Visibility", selection: $visibility) {
                    Text("Just for me").tag(MemoryVisibility.private)
                    Text("Share with explorers").tag(MemoryVisibility.public)
                }
                .pickerStyle(.segmented)

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
                            visibility: memory.visibility == .public ? "public" : "private",
                            photoData: selectedImageData
                        )
                    }

                    dismiss()
                } label: {
                    Text("Save Memory")
                        .font(ThemeFont.buttonSmall)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.terracotta)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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
