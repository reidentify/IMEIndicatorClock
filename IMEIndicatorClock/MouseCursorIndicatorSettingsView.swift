//
//	MouseCursorIndicatorSettingsView.swift
//	IMEIndicatorClock
//
//	Created on 2026/01/10.
//
//	マウスカーソルインジケータ（輪郭グラデーション蛍光発光／追従バッジ）設定UI
//

import SwiftUI
import AppKit

// MARK: - マウスカーソルインジケータ設定ビュー

struct MouseCursorIndicatorSettingsView: View {

	/// 設定マネージャー（リアルタイム反映）
	@ObservedObject private var appSettings = AppSettingsManager.shared

	private var cursorSettings: MouseCursorIndicatorSettings {
		appSettings.settings.mouseCursorIndicator
	}

	private let presetColumns = [
		GridItem(.adaptive(minimum: 135, maximum: 200), spacing: 10)
	]

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				// タイトルヘッダー
				HStack(spacing: 10) {
					Image(systemName: "cursorarrow.rays")
						.font(.system(size: 26))
						.foregroundStyle(
							LinearGradient(
								colors: [
									Color(red: 0.0, green: 0.95, blue: 0.45),
									Color(red: 0.05, green: 0.85, blue: 0.95)
								],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
					Text("title", tableName: "MouseCursorIndicator")
						.font(.title2)
						.fontWeight(.bold)
					Spacer()
				}
				.padding(.bottom, 2)

				// リアルタイムプレビュー（ダーク／ライト背景）
				GroupBox {
					CursorNeonGlowPreviewCard()
						.padding(6)
				} label: {
					Label {
						Text("preview", tableName: "MouseCursorIndicator")
					} icon: {
						Image(systemName: "sparkles")
					}
				}

				// 基本設定・スタイル選択
				GroupBox {
					VStack(alignment: .leading, spacing: 12) {
						Toggle(isOn: $appSettings.settings.mouseCursorIndicator.isVisible) {
							Text("show_indicator", tableName: "MouseCursorIndicator")
						}
						.onChange(of: appSettings.settings.mouseCursorIndicator.isVisible) { _, _ in
							saveSettings()
						}

						Divider()

						VStack(alignment: .leading, spacing: 6) {
							Text("style", tableName: "MouseCursorIndicator")
								.font(.subheadline)
								.foregroundColor(.secondary)

							Picker("", selection: $appSettings.settings.mouseCursorIndicator.style) {
								Text("style_cursor_glow", tableName: "MouseCursorIndicator")
									.tag(CursorIndicatorStyle.cursorGlow)
								Text("style_floating_badge", tableName: "MouseCursorIndicator")
									.tag(CursorIndicatorStyle.floatingBadge)
							}
							.pickerStyle(.segmented)
							.labelsHidden()
							.onChange(of: appSettings.settings.mouseCursorIndicator.style) { _, _ in
								saveSettings()
							}
						}

						Toggle(isOn: $appSettings.settings.mouseCursorIndicator.onlyShowWhenIMEActive) {
							Text("only_when_ime_active", tableName: "MouseCursorIndicator")
						}
						.onChange(of: appSettings.settings.mouseCursorIndicator.onlyShowWhenIMEActive) { _, _ in
							saveSettings()
						}
					}
					.padding(8)
				} label: {
					Label {
						Text("basic", tableName: "MouseCursorIndicator")
					} icon: {
						Image(systemName: "gearshape")
					}
				}

				// カラー設定（クライアント側で自由に変更可能）
				GroupBox {
					VStack(alignment: .leading, spacing: 14) {
						VStack(alignment: .leading, spacing: 6) {
							Text("color_mode", tableName: "MouseCursorIndicator")
								.font(.subheadline)
								.foregroundColor(.secondary)

							Picker("", selection: $appSettings.settings.mouseCursorIndicator.colorMode) {
								Text("color_mode_custom", tableName: "MouseCursorIndicator")
									.tag(CursorGlowColorMode.custom)
								Text("color_mode_per_language", tableName: "MouseCursorIndicator")
									.tag(CursorGlowColorMode.perLanguage)
							}
							.pickerStyle(.segmented)
							.labelsHidden()
							.onChange(of: appSettings.settings.mouseCursorIndicator.colorMode) { _, _ in
								saveSettings()
							}
						}

						Divider()

						if cursorSettings.colorMode == .custom {
							customNeonColorSection
						} else {
							perLanguageColorSection
						}
					}
					.padding(8)
				} label: {
					Label {
						Text("color_settings", tableName: "MouseCursorIndicator")
					} icon: {
						Image(systemName: "paintpalette")
					}
				}

				// 発光サイズ・強度 または バッジサイズ・位置設定
				if cursorSettings.style == .cursorGlow {
					glowSpreadAndIntensityBox
				} else {
					floatingBadgeGeometryBox
				}

				// リセットボタン
				HStack {
					Button {
						resetSettings()
					} label: {
						Text("reset", tableName: "MouseCursorIndicator")
					}
					.buttonStyle(.bordered)
					Spacer()
				}
				.padding(.top, 4)
			}
			.padding(24)
			.frame(maxWidth: 760, alignment: .leading)
			.frame(maxWidth: .infinity, alignment: .center)
		}
	}

	// MARK: - カスタム蛍光カラー設定セクション

	private var customNeonColorSection: some View {
		VStack(alignment: .leading, spacing: 14) {
			// ネオンプリセット一覧
			VStack(alignment: .leading, spacing: 8) {
				Text("presets", tableName: "MouseCursorIndicator")
					.font(.subheadline)
					.foregroundColor(.secondary)

				LazyVGrid(columns: presetColumns, alignment: .leading, spacing: 8) {
					ForEach(NeonGlowPreset.presets) { preset in
						Button {
							applyPreset(preset)
						} label: {
							HStack(spacing: 8) {
								Circle()
									.fill(
										LinearGradient(
											colors: [preset.inner.color, preset.outer.color],
											startPoint: .topLeading,
											endPoint: .bottomTrailing
										)
									)
									.frame(width: 14, height: 14)
									.overlay(
										Circle()
											.stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
									)
								Text(LocalizedStringKey(preset.localizationKey), tableName: "MouseCursorIndicator")
									.font(.caption)
									.lineLimit(1)
								Spacer(minLength: 0)
							}
							.padding(.horizontal, 10)
							.padding(.vertical, 6)
							.background(
								RoundedRectangle(cornerRadius: 7)
									.fill(isPresetSelected(preset) ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
							)
							.overlay(
								RoundedRectangle(cornerRadius: 7)
									.stroke(isPresetSelected(preset) ? Color.accentColor : Color.clear, lineWidth: 1)
							)
						}
						.buttonStyle(.plain)
					}
				}
			}

			Divider()

			// 内側蛍光カラーピッカー
			HStack {
				Text("inner_glow_color", tableName: "MouseCursorIndicator")
				Spacer()
				ColorPicker(
					"",
					selection: colorBinding(\.customGlowInnerColor),
					supportsOpacity: false
				)
				.labelsHidden()
			}

			// グラデーションON/OFF
			Toggle(isOn: $appSettings.settings.mouseCursorIndicator.useGradientGlow) {
				Text("use_gradient_glow", tableName: "MouseCursorIndicator")
			}
			.onChange(of: appSettings.settings.mouseCursorIndicator.useGradientGlow) { _, _ in
				saveSettings()
			}

			// 外側グラデーションカラーピッカー
			if cursorSettings.useGradientGlow {
				HStack {
					Text("outer_glow_color", tableName: "MouseCursorIndicator")
					Spacer()
					ColorPicker(
						"",
						selection: colorBinding(\.customGlowOuterColor),
						supportsOpacity: false
					)
					.labelsHidden()
				}
			}
		}
	}

	// MARK: - 入力言語別カラー設定セクション

	private var perLanguageColorSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Toggle(isOn: $appSettings.settings.mouseCursorIndicator.useSameColorAsIMEIndicator) {
				Text("use_same_color", tableName: "MouseCursorIndicator")
			}
			.onChange(of: appSettings.settings.mouseCursorIndicator.useSameColorAsIMEIndicator) { _, _ in
				saveSettings()
			}

			Toggle(isOn: $appSettings.settings.mouseCursorIndicator.useGradientGlow) {
				Text("use_gradient_glow", tableName: "MouseCursorIndicator")
			}
			.onChange(of: appSettings.settings.mouseCursorIndicator.useGradientGlow) { _, _ in
				saveSettings()
			}

			if cursorSettings.useSameColorAsIMEIndicator {
				Text("custom_color_hint", tableName: "MouseCursorIndicator")
					.font(.caption)
					.foregroundColor(.secondary)
			} else {
				Divider()
				Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
					GridRow {
						languageColorCell(titleKey: "lang_zh_hans", keyPath: \.chineseSimplifiedColor)
						languageColorCell(titleKey: "lang_english", keyPath: \.englishColor)
					}
					GridRow {
						languageColorCell(titleKey: "lang_zh_hant", keyPath: \.chineseTraditionalColor)
						languageColorCell(titleKey: "lang_ja", keyPath: \.japaneseColor)
					}
					GridRow {
						languageColorCell(titleKey: "lang_ko", keyPath: \.koreanColor)
						languageColorCell(titleKey: "lang_other", keyPath: \.otherColor)
					}
				}
			}
		}
	}

	private func languageColorCell(
		titleKey: String,
		keyPath: WritableKeyPath<MouseCursorIndicatorSettings, ColorComponents>
	) -> some View {
		HStack {
			Text(LocalizedStringKey(titleKey), tableName: "MouseCursorIndicator")
				.font(.callout)
			Spacer()
			ColorPicker("", selection: colorBinding(keyPath), supportsOpacity: false)
				.labelsHidden()
		}
	}

	// MARK: - 蛍光エッジ広がり・強度セクション

	private var glowSpreadAndIntensityBox: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 14) {
				VStack(alignment: .leading, spacing: 8) {
					HStack {
						Text("glow_radius", tableName: "MouseCursorIndicator")
						Spacer()
						Text("\(Int(cursorSettings.glowRadius)) px")
							.monospacedDigit()
							.foregroundColor(.secondary)
					}

					Slider(value: $appSettings.settings.mouseCursorIndicator.glowRadius, in: 4...22, step: 1)
						.onChange(of: appSettings.settings.mouseCursorIndicator.glowRadius) { _, _ in
							saveSettings()
						}

					HStack(spacing: 8) {
						Button {
							appSettings.settings.mouseCursorIndicator.glowRadius = 6
							saveSettings()
						} label: {
							Text("size_small", tableName: "MouseCursorIndicator")
						}
						.buttonStyle(.bordered)

						Button {
							appSettings.settings.mouseCursorIndicator.glowRadius = 10
							saveSettings()
						} label: {
							Text("size_medium", tableName: "MouseCursorIndicator")
						}
						.buttonStyle(.bordered)

						Button {
							appSettings.settings.mouseCursorIndicator.glowRadius = 16
							saveSettings()
						} label: {
							Text("size_large", tableName: "MouseCursorIndicator")
						}
						.buttonStyle(.bordered)
					}
					.font(.caption)
				}

				Divider()

				HStack {
					Text("glow_intensity", tableName: "MouseCursorIndicator")
					Spacer()
					Slider(value: $appSettings.settings.mouseCursorIndicator.opacity, in: 0.2...1.0, step: 0.05)
						.frame(width: 180)
						.onChange(of: appSettings.settings.mouseCursorIndicator.opacity) { _, _ in
							saveSettings()
						}
					Text("\(Int(cursorSettings.opacity * 100))%")
						.frame(width: 48, alignment: .trailing)
						.monospacedDigit()
						.foregroundColor(.secondary)
				}
			}
			.padding(8)
		} label: {
			Label {
				Text("glow_effect_settings", tableName: "MouseCursorIndicator")
			} icon: {
				Image(systemName: "sun.max")
			}
		}
	}

	// MARK: - 従来バッジのサイズ・オフセット設定セクション

	private var floatingBadgeGeometryBox: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 16) {
				VStack(alignment: .leading, spacing: 8) {
					HStack {
						Text("size", tableName: "MouseCursorIndicator")
						Spacer()
						Text("\(Int(cursorSettings.size)) px")
							.monospacedDigit()
							.foregroundColor(.secondary)
					}

					Slider(value: $appSettings.settings.mouseCursorIndicator.size, in: 12...32, step: 1)
						.onChange(of: appSettings.settings.mouseCursorIndicator.size) { _, _ in
							saveSettings()
						}

					HStack(spacing: 8) {
						Button {
							appSettings.settings.mouseCursorIndicator.size = 16
							saveSettings()
						} label: {
							Text("size_small", tableName: "MouseCursorIndicator")
						}
						.buttonStyle(.bordered)
						Button {
							appSettings.settings.mouseCursorIndicator.size = 20
							saveSettings()
						} label: {
							Text("size_medium", tableName: "MouseCursorIndicator")
						}
						.buttonStyle(.bordered)
						Button {
							appSettings.settings.mouseCursorIndicator.size = 28
							saveSettings()
						} label: {
							Text("size_large", tableName: "MouseCursorIndicator")
						}
						.buttonStyle(.bordered)
					}
					.font(.caption)
				}

				Divider()

				VStack(alignment: .leading, spacing: 8) {
					Text("offset", tableName: "MouseCursorIndicator")
						.font(.subheadline)
						.foregroundColor(.secondary)

					HStack(spacing: 20) {
						HStack {
							Text("X:")
								.frame(width: 20)
							Slider(value: $appSettings.settings.mouseCursorIndicator.offsetX, in: -30...30, step: 1)
								.frame(width: 110)
								.onChange(of: appSettings.settings.mouseCursorIndicator.offsetX) { _, _ in
									saveSettings()
								}
							Text(String(format: "%+.0f", cursorSettings.offsetX))
								.frame(width: 35)
								.monospacedDigit()
								.foregroundColor(.secondary)
						}

						HStack {
							Text("Y:")
								.frame(width: 20)
							Slider(value: $appSettings.settings.mouseCursorIndicator.offsetY, in: -30...30, step: 1)
								.frame(width: 110)
								.onChange(of: appSettings.settings.mouseCursorIndicator.offsetY) { _, _ in
									saveSettings()
								}
							Text(String(format: "%+.0f", cursorSettings.offsetY))
								.frame(width: 35)
								.monospacedDigit()
								.foregroundColor(.secondary)
						}
					}
				}

				Divider()

				HStack {
					Text("opacity", tableName: "MouseCursorIndicator")
					Spacer()
					Slider(value: $appSettings.settings.mouseCursorIndicator.opacity, in: 0.1...1.0, step: 0.05)
						.frame(width: 160)
						.onChange(of: appSettings.settings.mouseCursorIndicator.opacity) { _, _ in
							saveSettings()
						}
					Text("\(Int(cursorSettings.opacity * 100))%")
						.frame(width: 45, alignment: .trailing)
						.monospacedDigit()
						.foregroundColor(.secondary)
				}
			}
			.padding(8)
		} label: {
			Label {
				Text("size_position", tableName: "MouseCursorIndicator")
			} icon: {
				Image(systemName: "arrow.up.left.and.arrow.down.right")
			}
		}
	}

	// MARK: - ヘルパー

	private func colorBinding(
		_ keyPath: WritableKeyPath<MouseCursorIndicatorSettings, ColorComponents>
	) -> Binding<Color> {
		Binding<Color>(
			get: {
				appSettings.settings.mouseCursorIndicator[keyPath: keyPath].color
			},
			set: { newColor in
				appSettings.settings.mouseCursorIndicator[keyPath: keyPath] = makeColorComponents(from: newColor)
				saveSettings()
			}
		)
	}

	private func makeColorComponents(from swiftUIColor: Color) -> ColorComponents {
		let ns = NSColor(swiftUIColor)
		if let srgb = ns.usingColorSpace(.sRGB) {
			return ColorComponents(
				red: Double(srgb.redComponent),
				green: Double(srgb.greenComponent),
				blue: Double(srgb.blueComponent),
				alpha: 1.0
			)
		}
		return ColorComponents(nsColor: ns)
	}

	private func applyPreset(_ preset: NeonGlowPreset) {
		appSettings.settings.mouseCursorIndicator.customGlowInnerColor = preset.inner
		appSettings.settings.mouseCursorIndicator.customGlowOuterColor = preset.outer
		appSettings.settings.mouseCursorIndicator.useGradientGlow = true
		saveSettings()
	}

	private func isPresetSelected(_ preset: NeonGlowPreset) -> Bool {
		let inner = cursorSettings.customGlowInnerColor
		let outer = cursorSettings.customGlowOuterColor
		return abs(inner.red - preset.inner.red) < 0.02 &&
			   abs(inner.green - preset.inner.green) < 0.02 &&
			   abs(inner.blue - preset.inner.blue) < 0.02 &&
			   abs(outer.red - preset.outer.red) < 0.02 &&
			   abs(outer.green - preset.outer.green) < 0.02 &&
			   abs(outer.blue - preset.outer.blue) < 0.02 &&
			   cursorSettings.useGradientGlow
	}

	private func saveSettings() {
		appSettings.save()
		NotificationCenter.default.post(
			name: .mouseCursorIndicatorSettingsChanged,
			object: nil
		)
	}

	private func resetSettings() {
		appSettings.settings.mouseCursorIndicator = MouseCursorIndicatorSettings()
		saveSettings()
	}
}

// MARK: - プレビュー

private struct MouseCursorIndicatorSettingsPreview: View {
	@State private var selectedLocale = "zh-Hans"

	private let locales: [(id: String, name: String)] = [
		("zh-Hans", "简体中文"),
		("zh-Hant", "繁體中文"),
		("en", "English"),
		("ja", "日本語"),
		("ko", "한국어")
	]

	var body: some View {
		VStack(spacing: 0) {
			Picker("Locale", selection: $selectedLocale) {
				ForEach(locales, id: \.id) { locale in
					Text(locale.name).tag(locale.id)
				}
			}
			.pickerStyle(.segmented)
			.padding(8)

			MouseCursorIndicatorSettingsView()
				.environment(\.locale, Locale(identifier: selectedLocale))
		}
	}
}

#Preview("Mouse Cursor Indicator Settings") {
	MouseCursorIndicatorSettingsPreview()
		.frame(width: 820, height: 700)
}
