import Foundation

extension ServerAPI {
    func requestLinkForTelegramVerification(
        phoneNumber: String,
        deviceId: String,
        completion: @escaping (Result<AuthRegisterResponseDTO, Error>) -> Void
    ) {
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDeviceID = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanPhone.isEmpty, !cleanDeviceID.isEmpty else {
            completion(.failure(ServerAPIError.missingRequiredParameters(["phoneNumber", "deviceId"])))
            return
        }

        let body = AuthRegisterRequestDTO(phoneNumber: cleanPhone, deviceId: cleanDeviceID)

        do {
            let data = try encoder.encode(body)
            var request = URLRequest(url: API.authRegisterURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            urlSession.dataTask(with: request) { [weak self] data, response, error in
                if let error {
                    completion(.failure(ServerAPIError.network(underlying: error)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(ServerAPIError.invalidResponse))
                    return
                }

                guard let data else {
                    completion(.failure(ServerAPIError.emptyResponse))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = self?.extractMessage(from: data)
                    completion(.failure(ServerAPIError.httpStatus(code: httpResponse.statusCode, message: message)))
                    return
                }

                do {
                    let result = try self?.decoder.decode(AuthRegisterResponseDTO.self, from: data)
                    if let result {
                        completion(.success(result))
                    } else {
                        completion(.failure(ServerAPIError.decodingFailed(type: "AuthRegisterResponseDTO")))
                    }
                } catch {
                    completion(.failure(ServerAPIError.decodingFailed(type: "AuthRegisterResponseDTO")))
                }
            }.resume()
        } catch {
            completion(.failure(ServerAPIError.encodingFailed(underlying: error)))
        }
    }

    func getAuthStatus(
        phoneNumber: String,
        deviceId: String,
        completion: @escaping (Result<AuthStatusResponseDTO, Error>) -> Void
    ) {
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDeviceID = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = AuthStatusRequestDTO(phoneNumber: cleanPhone, deviceId: cleanDeviceID)

        guard !cleanPhone.isEmpty, !cleanDeviceID.isEmpty else {
            completion(.failure(ServerAPIError.missingRequiredParameters(["phoneNumber", "deviceId"])))
            return
        }

        var components = URLComponents(url: API.authStatusURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "phoneNumber", value: query.phoneNumber),
            URLQueryItem(name: "deviceId", value: query.deviceId)
        ]

        guard let url = components?.url else {
            completion(.failure(ServerAPIError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        urlSession.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                completion(.failure(ServerAPIError.network(underlying: error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ServerAPIError.invalidResponse))
                return
            }

            if httpResponse.statusCode == 404 {
                completion(.success(AuthStatusResponseDTO(isVerified: false)))
                return
            }

            guard let data else {
                completion(.failure(ServerAPIError.emptyResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = self?.extractMessage(from: data)
                completion(.failure(ServerAPIError.httpStatus(code: httpResponse.statusCode, message: message)))
                return
            }

            do {
                let result = try self?.decoder.decode(AuthStatusResponseDTO.self, from: data)
                if let result {
                    completion(.success(result))
                } else {
                    completion(.failure(ServerAPIError.decodingFailed(type: "AuthStatusResponseDTO")))
                }
            } catch {
                completion(.failure(ServerAPIError.decodingFailed(type: "AuthStatusResponseDTO")))
            }
        }.resume()
    }

    func exchangeAccessToken(
        verificationToken: String,
        completion: @escaping (Result<AuthExchangeResponseDTO, Error>) -> Void
    ) {
        let cleanToken = verificationToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            completion(.failure(ServerAPIError.missingRequiredParameters(["verificationToken"])))
            return
        }

        let body = AuthExchangeRequestDTO(verificationToken: cleanToken)

        do {
            let data = try encoder.encode(body)
            var request = URLRequest(url: API.authExchangeURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            urlSession.dataTask(with: request) { [weak self] data, response, error in
                if let error {
                    completion(.failure(ServerAPIError.network(underlying: error)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(ServerAPIError.invalidResponse))
                    return
                }

                guard let data else {
                    completion(.failure(ServerAPIError.emptyResponse))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = self?.extractMessage(from: data)
                    completion(.failure(ServerAPIError.httpStatus(code: httpResponse.statusCode, message: message)))
                    return
                }

                do {
                    let result = try self?.decoder.decode(AuthExchangeResponseDTO.self, from: data)
                    if let result {
                        self?.applyAccessTokenIfNeeded(result.accessToken)
                        completion(.success(result))
                    } else {
                        completion(.failure(ServerAPIError.decodingFailed(type: "AuthExchangeResponseDTO")))
                    }
                } catch {
                    completion(.failure(ServerAPIError.decodingFailed(type: "AuthExchangeResponseDTO")))
                }
            }.resume()
        } catch {
            completion(.failure(ServerAPIError.encodingFailed(underlying: error)))
        }
    }
}
