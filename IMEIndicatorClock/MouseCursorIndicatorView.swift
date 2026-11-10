//
//	MouseCursorIndicatorView.swift
//	IMEIndicatorClock
//
//	Created on 2026/01/10.
//
//	マウスカーソル輪郭の蛍光グラデーション発光レンダラーおよびSwiftUI View
//

import SwiftUI
import AppKit
import Combine
import CoreGraphics
import CoreImage

// MARK: - システムカーソル形状スナップショット

/// 現在のシステムカーソル情報（形状識別子・サイズ・ホットスポット）
struct SystemCursorDescriptor: Equatable {
	let key: String
	let size: CGSize
	let hotSpot: CGPoint
	let cursor: NSCursor

	static func current() -> SystemCursorDescriptor {
		let cursor = NSCursor.currentSystem ?? NSCursor.arrow
		let rawSize = cursor.image.size
		let validSize = (rawSize.width >= 8 && rawSize.height >= 8)
			? rawSize
			: CGSize(width: 28, height: 40)
		let hotSpot = cursor.hotSpot
		let key = Self.identifyKey(for: cursor, size: validSize, hotSpot: hotSpot)
		return SystemCursorDescriptor(
			key: key,
			size: validSize,
			hotSpot: hotSpot,
			cursor: cursor
		)
	}

	static func arrowDescriptor() -> SystemCursorDescriptor {
		let cursor = NSCursor.arrow
		let rawSize = cursor.image.size
		let validSize = (rawSize.width >= 8 && rawSize.height >= 8)
			? rawSize
			: CGSize(width: 28, height: 40)
		return SystemCursorDescriptor(
			key: "arrow",
			size: validSize,
			hotSpot: cursor.hotSpot,
			cursor: cursor
		)
	}

	private static func identifyKey(for cursor: NSCursor, size: CGSize, hotSpot: CGPoint) -> String {
		if cursor == NSCursor.arrow { return "arrow" }
		if cursor == NSCursor.iBeam { return "iBeam" }
		if cursor == NSCursor.pointingHand { return "pointingHand" }
		if cursor == NSCursor.crosshair { return "crosshair" }
		if cursor == NSCursor.openHand { return "openHand" }
		if cursor == NSCursor.closedHand { return "closedHand" }
		if cursor == NSCursor.resizeLeftRight { return "resizeLeftRight" }
		if cursor == NSCursor.resizeUpDown { return "resizeUpDown" }
		if cursor == NSCursor.operationNotAllowed { return "notAllowed" }
		if cursor == NSCursor.contextualMenu { return "contextualMenu" }
		if cursor == NSCursor.dragCopy { return "dragCopy" }
		if cursor == NSCursor.dragLink { return "dragLink" }
		return String(
			format: "custom_%dx%d_%d_%d",
			Int(size.width.rounded()),
			Int(size.height.rounded()),
			Int(hotSpot.x.rounded()),
			Int(hotSpot.y.rounded())
		)
	}
}

// MARK: - カーソル輪郭ネオン蛍光レンダラー

/// カーソルの実シルエットから外周グラデーション蛍光テクスチャを生成・キャッシュするクラス
final class CursorNeonGlowRenderer {

	static let shared = CursorNeonGlowRenderer()

	struct RenderedGlow {
		/// 実カーソル重畳用（カーソル内部をくり抜いた外周蛍光レイヤー）
		let overlayImage: NSImage
		/// 設定画面プレビュー用（外周蛍光＋カーソル本体を合成したレイヤー）
		let previewImage: NSImage
		/// キャンバス全体のサイズ（pt）
		let canvasSize: CGSize
		/// キャンバス左上からのホットスポット座標（pt）
		let canvasHotSpot: CGPoint
	}

	private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
	private var cache: [String: RenderedGlow] = [:]

	private init() {}

