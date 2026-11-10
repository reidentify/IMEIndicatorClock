//
//  ClockWindow.swift
//  IMEIndicatorClock
//
//  Created on 2025/12/24.
//
//  時計ウィンドウの管理
//  デスクトップに常時表示される時計ウィンドウを制御します
//

import SwiftUI
import AppKit

// MARK: - コンテキストメニュー付きコンテナビュー

/// 右クリックメニューをサポートするコンテナビュー
/// NSHostingViewを子ビューとして保持し、ウィンドウサイズの自動拡大を防止する
final class ContextMenuHostingView: NSView {

	/// 設定を開くタブの種類
	var settingsTab: SettingsTab = .clock

	/// 内部のNSHostingView
	private var hostingView: NSHostingView<AnyView>

	/// SwiftUIビューのルートを更新
	var rootView: AnyView {
		get { hostingView.rootView }
		set { hostingView.rootView = newValue }
	}

	/// 初期化
	init(rootView: AnyView) {
		self.hostingView = NSHostingView(rootView: rootView)
		super.init(frame: .zero)

		// NSHostingViewをサブビューとして追加し、親ビューのサイズに従わせる
		hostingView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(hostingView)
		NSLayoutConstraint.activate([
			hostingView.topAnchor.constraint(equalTo: topAnchor),
			hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
			hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
			hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
		])

		// コンテンツがはみ出す場合はクリップ
		self.clipsToBounds = true

		// NSHostingViewからウィンドウへのサイズ伝播を無効化
		if #available(macOS 13.0, *) {
			hostingView.sizingOptions = []
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	/// 右クリックイベント
	override func rightMouseDown(with event: NSEvent) {
		dbgLog(1, "🖱️ [ContextMenu] rightMouseDown呼び出し")

		// 設定ウィンドウが開いている場合はメニューを表示しない
		guard !UnifiedSettingsWindowManager.shared.isOpen else {
			dbgLog(1, "🖱️ [ContextMenu] 設定ウィンドウが開いているためメニューをスキップ")
			super.rightMouseDown(with: event)
			return
		}

		dbgLog(1, "🖱️ [ContextMenu] 右クリックメニューを表示: event.locationInWindow=(%d,%d)",
			   Int(event.locationInWindow.x), Int(event.locationInWindow.y))

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
		menu.addItem(settingsItem)

		// メニューを表示
		NSMenu.popUpContextMenu(menu, with: event, for: self)
	}

	/// 設定ウィンドウを開く
	@objc private func openSettings() {
		dbgLog(1, "🖱️ [ContextMenu] 設定ウィンドウを開く: tab=%@, moveMode=%@",
			   String(describing: settingsTab),
			   AppSettingsManager.shared.settings.clock.moveMode ? "true" : "false")
		UnifiedSettingsWindowManager.shared.openSettings(tab: settingsTab)
	}
}

// MARK: - 時計ウィンドウマネージャー

/// 時計ウィンドウを管理するクラス
///
/// 機能ごとにextensionで分割:
/// - 基本クラス: プロパティ、初期化、deinit
/// - extension (ウィンドウ管理): show(), hide(), recreate(), updateView()
/// - extension (移動モード): updateMoveModeFromSettings(), オブザーバー管理
/// - extension (通知ハンドラ): handleWindowDidMove(), handleWindowDidResize(), handleWindowDidEndLiveResize()
/// - extension (NSWindowDelegate): windowWillResize()
/// - extension (ヘルパー): calculateWindowSize(), getTargetScreen()
class ClockWindowManager: NSObject, NSWindowDelegate {

	/// シングルトンインスタンス
	static let shared = ClockWindowManager()

	/// 時計ウィンドウ
	var clockWindow: NSWindow?

	/// ContextMenuHostingView（強参照で保持、右クリックメニュー対応）
	var hostingView: ContextMenuHostingView?

	/// NotificationCenterのオブザーバートークン
	var windowMoveObserver: NSObjectProtocol?
	var windowResizeObserver: NSObjectProtocol?
	var windowDidEndLiveResizeObserver: NSObjectProtocol?

