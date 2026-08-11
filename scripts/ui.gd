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