	func render(
		descriptor: SystemCursorDescriptor,
		innerColor: ColorComponents,
		outerColor: ColorComponents,
		glowRadius: CGFloat
	) -> RenderedGlow {
		let clampedRadius = max(3.0, min(24.0, glowRadius))
		let paddingPt = ceil(clampedRadius * 2.2) + 6.0
		let cacheKey = String(
			format: "%@_%.3f_%.3f_%.3f_%.3f_%.3f_%.3f_%.1f",
			descriptor.key,
			innerColor.red, innerColor.green, innerColor.blue,
			outerColor.red, outerColor.green, outerColor.blue,
			clampedRadius
		)

		if let cached = cache[cacheKey] {
			return cached
		}

		if cache.count > 48 {
			cache.removeAll(keepingCapacity: true)
		}

		let scale: CGFloat = 2.0
		let canvasSize = CGSize(
			width: descriptor.size.width + paddingPt * 2.0,
			height: descriptor.size.height + paddingPt * 2.0
		)
		let canvasHotSpot = CGPoint(
			x: paddingPt + descriptor.hotSpot.x,
			y: paddingPt + descriptor.hotSpot.y
		)

		let pixelW = max(4, Int((canvasSize.width * scale).rounded()))
		let pixelH = max(4, Int((canvasSize.height * scale).rounded()))
		let padPx = (paddingPt * scale).rounded()
		let cursorDrawRect = CGRect(
			x: padPx,
			y: padPx,
			width: (descriptor.size.width * scale).rounded(),
			height: (descriptor.size.height * scale).rounded()
		)

		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

		let baseCursorCG = extractCursorCGImage(descriptor: descriptor, scale: scale)

		guard let overlayCtx = CGContext(
			data: nil,
			width: pixelW,
			height: pixelH,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: colorSpace,
			bitmapInfo: bitmapInfo
		),
		let previewCtx = CGContext(
			data: nil,
			width: pixelW,
			height: pixelH,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: colorSpace,
			bitmapInfo: bitmapInfo
		) else {
			let empty = NSImage(size: canvasSize)
			return RenderedGlow(
				overlayImage: empty,
				previewImage: empty,
				canvasSize: canvasSize,
				canvasHotSpot: canvasHotSpot
			)
		}

		let fullPixelRect = CGRect(x: 0, y: 0, width: pixelW, height: pixelH)

		if let cursorCG = baseCursorCG {
			let innerCGColor = CGColor(
				srgbRed: innerColor.red,
				green: innerColor.green,
				blue: innerColor.blue,
				alpha: 1.0
			)
			let outerCGColor = CGColor(
				srgbRed: outerColor.red,
				green: outerColor.green,
				blue: outerColor.blue,
				alpha: 1.0
			)

			let innerSil = makeSilhouette(
				cursorCG: cursorCG,
				drawRect: cursorDrawRect,
				pixelW: pixelW,
				pixelH: pixelH,
				fillColor: innerCGColor,
				colorSpace: colorSpace
			)
			let outerSil = makeSilhouette(
				cursorCG: cursorCG,
				drawRect: cursorDrawRect,
				pixelW: pixelW,
				pixelH: pixelH,
				fillColor: outerCGColor,
				colorSpace: colorSpace
			)

			// 外周の柔らかい蛍光オーラ（outerColor）
			if let outerSil {
				let ciOuter = CIImage(cgImage: outerSil)
				drawBlurredPass(
					ciImage: ciOuter,
					sigma: Double(clampedRadius * 0.85 * scale),
					alpha: 0.9,
					passes: 1,
					in: overlayCtx,
					previewCtx: previewCtx,
					rect: fullPixelRect
				)
				drawBlurredPass(
					ciImage: ciOuter,
					sigma: Double(clampedRadius * 0.48 * scale),
					alpha: 0.85,
					passes: 1,
					in: overlayCtx,
					previewCtx: previewCtx,
					rect: fullPixelRect
				)
			}

			// 内側輪郭の高輝度蛍光エッジ（innerColor）
			if let innerSil {
				let ciInner = CIImage(cgImage: innerSil)
				drawBlurredPass(
					ciImage: ciInner,
					sigma: Double(clampedRadius * 0.26 * scale),
					alpha: 0.95,
					passes: 2,
					in: overlayCtx,
					previewCtx: previewCtx,
					rect: fullPixelRect
				)
				drawBlurredPass(
					ciImage: ciInner,
					sigma: Double(max(1.2, clampedRadius * 0.11) * scale),
					alpha: 1.0,
					passes: 2,
					in: overlayCtx,
					previewCtx: previewCtx,
					rect: fullPixelRect
				)
			}

			// 実カーソル用レイヤーはカーソル内部をくり抜き、ハードウェアカーソル自体の鮮明さを100%維持
			overlayCtx.saveGState()
			overlayCtx.setBlendMode(.destinationOut)
			overlayCtx.draw(cursorCG, in: cursorDrawRect)
			overlayCtx.restoreGState()

			// プレビュー用レイヤーは実カーソル画像を上に重ねて表示イメージを再現
			previewCtx.draw(cursorCG, in: cursorDrawRect)
		}

		let overlayNSImage: NSImage
		if let cg = overlayCtx.makeImage() {
			overlayNSImage = NSImage(cgImage: cg, size: canvasSize)
		} else {
			overlayNSImage = NSImage(size: canvasSize)
		}

		let previewNSImage: NSImage
		if let cg = previewCtx.makeImage() {
			previewNSImage = NSImage(cgImage: cg, size: canvasSize)
		} else {
			previewNSImage = NSImage(size: canvasSize)
		}

		let rendered = RenderedGlow(
			overlayImage: overlayNSImage,
			previewImage: previewNSImage,
			canvasSize: canvasSize,
			canvasHotSpot: canvasHotSpot
		)
		cache[cacheKey] = rendered
		return rendered
	}

