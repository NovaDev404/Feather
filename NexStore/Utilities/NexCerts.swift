//
//  NexCerts.swift
//  NexStore
//
//  Created by NovaDev404 on 07.03.2026.
//

import Foundation

enum NexCerts {
	private static let apiBaseURL = "https://sideloading.net/api/certificates"
	private static let listAllURL = URL(string: "\(apiBaseURL)/list/all")!

	struct CatalogItem: Identifiable, Hashable {
		let id: Int
		let name: String
		let certificateType: String
		let status: Status
		let rawStatusText: String
		let validFrom: String
		let validTo: String
		let folderName: String
		fileprivate let order: Int

		var stringID: String {
			"\(id)-\(name)"
		}

		var subtitle: String {
			var components = [certificateType]
			if !validTo.isEmpty {
				components.append(String.localized("Valid To: %@", arguments: validTo))
			}
			return components.joined(separator: " • ")
		}

		var groupingBaseName: String? {
			guard let range = name.range(of: #"\s+\([^()]+\)$"#, options: .regularExpression) else {
				return nil
			}

			let baseName = String(name[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
			return baseName.isEmpty ? nil : baseName
		}

		var p12URL: URL {
			URL(string: "\(NexCerts.apiBaseURL)/download/\(id)/cert.p12")!
		}

		var provisionURL: URL {
			URL(string: "\(NexCerts.apiBaseURL)/download/\(id)/cert.mobileprovision")!
		}

		var passwordURL: URL {
			URL(string: "\(NexCerts.apiBaseURL)/download/\(id)/password")!
		}
	}

	struct CatalogSection: Identifiable, Hashable {
		let id: String
		let title: String
		let subtitle: String?
		let status: Status
		let certificates: [CatalogItem]

		var isGroup: Bool {
			certificates.count > 1
		}
	}

	enum Status: String, Hashable {
		case signed
		case revoked
		case expired
		case unknown

		init(apiValue: String) {
			let normalizedValue = apiValue.lowercased()
			if normalizedValue.contains("signed") || normalizedValue.contains("✅") {
				self = .signed
			} else if normalizedValue.contains("revoked") || normalizedValue.contains("❌") {
				self = .revoked
			} else {
				self = .unknown
			}
		}

		init(apiValue: String, validTo: String) {
			let normalizedValue = apiValue.lowercased()
			if Self._isExpired(validTo: validTo) {
				self = .expired
			} else if normalizedValue.contains("revoked") || normalizedValue.contains("❌") {
				self = .revoked
			} else if normalizedValue.contains("signed") || normalizedValue.contains("✅") {
				self = .signed
			} else {
				self = .unknown
			}
		}

		private static func _isExpired(validTo: String) -> Bool {
			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "yyyy-MM-dd"
			guard let expiryDate = dateFormatter.date(from: validTo) else {
				return false
			}
			return expiryDate < Date()
		}

		var title: String {
			switch self {
			case .signed:
				String.localized("Signed")
			case .revoked:
				String.localized("Revoked")
			case .expired:
				String.localized("Expired")
			case .unknown:
				String.localized("Unknown")
			}
		}

		static func aggregate(_ statuses: [Status]) -> Status {
			if statuses.contains(.signed) {
				return .signed
			}

			if statuses.contains(.revoked) {
				return .revoked
			}

			if statuses.contains(.expired) {
				return .expired
			}

			return .unknown
		}
	}

	enum NexCertsError: LocalizedError {
		case invalidResponse(URL)
		case invalidJSON
		case emptyCatalog
		case invalidPassword

		var errorDescription: String? {
			switch self {
			case .invalidResponse(let url):
				String.localized("Failed to fetch %@.", arguments: url.absoluteString)
			case .invalidJSON:
				String.localized("The NexCerts API response could not be parsed.")
			case .emptyCatalog:
				String.localized("NexCerts did not return any certificates.")
			case .invalidPassword:
				String.localized("The downloaded NexCerts certificate password is invalid.")
			}
		}
	}
}

// MARK: - Catalog
extension NexCerts {
	static func fetchCatalog() async throws -> [CatalogSection] {
		let entries = try await _fetchCatalogFromAPI()

		guard !entries.isEmpty else {
			throw NexCertsError.emptyCatalog
		}

		return _buildSections(from: entries)
	}

