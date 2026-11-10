//
//	MouseCursorIndicatorSettings.swift
//	IMEIndicatorClock
//
//	Created on 2026/01/10.
//
//	マウスカーソルインジケータ設定データモデル
//	マウスカーソル輪郭の蛍光グラデーション発光および追従バッジの設定を管理
//

import Foundation
import SwiftUI

// MARK: - 表示スタイル・カラーモード定義

/// マウスカーソルインジケータの表示スタイル
enum CursorIndicatorStyle: String, Codable, CaseIterable {
	/// マウスカーソル自体の輪郭から外側へ蛍光グラデーション発光（追従オフセットなし）
	case cursorGlow = "cursor_glow"
	/// カーソル右下に追従する従来の小バッジ表示
	case floatingBadge = "floating_badge"
}

/// 蛍光グラデーションの色決定モード
enum CursorGlowColorMode: String, Codable, CaseIterable {
	/// クライアント側で指定したカスタム蛍光色（デフォルト：蛍光グリーン）
	case custom = "custom"
	/// 現在の入力言語（IME状態）に応じて色を自動切り替え
	case perLanguage = "per_language"
}

/// クイック選択用の蛍光カラープリセット
struct NeonGlowPreset: Identifiable {
	let id: String
	let localizationKey: String
	let inner: ColorComponents
	let outer: ColorComponents

	static let presets: [NeonGlowPreset] = [
		NeonGlowPreset(
			id: "neon_green",
			localizationKey: "preset_neon_green",
			inner: ColorComponents(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0),
			outer: ColorComponents(red: 0.1, green: 1.0, blue: 0.78, alpha: 1.0)
		),
		NeonGlowPreset(
			id: "cyber_cyan",
			localizationKey: "preset_cyber_cyan",
			inner: ColorComponents(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0),
			outer: ColorComponents(red: 0.1, green: 0.48, blue: 1.0, alpha: 1.0)
		),
		NeonGlowPreset(
			id: "neon_pink",
			localizationKey: "preset_neon_pink",
			inner: ColorComponents(red: 1.0, green: 0.16, blue: 0.55, alpha: 1.0),
			outer: ColorComponents(red: 1.0, green: 0.52, blue: 0.12, alpha: 1.0)
		),
		NeonGlowPreset(
			id: "electric_purple",
			localizationKey: "preset_electric_purple",
			inner: ColorComponents(red: 0.68, green: 0.28, blue: 1.0, alpha: 1.0),
			outer: ColorComponents(red: 0.96, green: 0.24, blue: 0.72, alpha: 1.0)
		),
		NeonGlowPreset(
			id: "lime_laser",
			localizationKey: "preset_lime_laser",
			inner: ColorComponents(red: 0.78, green: 1.0, blue: 0.0, alpha: 1.0),
			outer: ColorComponents(red: 0.0, green: 1.0, blue: 0.38, alpha: 1.0)
		),
		NeonGlowPreset(
			id: "solar_orange",
			localizationKey: "preset_solar_orange",
			inner: ColorComponents(red: 1.0, green: 0.38, blue: 0.0, alpha: 1.0),
			outer: ColorComponents(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
		)
	]
}

// MARK: - マウスカーソルインジケータ設定データモデル

/// マウスカーソルインジケータの表示設定を管理する構造体
struct MouseCursorIndicatorSettings: Codable {

	// MARK: - 基本設定

	/// インジケータを表示するかどうか
	var isVisible: Bool = true

	/// 表示スタイル（デフォルト：カーソル輪郭蛍光発光）
	var style: CursorIndicatorStyle = .cursorGlow

	// MARK: - 蛍光グラデーション設定

	/// 蛍光色の決定モード（デフォルト：カスタム蛍光色）
	var colorMode: CursorGlowColorMode = .custom

	/// 内側（カーソル輪郭直近）のメイン蛍光色（デフォルト：蛍光グリーン #00FF73）
	var customGlowInnerColor: ColorComponents = ColorComponents(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0)

	/// 外側へ広がるグラデーション蛍光色（デフォルト：エメラルドシアン #1AFFC7）
	var customGlowOuterColor: ColorComponents = ColorComponents(red: 0.1, green: 1.0, blue: 0.78, alpha: 1.0)

	/// 2色グラデーション発光を有効にするか（OFF時はメイン蛍光色単色で減衰）
	var useGradientGlow: Bool = true

