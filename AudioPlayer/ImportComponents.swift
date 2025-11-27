//
//  ImportComponents.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData

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