	/// 設定マネージャー
	let settingsManager = AppSettingsManager.shared

	// MARK: - 初期化

	private override init() {
		// 設定変更の通知は使用しない（手動で recreate() を呼ぶ）
	}

	deinit {
		// オブザーバーを削除
		removeAllObservers()

		// ウィンドウをクリーンアップ
		hostingView = nil
		clockWindow?.close()
		clockWindow = nil

		dbgLog(1, "🗑️ [ClockWindow] ClockWindowManager が解放されました")
	}
}
	
// MARK: - ウィンドウ管理

extension ClockWindowManager {

	/// 時計ウィンドウを作成・表示
	func show() {
		dbgLog(1, "▶️ [ClockWindow] show開始")

		// 既存のウィンドウがある場合のみ閉じる
		if clockWindow != nil {
			dbgLog(1, "▶️ [ClockWindow] 既存ウィンドウを閉じる")
			hide()
		}

		dbgLog(1, "▶️ [ClockWindow] オブザーバーをクリーン中...")
		removeAllObservers()

		dbgLog(1, "▶️ [ClockWindow] 設定を取得中...")
		let settings = settingsManager.settings.clock

		// ウィンドウサイズを計算
		let windowSize = calculateWindowSize(for: settings)

		// 表示位置を計算（マルチディスプレイ対応・visibleFrameクランプ）
		let screen = getTargetScreen(index: settings.displayIndex)
		let clampedOrigin = clampedWindowOrigin(
			relativeX: settings.positionX, relativeY: settings.positionY,
			windowSize: windowSize, screen: screen
		)

		// ウィンドウの矩形を定義
		let windowRect = NSRect(
			origin: clampedOrigin,
			size: windowSize
		)

		// ウィンドウを作成
		let window = createWindow(rect: windowRect, moveMode: settings.moveMode)

		dbgLog(1, "▶️ [ClockWindow] ClockViewを作成中...")
		// SwiftUIビューを設定（システムの優先言語に基づいたLocaleを適用）
		let preferredLocale = Locale(identifier: Locale.preferredLanguages.first ?? "en")
		let clockView = ClockView(settingsManager: settingsManager)
			.environment(\.locale, preferredLocale)
		dbgLog(1, "▶️ [ClockWindow] ContextMenuHostingViewを作成中... locale=\(preferredLocale.identifier)")
		let newHostingView = ContextMenuHostingView(rootView: AnyView(clockView))
		newHostingView.settingsTab = .clock  // 時計設定タブを開く
		self.hostingView = newHostingView  // 強参照で保持
		dbgLog(1, "▶️ [ClockWindow] contentViewを設定中...")
		window.contentView = newHostingView

		dbgLog(1, "▶️ [ClockWindow] ウィンドウを表示中...")
		// ウィンドウを表示
		if settings.isVisible {
			window.orderFrontRegardless()
		}

		// 移動モードの時のみオブザーバーを登録
		if settings.moveMode {
			registerObservers(for: window)
		}

		self.clockWindow = window

		dbgLog(1, "🕐 [ClockWindow] 時計ウィンドウを作成しました")
		dbgLog(1, "▶️ [ClockWindow] show完了")
	}

	/// 時計ウィンドウを非表示
	func hide() {
		guard let window = clockWindow else {
			dbgLog(1, "🕐 [ClockWindow] 既にウィンドウは存在しません")
			return
		}

		dbgLog(1, "🕐 [ClockWindow] hide開始")

		// オブザーバーを削除
		removeAllObservers()

		// アニメーションを完全に無効化
		window.animationBehavior = .none

		// ウィンドウを非表示にする
		window.orderOut(nil)

		// ウィンドウのコンテンツビューをクリア
		window.contentView = nil

		// 参照をクリア（これでウィンドウは自動的に解放される）
		self.clockWindow = nil
		self.hostingView = nil

		// window.close() は呼ばない！
		// 参照がなくなれば自動的に解放される

		dbgLog(1, "🕐 [ClockWindow] ウィンドウを非表示にしました")
	}

