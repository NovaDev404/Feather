//
//  AboutView.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import SwiftUI
import NimbleViews
import NimbleJSON

// MARK: - Extension: Model
extension AboutView {
	struct CreditsModel: Codable, Hashable {
		let name: String?
		let desc: String?
		let github: String
	}
}

// MARK: - View
struct AboutView: View {
	typealias CreditsDataHandler = Result<[CreditsModel], Error>
	private let _dataService = NBFetchService()
	
	@State private var _credits: [CreditsModel] = []
	@State var isLoading = true
	
	private let _creditsUrl = "https://raw.githubusercontent.com/khcrysalis/project-credits/refs/heads/main/nexstore/creditsv2.json"
	
	// MARK: Body
	var body: some View {
		NBList(.localized("About")) {
			if !isLoading {
				Section {
					VStack {
						FRAppIconView(size: 72)
						
						Text(Bundle.main.exec)
							.font(.largeTitle)
							.bold()
							.foregroundStyle(Color.accentColor)
						
						HStack(spacing: 4) {
							Text(.localized("Version"))
							Text(Bundle.main.version)
						}
						.font(.footnote)
						.foregroundStyle(.secondary)
					}
				}
				.frame(maxWidth: .infinity)
				.listRowBackground(EmptyView())
				
				NBSection(.localized("Credits")) {
					ForEach(_credits, id: \.github) { credit in
						_credit(name: credit.name, desc: credit.desc, github: credit.github)
					}
					.transition(.slide)
				}
				
			}
		}
		.animation(.default, value: isLoading)
		.task {
			await _fetchAllData()
		}
	}
	
	private func _fetchAllData() async {
		let result = await _fetchCredits(self._creditsUrl, using: _dataService)
		await MainActor.run {
			switch result {
			case .success(let data):
				self._credits = data
			case .failure(_):
				break
			}
		}
		
		await MainActor.run {
			isLoading = false
		}
	}
	
	private func _fetchCredits(_ urlString: String, using service: NBFetchService) async -> CreditsDataHandler {
		return await withCheckedContinuation { continuation in
			service.fetch(from: urlString) { (result: CreditsDataHandler) in
				continuation.resume(returning: result)
			}
		}
	}
}

// MARK: - Extension: view
extension AboutView {
	@ViewBuilder
	private func _credit(
		name: String?,
		desc: String?,
		github: String
	) -> some View {
		Button {
			UIApplication.open("https://github.com/\(github)")
		} label: {
			HStack {
				FRIconCellView(
					title: name ?? github,
					subtitle: desc ?? "",
					iconUrl: URL(string: "https://github.com/\(github).png")!,
					size: 45,
					isCircle: true
				)
				
				Image(systemName: "arrow.up.right")
					.foregroundColor(.secondary.opacity(0.65))
			}
		}
	}
}
