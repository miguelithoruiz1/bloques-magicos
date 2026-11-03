extends Node
## RefactorController — controlador principal de la variante refactorizada.
##
## Responsabilidad única: que el botón Atrás / Volver NUNCA cierre la
## app por accidente. En Godot 4, si nadie desactiva el cierre
## automático, Android / Google TV cierra la aplicación al pulsar
## Atrás. En 1.15.0 ningún script llamaba a set_auto_accept_quit()
## (ver AUDITORIA-1.15.0.md): settings.gd y menu.gd solo reaccionaban
## a ui_cancel volviendo a la Plaza, y main.gd no gestionaba
## ui_cancel en absoluto, así que en un mundo el Atrás podía cerrar
## el juego y perder la sesión.
##
## Pila de menús (de dentro hacia fuera):
##   1. Si hay un panel modal abierto (Ajustes, Inventario, Pausa),
##      Atrás lo cierra y devuelve el foco al juego. NADA MÁS.
##   2. Si no hay panel y estamos en un mundo en pausa, Atrás
##      vuelve a la Plaza (hub.tscn). NUNCA quit().
##   3. Si estamos en la pantalla de título, Atrás abre el diálogo
##      modal de salida. Solo el botón «Salir» de ESE diálogo llama
##      a get_tree().quit().
##
## Uso: añadir como hijo de la escena refactor_main. Registrar cada
## panel con register_panel(panel). El panel debe ser un Control
## cuya visibilidad controla si está abierto.

signal back_pressed_handled(action: String)

var _panel_stack: Array[Control] = []
var _in_world := false
var _exit_dialog: AcceptDialog = null


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# 4.0.1: refactor_main es el único que decide qué
		# hace Atrás (ver handle_system_back). Este controlador
		# solo reenvía la notificación del sistema; ya no
		# tiene su propia lógica de ui_cancel, porque eso
		# duplicaba el manejo y rompía el menú.
		var parent := get_parent()
		if parent != null and parent.has_method("handle_system_back"):
			parent.handle_system_back()
		else:
			_handle_back()
		# Consumir la notificación: no llamar a quit() aquí jamás.
		get_viewport().set_input_as_handled()


func show_exit_dialog() -> void:
	_show_exit_dialog()


## Marca si la escena actual es un mundo (true) o título (false).
func set_in_world(value: bool) -> void:
	_in_world = value


func register_panel(panel: Control) -> void:
	if panel != null and not _panel_stack.has(panel):
		_panel_stack.append(panel)


func unregister_panel(panel: Control) -> void:
	_panel_stack.erase(panel)


func top_open_panel() -> Control:
	for i in range(_panel_stack.size() - 1, -1, -1):
		var panel: Control = _panel_stack[i]
		if panel != null and panel.visible:
			return panel
	return null


func _handle_back() -> void:
	# Respaldo solo si la escena principal no tiene
	# handle_system_back (no debería pasar en 4.0.1).
	# Corregido: cerrar un panel por su señal closed cuando
	# la tiene (Ajustes se libera y recarga), no solo
	# ocultarlo; y sin panel en mundo, abrir la pausa, no
	# saltar a hub.tscn legacy ni salir de la app.
	var panel := top_open_panel()
	if panel != null:
		if panel.has_signal("closed"):
			panel.emit_signal("closed")
		else:
			panel.visible = false
		back_pressed_handled.emit("close_panel")
		return
	if _in_world:
		back_pressed_handled.emit("open_pause")
		return
	_show_exit_dialog()


func _show_exit_dialog() -> void:
	if _exit_dialog == null:
		_exit_dialog = AcceptDialog.new()
		_exit_dialog.title = "¿Salir de Bloques Mágicos?"
		_exit_dialog.dialog_text = "¿Quieres salir del juego?"
		_exit_dialog.add_button("Salir", true, "quit")
		_exit_dialog.add_button("Seguir jugando", false, "stay")
		_exit_dialog.custom_action.connect(_on_exit_dialog_action)
		add_child(_exit_dialog)
	_exit_dialog.popup_centered()


func _on_exit_dialog_action(action: StringName) -> void:
	if action == "quit":
		get_tree().quit()