	/// ウィンドウを再作成（設定変更時）
	func recreate() {
		dbgLog(1, "🔄 [ClockWindow] recreate開始")

		let settings = settingsManager.settings.clock

		// ウィンドウが存在しない場合は新規作成
		guard let window = clockWindow, let hostingView = hostingView else {
			dbgLog(1, "🔄 [ClockWindow] ウィンドウが存在しないため、新規作成")
			if settings.isVisible {
				show()
			}
			dbgLog(1, "🔄 [ClockWindow] recreate完了")
			return
		}

		dbgLog(1, "🔄 [ClockWindow] 既存ウィンドウを更新")

		// ウィンドウサイズの制限を設定
		window.minSize = NSSize(width: AppConstants.clockWindowMinSize, height: AppConstants.clockWindowMinSize)
		window.maxSize = NSSize(width: AppConstants.clockWindowMaxSize, height: AppConstants.clockWindowMaxSize)

		// 表示/非表示の切り替え
		if settings.isVisible {
			window.orderFrontRegardless()
		} else {
			window.orderOut(nil)
			dbgLog(1, "🔄 [ClockWindow] recreate完了")
			return
		}

		// ウィンドウサイズを更新
		let windowSize = calculateWindowSize(for: settings)

		// 最大サイズ制限を確実に適用
		let clampedWidth = min(windowSize.width, AppConstants.clockWindowMaxSize)
		let clampedHeight = min(windowSize.height, AppConstants.clockWindowMaxSize)
		let clampedSize = NSSize(width: clampedWidth, height: clampedHeight)

		// オブザーバーを一時解除（setFrame/setFrameOriginによるdidMoveNotification発火で
		// プリセット位置が上書きされるのを防ぐ）
		removeAllObservers()

		var frame = window.frame
		frame.size = clampedSize
		window.setFrame(frame, display: true, animate: false)

		// 位置の更新（ウィンドウドラッグ中は更新しない・visibleFrameクランプ）
		if !settingsManager.isWindowDragging {
			let screen = getTargetScreen(index: settings.displayIndex)
			let newOrigin = clampedWindowOrigin(
				relativeX: settings.positionX, relativeY: settings.positionY,
				windowSize: clampedSize, screen: screen
			)
			frame.origin = newOrigin
			window.setFrameOrigin(newOrigin)

			dbgLog(1, "📐 [ClockWindow] ウィンドウサイズを更新: %dx%d 位置(%d, %d)", Int(clampedWidth), Int(clampedHeight), Int(settings.positionX), Int(settings.positionY))
		} else {
			dbgLog(1, "📐 [ClockWindow] ウィンドウサイズを更新: %dx%d (ドラッグ中のため位置更新スキップ)", Int(clampedWidth), Int(clampedHeight))
		}

		// オブザーバーを再登録
		registerObservers(for: window)

		// 移動モードの更新
		updateMoveMode(for: window, moveMode: settings.moveMode)

		// ビューの内容を更新（システムの優先言語に基づいたLocaleを適用）
		let preferredLocale = Locale(identifier: Locale.preferredLanguages.first ?? "en")
		let newClockView = ClockView(settingsManager: settingsManager)
			.environment(\.locale, preferredLocale)
		hostingView.rootView = AnyView(newClockView)

		dbgLog(1, "🔄 [ClockWindow] ウィンドウ更新完了")
		dbgLog(1, "🔄 [ClockWindow] recreate完了")
	}

	/// ウィンドウの表示内容だけを更新（軽量な処理、オブザーバーは保持）
	func updateView() {
		guard let hostingView = self.hostingView else {
			dbgLog(1, "⚠️ [ClockWindow] hostingViewが存在しないため、ビュー更新をスキップ")
			return
		}

		// ビューの内容だけを更新（システムの優先言語に基づいたLocaleを適用）
		let preferredLocale = Locale(identifier: Locale.preferredLanguages.first ?? "en")
		let newClockView = ClockView(settingsManager: settingsManager)
			.environment(\.locale, preferredLocale)
		hostingView.rootView = AnyView(newClockView)

		dbgLog(1, "🔄 [ClockWindow] ビューの内容を更新しました（軽量）")
	}
}

// MARK: - 移動モード管理

extension ClockWindowManager {

