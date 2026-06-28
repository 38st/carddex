import Foundation

/// Tracks a card sent to a grading company (PSA, CGC, BGS) through the
/// submission pipeline. Blue ocean — no competitor has this.
struct GradingSubmission: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var card: Card
    var company: GradingCompany
    var status: SubmissionStatus
    var submittedDate: Date
    var expectedReturnDate: Date?
    var receivedDate: Date?
    var gradedDate: Date?
    var resultGrade: String?
    var certNumber: String?
    var serviceLevel: String
    var cost: Double
    var notes: String

    enum GradingCompany: String, CaseIterable, Codable, Identifiable, Sendable {
        case psa = "PSA"
        case cgc = "CGC"
        case bgs = "BGS"
        var id: String { rawValue }
    }

    enum SubmissionStatus: String, CaseIterable, Codable, Identifiable, Sendable {
        case preparing = "Preparing"
        case submitted = "Submitted"
        case received = "Received"
        case inGrading = "In Grading"
        case shipped = "Shipped"
        case completed = "Completed"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .preparing: "box"
            case .submitted: "paperplane"
            case .received: "tray.and.arrow.down"
            case .inGrading: "wand.and.stars"
            case .shipped: "truck.box"
            case .completed: "checkmark.seal.fill"
            }
        }

        var next: SubmissionStatus? {
            switch self {
            case .preparing: .submitted
            case .submitted: .received
            case .received: .inGrading
            case .inGrading: .shipped
            case .shipped: .completed
            case .completed: nil
            }
        }
    }

    init(
        id: UUID = UUID(),
        card: Card,
        company: GradingCompany = .psa,
        status: SubmissionStatus = .preparing,
        submittedDate: Date = .now,
        expectedReturnDate: Date? = nil,
        receivedDate: Date? = nil,
        gradedDate: Date? = nil,
        resultGrade: String? = nil,
        certNumber: String? = nil,
        serviceLevel: String = "Regular",
        cost: Double = 25,
        notes: String = ""
    ) {
        self.id = id
        self.card = card
        self.company = company
        self.status = status
        self.submittedDate = submittedDate
        self.expectedReturnDate = expectedReturnDate
        self.receivedDate = receivedDate
        self.gradedDate = gradedDate
        self.resultGrade = resultGrade
        self.certNumber = certNumber
        self.serviceLevel = serviceLevel
        self.cost = cost
        self.notes = notes
    }

    var isCompleted: Bool { status == .completed }

    /// Days since submission.
    var daysInTransit: Int {
        Calendar.current.dateComponents([.day], from: submittedDate, to: Date()).day ?? 0
    }

    /// Estimated days remaining based on expected return date.
    var daysRemaining: Int? {
        guard let expected = expectedReturnDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expected).day ?? 0
        return days
    }

    /// True when the expected return date has passed and the card hasn't been graded.
    var isOverdue: Bool {
        guard let expected = expectedReturnDate, !isCompleted else { return false }
        return Date() > expected
    }
}
