//
//	MouseCursorIndicatorWindow.swift
//	IMEIndicatorClock
//
//	Created on 2026/01/10.
//
//	マウスカーソル輪郭の蛍光発光および追従インジケータウィンドウの管理
//

import SwiftUI
import AppKit
import CoreGraphics
import QuartzCore

// MARK: - マウスカーソルインジケータウィンドウマネージャー

/// マウスカーソル輪郭の蛍光グラデーション発光（または追従バッジ）ウィンドウを管理するクラス
final class MouseCursorIndicatorWindowManager: NSObject {

	/// シングルトンインスタンス
	static let shared = MouseCursorIndicatorWindowManager()

	/// インジケータウィンドウ
	private var indicatorWindow: NSWindow?

	/// マウス移動監視（グローバル）
	private var globalMouseMonitor: Any?

	/// マウス移動監視（ローカル：自アプリ内）
	private var localMouseMonitor: Any?

	/// VSync同期ディスプレイリンク（120Hz/60Hz追従およびカーソル形状同期用）
	private var displayLink: CADisplayLink?

	/// 設定変更監視
	private var settingsObserver: NSObjectProtocol?

	/// IMEインジケータ色変更監視（色連動モード用）
	private var imeSettingsObserver: NSObjectProtocol?

	/// 現在の入力言語
	private var currentLanguage: InputLanguage = .english

	/// 一時非表示状態フラグ（セキュリティUI退避またはIME OFF時非表示）
	private var isWindowOrderedOut: Bool = false

	/// 前回反映したマウス座標
	private var lastMouseLocation: NSPoint = NSPoint(x: -99999, y: -99999)

	/// 前回反映したウィンドウキャンバスサイズ
	private var lastCanvasSize: NSSize = .zero

	/// 前回チェックしたカーソル形状の時刻
	private var lastCursorCheckTime: CFAbsoluteTime = 0

	/// 保護対象セキュリティダイアログのCoreGraphics座標矩形キャッシュ
	private var cachedProtectedCGRects: [CGRect] = []

	/// 保護対象矩形キャッシュの最終更新時刻
	private var lastProtectedRectsUpdateTime: CFAbsoluteTime = 0

	/// プロセスIDごとのセキュリティUI判定キャッシュ
	private var securityProcessCache: [pid_t: Bool] = [:]

	// MARK: - 初期化

	private override init() {
		super.init()
		dbgLog(-1, "🖱️ [MouseCursorIndicator] WindowManager初期化開始")

		settingsObserver = NotificationCenter.default.addObserver(
			forName: .mouseCursorIndicatorSettingsChanged,
			object: nil,
			queue: .main
		) { [weak self] _ in
			dbgLog(-1, "🔔 [MouseCursorIndicator] 設定変更通知を受信")
			self?.handleSettingsChanged()
		}

		imeSettingsObserver = NotificationCenter.default.addObserver(
			forName: .imeIndicatorSettingsChanged,
			object: nil,
			queue: .main
		) { [weak self] _ in
			guard let self, let window = self.indicatorWindow else { return }
			self.updateWindowPosition(window: window, forceUpdate: true)
		}

		dbgLog(-1, "🖱️ [MouseCursorIndicator] 設定変更オブザーバー登録完了")
	}

	deinit {
		if let observer = settingsObserver {
			NotificationCenter.default.removeObserver(observer)
		}
		if let observer = imeSettingsObserver {
			NotificationCenter.default.removeObserver(observer)
		}
		stopMonitoring()
	}

	// MARK: - 表示制御

	/// インジケータを表示
	func show() {
		guard indicatorWindow == nil else {
			dbgLog(1, "ℹ️ [MouseCursorIndicator] 既に表示されています")
			return
		}

		currentLanguage = IMEMonitor.shared.currentLanguage
		Self.firstMouseMoveLogged = false

		dbgLog(-1, "🖱️ [MouseCursorIndicator] createWindow呼び出し前")
		createWindow()
		dbgLog(-1, "🖱️ [MouseCursorIndicator] createWindow完了、startMonitoring呼び出し")
		startMonitoring()

		NotificationCenter.default.post(
			name: .mouseCursorIndicatorLanguageChanged,
			object: currentLanguage
		)

		dbgLog(-1, "✅ [MouseCursorIndicator] 表示を開始しました（言語: %@）", String(describing: currentLanguage))
	}