	/// 移動モードを設定から更新（設定ウィンドウの開閉時に呼ばれる）
	func updateMoveModeFromSettings() {
		guard let window = clockWindow else {
			dbgLog(1, "⚠️ [ClockWindow] ウィンドウが存在しないため、移動モード更新をスキップ")
			return
		}

		let settings = settingsManager.settings.clock
		dbgLog(1, "🔄 [ClockWindow] updateMoveModeFromSettings: moveMode = %@", settings.moveMode ? "true" : "false")

		updateMoveMode(for: window, moveMode: settings.moveMode)
	}

	/// 移動モードを更新（内部用）
	func updateMoveMode(for window: NSWindow, moveMode: Bool) {
		// 注意: ignoresMouseEvents = false で右クリックメニューを受け取る
		window.ignoresMouseEvents = false
		dbgLog(1, "🔄 [ClockWindow] ignoresMouseEvents = false に設定")

		if moveMode {
			// 移動モード ON
			window.styleMask.insert(.resizable)
			window.isMovableByWindowBackground = true
			window.isMovable = true
			registerObservers(for: window)
			dbgLog(1, "🔄 [ClockWindow] 移動モード ON")
		} else {
			// 移動モード OFF
			window.styleMask.remove(.resizable)
			window.isMovableByWindowBackground = false
			window.isMovable = false
			removeAllObservers()
			dbgLog(1, "🔄 [ClockWindow] 移動モード OFF")
		}
	}
}

// MARK: - オブザーバー管理

extension ClockWindowManager {

	/// すべてのオブザーバーを登録
	func registerObservers(for window: NSWindow) {
		if windowMoveObserver == nil {
			windowMoveObserver = NotificationCenter.default.addObserver(
				forName: NSWindow.didMoveNotification,
				object: window,
				queue: .main
			) { [weak self] notification in
				self?.handleWindowDidMove(notification)
			}
			dbgLog(1, "🔄 [ClockWindow] 移動オブザーバー登録")
		}

		if windowResizeObserver == nil {
			windowResizeObserver = NotificationCenter.default.addObserver(
				forName: NSWindow.didResizeNotification,
				object: window,
				queue: .main
			) { [weak self] notification in
				self?.handleWindowDidResize(notification)
			}
			dbgLog(1, "🔄 [ClockWindow] リサイズオブザーバー登録")
		}

		if windowDidEndLiveResizeObserver == nil {
			windowDidEndLiveResizeObserver = NotificationCenter.default.addObserver(
				forName: NSWindow.didEndLiveResizeNotification,
				object: window,
				queue: .main
			) { [weak self] notification in
				self?.handleWindowDidEndLiveResize(notification)
			}
			dbgLog(1, "🔄 [ClockWindow] リサイズ終了オブザーバー登録")
		}
	}

	/// すべてのオブザーバーを削除
	func removeAllObservers() {
		if let observer = windowMoveObserver {
			NotificationCenter.default.removeObserver(observer)
			windowMoveObserver = nil
			dbgLog(1, "🔄 [ClockWindow] 移動オブザーバー削除")
		}
		if let observer = windowResizeObserver {
			NotificationCenter.default.removeObserver(observer)
			windowResizeObserver = nil
			dbgLog(1, "🔄 [ClockWindow] リサイズオブザーバー削除")
		}
		if let observer = windowDidEndLiveResizeObserver {
			NotificationCenter.default.removeObserver(observer)
			windowDidEndLiveResizeObserver = nil
			dbgLog(1, "🔄 [ClockWindow] リサイズ終了オブザーバー削除")
		}
	}
}

// MARK: - 通知ハンドラ

extension ClockWindowManager {

