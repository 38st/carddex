import Foundation

/// PSA / CGC / BGS certificate lookup. Fetches grading details from
/// public verification endpoints.
struct CertLookupService {

    enum GradingCompany: String, CaseIterable, Identifiable {
        case psa = "PSA"
        case cgc = "CGC"
        case bgs = "BGS"

        var id: String { rawValue }

        var verifyURL: String {
            switch self {
            case .psa: "https://www.psacard.com/verify/cert"
            case .cgc: "https://www.cgccomics.com/verify-cgc"
            case .bgs: "https://www.beckett.com/grade-lookup"
            }
        }
    }

    struct CertResult {
        let company: GradingCompany
        let certNumber: String
        let grade: String?
        let subject: String?
        let population: Int?
        let imageURL: URL?
    }

    /// Look up a certificate number. Currently returns a URL the user can
    /// open in Safari — the grading companies don't provide public JSON APIs,
    /// so we deep-link to their verification pages. A future enhancement
    /// could scrape the result or use a licensed API.
    static func lookupURL(company: GradingCompany, certNumber: String) -> URL? {
        switch company {
        case .psa:
            return URL(string: "https://www.psacard.com/verify/cert/\(certNumber)")
        case .cgc:
            return URL(string: "https://www.cgccomics.com/verify-cgc/?certNumber=\(certNumber)")
        case .bgs:
            return URL(string: "https://www.beckett.com/grade-lookup?certNumber=\(certNumber)")
        }
    }

    /// Validate cert number format (basic sanity check).
    static func isValidFormat(_ certNumber: String, company: GradingCompany) -> Bool {
        let cleaned = certNumber.replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return false }

        switch company {
        case .psa:
            // PSA certs are typically 7-8 digits.
            return cleaned.count >= 6 && cleaned.count <= 10 && cleaned.allSatisfy(\.isNumber)
        case .cgc:
            // CGC certs are typically 10-12 digits.
            return cleaned.count >= 8 && cleaned.count <= 15 && cleaned.allSatisfy(\.isNumber)
        case .bgs:
            // BGS certs are typically 10 digits.
            return cleaned.count >= 8 && cleaned.count <= 12 && cleaned.allSatisfy(\.isNumber)
        }
    }
}
