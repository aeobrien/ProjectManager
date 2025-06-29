
import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import Combine

/// Manages the syncing of `FocusTask` data with CloudKit.
@available(iOS 13.0, macOS 10.15, *)
public final class FocusTaskSyncManager {
    #if canImport(CloudKit)
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordType = "FocusTask"
    
    public init() {
        self.container = CKContainer(identifier: "iCloud.AOTondra.ProjectManageriOS")
        self.privateDatabase = container.privateCloudDatabase
    }
    
    /// Fetches all `FocusTask` records from CloudKit.
    public func fetchAll() async throws -> [FocusTask] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "syncType == %@", "task"))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        do {
            let results = try await privateDatabase.records(matching: query)
            var tasks: [FocusTask] = []
            
            for record in results.matchResults {
                if case .success(let recordResult) = record.1 {
                    if let task = focusTaskFromRecord(recordResult) {
                        tasks.append(task)
                    }
                }
            }
            
            print("Fetched \(tasks.count) focus tasks from CloudKit")
            return tasks
        } catch {
            print("Failed to fetch focus tasks: \(error)")
            throw error
        }
    }
    
    /// Syncs local `FocusTask` data with CloudKit.
    public func sync(localTasks: [FocusTask]) async throws {
        let cloudTasks = try await fetchAll()
        
        var mergedTaskDict = [UUID: FocusTask]()
        
        // Add cloud tasks to the dictionary first
        for task in cloudTasks {
            mergedTaskDict[task.id] = task
        }
        
        // Add local tasks, overwriting cloud versions if a conflict exists
        for task in localTasks {
            mergedTaskDict[task.id] = task
        }
        
        let mergedTasks = Array(mergedTaskDict.values)
        let recordsToSave = mergedTasks.map { recordFromFocusTask($0) }
        
        if !recordsToSave.isEmpty {
            let chunkSize = 400 // CloudKit limit
            let chunks = recordsToSave.chunked(into: chunkSize)
            
            for (index, chunk) in chunks.enumerated() {
                let modifyOp = CKModifyRecordsOperation(recordsToSave: chunk, recordIDsToDelete: nil)
                modifyOp.savePolicy = .allKeys
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    modifyOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("Successfully synced chunk \(index + 1)/\(chunks.count) of \(chunk.count) focus tasks")
                            continuation.resume()
                        case .failure(let error):
                            print("Failed to sync chunk \(index + 1)/\(chunks.count) of focus tasks: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    privateDatabase.add(modifyOp)
                }
            }
        }
        
        SimpleStorageManager.shared.save(mergedTasks, forKey: "shared_focusTasks")
    }
    
    // MARK: - Record Conversions
    
    private func recordFromFocusTask(_ task: FocusTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        record["id"] = task.id.uuidString as CKRecordValue
        record["text"] = task.displayText as CKRecordValue
        record["status"] = task.status.rawValue as CKRecordValue
        record["projectId"] = task.projectId.uuidString as CKRecordValue
        record["lastModified"] = task.lastModified as CKRecordValue
        record["syncType"] = "task" as CKRecordValue
        
        if let dueDate = task.dueDate {
            record["dueDate"] = dueDate as CKRecordValue
        }
        
        return record
    }
    
    private func focusTaskFromRecord(_ record: CKRecord) -> FocusTask? {
        guard let text = record["text"] as? String,
              let statusString = record["status"] as? String,
              let status = TaskStatus(rawValue: statusString),
              let projectIdString = record["projectId"] as? String,
              let projectId = UUID(uuidString: projectIdString) else {
            return nil
        }
        
        let task = FocusTask(
            text: text,
            status: status,
            projectId: projectId,
            dueDate: record["dueDate"] as? Date
        )
        
        return task
    }
    #endif
}
