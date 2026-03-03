//
//  AboutView.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import SwiftUI
import NimbleViews

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
	@State private var _credits: [CreditsModel] = []
	@State var isLoading = true

	private let _fixedCredits: [CreditsModel] = [
		.init(name: "NovaDev404", desc: "NexStore Developer", github: "NovaDev404"),
		.init(name: "Samara", desc: "Feather Developer", github: "claration"),
		.init(name: "Nyasami", desc: "Contributor", github: "Nyasami"),
		.init(name: "Adrian Castro", desc: "Contributor", github: "castdrian"),
		.init(name: "Lakhan Lothiyi", desc: "Repositories", github: "llsc12"),
		.init(name: "HAHALOSAH", desc: "Operations", github: "HAHALOSAH"),
		.init(name: "Jackson Coxson", desc: "Idevice", github: "jkcoxson")
	]
	
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
		await MainActor.run {
			self._credits = self._fixedCredits
		}
		
		await MainActor.run {
			isLoading = false
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