	/// インジケータを非表示
	func hide() {
		stopMonitoring()
		isWindowOrderedOut = false
		lastCanvasSize = .zero
		indicatorWindow?.orderOut(nil)
		indicatorWindow = nil
		dbgLog(1, "✅ [MouseCursorIndicator] 非表示にしました")
	}

	/// 表示/非表示を切り替え
	func toggle() {
		if indicatorWindow != nil {
			hide()
		} else {
			show()
		}
	}

	/// 表示中かどうか
	var isVisible: Bool {
		return indicatorWindow != nil
	}

	// MARK: - ウィンドウ作成

	/// インジケータウィンドウを作成
	private func createWindow() {
		let settings = AppSettingsManager.shared.settings.mouseCursorIndicator
		let initialSize = computeInitialCanvasSize(for: settings)

		let view = MouseCursorIndicatorView()
		let hostingView = NSHostingView(rootView: view)
		hostingView.sizingOptions = []
		hostingView.autoresizingMask = [.width, .height]

		let window = NSWindow(
			contentRect: NSRect(origin: .zero, size: initialSize),
			styleMask: .borderless,
			backing: .buffered,
			defer: false
		)

		window.backgroundColor = .clear
		window.isOpaque = false
		window.hasShadow = false
		window.level = .popUpMenu
		window.ignoresMouseEvents = true
		window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
		window.contentView = hostingView

		self.indicatorWindow = window
		self.isWindowOrderedOut = true
		self.lastCanvasSize = initialSize
		self.lastMouseLocation = NSPoint(x: -99999, y: -99999)

		updateWindowPosition(window: window, forceUpdate: true)
	}

	private func computeInitialCanvasSize(for settings: MouseCursorIndicatorSettings) -> NSSize {
		switch settings.style {
		case .cursorGlow:
			let descriptor = SystemCursorDescriptor.current()
			CursorIndicatorRuntimeState.shared.cursorDescriptor = descriptor
			let clampedRadius = max(3.0, min(24.0, settings.glowRadius))
			let paddingPt = ceil(clampedRadius * 2.2) + 6.0
			return NSSize(
				width: descriptor.size.width + paddingPt * 2.0,
				height: descriptor.size.height + paddingPt * 2.0
			)
		case .floatingBadge:
			return NSSize(width: settings.size, height: settings.size)
		}
	}

	// MARK: - マウス・VSync監視

	/// マウス移動およびVSyncディスプレイリンク監視を開始
	private func startMonitoring() {
		guard globalMouseMonitor == nil else {
			dbgLog(-1, "⚠️ [MouseCursorIndicator] 既に監視中のためスキップ")
			return
		}

		globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
			matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
		) { [weak self] _ in
			self?.handleMouseMoved(forceCursorCheck: true)
		}

		localMouseMonitor = NSEvent.addLocalMonitorForEvents(
			matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
		) { [weak self] event in
			self?.handleMouseMoved(forceCursorCheck: true)
			return event
		}

		if let window = indicatorWindow {
			let link = window.displayLink(target: self, selector: #selector(handleDisplayLink(_:)))
			link.add(to: .main, forMode: .common)
			displayLink = link
		}

		DispatchQueue.main.async { [weak self] in
			self?.handleMouseMoved(forceCursorCheck: true)
		}

		dbgLog(-1, "🖱️ [MouseCursorIndicator] 監視開始 globalMonitor=%@, localMonitor=%@, displayLink=%@",
			   globalMouseMonitor != nil ? "OK" : "nil",
			   localMouseMonitor != nil ? "OK" : "nil",
			   displayLink != nil ? "OK" : "nil")
	}

	/// 監視を停止
	private func stopMonitoring() {
		if let monitor = globalMouseMonitor {
			NSEvent.removeMonitor(monitor)
			globalMouseMonitor = nil
		}

		if let monitor = localMouseMonitor {
			NSEvent.removeMonitor(monitor)
			localMouseMonitor = nil
		}

		displayLink?.invalidate()
		displayLink = nil

		dbgLog(1, "🖱️ [MouseCursorIndicator] マウス監視を停止しました")
	}