	/// ウィンドウが移動された時（移動モード時に位置を保存）
	func handleWindowDidMove(_ notification: Notification) {
		guard let clockWindow = self.clockWindow,
			  let window = notification.object as? NSWindow,
			  window == clockWindow,
			  settingsManager.settings.clock.moveMode else {
			return
		}

		let frame = window.frame
		let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first!

		let relativeX = frame.origin.x - screen.frame.origin.x
		let relativeY = frame.origin.y - screen.frame.origin.y

		let currentX = settingsManager.settings.clock.positionX
		let currentY = settingsManager.settings.clock.positionY

		guard abs(relativeX - currentX) > AppConstants.windowPositionThreshold ||
			  abs(relativeY - currentY) > AppConstants.windowPositionThreshold else {
			return
		}

		settingsManager.updatePositionFromWindow(x: relativeX, y: relativeY)
		dbgLog(1, "🖱️ [ClockWindow] ドラッグで位置を更新: (%d, %d)", Int(relativeX), Int(relativeY))
	}

	/// ウィンドウがリサイズされた時（移動モード時にサイズを保存）
	func handleWindowDidResize(_ notification: Notification) {
		guard let clockWindow = self.clockWindow,
			  let window = notification.object as? NSWindow,
			  window == clockWindow,
			  settingsManager.settings.clock.moveMode else {
			return
		}

		let frame = window.frame
		let windowSize = frame.size
		let windowOrigin = frame.origin
		let mouseLocation = NSEvent.mouseLocation

		let isAtMaxLimit = windowSize.width >= AppConstants.clockWindowMaxSize || windowSize.height >= AppConstants.clockWindowMaxSize
		let isAtMinLimit = windowSize.width <= AppConstants.clockWindowMinSize || windowSize.height <= AppConstants.clockWindowMinSize

		if isAtMaxLimit || isAtMinLimit {
			dbgLog(1, "🔒 ドラッグ中: マウス位置(%d, %d) ウィンドウ(%dx%d) 位置(%d, %d)", Int(mouseLocation.x), Int(mouseLocation.y), Int(windowSize.width), Int(windowSize.height), Int(windowOrigin.x), Int(windowOrigin.y))
		}
	}

	/// ウィンドウのリサイズが終了した時（ドラッグ終了後に1回だけ保存）
	func handleWindowDidEndLiveResize(_ notification: Notification) {
		guard let clockWindow = self.clockWindow,
			  let window = notification.object as? NSWindow,
			  window == clockWindow,
			  settingsManager.settings.clock.moveMode else {
			return
		}

		let frame = window.frame
		let newWidth = frame.size.width
		let newHeight = frame.size.height
		let windowOrigin = frame.origin

		let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first!
		let relativeX = windowOrigin.x - screen.frame.origin.x
		let relativeY = windowOrigin.y - screen.frame.origin.y

		settingsManager.isUpdatingFromWindow = true
		settingsManager.settings.clock.windowWidth = newWidth
		settingsManager.settings.clock.windowHeight = newHeight
		settingsManager.settings.clock.positionX = relativeX
		settingsManager.settings.clock.positionY = relativeY

		settingsManager.save()
		dbgLog(1, "💾 リサイズ終了: ウィンドウ(%dx%d) 位置(%d, %d)", Int(newWidth), Int(newHeight), Int(relativeX), Int(relativeY))

		DispatchQueue.main.async {
			self.settingsManager.isUpdatingFromWindow = false
		}

		dbgLog(1, "✅ リサイズ完了: 設定画面を更新しました")
	}
}

// MARK: - NSWindowDelegate

extension ClockWindowManager {

	/// リサイズ中にサイズを制限
	func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
		let mouseLocation = NSEvent.mouseLocation

		let clampedWidth = min(frameSize.width, AppConstants.clockWindowMaxSize)
		let clampedHeight = min(frameSize.height, AppConstants.clockWindowMaxSize)

		let finalWidth = max(clampedWidth, AppConstants.clockWindowMinSize)
		let finalHeight = max(clampedHeight, AppConstants.clockWindowMinSize)

		let windowOrigin = sender.frame.origin

