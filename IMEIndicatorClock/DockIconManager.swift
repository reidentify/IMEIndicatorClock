//
//  DockIconManager.swift
//  IMEIndicatorClock
//
//  Created on 2026/07/11.
//
//  Dockアイコンの表示/非表示を管理
//  GeneralSettings.showDockIcon の値に応じて NSApplication のアクティベーションポリシーを切り替えます
//
//  【アクティベーションポリシーの意味】
//  - .regular:   Dockにアイコンを表示（通常のアプリ）
//  - .accessory: Dockにアイコンを表示しない（メニューバー常駐アプリ）
//

import AppKit

// MARK: - Dockアイコンマネージャー

/// Dockアイコンの表示状態を管理するクラス
class DockIconManager {

	// MARK: - シングルトン

	/// シングルトンインスタンス
	static let shared = DockIconManager()

	// MARK: - 初期化

	private init() {}

	// MARK: - 公開メソッド

	/// 設定値に基づいてDockアイコンの表示状態を適用
	func applyFromSettings() {
		let showDockIcon = AppSettingsManager.shared.settings.general.showDockIcon
		apply(showDockIcon: showDockIcon)
	}

	/// Dockアイコンの表示状態を設定
	/// - Parameter showDockIcon: true=Dockに表示（.regular）、false=非表示（.accessory）
	func apply(showDockIcon: Bool) {
		let policy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
		NSApplication.shared.setActivationPolicy(policy)
		dbgLog(1, "🚢 [DockIcon] アクティベーションポリシーを設定: %@", showDockIcon ? ".regular（Dock表示）" : ".accessory（Dock非表示）")
	}

	/// 設定を変更して即座に反映・保存
	/// - Parameter showDockIcon: 新しい表示状態
	func setShowDockIcon(_ showDockIcon: Bool) {
		let settingsManager = AppSettingsManager.shared
		settingsManager.settings.general.showDockIcon = showDockIcon
		settingsManager.save()
		apply(showDockIcon: showDockIcon)
		dbgLog(1, "🚢 [DockIcon] showDockIcon を変更: %@", showDockIcon ? "true" : "false")
	}
}