	@objc private func handleDisplayLink(_ sender: CADisplayLink) {
		handleMouseMoved(forceCursorCheck: false)
	}

	/// 初回ログ用フラグ
	private static var firstMouseMoveLogged = false

	/// マウス移動・フレーム更新時の処理
	private func handleMouseMoved(forceCursorCheck: Bool) {
		guard let window = indicatorWindow else {
			if !Self.firstMouseMoveLogged {
				dbgLog(-1, "⚠️ [MouseCursorIndicator] handleMouseMoved: indicatorWindow=nil")
				Self.firstMouseMoveLogged = true
			}
			return
		}
		if !Self.firstMouseMoveLogged {
			dbgLog(-1, "✅ [MouseCursorIndicator] handleMouseMoved: 初回呼び出しOK")
			Self.firstMouseMoveLogged = true
		}
		updateWindowPosition(window: window, forceUpdate: false, forceCursorCheck: forceCursorCheck)
	}

	/// ウィンドウ位置・サイズ・表示状態を更新
	private func updateWindowPosition(
		window: NSWindow,
		forceUpdate: Bool,
		forceCursorCheck: Bool = true
	) {
		let settings = AppSettingsManager.shared.settings.mouseCursorIndicator

		// IME ON時のみ発光する設定で、現在英語（IME OFF）の場合は非表示にする
		if settings.onlyShowWhenIMEActive && !currentLanguage.isIMEOn {
			if !isWindowOrderedOut {
				isWindowOrderedOut = true
				window.orderOut(nil)
			}
			return
		}

		let mouseLocation = NSEvent.mouseLocation
		let mouseMoved = (mouseLocation != lastMouseLocation)

		let targetSize: NSSize
		let targetOrigin: NSPoint

		switch settings.style {
		case .cursorGlow:
			let now = CFAbsoluteTimeGetCurrent()
			let descriptor: SystemCursorDescriptor
			if forceUpdate || forceCursorCheck || mouseMoved || (now - lastCursorCheckTime >= 0.05) {
				lastCursorCheckTime = now
				let currentDesc = SystemCursorDescriptor.current()
				if currentDesc != CursorIndicatorRuntimeState.shared.cursorDescriptor {
					CursorIndicatorRuntimeState.shared.cursorDescriptor = currentDesc
				}
				descriptor = currentDesc
			} else {
				descriptor = CursorIndicatorRuntimeState.shared.cursorDescriptor
			}

			let clampedRadius = max(3.0, min(24.0, settings.glowRadius))
			let paddingPt = ceil(clampedRadius * 2.2) + 6.0
			targetSize = NSSize(
				width: descriptor.size.width + paddingPt * 2.0,
				height: descriptor.size.height + paddingPt * 2.0
			)
			let hotSpotInCanvas = CGPoint(
				x: paddingPt + descriptor.hotSpot.x,
				y: paddingPt + descriptor.hotSpot.y
			)
			targetOrigin = NSPoint(
				x: mouseLocation.x - hotSpotInCanvas.x,
				y: mouseLocation.y - targetSize.height + hotSpotInCanvas.y
			)

		case .floatingBadge:
			targetSize = NSSize(width: settings.size, height: settings.size)
			targetOrigin = NSPoint(
				x: mouseLocation.x + settings.offsetX,
				y: mouseLocation.y - settings.size - settings.offsetY
			)
		}

		// App Store決済シートやTouch ID等のシステムセキュリティUI（NSOcclusionDetectionView）上では
		// オーバーレイによるボタン非表示保護を発動させないよう一時的にorderOutする
		if shouldSuppressIndicator(
			mouseLocation: mouseLocation,
			indicatorOrigin: targetOrigin,
			indicatorSize: targetSize
		) {
			if !isWindowOrderedOut {
				isWindowOrderedOut = true
				window.orderOut(nil)
				dbgLog(1, "🛡️ [MouseCursorIndicator] セキュリティUI領域上のため一時非表示にしました")
			}
			return
		}

		if forceUpdate || targetSize != lastCanvasSize {
			lastCanvasSize = targetSize
			lastMouseLocation = mouseLocation
			window.setFrame(NSRect(origin: targetOrigin, size: targetSize), display: true)
		} else if mouseMoved || isWindowOrderedOut {
			lastMouseLocation = mouseLocation
			window.setFrameOrigin(targetOrigin)
		}

		if isWindowOrderedOut {
			isWindowOrderedOut = false
			window.orderFront(nil)
		}
	}

