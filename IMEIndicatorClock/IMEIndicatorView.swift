//
//  IMEIndicatorView.swift
//  IMEIndicatorClock
//
//  Created on 2026/01/08.
//
//  IMEインジケータのSwiftUIビューとドラッグ機能
//

import SwiftUI
import AppKit

// MARK: - IMEインジケータビュー（SwiftUI）

/// 実際に画面上に表示される円形インジケータのビュー
/// SwiftUIで描画され、入力言語に応じて色とテキストが変化します
struct IMEIndicatorView: View {
	// MARK: - プロパティ

	/// 現在の入力言語
	let language: InputLanguage

	/// インジケータのサイズ（ピクセル）
	let size: CGFloat

	/// 背景の不透明度（0.0〜1.0）
	let opacity: Double

	/// 現在の言語の色
	let color: ColorComponents

	/// 現在の言語のテキスト
	let text: String

	/// 移動モードかどうか（true: ドラッグ可能、false: 固定）
	let moveMode: Bool

	/// フォントサイズの比率（0.3〜0.8）
	let fontSizeRatio: CGFloat

	/// フォント名
	let fontName: String

	// MARK: - ビュー本体

	var body: some View {
		ZStack {
			// --- レイヤー1: 外側の円（グロー効果） ---
			Circle()
				.fill(
					RadialGradient(
						gradient: Gradient(colors: [
							color.color.opacity(0.6),
							color.color.opacity(0.3),
							Color.clear
						]),
						center: .center,
						startRadius: 0,
						endRadius: size * 0.5
					)
				)
				.frame(width: size, height: size)

			// --- レイヤー2: 内側の円（メイン表示） ---
			Circle()
				.fill(
					LinearGradient(
						gradient: Gradient(colors: [
							color.color,
							color.color.opacity(0.7)
						]),
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.frame(width: size * 0.8, height: size * 0.8)
				.overlay(
					Circle()
						.stroke(Color.white.opacity(0.3), lineWidth: 2)
				)

			// --- レイヤー3: テキスト ---
			Text(text)
				.foregroundColor(.white)
				.font(customFont(size: size * fontSizeRatio))
				.shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

			// 移動モード時はカーソルを表示
			if moveMode {
				VStack {
					Spacer()
					HStack {
						Spacer()
						Image(systemName: "hand.point.up.left.fill")
							.font(.system(size: size * 0.2))
							.foregroundColor(.white.opacity(0.5))
							.padding(4)
					}
				}
			}
		}
		.frame(width: size, height: size)
		.opacity(opacity)
	}

	// MARK: - ヘルパー

	/// カスタムフォントを取得
	private func customFont(size: CGFloat) -> Font {
		if fontName == ".AppleSystemUIFont" || fontName.isEmpty {
			return .system(size: size, weight: .bold)
		} else {
			return .custom(fontName, size: size)
		}
	}
}

// MARK: - ドラッグ可能なホスティングビュー

/// ドラッグ機能を持つNSHostingView
/// 移動モードがONの時、インジケータをドラッグで移動できるようにします
final class DraggableHostingView: NSHostingView<IMEIndicatorView> {

	/// ドラッグ開始時のマウス位置
	private var initialLocation: NSPoint = .zero

	/// ドラッグ開始時のウィンドウ位置
	private var initialWindowOrigin: NSPoint = .zero

	/// 初期化
	required init(rootView: IMEIndicatorView) {
		super.init(rootView: rootView)
	}

	@MainActor required dynamic init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	/// マウスダウンイベント（ドラッグ開始）
	override func mouseDown(with event: NSEvent) {
		// 移動モードがONの場合のみドラッグを有効化
		guard AppSettingsManager.shared.settings.imeIndicator.moveMode else {
			super.mouseDown(with: event)
			return
		}

		// 画面座標でのマウス位置を記録
		initialLocation = NSEvent.mouseLocation
		initialWindowOrigin = window?.frame.origin ?? .zero
	}

	/// マウスドラッグイベント（ドラッグ中）
	override func mouseDragged(with event: NSEvent) {
		// 移動モードがONの場合のみドラッグを処理
		guard let window = window,
			  AppSettingsManager.shared.settings.imeIndicator.moveMode else {
			super.mouseDragged(with: event)
			return
		}

		// 現在の画面座標でのマウス位置を取得
		let currentLocation = NSEvent.mouseLocation

		// マウスの移動量を計算
		let deltaX = currentLocation.x - initialLocation.x
		let deltaY = currentLocation.y - initialLocation.y

		// 新しいウィンドウ位置を計算
		let newOrigin = NSPoint(
			x: initialWindowOrigin.x + deltaX,
			y: initialWindowOrigin.y + deltaY
		)

		// ウィンドウを移動
		window.setFrameOrigin(newOrigin)
	}

	/// マウスアップイベント（ドラッグ終了）
	override func mouseUp(with event: NSEvent) {
		// 移動モードがONの場合、最終位置を保存
		guard let window = window,
			  AppSettingsManager.shared.settings.imeIndicator.moveMode else {
			super.mouseUp(with: event)
			return
		}

		// 最終位置を取得（グローバル座標）
		let finalOrigin = window.frame.origin

		// 選択されたディスプレイを取得
		let displayIndex = AppSettingsManager.shared.settings.imeIndicator.displayIndex
		guard displayIndex < NSScreen.screens.count else {
			dbgLog(-1, "⚠️ [IMEIndicator] 無効なディスプレイインデックス: %d", displayIndex)
			return
		}
		let screen = NSScreen.screens[displayIndex]

		// グローバル座標からディスプレイ相対座標に変換
		let relativeX = finalOrigin.x - screen.frame.origin.x
		let relativeY = finalOrigin.y - screen.frame.origin.y

		// ディスプレイ相対座標で保存
		AppSettingsManager.shared.settings.imeIndicator.positionX = relativeX
		AppSettingsManager.shared.settings.imeIndicator.positionY = relativeY
		AppSettingsManager.shared.save()

		// 設定画面のUI更新のため通知を送信
		NotificationCenter.default.post(name: .imeIndicatorSettingsChanged, object: nil)

		dbgLog(1, "📍 [IMEIndicator] ドラッグ終了: グローバル=(%d, %d) → ディスプレイ%d相対=(%d, %d)",
			   Int(finalOrigin.x), Int(finalOrigin.y),
			   displayIndex + 1,
			   Int(relativeX), Int(relativeY))
	}

	/// 右クリックイベント（コンテキストメニュー表示）
	override func rightMouseDown(with event: NSEvent) {
		// 設定ウィンドウが開いている場合はメニューを表示しない
		guard !UnifiedSettingsWindowManager.shared.isOpen else {
			dbgLog(1, "🖱️ [IMEIndicator] 設定ウィンドウが開いているためメニューをスキップ")
			super.rightMouseDown(with: event)
			return
		}

		dbgLog(1, "🖱️ [IMEIndicator] 右クリックメニューを表示")

		// メニューを作成
		let menu = NSMenu()
		menu.autoenablesItems = false  // 自動バリデーションを無効化

		// 設定を開くメニュー項目
		let settingsItem = NSMenuItem(
			title: String(localized: "menu.settings"),
			action: #selector(openSettings),
			keyEquivalent: ""
		)
		settingsItem.target = self
		settingsItem.isEnabled = true
		menu.addItem(settingsItem)

		// メニューを表示
		NSMenu.popUpContextMenu(menu, with: event, for: self)
	}

	/// 設定ウィンドウを開く
	@objc private func openSettings() {
		dbgLog(1, "🖱️ [IMEIndicator] 設定ウィンドウを開く: tab=imeIndicator")
		UnifiedSettingsWindowManager.shared.openSettings(tab: .imeIndicator)
	}
}
