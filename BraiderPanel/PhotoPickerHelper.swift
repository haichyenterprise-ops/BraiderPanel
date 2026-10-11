import SwiftUI
import PhotosUI
import UIKit

// MARK: - Photo picker button (returns URL)

struct PhotoPickerButton<Label: View>: View {
    var selectionStyle: PhotosPickerFilter = .images
    @ViewBuilder var label: (Bool) -> Label
    let onUploaded: (String) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            label(isUploading)
        }
        .disabled(isUploading)
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task { await handleUpload(newValue) }
        }
        .alert("Upload failed", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK", role: .cancel) { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
    }

    private func handleUpload(_ item: PhotosPickerItem) async {
        await MainActor.run { isUploading = true }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw NSError(domain: "PhotoPicker", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Could not read photo."])
            }
            let url = try await ImageUploader.upload(image)
            await MainActor.run {
                isUploading = false
                Haptics.success()
                onUploaded(url)
            }
        } catch {
            await MainActor.run {
                isUploading = false
                uploadError = error.localizedDescription
                Haptics.error()
            }
        }
    }
}

enum PhotosPickerFilter {
    case images
}

// MARK: - Multi photo picker (for portfolio bulk add)

struct MultiPhotoPickerButton: View {
    let onUploaded: ([String]) -> Void

    @State private var items: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var progress: Double = 0
    @State private var uploadError: String?

    var body: some View {
        PhotosPicker(
            selection: $items,
            maxSelectionCount: 10,
            matching: .images
        ) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                    Text("Uploading \(Int(progress * 100))%")
                        .font(AppTheme.sans(15, weight: .semibold))
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Add photos")
                        .font(AppTheme.sans(15, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isUploading ? AppTheme.slate : AppTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isUploading)
        .onChange(of: items) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task { await handleBatch(newValue) }
        }
        .alert("Upload failed", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK", role: .cancel) { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
    }

    private func handleBatch(_ pickerItems: [PhotosPickerItem]) async {
        await MainActor.run {
            isUploading = true
            progress = 0
        }
        var urls: [String] = []

        for (idx, item) in pickerItems.enumerated() {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { continue }
                let url = try await ImageUploader.upload(image)
                urls.append(url)
            } catch {
                print("[MultiPhotoPicker] item \(idx) failed:", error)
            }
            await MainActor.run {
                progress = Double(idx + 1) / Double(pickerItems.count)
            }
        }

        await MainActor.run {
            isUploading = false
            self.items = []
            if urls.isEmpty {
                uploadError = "No photos uploaded. Try again."
            } else {
                Haptics.success()
                onUploaded(urls)
            }
        }
    }
}