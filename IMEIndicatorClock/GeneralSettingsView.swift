//
//  GeneralSettingsView.swift
//  IMEIndicatorClock
//
//  Created on 2026/07/11.
//
//  一般設定ウィンドウのSwiftUI UI
//  Dockアイコンの表示切り替えなど、アプリ全体の設定を扱う
//

import SwiftUI

// MARK: - 一般設定ビュー

struct GeneralSettingsView: View {

	// 設定マネージャーを監視（リアルタイム反映）
	@ObservedObject private var appSettings = AppSettingsManager.shared

	var body: some View {
		VStack(spacing: 20) {
			// タイトル
			HStack {
				Image(systemName: "gearshape.2")
					.font(.system(size: 24))
					.foregroundColor(.blue)
				Text("general.title", tableName: "Settings")
					.font(.title2)
					.fontWeight(.bold)
			}
			.padding(.bottom, 5)

			// Dockアイコン設定
			GroupBox {
				VStack(alignment: .leading, spacing: 12) {
					// 表示ON/OFF
					Toggle(isOn: Binding(
						get: { appSettings.settings.general.showDockIcon },
						set: { newValue in
							// DockIconManager経由で保存・即時反映
							DockIconManager.shared.setShowDockIcon(newValue)
						}
					)) {
						Text("general.show_dock_icon", tableName: "Settings")
					}

					// 説明文
					Text("general.show_dock_icon_hint", tableName: "Settings")
						.font(.caption)
						.foregroundColor(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
				.padding(8)
			} label: {
				Label {
					Text("general.dock_section", tableName: "Settings")
				} icon: {
					Image(systemName: "dock.rectangle")
				}
			}

			// 上詰めにするためのスペーサー
			Spacer()
		}
		.padding(20)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	}
}

// MARK: - プレビュー

#Preview("General Settings") {
	GeneralSettingsView()
		.frame(width: 500, height: 400)
		.environment(\.locale, Locale(identifier: "zh-Hans"))
}
