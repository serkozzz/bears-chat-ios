import Foundation

struct AuthRegisterRequestDTO: Codable {
    let phoneNumber: String
    let deviceId: String
}

struct AuthRegisterResponseDTO: Codable {
    let isVerified: Bool
    let verificationUrl: String?
}