		if frameSize.width > AppConstants.clockWindowMaxSize || frameSize.height > AppConstants.clockWindowMaxSize ||
		   frameSize.width < AppConstants.clockWindowMinSize || frameSize.height < AppConstants.clockWindowMinSize {
			dbgLog(1, "🔒 リサイズ制限: マウス位置(%d, %d) 要求(%dx%d) → ウィンドウ(%dx%d) 位置(%d, %d)", Int(mouseLocation.x), Int(mouseLocation.y), Int(frameSize.width), Int(frameSize.height), Int(finalWidth), Int(finalHeight), Int(windowOrigin.x), Int(windowOrigin.y))
		}

		return NSSize(width: finalWidth, height: finalHeight)
	}
}

// MARK: - ヘルパーメソッド

extension ClockWindowManager {

	/// ウィンドウサイズを計算
	func calculateWindowSize(for settings: ClockSettings) -> NSSize {
		return NSSize(width: settings.windowWidth, height: settings.windowHeight)
	}

	/// 保存された相対位置をvisibleFrame内にクランプした絶対座標を返す
	func clampedWindowOrigin(relativeX: CGFloat, relativeY: CGFloat, windowSize: NSSize, screen: NSScreen) -> CGPoint {
		let absoluteX = screen.frame.origin.x + relativeX
		let absoluteY = screen.frame.origin.y + relativeY
		let visible = screen.visibleFrame

		let clampedX = max(visible.minX, min(absoluteX, visible.maxX - windowSize.width))
		let clampedY = max(visible.minY, min(absoluteY, visible.maxY - windowSize.height))

		dbgLog(1, "📐 [ClockWindow] clampedWindowOrigin: relative(%.0f, %.0f) → absolute(%.0f, %.0f) → clamped(%.0f, %.0f) visibleFrame=(%.0f, %.0f, %.0f, %.0f)",
			   relativeX, relativeY, absoluteX, absoluteY, clampedX, clampedY,
			   visible.origin.x, visible.origin.y, visible.width, visible.height)

		return CGPoint(x: clampedX, y: clampedY)
	}

	/// 対象のスクリーンを取得（マルチディスプレイ対応）
	func getTargetScreen(index: Int) -> NSScreen {
		let screens = NSScreen.screens
		if index < screens.count {
			return screens[index]
		} else {
			return NSScreen.main ?? screens.first!
		}
	}

	/// ウィンドウを作成
	func createWindow(rect: NSRect, moveMode: Bool) -> NSWindow {
		let styleMask: NSWindow.StyleMask = moveMode
			? [.borderless, .nonactivatingPanel, .resizable]
			: [.borderless, .nonactivatingPanel]

		let window = NSWindow(
			contentRect: rect,
			styleMask: styleMask,
			backing: .buffered,
			defer: false
		)

		// ウィンドウのプロパティ設定
		window.isOpaque = false
		window.backgroundColor = .clear
		// フルスクリーンアプリの上にも浮かせるため、レベルを上げ .fullScreenAuxiliary を付与
		// （.regular=Dock表示 のままでも他アプリのフルスクリーン空間上に表示可能）
		window.level = .screenSaver
		window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
		window.minSize = NSSize(width: AppConstants.clockWindowMinSize, height: AppConstants.clockWindowMinSize)
		window.maxSize = NSSize(width: AppConstants.clockWindowMaxSize, height: AppConstants.clockWindowMaxSize)
		window.animationBehavior = .none
		window.ignoresMouseEvents = false
		window.hasShadow = true
		window.delegate = self

		if moveMode {
			window.isMovableByWindowBackground = true
			window.isMovable = true
		} else {
			window.isMovableByWindowBackground = false
			window.isMovable = false
		}

		dbgLog(1, "▶️ [ClockWindow] ignoresMouseEvents = false に設定")

		return window
	}

	/// 時計設定を開く（右クリックメニュー用）
	@objc func openClockSettings() {
		dbgLog(1, "🖱️ [ClockWindow] 設定ウィンドウを開く: tab=clock")
		UnifiedSettingsWindowManager.shared.openSettings(tab: .clock)
	}
}