	/// 蛍光エッジの広がり半径（4〜22pt）
	var glowRadius: CGFloat = 10

	/// IMEがON（英語以外の入力中）の時のみ発光させるか
	var onlyShowWhenIMEActive: Bool = false

	// MARK: - サイズ・位置設定（従来バッジ互換用）

	/// インジケータのサイズ（12〜32px）
	var size: CGFloat = 20

	/// カーソルからのX方向オフセット（-30〜+30px、正=右、負=左）
	var offsetX: CGFloat = 16

	/// カーソルからのY方向オフセット（-30〜+30px、正=下、負=上）
	var offsetY: CGFloat = 8

	// MARK: - 外観設定

	/// 不透明度・発光強度（0.2〜1.0）
	var opacity: Double = 0.92

	/// IMEインジケータと同じ色を使用するかどうか（perLanguageモード時）
	var useSameColorAsIMEIndicator: Bool = false

	/// 独自の英語（IME OFF）の色（useSameColorAsIMEIndicator=false時に使用）
	var englishColor: ColorComponents = ColorComponents(red: 0.0, green: 0.75, blue: 1.0, alpha: 1.0)

	/// 独自の日本語の色（useSameColorAsIMEIndicator=false時に使用）
	var japaneseColor: ColorComponents = ColorComponents(red: 1.0, green: 0.2, blue: 0.35, alpha: 1.0)

	/// 独自の中国語（簡体字）の色（デフォルト：蛍光グリーン）
	var chineseSimplifiedColor: ColorComponents = ColorComponents(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0)

	/// 独自の中国語（繁体字）の色
	var chineseTraditionalColor: ColorComponents = ColorComponents(red: 0.0, green: 0.9, blue: 0.55, alpha: 1.0)

	/// 独自の韓国語の色
	var koreanColor: ColorComponents = ColorComponents(red: 0.72, green: 0.25, blue: 1.0, alpha: 1.0)

	/// 独自のタイ語の色
	var thaiColor: ColorComponents = ColorComponents(red: 0.0, green: 0.6, blue: 0.6, alpha: 1.0)

	/// 独自のベトナム語の色
	var vietnameseColor: ColorComponents = ColorComponents(red: 0.0, green: 0.7, blue: 0.7, alpha: 1.0)

	/// 独自のアラビア語の色
	var arabicColor: ColorComponents = ColorComponents(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)

	/// 独自のヘブライ語の色
	var hebrewColor: ColorComponents = ColorComponents(red: 0.85, green: 0.65, blue: 0.0, alpha: 1.0)

	/// 独自のヒンディー語の色
	var hindiColor: ColorComponents = ColorComponents(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)

	/// 独自のロシア語の色
	var russianColor: ColorComponents = ColorComponents(red: 0.7, green: 0.0, blue: 0.3, alpha: 1.0)

	/// 独自のギリシャ語の色
	var greekColor: ColorComponents = ColorComponents(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)

	/// 独自のモンゴル語の色
	var mongolianColor: ColorComponents = ColorComponents(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0)

	/// 独自のミャンマー語の色
	var myanmarColor: ColorComponents = ColorComponents(red: 0.8, green: 0.6, blue: 0.0, alpha: 1.0)

	/// 独自のクメール語の色
	var khmerColor: ColorComponents = ColorComponents(red: 0.2, green: 0.6, blue: 0.4, alpha: 1.0)

	/// 独自のラオス語の色
	var laoColor: ColorComponents = ColorComponents(red: 0.4, green: 0.7, blue: 0.3, alpha: 1.0)

	/// 独自のベンガル語の色
	var bengaliColor: ColorComponents = ColorComponents(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0)

	/// 独自のタミル語の色
	var tamilColor: ColorComponents = ColorComponents(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)

	/// 独自のテルグ語の色
	var teluguColor: ColorComponents = ColorComponents(red: 0.6, green: 0.3, blue: 0.0, alpha: 1.0)

	/// 独自のネパール語の色
	var nepaliColor: ColorComponents = ColorComponents(red: 0.8, green: 0.0, blue: 0.4, alpha: 1.0)

	/// 独自のシンハラ語の色
	var sinhalaColor: ColorComponents = ColorComponents(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0)

	/// 独自のペルシア語の色
	var persianColor: ColorComponents = ColorComponents(red: 0.0, green: 0.6, blue: 0.3, alpha: 1.0)

