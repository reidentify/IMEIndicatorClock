//
//  IMEIndicatorWindowManager.swift
//  IMEIndicatorClock
//
//  Created on 2026/01/09.
//
//  IMEインジケータウィンドウの管理
//  画面上に表示されるIMEインジケータウィンドウを制御します
//

import SwiftUI
import AppKit

// MARK: - IMEインジケータウィンドウマネージャー

/// IMEインジケータウィンドウを管理するクラス
class IMEIndicatorWindowManager: NSObject {

	// MARK: - シングルトン

	/// シングルトンインスタンス
	static let shared = IMEIndicatorWindowManager()

	// MARK: - プロパティ

	/// インジケータウィンドウ
	private var indicatorWindow: NSWindow?

	/// DraggableHostingView（強参照で保持、ドラッグ機能付き）
	private var hostingView: DraggableHostingView?

	/// 現在の入力言語
	private(set) var currentLanguage: InputLanguage = .english

	/// インジケータが表示中かどうか
	private(set) var isVisible: Bool = true

	/// 設定マネージャー（統合設定を使用）
	private var settings: IMEIndicatorSettings {
		return AppSettingsManager.shared.settings.imeIndicator
	}

	// MARK: - 初期化

	private override init() {
		super.init()

		// 設定変更の通知を監視
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(settingsChanged),
			name: .imeIndicatorSettingsChanged,
			object: nil
		)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
		hostingView = nil
		indicatorWindow?.close()
		indicatorWindow = nil
	}

	// MARK: - ユーティリティ

	/// 保存された相対位置をvisibleFrame内にクランプした絶対座標を返す
	private func clampedWindowOrigin(relativeX: CGFloat, relativeY: CGFloat, windowSize: CGFloat, screen: NSScreen) -> CGPoint {
		let absoluteX = screen.frame.origin.x + relativeX
		let absoluteY = screen.frame.origin.y + relativeY
		let visible = screen.visibleFrame

		let clampedX = max(visible.minX, min(absoluteX, visible.maxX - windowSize))
		let clampedY = max(visible.minY, min(absoluteY, visible.maxY - windowSize))

		dbgLog(1, "📐 [IMEIndicator] clampedWindowOrigin: relative(%.0f, %.0f) → clamped(%.0f, %.0f)",
			   relativeX, relativeY, clampedX, clampedY)

		return CGPoint(x: clampedX, y: clampedY)
	}

	// MARK: - ウィンドウ管理

	/// インジケータウィンドウを作成・表示
	func show() {
		dbgLog(1, "▶️ [IMEIndicator] show開始")

		// 既存のウィンドウがある場合は閉じる
		if indicatorWindow != nil {
			hide()
		}

		// 設定を取得
		let currentSettings = settings
		isVisible = currentSettings.isVisible

		// 表示設定がOFFの場合は作成しない
		guard isVisible else {
			dbgLog(1, "▶️ [IMEIndicator] 表示設定がOFFのためスキップ")
			return
		}

		// 選択されたディスプレイを取得
		let displayIndex = currentSettings.displayIndex
		guard displayIndex < NSScreen.screens.count else {
			dbgLog(-1, "⚠️ [IMEIndicator] 無効なディスプレイインデックス: %d", displayIndex)
			return
		}
		let screen = NSScreen.screens[displayIndex]

		// ウィンドウの位置とサイズを計算（visibleFrameクランプ）
		let clampedOrigin = clampedWindowOrigin(
			relativeX: currentSettings.positionX, relativeY: currentSettings.positionY,
			windowSize: currentSettings.indicatorSize, screen: screen
		)
		let windowRect = NSRect(
			x: clampedOrigin.x,
			y: clampedOrigin.y,
			width: currentSettings.indicatorSize,
			height: currentSettings.indicatorSize
		)

		// ウィンドウを作成
		let window = NSWindow(
			contentRect: windowRect,
			styleMask: [.borderless],
			backing: .buffered,
			defer: false
		)

		// ウィンドウのプロパティを設定
		window.isOpaque = false
		window.backgroundColor = .clear
		window.level = .screenSaver
		window.collectionBehavior = [
			.canJoinAllSpaces,
			.stationary,
			.ignoresCycle,
			.fullScreenAuxiliary
		]
		window.isMovableByWindowBackground = currentSettings.moveMode
		window.ignoresMouseEvents = false
		window.hasShadow = true

		// SwiftUIビューを作成（DraggableHostingViewでドラッグ機能を有効化）
		let contentView = createIndicatorView(settings: currentSettings)
		let newHostingView = DraggableHostingView(rootView: contentView)
		self.hostingView = newHostingView
		window.contentView = newHostingView
		dbgLog(1, "🖱️ [IMEIndicator] DraggableHostingView作成（ドラッグ機能有効）")

		// ウィンドウを表示
		window.orderFrontRegardless()
		self.indicatorWindow = window

		dbgLog(1, "✅ [IMEIndicator] ウィンドウを作成しました")
	}

	/// インジケータウィンドウを非表示
	func hide() {
		guard let window = indicatorWindow else { return }

		window.orderOut(nil)
		window.contentView = nil
		self.indicatorWindow = nil
		self.hostingView = nil

		dbgLog(1, "✅ [IMEIndicator] ウィンドウを非表示にしました")
	}

	/// ウィンドウを再作成（設定変更時）
	func recreate() {
		dbgLog(1, "🔄 [IMEIndicator] recreate開始")

		let currentSettings = settings
		isVisible = currentSettings.isVisible

		// 表示設定に応じて処理
		if isVisible {
			// 一度閉じて再作成
			hide()
			show()
		} else {
			hide()
		}

		dbgLog(1, "🔄 [IMEIndicator] recreate完了")
	}

	/// ビューの内容を更新
	func updateView() {
		guard let hostingView = self.hostingView else { return }

		// レイアウト再帰を防ぐため非同期で更新
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			let settings = self.settings
			let newView = self.createIndicatorView(settings: settings)
			hostingView.rootView = newView
			dbgLog(1, "🔄 [IMEIndicator] ビューを更新しました")
		}
	}

	/// アニメーション付きで表示を更新
	func updateWithAnimation() {
		guard let window = indicatorWindow else { return }

		// 点滅アニメーション
		NSAnimationContext.runAnimationGroup({ context in
			context.duration = 0.1
			window.animator().alphaValue = 0.3
		}, completionHandler: {
			NSAnimationContext.runAnimationGroup({ context in
				context.duration = 0.1
				window.animator().alphaValue = 1.0
			}, completionHandler: {
				self.updateView()
			})
		})
	}

	/// 入力言語を更新
	func updateLanguage(_ newLanguage: InputLanguage) {
		guard newLanguage != currentLanguage else { return }

		currentLanguage = newLanguage
		updateWithAnimation()
	}

	/// 表示/非表示を切り替え
	func toggleVisibility() {
		isVisible.toggle()

		// 設定を更新
		AppSettingsManager.shared.settings.imeIndicator.isVisible = isVisible
		AppSettingsManager.shared.save()

		if isVisible {
			if indicatorWindow == nil {
				show()
			} else {
				indicatorWindow?.orderFrontRegardless()
			}
		} else {
			indicatorWindow?.orderOut(nil)
		}

		dbgLog(1, "🔍 [IMEIndicator] isVisible = %@", isVisible ? "true" : "false")
	}

	// MARK: - ヘルパー

	/// IMEIndicatorViewを作成
	private func createIndicatorView(settings: IMEIndicatorSettings) -> IMEIndicatorView {
		return IMEIndicatorView(
			language: currentLanguage,
			size: settings.indicatorSize,
			opacity: settings.backgroundOpacity,
			color: settings.color(for: currentLanguage),
			text: settings.text(for: currentLanguage),
			moveMode: settings.moveMode,
			fontSizeRatio: settings.fontSizeRatio,
			fontName: settings.fontName
		)
	}

	// MARK: - 通知ハンドラ

	/// 設定変更通知を受け取った時の処理
	@objc private func settingsChanged() {
		dbgLog(1, "🔔 [IMEIndicator] 設定変更通知を受信")

		let currentSettings = settings

		// 位置やサイズが変わった場合はウィンドウを再作成（visibleFrameクランプ後の値で比較）
		if let window = indicatorWindow {
			let currentFrame = window.frame
			let screen = NSScreen.screens[safe: currentSettings.displayIndex] ?? NSScreen.main ?? NSScreen.screens.first!
			let expected = clampedWindowOrigin(
				relativeX: currentSettings.positionX, relativeY: currentSettings.positionY,
				windowSize: currentSettings.indicatorSize, screen: screen
			)

			let needsRecreate = (currentFrame.width != currentSettings.indicatorSize ||
								 currentFrame.origin.x != expected.x ||
								 currentFrame.origin.y != expected.y)

			if needsRecreate {
				recreate()
			} else {
				// 表示状態の更新
				isVisible = currentSettings.isVisible
				if isVisible {
					indicatorWindow?.orderFrontRegardless()
				} else {
					indicatorWindow?.orderOut(nil)
				}
				updateView()
			}
		} else if currentSettings.isVisible {
			// ウィンドウがない場合は新規作成
			show()
		}

		// 移動モードの更新
		indicatorWindow?.isMovableByWindowBackground = currentSettings.moveMode

		dbgLog(1, "✅ [IMEIndicator] 設定の適用完了")
	}
}