	// MARK: - セキュリティUI干渉回避

	/// セキュリティUIバンドルID完全一致リスト
	private static let securityBundleIDs: Set<String> = [
		"com.apple.AMSUIPaymentViewService",
		"com.apple.AMSUIAuthenticationViewService",
		"com.apple.PassKit.PaymentAuthorizationUIExtension",
		"com.apple.StoreKit.UIService",
		"com.apple.AppStoreDaemon.StoreUIService",
		"com.apple.CoreAuthUI",
		"com.apple.SecurityAgent",
		"com.apple.UniversalAccessAuthWarn",
		"com.apple.UserNotificationCenter",
		"com.apple.EscrowSecurityAlert",
		"com.apple.security.Keychain-Circle-Notification"
	]

	/// セキュリティUIバンドルIDプレフィックスリスト
	private static let securityBundlePrefixes: [String] = [
		"com.apple.AuthKitUI.",
		"com.apple.LocalAuthentication",
		"com.apple.PassKit."
	]

	/// セキュリティUIプロセス名・実行ファイル名フォールバックリスト
	private static let securityExecutableNames: Set<String> = [
		"AMSUIPaymentViewService_macOS",
		"AMSUIAuthenticationViewService_macOS",
		"com.apple.PassKit.PaymentAuthorizationUIExtension",
		"StoreKitUIServiceMac",
		"com.apple.AppStoreDaemon.StoreUIService",
		"AKAuthorizationRemoteViewService",
		"LocalAuthenticationRemoteService",
		"CoreAuthUI",
		"SecurityAgent",
		"UniversalAccessAuthWarn",
		"UserNotificationCenter"
	]

	/// カーソルまたはインジケータが保護対象のセキュリティUI領域と重なるか判定
	private func shouldSuppressIndicator(
		mouseLocation: NSPoint,
		indicatorOrigin: NSPoint,
		indicatorSize: NSSize
	) -> Bool {
		let protectedRects = activeProtectedSecurityRects()
		guard !protectedRects.isEmpty else { return false }

		// AppKit座標（左下原点）からCoreGraphics座標（メイン画面左上原点）へ変換
		let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
		let mouseCGPoint = CGPoint(
			x: mouseLocation.x,
			y: primaryScreenHeight - mouseLocation.y
		)
		let indicatorCGRect = CGRect(
			x: indicatorOrigin.x,
			y: primaryScreenHeight - (indicatorOrigin.y + indicatorSize.height),
			width: indicatorSize.width,
			height: indicatorSize.height
		)
		// NSOcclusionDetectionViewの監視領域に入る直前で退避するようマージンを確保
		let paddedIndicatorRect = indicatorCGRect.insetBy(dx: -16, dy: -16)

		for rect in protectedRects {
			if rect.contains(mouseCGPoint) || rect.intersects(paddedIndicatorRect) {
				return true
			}
		}
		return false
	}

	/// 現在画面上で有効なシステムセキュリティ・決済UIのCoreGraphics座標矩形一覧を取得（短時間キャッシュ付き）
	private func activeProtectedSecurityRects() -> [CGRect] {
		let now = CFAbsoluteTimeGetCurrent()
		if now - lastProtectedRectsUpdateTime < 0.12 {
			return cachedProtectedCGRects
		}
		lastProtectedRectsUpdateTime = now

		guard let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
			cachedProtectedCGRects = []
			return []
		}

		let selfPID = ProcessInfo.processInfo.processIdentifier
		var directSecurityRects: [CGRect] = []
		var onScreenHostRects: [CGRect] = []
		var remoteSecurityCandidateRects: [CGRect] = []