	private static func _fetchCatalogFromAPI() async throws -> [CatalogItem] {
		let data = try await _downloadData(from: listAllURL)

		struct APICertificate: Codable {
			let id: Int
			let name: String
			let status: String
			let valid_from: String
			let valid_to: String
			let folder_name: String
		}

		let apiCertificates: [APICertificate]
		do {
			apiCertificates = try JSONDecoder().decode([APICertificate].self, from: data)
		} catch {
			throw NexCertsError.invalidJSON
		}

		return apiCertificates.enumerated().map { index, cert in
			CatalogItem(
				id: cert.id,
				name: cert.name,
				certificateType: "Development",
				status: Status(apiValue: cert.status, validTo: cert.valid_to),
				rawStatusText: cert.status,
				validFrom: cert.valid_from,
				validTo: cert.valid_to,
				folderName: cert.folder_name,
				order: index
			)
		}
	}

	private static func _buildSections(from entries: [CatalogItem]) -> [CatalogSection] {
		var groupedEntries: [String: [CatalogItem]] = [:]

		for entry in entries {
			guard let baseName = entry.groupingBaseName else {
				continue
			}

			groupedEntries[baseName, default: []].append(entry)
		}

		var renderedGroups = Set<String>()
		var sections: [CatalogSection] = []

		for entry in entries {
			if let baseName = entry.groupingBaseName,
			   let bucket = groupedEntries[baseName],
			   bucket.count > 1 {
				guard renderedGroups.insert(baseName).inserted else {
					continue
				}

				let sortedBucket = bucket.sorted { $0.order < $1.order }
				sections.append(
					CatalogSection(
						id: "group-\(baseName)",
						title: String.localized("%@ - %lld Versions", arguments: baseName, Int64(sortedBucket.count)),
						subtitle: String.localized("%lld versions available", arguments: Int64(sortedBucket.count)),
						status: Status.aggregate(sortedBucket.map(\.status)),
						certificates: sortedBucket
					)
				)
			} else {
				sections.append(
					CatalogSection(
						id: "single-\(entry.stringID)",
						title: entry.name,
						subtitle: entry.subtitle,
						status: entry.status,
						certificates: [entry]
					)
				)
			}
		}

		return sections
	}
}

// MARK: - Import
extension NexCerts {
	static func importCertificate(_ certificate: CatalogItem) async throws {
		let fileManager = FileManager.default
		let temporaryDirectory = fileManager.temporaryDirectory.appendingPathComponent("NexCerts_\(UUID().uuidString)", isDirectory: true)

		try fileManager.createDirectoryIfNeeded(at: temporaryDirectory)

		do {
			async let p12Contents = _downloadData(from: certificate.p12URL)
			async let provisionContents = _downloadData(from: certificate.provisionURL)
			async let passwordContents = _downloadText(from: certificate.passwordURL)

			let p12URL = temporaryDirectory.appendingPathComponent("certificate.p12")
			let provisionURL = temporaryDirectory.appendingPathComponent("certificate.mobileprovision")
			let p12Data = try await p12Contents
			let provisionData = try await provisionContents
			let passwordText = try await passwordContents

			try p12Data.write(to: p12URL, options: .atomic)
			try provisionData.write(to: provisionURL, options: .atomic)

			let password = passwordText.trimmingCharacters(in: .whitespacesAndNewlines)

			guard FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL) else {
				throw NexCertsError.invalidPassword
			}

			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
				FR.handleCertificateFiles(
					p12URL: p12URL,
					provisionURL: provisionURL,
					p12Password: password,
					certificateName: certificate.name
				) { error in
					try? fileManager.removeFileIfNeeded(at: temporaryDirectory)

					if let error {
						continuation.resume(throwing: error)
					} else {
						continuation.resume(returning: ())
					}
				}
			}
		} catch {
			try? fileManager.removeFileIfNeeded(at: temporaryDirectory)
			throw error
		}
	}
}

// MARK: - Networking
extension NexCerts {
	private static func _downloadData(from url: URL) async throws -> Data {
		var request = URLRequest(url: url)
		request.timeoutInterval = 30
		request.setValue("NexStore/1.0", forHTTPHeaderField: "User-Agent")

		let (data, response) = try await URLSession.shared.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
			throw NexCertsError.invalidResponse(url)
		}

		return data
	}

	private static func _downloadText(from url: URL) async throws -> String {
		let data = try await _downloadData(from: url)
		guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
			throw NexCertsError.invalidJSON
		}

		return text
	}
}

