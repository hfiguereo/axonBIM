# © 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Object

## Paleta y ``StyleBoxFlat`` tipo escritorio BIM (inspiración: boceto Revit-like
## archivado; ver ``docs/ui/UI-inspiration-notes.md``).
##
## No construye nodos: solo aplica overrides de tema a la escena principal
## ya definida en ``main.tscn`` para mantener una sola fuente de verdad del
## layout y cablear lógica en ``main_scene.gd``.

const COLOR_BG_MAIN := Color(0.96, 0.96, 0.96)
const COLOR_BG_PANELS := Color(1.0, 1.0, 1.0)
const COLOR_BG_VIEWPORT := Color(0.90, 0.90, 0.92)
const COLOR_BORDER := Color(0.85, 0.85, 0.85)
const COLOR_BTN_NORMAL := Color(0.96, 0.96, 0.96)
const COLOR_BTN_HOVER := Color(0.90, 0.94, 0.98)
const COLOR_BTN_PRESSED := Color(0.80, 0.88, 0.95)
const COLOR_TEXT := Color(0.1, 0.1, 0.1)
const COLOR_CAPTION := Color(0.4, 0.4, 0.4)
const COLOR_TAB_UNSELECTED_BG := Color(0.9, 0.9, 0.9)


static func _flat(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border
	return s


static func _panel_chrome() -> StyleBoxFlat:
	return _flat(COLOR_BG_PANELS, COLOR_BORDER, 1)


static func _style_ribbon_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(COLOR_BTN_NORMAL))
	btn.add_theme_stylebox_override("hover", _flat(COLOR_BTN_HOVER, Color(0.6, 0.8, 0.9), 1))
	btn.add_theme_stylebox_override("pressed", _flat(COLOR_BTN_PRESSED, Color(0.4, 0.6, 0.8), 1))
	btn.add_theme_stylebox_override("focus", _flat(COLOR_BTN_NORMAL, Color(0.4, 0.6, 0.8), 1))
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT)
	btn.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	btn.add_theme_color_override("font_focus_color", COLOR_TEXT)


static func _style_nav_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.82), COLOR_BORDER, 1))
	btn.add_theme_stylebox_override("hover", _flat(COLOR_BTN_HOVER, Color(0.6, 0.8, 0.9), 1))
	btn.add_theme_stylebox_override("pressed", _flat(COLOR_BTN_PRESSED, Color(0.4, 0.6, 0.8), 1))
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", 11)
	btn.custom_minimum_size = Vector2(54, 28)


