//
//  SettingsView.swift
//  Feather
//
//  Created by NovaDev404 on 24.02.2026.
//

import SwiftUI

struct MoreView: View {
	@AppStorage("Feather.useNovaDNSDynamic") private var useNovaDNSDynamic: Bool = false

	var body: some View {
		NBList(.localized("More Settings")) {
			Section {
				HStack {
					Toggle(isOn: $useNovaDNSDynamic) {
						Text("Use NovaDNS Dynamic")
					}
					Spacer()
					Button(action: {
						if let url = URL(string: "https://novadev.vip/resources/dns/") {
							UIApplication.shared.open(url)
						}
					}) {
						Image(systemName: "questionmark.circle.fill")
							.foregroundColor(.blue)
					}
					.buttonStyle(.plain)
				}
			}
		}
	}
}