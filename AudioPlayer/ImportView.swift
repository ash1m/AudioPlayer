//
//  ImportView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct ImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioFileManager: AudioFileManager
    
    @State private var isShowingDocumentPicker = false
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isImporting = false
    @State private var importResults: [AudioFileManager.ImportResult] = []
    @State private var isShowingDetailedResults = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Import Icon
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 16) {
                    Text("Import Audio Files")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Add audio files or folders to your library")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Import Button
                Button(action: {
                    isShowingDocumentPicker = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                        Text("Choose Files or Folders")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.accentColor)
                    .cornerRadius(25)
                }
                .disabled(isImporting)
                
                if isImporting {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Importing files...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Supported Formats
                VStack(spacing: 8) {
                    Text("Supported Formats")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("MP3 • M4A • M4B • AAC • WAV • FLAC • AIFF • CAF")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("Import")
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPicker(
                    allowedContentTypes: [
                        .mp3,
                        .mpeg4Audio,
                        .wav,
                        .audio
                    ]
                ) { urls in
                    importAudioFiles(urls: urls)
                }
            }
            .alert("Import Results", isPresented: $isShowingAlert) {
                Button("OK") { }
                if importResults.contains(where: { !$0.success }) {
                    Button("View Details") {
                        isShowingDetailedResults = true
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $isShowingDetailedResults) {
                ImportResultsDetailView(results: importResults)
            }
        }
    }
    
    private func importAudioFiles(urls: [URL]) {
        isImporting = true
        
        Task {
            let results = await audioFileManager.importAudioFiles(urls: urls, context: viewContext)
            
            await MainActor.run {
                isImporting = false
                importResults = results
                
                let successCount = results.filter { $0.success }.count
                let failureCount = results.count - successCount
                let totalProcessed = results.count
                
                if failureCount == 0 {
                    if totalProcessed == 1 {
                        alertMessage = "Successfully imported 1 file!"
                    } else {
                        alertMessage = "Successfully imported \(successCount) files!"
                    }
                } else if successCount == 0 {
                    alertMessage = "Failed to import \(failureCount) file(s). Tap 'View Details' for more information."
                } else {
                    alertMessage = "Imported \(successCount) file(s) successfully.\n\(failureCount) file(s) failed to import. Tap 'View Details' for more information."
                }
                
                isShowingAlert = true
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onDocumentsSelected: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Allow both files and folders to be selected
        var contentTypes = allowedContentTypes
        contentTypes.append(.folder) // Add folder support
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: false)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        picker.directoryURL = nil // Allow browsing from default location
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentsSelected(urls)
        }
    }
}

struct ImportResultsDetailView: View {
    let results: [AudioFileManager.ImportResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                let successResults = results.filter { $0.success }
                let failureResults = results.filter { !$0.success }
                
                if !successResults.isEmpty {
                    Section("Successfully Imported (\(successResults.count))") {
                        ForEach(successResults, id: \.url) { result in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(result.fileName)
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                    }
                }
                
                if !failureResults.isEmpty {
                    Section("Failed to Import (\(failureResults.count))") {
                        ForEach(failureResults, id: \.url) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(result.fileName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                
                                if let failureReason = result.failureReason {
                                    Text(failureReason)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 24)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Import Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ImportView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioFileManager())
        .environmentObject(AudioPlayerService())
}
