
import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import Combine

/// Manages the syncing of `Project` data with CloudKit.
@available(iOS 13.0, macOS 10.15, *)
public final class ProjectSyncManager {
    #if canImport(CloudKit)
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordType = "Project"
    
    public init() {
        self.container = CKContainer(identifier: "iCloud.AOTondra.ProjectManageriOS")
        self.privateDatabase = container.privateCloudDatabase
    }
    
    /// Fetches all `Project` records from CloudKit.
    public func fetchAll() async throws -> [Project] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "syncType == %@", "project"))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        do {
            let results = try await privateDatabase.records(matching: query)
            var projects: [Project] = []
            
            for record in results.matchResults {
                if case .success(let recordResult) = record.1 {
                    if let project = projectFromRecord(recordResult) {
                        projects.append(project)
                    }
                }
            }
            
            print("Fetched \(projects.count) projects from CloudKit")
            return projects
        } catch {
            print("Failed to fetch projects: \(error)")
            throw error
        }
    }
    
    /// Syncs local `Project` data with CloudKit.
    public func sync(localProjects: [Project]) async throws {
        let cloudProjects = try await fetchAll()
        
        var mergedProjectDict = [UUID: Project]()
        
        // Add cloud projects to the dictionary first
        for project in cloudProjects {
            mergedProjectDict[project.id] = project
        }
        
        // Add local projects, overwriting cloud versions if a conflict exists
        for project in localProjects {
            mergedProjectDict[project.id] = project
        }
        
        let mergedProjects = Array(mergedProjectDict.values)
        let recordsToSave = mergedProjects.map { recordFromProject($0) }
        
        if !recordsToSave.isEmpty {
            let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            modifyOp.savePolicy = .allKeys
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                modifyOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("Successfully synced \(recordsToSave.count) projects")
                        continuation.resume()
                    case .failure(let error):
                        print("Failed to sync projects: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
                privateDatabase.add(modifyOp)
            }
        }
        
        SimpleStorageManager.shared.save(mergedProjects, forKey: "shared_projects")
    }
    
    // MARK: - Record Conversions
    
    private func recordFromProject(_ project: Project) -> CKRecord {
        let recordID = CKRecord.ID(recordName: project.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        record["id"] = project.id.uuidString as CKRecordValue
        record["name"] = project.name as CKRecordValue
        record["folderPath"] = project.folderPath.absoluteString as CKRecordValue
        record["syncType"] = "project" as CKRecordValue
        
        if FileManager.default.fileExists(atPath: project.overviewPath.path) {
            do {
                let overviewContent = try String(contentsOf: project.overviewPath, encoding: .utf8)
                record["overviewContent"] = overviewContent as CKRecordValue
            } catch {
                print("Failed to read overview for \(project.name): \(error)")
            }
        }
        
        return record
    }
    
    private func projectFromRecord(_ record: CKRecord) -> Project? {
        guard let name = record["name"] as? String,
              let folderPathString = record["folderPath"] as? String,
              let folderURL = URL(string: folderPathString) else {
            return nil
        }
        
        let overviewContent = record["overviewContent"] as? String
        
        return Project(folderPath: folderURL, overviewContent: overviewContent)
    }
    #endif
}
