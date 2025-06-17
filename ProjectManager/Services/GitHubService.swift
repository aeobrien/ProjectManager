import Foundation

// MARK: - GitHub Models
struct GitHubCommit: Codable {
    let sha: String
    let commit: CommitData
    let author: GitHubUser?
    let committer: GitHubUser?
    
    struct CommitData: Codable {
        let author: GitHubCommitAuthor
        let committer: GitHubCommitAuthor
        let message: String
        
        struct GitHubCommitAuthor: Codable {
            let name: String
            let email: String
            let date: String
        }
    }
    
    struct GitHubUser: Codable {
        let login: String
        let id: Int
        let avatarUrl: String
        
        enum CodingKeys: String, CodingKey {
            case login, id
            case avatarUrl = "avatar_url"
        }
    }
}

struct GitHubRepository {
    let owner: String
    let repo: String
    
    init?(url: String) {
        // Parse GitHub URLs like:
        // https://github.com/owner/repo
        // git@github.com:owner/repo.git
        // owner/repo
        
        let cleanedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanedUrl.contains("github.com") {
            let components = cleanedUrl.components(separatedBy: "github.com")
            guard components.count >= 2 else { return nil }
            
            var pathComponent = components[1]
            if pathComponent.hasPrefix("/") {
                pathComponent.removeFirst()
            }
            if pathComponent.hasPrefix(":") {
                pathComponent.removeFirst()
            }
            if pathComponent.hasSuffix(".git") {
                pathComponent = String(pathComponent.dropLast(4))
            }
            
            let pathParts = pathComponent.components(separatedBy: "/")
            guard pathParts.count >= 2 else { return nil }
            
            self.owner = pathParts[0]
            self.repo = pathParts[1]
        } else if cleanedUrl.contains("/") && !cleanedUrl.contains(" ") {
            // Assume it's in owner/repo format
            let parts = cleanedUrl.components(separatedBy: "/")
            guard parts.count >= 2 else { return nil }
            
            self.owner = parts[0]
            self.repo = parts[1]
        } else {
            return nil
        }
    }
    
    var apiUrl: String {
        return "https://api.github.com/repos/\(owner)/\(repo)/commits"
    }
}

// MARK: - GitHub Service
class GitHubService {
    static let shared = GitHubService()
    private let accessToken = ProcessInfo.processInfo.environment["GITHUB_ACCESS_TOKEN"]
   
    private init() {}
    
    func fetchRecentCommits(for repositories: [GitHubRepository], completion: @escaping ([GitHubCommit]) -> Void) {
        let group = DispatchGroup()
        var allCommits: [GitHubCommit] = []
        let queue = DispatchQueue(label: "github.commits", attributes: .concurrent)
        
        for repo in repositories {
            group.enter()
            fetchCommits(for: repo) { commits in
                queue.async(flags: .barrier) {
                    allCommits.append(contentsOf: commits)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            // Sort commits by date, most recent first
            let sortedCommits = allCommits.sorted { commit1, commit2 in
                let date1 = self.parseDate(commit1.commit.author.date) ?? Date.distantPast
                let date2 = self.parseDate(commit2.commit.author.date) ?? Date.distantPast
                return date1 > date2
            }
            
            completion(sortedCommits)
        }
    }
    
    private func fetchCommits(for repository: GitHubRepository, completion: @escaping ([GitHubCommit]) -> Void) {
        guard let url = URL(string: repository.apiUrl + "?per_page=10") else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("GitHub API Error: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                completion([])
                return
            }
            
            do {
                let commits = try JSONDecoder().decode([GitHubCommit].self, from: data)
                completion(commits)
            } catch {
                print("GitHub JSON Decode Error: \(error)")
                completion([])
            }
        }.resume()
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    func formatCommitForLog(_ commit: GitHubCommit, repositoryName: String) -> String {
        guard let date = parseDate(commit.commit.author.date) else {
            return ""
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let formattedDate = dateFormatter.string(from: date)
        let author = commit.author?.login ?? commit.commit.author.name
        let shortSha = String(commit.sha.prefix(7))
        
        // Clean up commit message - remove extra newlines and limit length
        let message = commit.commit.message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first ?? ""
        
        let truncatedMessage = message.count > 80 ? String(message.prefix(80)) + "..." : message
        
        return "### \(formattedDate)\nGitHub Commit to \(repositoryName) by \(author) ([\(shortSha)]): \(truncatedMessage)"
    }
    
    func extractRepositoriesFromText(_ text: String) -> [GitHubRepository] {
        var repositories: [GitHubRepository] = []
        
        // Split text into lines and look for GitHub URLs or repo references
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and headers
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Look for GitHub URLs and repo patterns
            let patterns = [
                "https://github\\.com/[\\w\\-\\.]+/[\\w\\-\\.]+",
                "git@github\\.com:[\\w\\-\\.]+/[\\w\\-\\.]+\\.git",
                "github\\.com/[\\w\\-\\.]+/[\\w\\-\\.]+",
                "\\b[\\w\\-\\.]+/[\\w\\-\\.]+\\b"
            ]
            
            for pattern in patterns {
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                    let matches = regex.matches(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count))
                    
                    for match in matches {
                        if let range = Range(match.range, in: trimmedLine) {
                            let repoString = String(trimmedLine[range])
                            if let repo = GitHubRepository(url: repoString) {
                                repositories.append(repo)
                            }
                        }
                    }
                } catch {
                    continue
                }
            }
        }
        
        // Remove duplicates
        var uniqueRepos: [GitHubRepository] = []
        for repo in repositories {
            if !uniqueRepos.contains(where: { $0.owner == repo.owner && $0.repo == repo.repo }) {
                uniqueRepos.append(repo)
            }
        }
        
        return uniqueRepos
    }
}