## Aplica paleta y estilos a nodos bajo ``Main`` (rutas relativas a ``main``).
static func apply_from_main(main: Node) -> void:
	var tab_bar: TabBar = main.get_node_or_null("UI/Root/Ribbon/RibbonTabs") as TabBar
	if tab_bar != null:
		tab_bar.add_theme_stylebox_override("tab_selected", _flat(COLOR_BG_MAIN, COLOR_BORDER, 1))
		tab_bar.add_theme_stylebox_override("tab_unselected", _flat(COLOR_TAB_UNSELECTED_BG, COLOR_BORDER, 1))
		tab_bar.add_theme_stylebox_override("tab_hover", _flat(COLOR_BTN_HOVER, COLOR_BORDER, 1))
		tab_bar.add_theme_color_override("font_selected_color", COLOR_TEXT)
		tab_bar.add_theme_color_override("font_unselected_color", COLOR_CAPTION)
		tab_bar.add_theme_color_override("font_hover_color", COLOR_TEXT)

	for path: String in [
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelSistema",
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelModelado",
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelArchivo",
		"UI/Root/Workspace/MainSplit/LeftDock/LeftDockHeader",
		"UI/Root/Workspace/MainSplit/InnerSplit/RightDock/RightDockHeader",
		"UI/Root/StatusBar",
		"UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/ViewNavOverlay/Panel",
	]:
		var pc: PanelContainer = main.get_node_or_null(path) as PanelContainer
		if pc != null:
			pc.add_theme_stylebox_override("panel", _panel_chrome())

	for label_path: String in [
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelSistema/VBoxSistema/LblSistema",
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelModelado/VBoxModelado/LblModelado",
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelArchivo/VBoxArchivo/LblArchivo",
	]:
		var cap: Label = main.get_node_or_null(label_path) as Label
		if cap != null:
			cap.add_theme_color_override("font_color", COLOR_CAPTION)

	var tree: Tree = main.get_node_or_null("UI/Root/Workspace/MainSplit/LeftDock/ProjectTree") as Tree
	if tree != null:
		tree.add_theme_stylebox_override("panel", _flat(COLOR_BG_PANELS))
		tree.add_theme_color_override("font_color", COLOR_TEXT)
		tree.add_theme_color_override("guide_color", COLOR_BORDER)

	var title: Label = main.get_node_or_null("UI/Root/Ribbon/TitleBar/AppTitle") as Label
	if title != null:
		title.add_theme_color_override("font_color", COLOR_TEXT)

	var status: Label = main.get_node_or_null("UI/Root/Ribbon/TitleBar/StatusLabel") as Label
	if status != null:
		status.add_theme_color_override("font_color", COLOR_CAPTION)

	for btn_path: String in [
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelSistema/VBoxSistema/PingButton",
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelModelado/VBoxModelado/CreateWallButton",
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelModelado/VBoxModelado/PushPullButton",
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelArchivo/VBoxArchivo/SaveButton",
	]:
		var btn: Button = main.get_node_or_null(btn_path) as Button
		if btn != null:
			_style_ribbon_button(btn)

	var we: WorldEnvironment = (
		main.get_node_or_null(
			"UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/SubViewport/World/WorldEnvironment"
		) as WorldEnvironment
	)
	if we != null and we.environment != null:
		we.environment.background_color = COLOR_BG_VIEWPORT

	for prop_label_path: String in [
		"UI/Root/Workspace/MainSplit/InnerSplit/RightDock/PropsScroll/PropsVBox/PropGuidLabel",
		"UI/Root/Workspace/MainSplit/InnerSplit/RightDock/PropsScroll/PropsVBox/PropTypeLabel",
		"UI/Root/Workspace/MainSplit/InnerSplit/RightDock/PropsScroll/PropsVBox/PropDimsLabel",
	]:
		var pl: Label = main.get_node_or_null(prop_label_path) as Label
		if pl != null:
			pl.add_theme_color_override("font_color", COLOR_TEXT)

	var dock_titles: Array[String] = [
		"UI/Root/Workspace/MainSplit/LeftDock/LeftDockHeader/LeftDockTitle",
		"UI/Root/Workspace/MainSplit/InnerSplit/RightDock/RightDockHeader/RightDockTitle",
	]
	for p: String in dock_titles:
		var dl: Label = main.get_node_or_null(p) as Label
		if dl != null:
			dl.add_theme_color_override("font_color", COLOR_TEXT)

	var log_l: Label = main.get_node_or_null("UI/Root/StatusBar/LogLabel") as Label
	if log_l != null:
		log_l.add_theme_color_override("font_color", COLOR_CAPTION)

	var ph: Label = main.get_node_or_null(
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsPlaceholder/PlaceholderLabel"
	) as Label
	if ph != null:
		ph.add_theme_color_override("font_color", COLOR_CAPTION)

	var rtt: Label = main.get_node_or_null(
		"UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelSistema/VBoxSistema/RttLabel"
	) as Label
	if rtt != null:
		rtt.add_theme_color_override("font_color", COLOR_CAPTION)

	var nav_title: Label = main.get_node_or_null(
		"UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/ViewNavOverlay/Panel/NavVBox/NavTitle"
	) as Label
	if nav_title != null:
		nav_title.add_theme_color_override("font_color", COLOR_CAPTION)
		nav_title.add_theme_font_size_override("font_size", 11)

	for nav_btn_path: String in [
		"UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/ViewNavOverlay/Panel/NavVBox/NavGrid/ViewTopButton",
		"UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/ViewNavOverlay/Panel/NavVBox/NavGrid/ViewFrontButton",
		"UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/ViewNavOverlay/Panel/NavVBox/NavGrid/ViewRightButton",
		"UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/ViewNavOverlay/Panel/NavVBox/NavGrid/ViewPerspButton",
		"UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/ViewNavOverlay/Panel/NavVBox/ViewResetButton",
	]:
		var nbtn: Button = main.get_node_or_null(nav_btn_path) as Button
		if nbtn != null:
			_style_nav_button(nbtn)
