import Foundation
import SwiftUI
import Combine
import ProjectManagerCore

@MainActor
class CloudKitViewModel: ObservableObject {
    @Published var syncStatus: String = "Unknown"
    @Published var lastSyncDate: Date?
    @Published var isSyncing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        if #available(iOS 13.0, *) {
            setupCloudKitObserver()
        }
    }
    
    @available(iOS 13.0, *)
    private func setupCloudKitObserver() {
        SimpleSyncManager.shared.$syncStatusText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
            }
            .store(in: &cancellables)
        
        SimpleSyncManager.shared.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                self?.lastSyncDate = date
            }
            .store(in: &cancellables)
        
        SimpleSyncManager.shared.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncing in
                self?.isSyncing = syncing
            }
            .store(in: &cancellables)
        
        SimpleSyncManager.shared.checkSyncStatus()
    }
    
    @available(iOS 13.0, *)
    func syncNow() async {
        guard !isSyncing else { return }
        do {
            try await SimpleSyncManager.shared.syncNow()
        } catch {
            print("Sync error: \(error)")
        }
    }
}
