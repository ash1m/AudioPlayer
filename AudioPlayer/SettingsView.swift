//
//  SettingsView.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/16.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var audioFileManager: AudioFileManager
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    
    var body: some View {
        NavigationStack {
            List {
                // Language Section
                Section {
                    Picker(localizationManager.localizedString("settings.language"), selection: $settingsManager.selectedLanguage) {
                        ForEach(SettingsManager.Language.allCases, id: \.self) { language in
                            HStack {
                                Text(language.displayName)
                                    .dynamicTypeSupport(.body, maxSize: .accessibility2)
                                Spacer()
                                Text(language.rawValue.uppercased())
                                    .dynamicTypeSupport(.caption, maxSize: .accessibility1)
                                    .foregroundColor(.secondary)
                                    .visualAccessibility(foreground: .secondary)
                            }
                            .tag(language)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityLabel(localizationManager.localizedString("settings.language.label"))
                    .accessibilityValue(localizationManager.localizedString("language.currently.set", settingsManager.selectedLanguage.displayName))
                    .accessibilityHint(localizationManager.localizedString("settings.language.hint"))
                }
                
                
                // Import Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizationManager.settingsSupportedFormats)
                            .font(FontManager.fontWithSystemFallback(weight: .medium, size: 15))
                        
                        Text(localizationManager.settingsSupportedFormatsList)
                            .font(FontManager.font(.regular, size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(localizationManager.settingsImportDescription)
                            .font(FontManager.font(.regular, size: 13))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                
                // App Info Section
                Section {
                    HStack {
                        Text(localizationManager.settingsVersion)
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(localizationManager.settingsBuild)
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(localizationManager.settingsTitle)
            .accessibilityLabel(localizationManager.settingsTitle)
            .onAppear {
                accessibilityManager.announceScreenChange()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(SettingsManager())
        .environmentObject(AudioFileManager())
        .environmentObject(AudioPlayerService())
        .environmentObject(AccessibilityManager())
        .environmentObject(LocalizationManager.shared)
}