	private func extractCursorCGImage(descriptor: SystemCursorDescriptor, scale: CGFloat) -> CGImage? {
		var rect = NSRect(origin: .zero, size: descriptor.size)
		if let cg = descriptor.cursor.image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
			return cg
		}
		// フォールバック：標準矢印ベクターパスを生成
		let w = max(4, Int((descriptor.size.width * scale).rounded()))
		let h = max(4, Int((descriptor.size.height * scale).rounded()))
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		guard let ctx = CGContext(
			data: nil,
			width: w,
			height: h,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: colorSpace,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			return nil
		}
		ctx.scaleBy(x: scale, y: scale)
		let path = CGMutablePath()
		path.move(to: CGPoint(x: 5, y: 35))
		path.addLine(to: CGPoint(x: 5, y: 19))
		path.addLine(to: CGPoint(x: 9.5, y: 23))
		path.addLine(to: CGPoint(x: 13, y: 15))
		path.addLine(to: CGPoint(x: 15.5, y: 16.2))
		path.addLine(to: CGPoint(x: 12, y: 24))
		path.addLine(to: CGPoint(x: 18, y: 24))
		path.closeSubpath()
		ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
		ctx.addPath(path)
		ctx.fillPath()
		return ctx.makeImage()
	}

	private func makeSilhouette(
		cursorCG: CGImage,
		drawRect: CGRect,
		pixelW: Int,
		pixelH: Int,
		fillColor: CGColor,
		colorSpace: CGColorSpace
	) -> CGImage? {
		guard let ctx = CGContext(
			data: nil,
			width: pixelW,
			height: pixelH,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: colorSpace,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			return nil
		}
		ctx.draw(cursorCG, in: drawRect)
		ctx.setBlendMode(.sourceIn)
		ctx.setFillColor(fillColor)
		ctx.fill(CGRect(x: 0, y: 0, width: pixelW, height: pixelH))
		return ctx.makeImage()
	}

	private func drawBlurredPass(
		ciImage: CIImage,
		sigma: Double,
		alpha: CGFloat,
		passes: Int,
		in overlayCtx: CGContext,
		previewCtx: CGContext,
		rect: CGRect
	) {
		let blurred = ciImage.applyingGaussianBlur(sigma: sigma)
		guard let blurredCG = ciContext.createCGImage(blurred, from: rect) else { return }

		overlayCtx.saveGState()
		overlayCtx.setAlpha(alpha)
		for _ in 0..<passes {
			overlayCtx.draw(blurredCG, in: rect)
		}
		overlayCtx.restoreGState()

		previewCtx.saveGState()
		previewCtx.setAlpha(alpha)
		for _ in 0..<passes {
			previewCtx.draw(blurredCG, in: rect)
		}
		previewCtx.restoreGState()
	}
}

// MARK: - カーソル形状共有状態

/// ウィンドウマネージャーとView間で現在のシステムカーソル形状を同期するモデル
final class CursorIndicatorRuntimeState: ObservableObject {
	static let shared = CursorIndicatorRuntimeState()

	@Published var cursorDescriptor: SystemCursorDescriptor = .current()

	private init() {}
}

// MARK: - マウスカーソルインジケータView

/// マウスカーソルの蛍光エッジ発光または追従バッジを描画するSwiftUI View
struct MouseCursorIndicatorView: View {

	/// 現在の入力言語（初期値はIMEMonitorから取得）
	@State private var currentLanguage: InputLanguage = IMEMonitor.shared.currentLanguage

	/// 設定マネージャー
	@ObservedObject private var appSettings = AppSettingsManager.shared

	/// リアルタイムカーソル形状状態
	@ObservedObject private var runtimeState = CursorIndicatorRuntimeState.shared

	var body: some View {
		Group {
			switch cursorSettings.style {
			case .cursorGlow:
				cursorEdgeGlowBody
			case .floatingBadge:
				floatingBadgeBody
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .mouseCursorIndicatorLanguageChanged)) { notification in
			if let language = notification.object as? InputLanguage {
				currentLanguage = language
			}
		}
	}

	// MARK: - スタイル1: カーソル輪郭蛍光グラデーション発光

