import Foundation
import Combine

class FileMonitor: ObservableObject {
    private var fileSystemObject: DispatchSourceFileSystemObject?
    private var monitoredURL: URL?
    private let queue = DispatchQueue(label: "com.projectmanager.filemonitor")
    
    @Published var lastUpdate = Date()
    
    func startMonitoring(url: URL) {
        stopMonitoring()
        
        monitoredURL = url
        
        // Ensure we have access to the URL
        let accessing = url.startAccessingSecurityScopedResource()
        
        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open file descriptor for: \(url.path)")
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
            return
        }
        
        fileSystemObject = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )
        
        fileSystemObject?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.lastUpdate = Date()
            }
        }
        
        fileSystemObject?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileSystemObject?.resume()
    }
    
    func stopMonitoring() {
        fileSystemObject?.cancel()
        fileSystemObject = nil
        monitoredURL = nil
    }
    
    deinit {
        stopMonitoring()
    }
}