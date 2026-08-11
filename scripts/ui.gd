extends CanvasLayer


@onready var branch_tab_button: Button = (
	$UpgradeTabs/BranchTabButton
)

@onready var tree_tab_button: Button = (
	$UpgradeTabs/TreeTabButton
)

@onready var soul_tab_button: Button = (
	$UpgradeTabs/SoulTabButton
)

@onready var talents_button: Button = (
	$TalentsButton
)

@onready var tree_screen_button: Button = (
	$TreeScreenButton
)

@onready var branch_upgrade_panel: Panel = (
	$BranchUpgradePanel
)

@onready var tree_upgrade_panel: Panel = (
	$TreeUpgradePanel
)

@onready var tree_soul_status_panel: Panel = (
	$TreeSoulStatusPanel
)

@onready var talent_screen: Control = (
	$TalentScreen
)

@onready var tree_screen: Control = (
	$TreeScreen
)

var wave_manager: Node


func _ready() -> void:
	branch_tab_button.pressed.connect(
		show_branch_upgrades
	)

	tree_tab_button.pressed.connect(
		show_tree_upgrades
	)

	soul_tab_button.pressed.connect(
		show_soul_status
	)

	talents_button.pressed.connect(
		open_talent_screen
	)

	tree_screen_button.pressed.connect(
		open_tree_screen
	)

	show_branch_upgrades()

	wave_manager = get_node_or_null("../WaveManager")
	if (
		is_instance_valid(wave_manager)
		and wave_manager.has_signal("preparation_state_changed")
		and not wave_manager.preparation_state_changed.is_connected(
			_on_preparation_state_changed
		)
	):
		wave_manager.preparation_state_changed.connect(
			_on_preparation_state_changed
		)
	call_deferred("_sync_preparation_state")


func show_branch_upgrades() -> void:
	branch_upgrade_panel.visible = true
	tree_upgrade_panel.visible = false
	tree_soul_status_panel.visible = false

	branch_tab_button.disabled = true
	tree_tab_button.disabled = false
	soul_tab_button.disabled = false


func show_tree_upgrades() -> void:
	branch_upgrade_panel.visible = false
	tree_upgrade_panel.visible = true
	tree_soul_status_panel.visible = false

	branch_tab_button.disabled = false
	tree_tab_button.disabled = true
	soul_tab_button.disabled = false


func show_soul_status() -> void:
	branch_upgrade_panel.visible = false
	tree_upgrade_panel.visible = false
	tree_soul_status_panel.visible = true

	branch_tab_button.disabled = false
	tree_tab_button.disabled = false
	soul_tab_button.disabled = true


func open_talent_screen() -> void:
	if (
		is_instance_valid(wave_manager)
		and wave_manager.has_method("is_preparation_active")
		and wave_manager.is_preparation_active()
	):
		return
	if tree_screen.has_method("close_screen"):
		tree_screen.close_screen()
	if talent_screen.has_method(
		"open_screen"
	):
		talent_screen.open_screen()


func open_tree_screen() -> void:
	if talent_screen.has_method("close_screen"):
		talent_screen.close_screen()
	if tree_screen.has_method("open_screen"):
		tree_screen.open_screen()


func _sync_preparation_state() -> void:
	if not is_instance_valid(wave_manager):
		wave_manager = get_node_or_null("../WaveManager")
	if not is_instance_valid(wave_manager):
		return
	_on_preparation_state_changed(
		wave_manager.is_preparation_active(),
		wave_manager.get_preparation_reason()
	)


func _on_preparation_state_changed(
	is_active: bool,
	reason: StringName
) -> void:
	if is_active:
		if talent_screen.has_method("close_screen"):
			talent_screen.close_screen()
		if tree_screen.has_method("set_preparation_mode"):
			tree_screen.set_preparation_mode(true, reason)
		if tree_screen.has_method("open_screen"):
			tree_screen.open_screen()
		return

	if tree_screen.has_method("set_preparation_mode"):
		tree_screen.set_preparation_mode(false, &"")
	if tree_screen.has_method("close_screen"):
		tree_screen.close_screen()
