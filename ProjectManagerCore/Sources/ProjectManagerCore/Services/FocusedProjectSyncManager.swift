
import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import Combine

/// Manages the syncing of `FocusedProject` data with CloudKit.
@available(iOS 13.0, macOS 10.15, *)
public final class FocusedProjectSyncManager {
    #if canImport(CloudKit)
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordType = "FocusedProject"
    
    public init() {
        self.container = CKContainer(identifier: "iCloud.AOTondra.ProjectManageriOS")
        self.privateDatabase = container.privateCloudDatabase
    }
    
    /// Fetches all `FocusedProject` records from CloudKit.
    public func fetchAll() async throws -> [FocusedProject] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "syncType == %@", "focused"))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        do {
            let results = try await privateDatabase.records(matching: query)
            var focusedProjects: [FocusedProject] = []
            
            for record in results.matchResults {
                if case .success(let recordResult) = record.1 {
                    if let project = focusedProjectFromRecord(recordResult) {
                        focusedProjects.append(project)
                    }
                }
            }
            
            print("Fetched \(focusedProjects.count) focused projects from CloudKit")
            return focusedProjects
        } catch {
            print("Failed to fetch focused projects: \(error)")
            throw error
        }
    }
    
    /// Syncs local `FocusedProject` data with CloudKit.
    public func sync(localProjects: [FocusedProject]) async throws {
        let cloudProjects = try await fetchAll()
        
        var mergedProjectDict = [UUID: FocusedProject]()
        
        // Add cloud projects to the dictionary first
        for project in cloudProjects {
            mergedProjectDict[project.projectId] = project
        }
        
        // Add local projects, overwriting cloud versions if a conflict exists
        for project in localProjects {
            mergedProjectDict[project.projectId] = project
        }
        
        let mergedProjects = Array(mergedProjectDict.values)
        let recordsToSave = mergedProjects.map { recordFromFocusedProject($0) }
        
        if !recordsToSave.isEmpty {
            let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            modifyOp.savePolicy = .allKeys // Overwrite with merged data
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                modifyOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("Successfully synced \(recordsToSave.count) focused projects")
                        continuation.resume()
                    case .failure(let error):
                        print("Failed to sync focused projects: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
                privateDatabase.add(modifyOp)
            }
        }
        
        // Save final merged data locally
        SimpleStorageManager.shared.save(mergedProjects, forKey: "shared_focusedProjects")
    }
    
    // MARK: - Record Conversions
    
    private func recordFromFocusedProject(_ focusedProject: FocusedProject) -> CKRecord {
        let recordID = CKRecord.ID(recordName: focusedProject.projectId.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        record["projectId"] = focusedProject.projectId.uuidString as CKRecordValue
        record["status"] = focusedProject.status.rawValue as CKRecordValue
        record["syncType"] = "focused" as CKRecordValue
        if let lastWorkedOn = focusedProject.lastWorkedOn {
            record["lastWorkedOn"] = lastWorkedOn as CKRecordValue
        }
        if let activatedDate = focusedProject.activatedDate {
            record["activatedDate"] = activatedDate as CKRecordValue
        }
        
        print("Preparing FocusedProject record for CloudKit: ID=\(focusedProject.projectId), Status=\(focusedProject.status.rawValue), LastWorked=\(focusedProject.lastWorkedOn?.description ?? "nil"), Activated=\(focusedProject.activatedDate?.description ?? "nil")")
        
        return record
    }
    
    private func focusedProjectFromRecord(_ record: CKRecord) -> FocusedProject? {
        guard let projectIdString = record["projectId"] as? String,
              let projectId = UUID(uuidString: projectIdString),
              let statusString = record["status"] as? String,
              let status = ProjectStatus(rawValue: statusString) else {
            print("Failed to parse FocusedProject record: Missing projectId, status, or invalid status string.")
            return nil
        }
        
        var focusedProject = FocusedProject(projectId: projectId, status: status)
        
        if let lastWorkedOn = record["lastWorkedOn"] as? Date {
            focusedProject.lastWorkedOn = lastWorkedOn
        }
        if let activatedDate = record["activatedDate"] as? Date {
            focusedProject.activatedDate = activatedDate
        }
        
        print("Parsed FocusedProject from CloudKit: ID=\(focusedProject.projectId), Status=\(focusedProject.status.rawValue), LastWorked=\(focusedProject.lastWorkedOn?.description ?? "nil"), Activated=\(focusedProject.activatedDate?.description ?? "nil")")
        
        return focusedProject
    }
    #endif
}