	/// 独自のウクライナ語の色
	var ukrainianColor: ColorComponents = ColorComponents(red: 0.0, green: 0.35, blue: 0.7, alpha: 1.0)

	/// 独自のその他のIMEの色
	var otherColor: ColorComponents = ColorComponents(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)

	// MARK: - 初期化（後方互換デコード対応）

	init() {}

	enum CodingKeys: String, CodingKey {
		case isVisible
		case style
		case colorMode
		case customGlowInnerColor
		case customGlowOuterColor
		case useGradientGlow
		case glowRadius
		case onlyShowWhenIMEActive
		case size
		case offsetX
		case offsetY
		case opacity
		case useSameColorAsIMEIndicator
		case englishColor
		case japaneseColor
		case chineseSimplifiedColor
		case chineseTraditionalColor
		case koreanColor
		case thaiColor
		case vietnameseColor
		case arabicColor
		case hebrewColor
		case hindiColor
		case russianColor
		case greekColor
		case mongolianColor
		case myanmarColor
		case khmerColor
		case laoColor
		case bengaliColor
		case tamilColor
		case teluguColor
		case nepaliColor
		case sinhalaColor
		case persianColor
		case ukrainianColor
		case otherColor
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let defaults = MouseCursorIndicatorSettings()

		self.isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? defaults.isVisible
		self.style = try container.decodeIfPresent(CursorIndicatorStyle.self, forKey: .style) ?? defaults.style
		self.colorMode = try container.decodeIfPresent(CursorGlowColorMode.self, forKey: .colorMode) ?? defaults.colorMode
		self.customGlowInnerColor = try container.decodeIfPresent(ColorComponents.self, forKey: .customGlowInnerColor) ?? defaults.customGlowInnerColor
		self.customGlowOuterColor = try container.decodeIfPresent(ColorComponents.self, forKey: .customGlowOuterColor) ?? defaults.customGlowOuterColor
		self.useGradientGlow = try container.decodeIfPresent(Bool.self, forKey: .useGradientGlow) ?? defaults.useGradientGlow
		self.glowRadius = try container.decodeIfPresent(CGFloat.self, forKey: .glowRadius) ?? defaults.glowRadius
		self.onlyShowWhenIMEActive = try container.decodeIfPresent(Bool.self, forKey: .onlyShowWhenIMEActive) ?? defaults.onlyShowWhenIMEActive
		self.size = try container.decodeIfPresent(CGFloat.self, forKey: .size) ?? defaults.size
		self.offsetX = try container.decodeIfPresent(CGFloat.self, forKey: .offsetX) ?? defaults.offsetX
		self.offsetY = try container.decodeIfPresent(CGFloat.self, forKey: .offsetY) ?? defaults.offsetY
		self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? defaults.opacity
		self.useSameColorAsIMEIndicator = try container.decodeIfPresent(Bool.self, forKey: .useSameColorAsIMEIndicator) ?? defaults.useSameColorAsIMEIndicator
		self.englishColor = try container.decodeIfPresent(ColorComponents.self, forKey: .englishColor) ?? defaults.englishColor
		self.japaneseColor = try container.decodeIfPresent(ColorComponents.self, forKey: .japaneseColor) ?? defaults.japaneseColor
		self.chineseSimplifiedColor = try container.decodeIfPresent(ColorComponents.self, forKey: .chineseSimplifiedColor) ?? defaults.chineseSimplifiedColor
		self.chineseTraditionalColor = try container.decodeIfPresent(ColorComponents.self, forKey: .chineseTraditionalColor) ?? defaults.chineseTraditionalColor
		self.koreanColor = try container.decodeIfPresent(ColorComponents.self, forKey: .koreanColor) ?? defaults.koreanColor
		self.thaiColor = try container.decodeIfPresent(ColorComponents.self, forKey: .thaiColor) ?? defaults.thaiColor
		self.vietnameseColor = try container.decodeIfPresent(ColorComponents.self, forKey: .vietnameseColor) ?? defaults.vietnameseColor
		self.arabicColor = try container.decodeIfPresent(ColorComponents.self, forKey: .arabicColor) ?? defaults.arabicColor
		self.hebrewColor = try container.decodeIfPresent(ColorComponents.self, forKey: .hebrewColor) ?? defaults.hebrewColor
		self.hindiColor = try container.decodeIfPresent(ColorComponents.self, forKey: .hindiColor) ?? defaults.hindiColor
		self.russianColor = try container.decodeIfPresent(ColorComponents.self, forKey: .russianColor) ?? defaults.russianColor
		self.greekColor = try container.decodeIfPresent(ColorComponents.self, forKey: .greekColor) ?? defaults.greekColor
		self.mongolianColor = try container.decodeIfPresent(ColorComponents.self, forKey: .mongolianColor) ?? defaults.mongolianColor
		self.myanmarColor = try container.decodeIfPresent(ColorComponents.self, forKey: .myanmarColor) ?? defaults.myanmarColor
		self.khmerColor = try container.decodeIfPresent(ColorComponents.self, forKey: .khmerColor) ?? defaults.khmerColor
		self.laoColor = try container.decodeIfPresent(ColorComponents.self, forKey: .laoColor) ?? defaults.laoColor
		self.bengaliColor = try container.decodeIfPresent(ColorComponents.self, forKey: .bengaliColor) ?? defaults.bengaliColor
		self.tamilColor = try container.decodeIfPresent(ColorComponents.self, forKey: .tamilColor) ?? defaults.tamilColor
		self.teluguColor = try container.decodeIfPresent(ColorComponents.self, forKey: .teluguColor) ?? defaults.teluguColor
		self.nepaliColor = try container.decodeIfPresent(ColorComponents.self, forKey: .nepaliColor) ?? defaults.nepaliColor
		self.sinhalaColor = try container.decodeIfPresent(ColorComponents.self, forKey: .sinhalaColor) ?? defaults.sinhalaColor
		self.persianColor = try container.decodeIfPresent(ColorComponents.self, forKey: .persianColor) ?? defaults.persianColor
		self.ukrainianColor = try container.decodeIfPresent(ColorComponents.self, forKey: .ukrainianColor) ?? defaults.ukrainianColor
		self.otherColor = try container.decodeIfPresent(ColorComponents.self, forKey: .otherColor) ?? defaults.otherColor
	}

