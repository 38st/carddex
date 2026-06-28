import SwiftUI
import Observation

/// In-memory store for grading submissions. Persists via UserDefaults
/// (local-only for now; sync integration follows the same pattern as
/// CollectionStore when the SwiftData entity is added).
@MainActor
@Observable
final class GradingStore {
    private(set) var submissions: [GradingSubmission] = []
    private let key = "grading_submissions"

    init() {
        load()
    }

    var activeSubmissions: [GradingSubmission] {
        submissions.filter { !$0.isCompleted }.sorted { $0.submittedDate > $1.submittedDate }
    }

    var completedSubmissions: [GradingSubmission] {
        submissions.filter { $0.isCompleted }.sorted { ($0.gradedDate ?? .now) > ($1.gradedDate ?? .now) }
    }

    var totalSpent: Double {
        submissions.reduce(0) { $0 + $1.cost }
    }

    var inTransitCount: Int {
        submissions.filter { !$0.isCompleted }.count
    }

    func add(_ submission: GradingSubmission) {
        submissions.append(submission)
        save()
    }

    func update(_ submission: GradingSubmission) {
        guard let idx = submissions.firstIndex(where: { $0.id == submission.id }) else { return }
        submissions[idx] = submission
        save()
    }

    func advance(_ submission: GradingSubmission) {
        guard let idx = submissions.firstIndex(where: { $0.id == submission.id }),
              let next = submissions[idx].status.next else { return }
        submissions[idx].status = next
        switch next {
        case .received: submissions[idx].receivedDate = .now
        case .completed:
            submissions[idx].gradedDate = .now
        default: break
        }
        save()
    }

    func remove(_ submission: GradingSubmission) {
        submissions.removeAll { $0.id == submission.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(submissions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GradingSubmission].self, from: data) else { return }
        submissions = decoded
    }
}