	private var cursorEdgeGlowBody: some View {
		let colors = cursorSettings.effectiveGlowColors(
			for: currentLanguage,
			imeSettings: appSettings.settings.imeIndicator
		)
		let rendered = CursorNeonGlowRenderer.shared.render(
			descriptor: runtimeState.cursorDescriptor,
			innerColor: colors.inner,
			outerColor: colors.outer,
			glowRadius: cursorSettings.glowRadius
		)

		return Image(nsImage: rendered.overlayImage)
			.interpolation(.high)
			.frame(
				width: rendered.canvasSize.width,
				height: rendered.canvasSize.height,
				alignment: .topLeading
			)
			.opacity(cursorSettings.opacity)
	}

	// MARK: - スタイル2: 従来の追従小バッジ（互換モード）

	private var floatingBadgeBody: some View {
		ZStack {
			Circle()
				.fill(
					RadialGradient(
						gradient: Gradient(colors: [
							badgeColor.opacity(0.6),
							badgeColor.opacity(0.3),
							Color.clear
						]),
						center: .center,
						startRadius: 0,
						endRadius: badgeSize * 0.5
					)
				)
				.frame(width: badgeSize, height: badgeSize)

			Circle()
				.fill(
					LinearGradient(
						gradient: Gradient(colors: [
							badgeColor,
							badgeColor.opacity(0.7)
						]),
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.frame(width: badgeSize * 0.8, height: badgeSize * 0.8)
				.overlay(
					Circle()
						.stroke(Color.white.opacity(0.3), lineWidth: 1)
				)

			Text(indicatorText)
				.foregroundColor(.white)
				.font(.system(size: badgeSize * fontSizeRatio, weight: .bold))
				.shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
		}
		.frame(width: badgeSize, height: badgeSize, alignment: .topLeading)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.opacity(cursorSettings.opacity)
	}

	// MARK: - 計算プロパティ

	private var cursorSettings: MouseCursorIndicatorSettings {
		appSettings.settings.mouseCursorIndicator
	}

	private var indicatorText: String {
		appSettings.settings.imeIndicator.text(for: currentLanguage)
	}

	private var badgeColor: Color {
		let colors = cursorSettings.effectiveGlowColors(
			for: currentLanguage,
			imeSettings: appSettings.settings.imeIndicator
		)
		return colors.inner.color
	}

	private var badgeSize: CGFloat {
		cursorSettings.size
	}

	private var fontSizeRatio: CGFloat {
		appSettings.settings.imeIndicator.fontSizeRatio
	}
}

// MARK: - 設定画面用リアルタイムプレビューカード

/// 設定ウィンドウ内で蛍光グラデーション発光カーソルの実寸プレビューを表示するコンポーネント
struct CursorNeonGlowPreviewCard: View {

	@ObservedObject private var appSettings = AppSettingsManager.shared

	var body: some View {
		let currentLang = appSettings.currentLanguage
		let cursorSettings = appSettings.settings.mouseCursorIndicator
		let colors = cursorSettings.effectiveGlowColors(
			for: currentLang,
			imeSettings: appSettings.settings.imeIndicator
		)
		let arrowDesc = SystemCursorDescriptor.arrowDescriptor()
		let rendered = CursorNeonGlowRenderer.shared.render(
			descriptor: arrowDesc,
			innerColor: colors.inner,
			outerColor: colors.outer,
			glowRadius: cursorSettings.glowRadius
		)

		HStack(spacing: 24) {
			// ダーク背景上のプレビュー
			ZStack {
				RoundedRectangle(cornerRadius: 10)
					.fill(
						LinearGradient(
							colors: [Color(white: 0.11), Color(white: 0.18)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.overlay(
						RoundedRectangle(cornerRadius: 10)
							.stroke(Color.white.opacity(0.12), lineWidth: 1)
					)

				if cursorSettings.style == .cursorGlow {
					Image(nsImage: rendered.previewImage)
						.interpolation(.high)
						.opacity(cursorSettings.opacity)
				} else {
					MouseCursorIndicatorView()
						.frame(width: cursorSettings.size, height: cursorSettings.size)
				}
			}
			.frame(height: 96)

			// ライト背景上のプレビュー
			ZStack {
				RoundedRectangle(cornerRadius: 10)
					.fill(
						LinearGradient(
							colors: [Color(white: 0.96), Color(white: 0.88)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.overlay(
						RoundedRectangle(cornerRadius: 10)
							.stroke(Color.black.opacity(0.1), lineWidth: 1)
					)

				if cursorSettings.style == .cursorGlow {
					Image(nsImage: rendered.previewImage)
						.interpolation(.high)
						.opacity(cursorSettings.opacity)
				} else {
					MouseCursorIndicatorView()
						.frame(width: cursorSettings.size, height: cursorSettings.size)
				}
			}
			.frame(height: 96)
		}
	}
}

// MARK: - プレビュー

#Preview("Neon Glow Cursor") {
	CursorNeonGlowPreviewCard()
		.padding()
		.frame(width: 420)
}