	// MARK: - ヘルパーメソッド

	/// 蛍光発光のパディング量（ガウスブラーが見切れない余白）
	var glowCanvasPadding: CGFloat {
		return ceil(glowRadius * 2.2) + 6
	}

	/// 指定した言語の色を取得（IMEインジケータと共有または独自色）
	func color(for language: InputLanguage, imeSettings: IMEIndicatorSettings) -> ColorComponents {
		if useSameColorAsIMEIndicator {
			return imeSettings.color(for: language)
		} else {
			switch language {
			case .english: return englishColor
			case .japanese: return japaneseColor
			case .chineseSimplified: return chineseSimplifiedColor
			case .chineseTraditional: return chineseTraditionalColor
			case .korean: return koreanColor
			case .thai: return thaiColor
			case .vietnamese: return vietnameseColor
			case .arabic: return arabicColor
			case .hebrew: return hebrewColor
			case .hindi: return hindiColor
			case .russian: return russianColor
			case .greek: return greekColor
			case .mongolian: return mongolianColor
			case .myanmar: return myanmarColor
			case .khmer: return khmerColor
			case .lao: return laoColor
			case .bengali: return bengaliColor
			case .tamil: return tamilColor
			case .telugu: return teluguColor
			case .nepali: return nepaliColor
			case .sinhala: return sinhalaColor
			case .persian: return persianColor
			case .ukrainian: return ukrainianColor
			case .other: return otherColor
			}
		}
	}

	/// 現在の設定・言語に対する内側・外側の蛍光グラデーション色を返す
	func effectiveGlowColors(
		for language: InputLanguage,
		imeSettings: IMEIndicatorSettings
	) -> (inner: ColorComponents, outer: ColorComponents) {
		switch colorMode {
		case .custom:
			let inner = customGlowInnerColor
			let outer = useGradientGlow ? customGlowOuterColor : customGlowInnerColor
			return (inner, outer)
		case .perLanguage:
			let base = color(for: language, imeSettings: imeSettings)
			if useGradientGlow {
				// 明度・彩度を高めた外周ネオンカラーを自動生成
				let outer = ColorComponents(
					red: min(1.0, base.red * 0.75 + 0.25),
					green: min(1.0, base.green * 0.85 + 0.15),
					blue: min(1.0, base.blue * 0.75 + 0.25),
					alpha: 1.0
				)
				return (base, outer)
			} else {
				return (base, base)
			}
		}
	}
}
