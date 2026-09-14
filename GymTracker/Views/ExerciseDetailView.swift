import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var fullScreenPhoto: ProgressPhoto?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingDeleteConfirmation = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    private var muscleGroupBinding: Binding<MuscleGroup> {
        Binding(
            get: { exercise.muscleGroup },
            set: { newValue in
                exercise.muscleGroup = newValue
                try? context.save()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Exercise Name", text: $exercise.name)
                    .font(.title3.bold())
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onSubmit { try? context.save() }

                Picker("Muscle Group", selection: muscleGroupBinding) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.rawValue, systemImage: group.systemImage).tag(group)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label(isImporting ? "Adding…" : "Add Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isImporting)
                .padding(.horizontal)

                if exercise.photos.isEmpty {
                    ContentUnavailableView("No Photos Yet", systemImage: "photo",
                                            description: Text("Add form checks or progress photos for \(exercise.name)."))
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(exercise.photos.sorted(by: { $0.date > $1.date })) { photo in
                            Button {
                                fullScreenPhoto = photo
                            } label: {
                                PhotoThumbnail(photo: photo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
        .fullScreenCover(item: $fullScreenPhoto) { photo in
            PhotoViewer(photo: photo)
        }
        .alert("Couldn't Add Photo", isPresented: .constant(importError != nil), actions: {
            Button("OK") { importError = nil }
        }, message: {
            Text(importError ?? "")
        })
        .confirmationDialog(
            "Delete \(exercise.name)? This also removes its photos. Any logged sets stay in your history as \"Unknown.\"",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Exercise", role: .destructive) {
                context.delete(exercise)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isImporting = true
        defer { isImporting = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            importError = "That file couldn't be read as an image."
            selectedItem = nil
            return
        }
        guard let processed = Self.downscaledJPEGData(from: data) else {
            importError = "That image format isn't supported."
            selectedItem = nil
            return
        }

        context.insert(ProgressPhoto(imageData: processed, exercise: exercise))
        try? context.save()
        selectedItem = nil
    }

    /// Downscales to a max dimension and re-encodes as JPEG so large camera photos
    /// don't bloat local storage or slow down the grid.
    private static func downscaledJPEGData(from data: Data, maxDimension: CGFloat = 1200, quality: CGFloat = 0.72) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: quality) }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }
}

private struct PhotoThumbnail: View {
    let photo: ProgressPhoto

    var body: some View {
        Group {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PhotoViewer: View {
    let photo: ProgressPhoto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    ContentUnavailableView("Unable to Load Image", systemImage: "exclamationmark.triangle")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Photo", role: .destructive) {
                    context.delete(photo)
                    try? context.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
