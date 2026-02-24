//
//  StatusViewModel.swift
//  Feather
//
//  Created by samara on 24.04.2025.
//

import Foundation
import Combine
import IDeviceSwift

extension String {
	var localized: String { NSLocalizedString(self, comment: "") }
}

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
			return "Enabling PPQ".localized
		}
		switch status {
		case .none: "Packaging".localized
		case .ready: "Ready".localized
		case .sendingManifest: "Sending Manifest".localized
		case .sendingPayload: "Sending Payload".localized
		case .installing: "Installing".localized
		case .completed: "Completed".localized
		case .broken: "Error".localized
		default: "Packaging".localized
		}
	}
}
