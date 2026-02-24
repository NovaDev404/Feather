//
//  StatusViewModel.swift
//  Feather
//
//  Created by samara on 24.04.2025.
//

import Foundation
import Combine
import IDeviceSwift

extension InstallerStatusViewModel {
	static var enablingPPQStatus: Any {
		struct EnablingPPQ: Equatable {}
		return EnablingPPQ()
	}

	var statusImage: String {
		if String(describing: status) == String(describing: InstallerStatusViewModel.enablingPPQStatus) {
			return "bolt.horizontal.fill"
		}
		switch status {
		case .none: "archivebox.fill"
		case .ready: "app.gift"
		case .sendingManifest, .sendingPayload: "paperplane.fill"
		case .installing: "square.and.arrow.down"
		case .completed: "app.badge.checkmark"
		case .broken: "exclamationmark.triangle.fill"
		default: "archivebox.fill"
		}
	}

	var statusLabel: String {
		if String(describing: status) == String(describing: InstallerStatusViewModel.enablingPPQStatus) {
			return .localized("Enabling PPQ")
		}
		switch status {
		case .none: .localized("Packaging")
		case .ready: .localized("Ready")
		case .sendingManifest: .localized("Sending Manifest")
		case .sendingPayload: .localized("Sending Payload")
		case .installing: .localized("Installing")
		case .completed: .localized("Completed")
		case .broken: .localized("Error")
		default: .localized("Packaging")
		}
	}
}
