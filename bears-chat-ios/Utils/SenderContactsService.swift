import Contacts
import Foundation

final class SenderContactsService {
    static let shared = SenderContactsService()

    private let store = CNContactStore()
    private let queue = DispatchQueue(label: "SenderContactsService.queue")
    private var contactsCache: [String: String]?

    func requestAccessIfNeeded() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .notDetermined else { return }
        store.requestAccess(for: .contacts) { _, _ in }
    }

    func resolveDisplayName(for senderID: String, completion: @escaping (String?) -> Void) {
        let normalizedSenderID = Self.normalizePhone(senderID)
        guard !normalizedSenderID.isEmpty else {
            completion(nil)
            return
        }

        ensureAccess { [weak self] granted in
            guard let self, granted else {
                completion(nil)
                return
            }

            self.loadContactsCacheIfNeeded { cache in
                completion(cache[normalizedSenderID])
            }
        }
    }

    private func ensureAccess(completion: @escaping (Bool) -> Void) {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func loadContactsCacheIfNeeded(completion: @escaping ([String: String]) -> Void) {
        queue.async {
            //не надо выносить из queue, сейчас contactsCache и читается и пишется в queue, иначе будет не потокобезопасно.
            if let cache = self.contactsCache {
                DispatchQueue.main.async {
                    completion(cache)
                }
                return
            }

            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var index: [String: String] = [:]

            do {
                try self.store.enumerateContacts(with: request) { contact, _ in
                    let name = Self.contactDisplayName(contact)
                    guard !name.isEmpty else { return }

                    for phoneNumber in contact.phoneNumbers {
                        let normalized = Self.normalizePhone(phoneNumber.value.stringValue)
                        guard !normalized.isEmpty else { continue }
                        index[normalized] = name
                    }
                }
            } catch {
                index = [:]
            }

            self.contactsCache = index
            DispatchQueue.main.async {
                completion(index)
            }
        }
    }

    private static func contactDisplayName(_ contact: CNContact) -> String {
        let fullName = "\(contact.givenName) \(contact.familyName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName
    }

    private static func normalizePhone(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        if digits.count == 10 {
            return "7\(digits)"
        }
        if digits.count == 11 && digits.hasPrefix("8") {
            return "7\(digits.dropFirst())"
        }
        return digits
    }
}
