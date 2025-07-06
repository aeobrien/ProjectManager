
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
        
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        
        do {
            repeat {
                let operation: CKQueryOperation
                if let cursor = cursor {
                    operation = CKQueryOperation(cursor: cursor)
                } else {
                    operation = CKQueryOperation(query: query)
                }
                
                operation.resultsLimit = 100
                operation.qualityOfService = .userInitiated
                
                let (results, nextCursor) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([(CKRecord.ID, Result<CKRecord, Error>)], CKQueryOperation.Cursor?), Error>) in
                    var fetchedRecords: [(CKRecord.ID, Result<CKRecord, Error>)] = []
                    
                    operation.recordMatchedBlock = { recordID, result in
                        fetchedRecords.append((recordID, result))
                    }
                    
                    operation.queryResultBlock = { result in
                        switch result {
                        case .success(let cursor):
                            continuation.resume(returning: (fetchedRecords, cursor))
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    
                    privateDatabase.add(operation)
                }
                
                // Process results
                for (_, result) in results {
                    if case .success(let record) = result {
                        allRecords.append(record)
                    }
                }
                
                cursor = nextCursor
            } while cursor != nil
            
            // Convert records to FocusTask objects
            var tasks: [FocusTask] = []
            for record in allRecords {
                if let task = focusTaskFromRecord(record) {
                    tasks.append(task)
                }
            }
            
            print("Fetched \(tasks.count) focus tasks from CloudKit")
            return tasks
        } catch {
            print("Failed to fetch focus tasks: \(error)")
            throw error
        }
    }
    
    /// Cleans up duplicate task records for a specific project
    public func cleanupDuplicatesForProject(_ projectId: UUID) async throws {
        print("=== Cleaning up duplicate tasks for project \(projectId) ===")
        
        let predicate = NSPredicate(format: "projectId == %@", projectId.uuidString)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        var allRecords: [(CKRecord.ID, CKRecord)] = []
        let results = try await privateDatabase.records(matching: query)
        
        for record in results.matchResults {
            if case .success(let recordResult) = record.1 {
                allRecords.append((record.0, recordResult))
            }
        }
        
        print("Fetched \(allRecords.count) task records for project")
        
        // Group by task text
        var tasksByText = [String: [(CKRecord.ID, CKRecord)]]()
        
        for (recordID, record) in allRecords {
            if let taskText = record["text"] as? String {
                if tasksByText[taskText] == nil {
                    tasksByText[taskText] = []
                }
                tasksByText[taskText]?.append((recordID, record))
            }
        }
        
        // Find and delete duplicates
        var recordsToDelete = [CKRecord.ID]()
        for (taskText, records) in tasksByText {
            if records.count > 1 {
                print("Found \(records.count) duplicates of: \(taskText)")
                
                // Keep the newest one
                let sorted = records.sorted { (a, b) in
                    let dateA = a.1["lastModified"] as? Date ?? a.1.modificationDate ?? Date.distantPast
                    let dateB = b.1["lastModified"] as? Date ?? b.1.modificationDate ?? Date.distantPast
                    return dateA > dateB
                }
                
                // Delete all but the first (newest)
                for i in 1..<sorted.count {
                    recordsToDelete.append(sorted[i].0)
                }
            }
        }
        
        if !recordsToDelete.isEmpty {
            print("Deleting \(recordsToDelete.count) duplicate records...")
            
            let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsToDelete)
            deleteOp.qualityOfService = .userInitiated
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                deleteOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("Successfully deleted \(recordsToDelete.count) duplicates for project")
                        continuation.resume()
                    case .failure(let error):
                        print("Failed to delete duplicates: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
                privateDatabase.add(deleteOp)
            }
        } else {
            print("No duplicates found for this project")
        }
    }
    
    /// Cleans up duplicate task records in CloudKit
    public func cleanupDuplicates() async throws {
        print("=== Cleaning up duplicate FocusTask records ===")
        
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "syncType == %@", "task"))
        
        var allRecords: [(CKRecord.ID, CKRecord)] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }
            
            operation.resultsLimit = 100
            operation.qualityOfService = .userInitiated
            
            let (results, nextCursor) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([(CKRecord.ID, Result<CKRecord, Error>)], CKQueryOperation.Cursor?), Error>) in
                var fetchedRecords: [(CKRecord.ID, Result<CKRecord, Error>)] = []
                
                operation.recordMatchedBlock = { recordID, result in
                    fetchedRecords.append((recordID, result))
                }
                
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(let cursor):
                        continuation.resume(returning: (fetchedRecords, cursor))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                privateDatabase.add(operation)
            }
            
            // Process results
            for (recordID, result) in results {
                if case .success(let record) = result {
                    allRecords.append((recordID, record))
                }
            }
            
            cursor = nextCursor
        } while cursor != nil
        
        print("Fetched \(allRecords.count) total FocusTask records")
        
        // Group by projectId and task text
        var tasksByProjectAndText = [String: [(CKRecord.ID, CKRecord)]]()
        
        for (recordID, record) in allRecords {
            if let projectIdString = record["projectId"] as? String,
               let taskText = record["text"] as? String {
                let key = "\(projectIdString)::::\(taskText)"
                if tasksByProjectAndText[key] == nil {
                    tasksByProjectAndText[key] = []
                }
                tasksByProjectAndText[key]?.append((recordID, record))
            }
        }
        
        // Find and delete duplicates
        var recordsToDelete = [CKRecord.ID]()
        for (key, records) in tasksByProjectAndText {
            if records.count > 1 {
                print("Found \(records.count) duplicate tasks for key: \(key)")
                
                // Keep the newest one
                let sorted = records.sorted { (a, b) in
                    let dateA = a.1["lastModified"] as? Date ?? a.1.modificationDate ?? Date.distantPast
                    let dateB = b.1["lastModified"] as? Date ?? b.1.modificationDate ?? Date.distantPast
                    return dateA > dateB
                }
                
                // Delete all but the first (newest)
                for i in 1..<sorted.count {
                    recordsToDelete.append(sorted[i].0)
                }
            }
        }
        
        if !recordsToDelete.isEmpty {
            print("Deleting \(recordsToDelete.count) duplicate task records...")
            
            // Delete in smaller chunks to avoid timeouts
            let chunkSize = 100  // Reduced from 400 to avoid timeouts
            let chunks = recordsToDelete.chunked(into: chunkSize)
            
            print("Will delete in \(chunks.count) chunks of up to \(chunkSize) records each")
            
            for (index, chunk) in chunks.enumerated() {
                // Add a small delay between chunks to avoid overwhelming CloudKit
                if index > 0 {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                
                print("Deleting chunk \(index + 1)/\(chunks.count) (\(chunk.count) records)...")
                
                let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: chunk)
                deleteOp.qualityOfService = .userInitiated
                deleteOp.configuration.timeoutIntervalForRequest = 30 // 30 second timeout per chunk
                deleteOp.configuration.timeoutIntervalForResource = 60
                
                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        deleteOp.modifyRecordsResultBlock = { result in
                            switch result {
                            case .success:
                                print("✓ Successfully deleted chunk \(index + 1)/\(chunks.count)")
                                continuation.resume()
                            case .failure(let error):
                                print("✗ Failed to delete chunk \(index + 1): \(error)")
                                continuation.resume(throwing: error)
                            }
                        }
                        privateDatabase.add(deleteOp)
                    }
                } catch {
                    print("Error deleting chunk \(index + 1), continuing with next chunk: \(error)")
                    // Continue with next chunk even if one fails
                }
            }
            
            print("Completed deletion attempt for \(recordsToDelete.count) records")
        } else {
            print("No duplicate task records found")
        }
    }
    
    /// Syncs local `FocusTask` data with CloudKit.
    public func sync(localTasks: [FocusTask]) async throws {
        // First clean up any duplicates
        try await cleanupDuplicates()
        
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
