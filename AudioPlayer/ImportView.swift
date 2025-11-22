//
//  ImportView.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct ImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioFileManager: AudioFileManager
    @EnvironmentObject var localizationManager: LocalizationManager
    
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
                    .font(FontManager.font(.regular, size: 80))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 16) {
                    Text("Import Audio Files")
                        .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 28))
                    
                    Text("Add audio files or folders to your library")
                        .font(FontManager.font(.regular, size: 17))
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
                    .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 17))
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
                        Text(localizationManager.importProgressImporting)
                            .font(FontManager.font(.regular, size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Supported Formats
                VStack(spacing: 8) {
                    Text("Supported Formats")
                        .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 17))
                        .foregroundColor(.secondary)
                    
                    Text("MP3 • M4A • M4B • AAC • WAV • FLAC • AIFF • CAF")
                        .font(FontManager.font(.regular, size: 15))
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
            .alert(localizationManager.importResultsTitle, isPresented: $isShowingAlert) {
                Button(localizationManager.importButtonOK) { }
                if importResults.contains(where: { !$0.success }) {
                    Button(localizationManager.importButtonViewDetails) {
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
                        alertMessage = localizationManager.importSuccessSingle
                    } else {
                        alertMessage = localizationManager.importSuccessMultiple(successCount)
                    }
                } else if successCount == 0 {
                    alertMessage = localizationManager.importFailureAll(failureCount)
                } else {
                    alertMessage = localizationManager.importPartialSuccessDetailed(successCount, failureCount)
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
    @EnvironmentObject var localizationManager: LocalizationManager
    
    var body: some View {
        NavigationStack {
            List {
                let successResults = results.filter { $0.success }
                let failureResults = results.filter { !$0.success }
                
                if !successResults.isEmpty {
                    Section(localizationManager.importDetailsSuccessSection(successResults.count)) {
                        ForEach(successResults, id: \.url) { result in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(result.fileName)
                                    .font(FontManager.font(.regular, size: 15))
                                Spacer()
                            }
                        }
                    }
                }
                
                if !failureResults.isEmpty {
                    Section(localizationManager.importDetailsFailureSection(failureResults.count)) {
                        ForEach(failureResults, id: \.url) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(result.fileName)
                                        .font(FontManager.fontWithSystemFallback(weight: .medium, size: 15))
                                    Spacer()
                                }
                                
                                if let failureReason = result.failureReason {
                                    Text(failureReason)
                                        .font(FontManager.font(.regular, size: 12))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 24)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.importDetailsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.importButtonDone) {
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