		for info in windowList {
			guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
				  pid != selfPID else {
				continue
			}

			let alpha = info[kCGWindowAlpha as String] as? Double ?? 1.0
			guard alpha > 0.01 else { continue }

			guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
				  let bounds = CGRect(dictionaryRepresentation: boundsDict),
				  bounds.width >= 40,
				  bounds.height >= 40 else {
				continue
			}

			let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
			let layer = info[kCGWindowLayer as String] as? Int ?? 0
			let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""

			if isOnScreen {
				if isSecurityUIProcess(pid: pid, ownerName: ownerName) {
					directSecurityRects.append(bounds)
				} else if layer >= 0 {
					onScreenHostRects.append(bounds)
				}
			} else if isSecurityUIProcess(pid: pid, ownerName: ownerName) {
				// ViewBridge経由のシート（AMSUIPaymentViewService / PassKit等）はkCGWindowIsOnscreen=falseとなり、
				// ホスト側アプリに同一BoundsのNSRemoteView用オンデマンドウィンドウが存在する場合のみ現在表示中と判定する
				remoteSecurityCandidateRects.append(bounds)
			}
		}

		var result = directSecurityRects
		for remoteRect in remoteSecurityCandidateRects {
			let hasActiveHostSheet = onScreenHostRects.contains { hostRect in
				rectsMatch(hostRect, remoteRect, tolerance: 4.0)
			}
			if hasActiveHostSheet {
				result.append(remoteRect)
			}
		}

		cachedProtectedCGRects = result
		return result
	}

	/// 指定プロセスがmacOSのセキュリティ・認証・決済UIプロセスか判定（キャッシュ付き）
	private func isSecurityUIProcess(pid: pid_t, ownerName: String) -> Bool {
		if let cached = securityProcessCache[pid] {
			return cached
		}

		if securityProcessCache.count > 256 {
			securityProcessCache.removeAll(keepingCapacity: true)
		}

		var matched = false
		if let app = NSRunningApplication(processIdentifier: pid) {
			if let bundleID = app.bundleIdentifier {
				if Self.securityBundleIDs.contains(bundleID) ||
					Self.securityBundlePrefixes.contains(where: { bundleID.hasPrefix($0) }) {
					matched = true
				}
			}
			if !matched, let exeName = app.executableURL?.lastPathComponent,
			   Self.securityExecutableNames.contains(exeName) {
				matched = true
			}
		}

		if !matched && Self.securityExecutableNames.contains(ownerName) {
			matched = true
		}

		securityProcessCache[pid] = matched
		return matched
	}

	/// 2つの矩形が許容誤差内で一致するか判定
	private func rectsMatch(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat) -> Bool {
		return abs(lhs.minX - rhs.minX) <= tolerance &&
			   abs(lhs.minY - rhs.minY) <= tolerance &&
			   abs(lhs.width - rhs.width) <= tolerance &&
			   abs(lhs.height - rhs.height) <= tolerance
	}

	// MARK: - 言語更新

	/// 入力言語を更新（IME状態変更時に呼ばれる）
	func updateLanguage(_ language: InputLanguage) {
		let changed = currentLanguage != language
		currentLanguage = language

		if let window = indicatorWindow {
			if changed {
				dbgLog(1, "🔤 [MouseCursorIndicator] 言語変更: %@", String(describing: language))
				NotificationCenter.default.post(
					name: .mouseCursorIndicatorLanguageChanged,
					object: language
				)
			}
			updateWindowPosition(window: window, forceUpdate: true)
		}
	}

	// MARK: - 設定変更ハンドラー

	/// 設定変更時の処理
	private func handleSettingsChanged() {
		let settings = AppSettingsManager.shared.settings.mouseCursorIndicator
		dbgLog(-1, "🔔 [MouseCursorIndicator] handleSettingsChanged: isVisible=%@, style=%@, glowRadius=%.0f",
			   settings.isVisible ? "true" : "false",
			   settings.style.rawValue,
			   settings.glowRadius)

		if settings.isVisible && indicatorWindow == nil {
			show()
			return
		} else if !settings.isVisible && indicatorWindow != nil {
			hide()
			return
		}

		if let window = indicatorWindow {
			updateWindowPosition(window: window, forceUpdate: true)
		}
	}
}
