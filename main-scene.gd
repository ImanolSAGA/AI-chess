extends Node2D

var bb= preload("res://piezas/bb.png")
var bh= preload("res://piezas/bh.png")
var bk= preload("res://piezas/bk.png")
var bp= preload("res://piezas/bp.png")
var bq= preload("res://piezas/bq.png")
var bt= preload("res://piezas/bt.png")

var wb= preload("res://piezas/wb.png")
var wh= preload("res://piezas/wh.png")
var wk= preload("res://piezas/wk.png")
var wp= preload("res://piezas/wp.png")
var wq= preload("res://piezas/wq.png")
var wt= preload("res://piezas/wt.png")

var lt= "abcdefgh"

var casillas= { }

var thinking

var dragging= false
var last_casilla

var selecting= false
var selectingType
var selectingTexture

var time

#multithread data
var thread_running
var mutex
var mt_results= []
var thread= []
var mt_moves
var mt_maxcores
var mt_movesCount

func _ready():
	
	thread_running= false
	mutex= Mutex.new()
	mt_maxcores= OS.get_processor_count() - 1
	
	_on_TextureButton_pressed()
	
func _process(delta):
	
	if thread_running:
		if mt_results.size() >= mt_moves.size(): 
			
			$AudioStreamPlayer.play()
			var rmax= -1.001
			var move= "none"
				
			var negras= $TextureButton.pressed
			if negras: #busca el maximo
				rmax= -1.001
				for r in mt_results.size():
					if mt_results[r]["eval"] > rmax:
						move= mt_results[r]["move"]
						rmax= mt_results[r]["eval"]
			else: #busca el minimo
				rmax= 101.001
				for r in mt_results.size():
					if mt_results[r]["eval"] < rmax:
						move= mt_results[r]["move"]
						rmax= mt_results[r]["eval"]
					
			print("move= " + move)
			print("eval= " + str(rmax))
			
			_mueve_visuales(move)
			
			casillas= _prepara_tablero(casillas, move)
			_comprueba_fichas(casillas)
			
			$move.pressed= false
			thread_running= false
			for t in thread.size():
				thread[t].wait_to_finish()
		else:
			if mt_moves.size() > 0:
				if mt_movesCount < mt_moves.size():
					if mt_results.size() + mt_maxcores > thread.size():
						
						if $TextureButton.pressed: #negras= true
							mt_moves= _escenarios_negras(casillas, true)
						
							var new_table= _prepara_tablero(casillas, mt_moves[mt_movesCount])
							
							var rmax= -1.001
							for r in mt_results.size():
								if mt_results[r]["eval"] > rmax:
									rmax= mt_results[r]["eval"]
					
							new_table["negras"]= false
							new_table["move"]= mt_moves[mt_movesCount]
							new_table["alpha"]= rmax
							thread.append(Thread.new())
							thread[mt_movesCount].start(self, "_multiT_minimax", new_table)
							mt_movesCount+= 1
								
						else: #negras= false
							mt_moves= _escenarios_blancas(casillas, true)
							
							var new_table= _prepara_tablero(casillas, mt_moves[mt_movesCount])
							
							var rmax= 101.001
							for r in mt_results.size():
								if mt_results[r]["eval"] < rmax:
									rmax= mt_results[r]["eval"]
							
							new_table["negras"]= true
							new_table["move"]= mt_moves[mt_movesCount]
							new_table["beta"]= rmax
							thread.append(Thread.new())
							thread[mt_movesCount].start(self, "_multiT_minimax", new_table)
							mt_movesCount+= 1
				
			time+= delta
			var s = fmod(time,60)
			var m = fmod(time, 3600) / 60
			
			$time/Label.text= "t: %02d:%02d" % [m, s]
			$mensaje/Label.text= "p: " + str(thinking)
	
	if dragging:
		var mousepos = get_viewport().get_mouse_position()
		for ch in self.get_children():
			if ch.name == "moving":
				ch.position= Vector2(mousepos.x, mousepos.y)
				break
	elif selecting:
		if selectingType != null:
			var mousepos = get_viewport().get_mouse_position()
			for ch in self.get_children():
				if ch.name == "moving":
					ch.position= Vector2(mousepos.x, mousepos.y)
					break

func _start_white():
	get_node("table").rotation_degrees= 0
	get_node("table").position= Vector2(0, 0)
	$ProgressBar.rect_rotation= 90
	
	casillas.clear()
	casillas= {}
	
	for a in 8:
		for b in 8:
			var cell= "Control/" + lt[a] + str(b+1)
			var x= (a * 31)
			var y= 217 - (b * 31)
			get_node(cell).rect_position= Vector2(x, y)
			get_node(cell).color= Color(0, 0, 0, 0)
			
			if get_node(cell).get_child_count() > 0:
				for obj in get_node(cell).get_children():
					obj.queue_free()
	
	_pon_piezas()
	
func _start_black():
	get_node("table").rotation_degrees= 180
	get_node("table").position= Vector2(248, 248)
	$ProgressBar.rect_rotation= 270
	
	casillas.clear()
	casillas= {}
	
	for a in 8:
		for b in 8:
			var cell= "Control/" + lt[a] + str(b+1)
			var x= 217 - (a * 31)
			var y= (b * 31)
			get_node(cell).rect_position= Vector2(x, y)
			get_node(cell).color= Color(0, 0, 0, 0)
			
			if get_node(cell).get_child_count() > 0:
				for obj in get_node(cell).get_children():
					obj.queue_free()
	
	_pon_piezas()

func _on_TextureButton_pressed():
	if $TextureButton.pressed == false:
		_start_white()
	else:
		_start_black()
#	var p= {}
#	$key.text= _getkey(casillas, p)
#	$piezas.text= str(p["p"])
	$ProgressBar.value= _eval(casillas)
	$time/Label.text= "Quiet..."
	$mensaje/Label.text= "Quiet..."

func _input(event):
	if event is InputEventKey: 
		if event.scancode == KEY_SPACE:
			$move.pressed= true
			_on_move_pressed()
			
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed and !selecting:
			var mousepos = get_viewport().get_mouse_position()
			var cell= _casilla(mousepos.x, mousepos.y)
			if cell != null and casillas.has(cell):
				for i in 8:
					for i2 in 8:
						get_node("Control/" + lt[i] + str(i2 + 1)).color= Color(0, 0, 0, 0)
						
				var texture= _casilla_pieza_textura(casillas[cell])
				if texture != null:
					last_casilla= cell
					get_node("Control/" + last_casilla).color= Color(1, 0, 0, 0.5)
					dragging= true
					var s= Sprite.new()
					s.set_texture(texture)
					s.name= "moving"
					s.position= Vector2(mousepos.x, mousepos.y)
					self.add_child(s, true)
					for ch in get_node("Control/" + last_casilla).get_children():
						ch.queue_free()
						break
				else:
					last_casilla= null
			else:
				last_casilla= null
			
		elif event.button_index == BUTTON_LEFT and !event.pressed and !selecting:
			if dragging:
				dragging= false
				var mousepos = get_viewport().get_mouse_position()
				var cell= _casilla(mousepos.x, mousepos.y)
				if cell == null:
					casillas.erase(last_casilla)
					for ch in get_node("Control/" + last_casilla).get_children():
						ch.queue_free()
#					var p= {}
#					$key.text= _getkey(casillas, p)
#					$piezas.text= str(p["p"])
					$ProgressBar.value= _eval(casillas)
				elif cell != last_casilla:
					var texture= _casilla_pieza_textura(casillas[last_casilla])
					var s= Sprite.new()
					s.set_texture(texture)
					s.centered= false
					
					var move= last_casilla + "-" + cell
					if last_casilla[1] == "2":
						if cell[1] == "4":
							if casillas[last_casilla] == "wp":
								move= last_casilla + "-S-" + cell
					elif last_casilla[1] == "7":
						if cell[1] == "5":
							if casillas[last_casilla] == "bp":
								move= last_casilla + "-S-" + cell
					casillas= _prepara_tablero(casillas, move)
					
					for ch in get_node("Control/" + cell).get_children():
						ch.queue_free()
					get_node("Control/" + cell).add_child(s)
					for ch in get_node("Control/" + last_casilla).get_children():
						ch.queue_free()
						
					get_node("Control/" + cell).color= Color(0.8, 0.8, 0, 0.5)
					get_node("Control/" + last_casilla).color= Color(0.8, 0.8, 0, 0.5)
#					var p= {}
#					$key.text= _getkey(casillas, p)
#					$piezas.text= str(p["p"])
					$ProgressBar.value= _eval(casillas)
				else:
					var texture= _casilla_pieza_textura(casillas[last_casilla])
					var s= Sprite.new()
					s.set_texture(texture)
					s.centered= false
					get_node("Control/" + last_casilla).add_child(s)
				last_casilla= null
				for ch in self.get_children():
					if ch.name == "moving":
						ch.queue_free()
						break
				_comprueba_fichas(casillas)
						
		elif event.button_index == BUTTON_LEFT and !event.pressed and selecting:
			if selectingType != null:
				var mousepos = get_viewport().get_mouse_position()
				var cell= _casilla(mousepos.x, mousepos.y)
				if cell != null:
					var texture= selectingTexture
					var s= Sprite.new()
					s.set_texture(texture)
					s.centered= false
					
					var move= "aux-" + cell
					casillas["aux"]= selectingType
					casillas= _prepara_tablero(casillas, move)
					
					for ch in get_node("Control/" + cell).get_children():
						ch.queue_free()
					get_node("Control/" + cell).add_child(s)
#					var p= {}
#					$key.text= _getkey(casillas, p)
#					$piezas.text= str(p["p"])
					$ProgressBar.value= _eval(casillas)
				
				selectingType= null
				selecting= false
				
				for ch in self.get_children():
					if ch.name == "moving":
						ch.queue_free()
						break
				_comprueba_fichas(casillas)
		
		elif event.button_index == BUTTON_RIGHT and event.pressed:
			if selecting:
				$ItemList.visible= false
				selecting= false
			else:
				$ItemList.unselect_all()
				$ItemList.visible= true
				selecting= true
				selectingType= null

func _reyes_vivos(_table):
	var black_king= false
	var white_king= false
	var dval= _table.values()
	for v in dval.size():
		if str(dval[v]) == "bk":
			black_king= true
		elif str(dval[v]) == "wk":
			white_king= true
		if black_king:
			if white_king:
				return true
				
	return false
	
func _comprueba_fichas(_table):
#	for l in 8:
#		for n in 8:
#			if !_table.has(lt[l] + str(n + 1)):
#				if get_node("Control/" + lt[l] + str(n + 1)).get_child_count() > 0:
#					print(lt[l] + str(n + 1) + " tiene pieza y no esta en casillas")
#			elif get_node("Control/" + lt[l] + str(n + 1)).get_child_count() == 0:
#				print(lt[l] + str(n + 1) + " no tiene pieza y esta en casillas")
	pass

func _prepara_tablero(_dict, _move):
	
	if _move == "none":
		print("fail prepara tablero(), move is none")
		return(_dict)
		
	var dict= _dict.duplicate()
	
	#prepara el tablero original + los movimientos hechos
	
	for l in lt.length():#borra salto peon info cada nuevo movimiento
		dict.erase("S" + lt[l] + "4")
		dict.erase("S" + lt[l] + "5")
			
	var s= _move.rsplit("-")
	if s.size() == 2: #movimiento normal
		dict[s[1]]= dict[s[0]]
		dict.erase(s[0])
		
		#adios enrroques
		if dict[s[1]] == "wk":
			dict.erase("Rh1")
			dict.erase("Ra1")
			dict.erase("Rw2")
		elif s[1] == "h1":
			if dict.has("Rw2"):
				dict.erase("Rw2")
				dict["Ra1"]= 1
			else:
				dict.erase("Rh1")
				dict.erase("Ra1")
				dict.erase("Rw2")
		elif s[1] == "a1":
			if dict.has("Rw2"):
				dict.erase("Rw2")
				dict["Rh1"]= 1
			else:
				dict.erase("Rh1")
				dict.erase("Ra1")
				dict.erase("Rw2")
		
		if dict[s[1]] == "bk":
			dict.erase("Rh8")
			dict.erase("Ra8")
			dict.erase("Rb2")
		elif s[1] == "h8":
			if dict.has("Rb2"):
				dict.erase("Rb2")
				dict["Ra8"]= 1
			else:
				dict.erase("Rh8")
				dict.erase("Ra8")
				dict.erase("Rb2")
		elif s[1] == "a8":
			if dict.has("Rb2"):
				dict.erase("Rb2")
				dict["Rh8"]= 1
			else:
				dict.erase("Rh8")
				dict.erase("Ra8")
				dict.erase("Rb2")
			
	elif s.size() == 4: #captura al paso
		dict[s[3]]= dict[s[0]]
		dict.erase(s[0])
		dict.erase(s[2])
	else:
		if s[1] == "S": #salto peon
			dict[s[2]]= dict[s[0]]
			dict.erase(s[0])
			dict["S"+s[2]]= 1 #guarda info de que este peon ha saltado
		elif s[1] == "O": #los 4 posibles enroques
			if s[2] == "h1":
				dict["g1"]= dict["e1"]
				dict.erase("e1")
				dict["f1"]= dict["h1"]
				dict.erase("h1")
				dict.erase("Rh1")
				dict.erase("Rw2")
			elif s[2] == "a1":
				dict["c1"]= dict["e1"]
				dict.erase("e1")
				dict["d1"]= dict["a1"]
				dict.erase("a1")
				dict.erase("Ra1")
				dict.erase("Rw2")
			elif s[2] == "a8":
				dict["c8"]= dict["e8"]
				dict.erase("e8")
				dict["d8"]= dict["a8"]
				dict.erase("d8")
				dict.erase("Ra8")
				dict.erase("Rb2")
			else:
				dict["g8"]= dict["e8"]
				dict.erase("e8")
				dict["f8"]= dict["h8"]
				dict.erase("h8")
				dict.erase("Rh8")
				dict.erase("Rb2")
		else: #coronar peon
			dict[s[1]]= s[2]
			dict.erase(s[0])
			
	return dict
	
func _escenarios_blancas(_inputDict, _enroque):
	var dict= _inputDict.duplicate()
	var ps= PoolStringArray()
	var ka= dict.keys()
	
	for k in ka.size():
		var cell= ka[k]
		
		var a= int(cell[1]) - 1
		var b= lt.find(cell[0])
		
		var value= str(dict[cell])
		
		if value == "wp": #PEON BLANCO
			if a < 7: #avanza uno
				if a < 6:
					if !dict.has(lt[b] + str(a+2)):
						ps.append(cell + "-" + lt[b] + str(a+2))
				if b < 7: #come a derecha
					if dict.has(lt[b+1] + str(a+2)):
						var s= dict[lt[b+1] + str(a+2)]
						if s[0] == "b":
							ps.append(cell + "-" + lt[b+1] + str(a+2))
							if a == 6:
								ps.append(cell + "-" + lt[b+1] + "8-wq")
					if a == 4: #captura al paso derecha
						if dict.has("S" + lt[b + 1] + "5"): 
							ps.append(cell + "-P-" + lt[b+1] + "5-" + lt[b+1] + "6")
				if b > 0: #come izquierda
					if dict.has(lt[b-1] + str(a+2)):
						var s= dict[lt[b-1] + str(a+2)]
						if s[0] == "b":
							ps.append(cell + "-" + lt[b-1] + str(a+2))
							if a == 6:
								ps.append(cell + "-" + lt[b-1] + "8-wq")
					if a == 4: #captura al paso izquierda
						if dict.has("S" + lt[b - 1] + "5"): 
							ps.append(cell + "-P-" + lt[b-1] + "5-" + lt[b-1] + "6")
			if a == 1: #avanza dos
				if !dict.has(lt[b] + str(a+2)):
					if !dict.has(lt[b] + str(a+3)):
						ps.append(cell + "-S-" + lt[b] + str(a+3))
			elif a == 6: #asciende a reina
				if !dict.has(cell[0] + "8"):
					ps.append(cell + "-" + cell[0] + "8-wq")
			
		elif value == "wb": #ALFIL BLANCO
			var auxA= a+1
			var auxB= b+1
			while auxA <= 7 and auxB <= 7: #avanza arriba-derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA+= 1
				auxB+= 1
				
			auxA= a+1
			auxB= b-1
			while auxA <= 7 and auxB >= 0: #avanza arriba-izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA+= 1
				auxB-= 1
				
			auxA= a-1
			auxB= b-1
			while auxA >= 0 and auxB >= 0: #avanza abajo-izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA-= 1
				auxB-= 1
				
			auxA= a-1
			auxB= b+1
			while auxA >= 0 and auxB <= 7: #avanza abajo-derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA-= 1
				auxB+= 1
			
		elif value == "wh": #CABALLO BLANCO
			var auxA= a + 2
			var auxB= b + 1
			if auxA <= 7 and auxB <= 7:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a + 1
			auxB= b + 2
			if auxA <= 7 and auxB <= 7:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a - 1
			auxB= b - 2
			if auxA >= 0 and auxB >= 0:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a - 2
			auxB= b - 1
			if auxA >= 0 and auxB >= 0:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a + 2
			auxB= b - 1
			if auxA <= 7 and auxB >= 0:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a + 1
			auxB= b - 2
			if auxA <= 7 and auxB >= 0:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a - 2
			auxB= b + 1
			if auxA >= 0 and auxB <= 7:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a - 1
			auxB= b + 2
			if auxA >= 0 and auxB <= 7:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			
		elif value == "wt": #TORRE BLANCA
			var auxA= a+1
			var auxB= b
			while auxA <= 7: #avanza arriba
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[b] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA+= 1
				
			auxA= a-1
			auxB= b
			while auxA >= 0: #avanza abajo
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA-= 1
				
			auxA= a
			auxB= b-1
			while auxB >= 0: #avanza izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxB-= 1
				
			auxA= a
			auxB= b+1
			while auxB <= 7: #avanza derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxB+= 1
			
		elif value == "wq": #REINA BLANCA
			var auxA= a+1
			var auxB= b
			while auxA <= 7: #avanza arriba
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA+= 1
				
			auxA= a-1
			auxB= b
			while auxA >= 0: #avanza abajo
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA-= 1
			
			auxA= a
			auxB= b-1
			while auxB >= 0: #avanza izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxB-= 1
				
			auxA= a
			auxB= b+1
			while auxB <= 7: #avanza derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxB+= 1
				
			auxA= a+1
			auxB= b+1
			while auxA <= 7 and auxB <= 7: #avanza arriba-derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA+= 1
				auxB+= 1
				
			auxA= a+1
			auxB= b-1
			while auxA <= 7 and auxB >= 0: #avanza arriba-izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA+= 1
				auxB-= 1
				
			auxA= a-1
			auxB= b-1
			while auxA >= 0 and auxB >= 0: #avanza abajo-izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA-= 1
				auxB-= 1
				
			auxA= a-1
			auxB= b+1
			while auxA >= 0 and auxB <= 7: #avanza abajo-derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				auxA-= 1
				auxB+= 1
			
		elif value == "wk": #REY BLANCO
			if !_enroque:
				continue
			
			var auxA= a+1
			var auxB= b+1
			if auxA <= 7 and auxB <= 7: #arriba derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a+1
			auxB= b
			if auxA <= 7: #arriba 
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a+1
			auxB= b-1
			if auxA <= 7 and auxB >= 0: #arriba izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a
			auxB= b-1
			if auxB >= 0: #izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a-1
			auxB= b-1
			if auxA >= 0 and auxB >= 0: #abajo izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a-1
			auxB= b
			if auxA >= 0: #abajo 
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a-1
			auxB= b+1
			if auxA >= 0 and auxB <= 7: #abajo derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a
			auxB= b+1
			if auxB <= 7: #derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "w":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
					
			if cell == "e1": #enrroques
				if dict.has("Rh1") or dict.has("Rw2"):
					if !dict.has("f1"):
						if !dict.has("g1"):
							if dict.has("h1"):
								if dict["h1"] == "wt":
									var arr= _escenarios_negras(dict, false)
									var apuntan= false
									for i in arr.size():
										var spl= arr[i].rsplit("-")
										if spl[spl.size() - 1] == "e1":
											apuntan= true
											break
										if spl[spl.size() - 1] == "f1":
											apuntan= true
											break
										if spl[spl.size() - 1] == "g1":
											apuntan= true
											break
									if !apuntan:
										ps.append(cell + "-O-h1")
				
				if dict.has("Ra1") or dict.has("Rw2"):
					if !dict.has("b1"):
						if !dict.has("c1"):
							if !dict.has("d1"):
								if dict.has("a1"):
									if dict["a1"] == "wt":
										var arr= _escenarios_negras(dict, false)
										var apuntan= false
										for i in arr.size():
											var spl= arr[i].rsplit("-")
											if spl[spl.size() - 1] == "e1":
												apuntan= true
												break
											if spl[spl.size() - 1] == "b1":
												apuntan= true
												break
											if spl[spl.size() - 1] == "c1":
												apuntan= true
												break
											if spl[spl.size() - 1] == "d1":
												apuntan= true
												break
										if !apuntan:
											ps.append(cell + "-O-a1")
			
	return ps
	
func _escenarios_negras(_inputDict, _enroque):
	var dict= _inputDict.duplicate()
	var ps= PoolStringArray()
	var ka= dict.keys()
	
	for k in ka.size():
		var cell= ka[k]
		
		var a= int(cell[1]) - 1
		var b= lt.find(cell[0])
		
		var value= str(dict[cell])
		
		if value == "bp": #PEON NEGRO
			if a > 0: #avanza uno
				if a > 1:
					if !dict.has(lt[b] + str(a)):
						ps.append(cell + "-" + lt[b] + str(a))
				if b < 7: #come a derecha
					if dict.has(lt[b+1] + str(a)):
						var s= dict[lt[b+1] + str(a)]
						if s[0] == "w":
							ps.append(cell + "-" + lt[b+1] + str(a))
							if a == 1:
								ps.append(cell + "-" + lt[b+1] + "1-bq")
					if a == 3: #captura al paso derecha
						if dict.has("S" + lt[b + 1] + "4"): 
							ps.append(cell + "-P-" + lt[b+1] + "4-" + lt[b+1] + "3")
				if b > 0: #come izquierda
					if dict.has(lt[b-1] + str(a)):
						var s= dict[lt[b-1] + str(a)]
						if s[0] == "w":
							ps.append(cell + "-" + lt[b-1] + str(a))
							if a == 1:
								ps.append(cell + "-" + lt[b-1] + "1-bq")
					if a == 3: #captura al paso izquierda
						if dict.has("S" + lt[b - 1] + "4"): 
							ps.append(cell + "-P-" + lt[b-1] + "4-" + lt[b-1] + "3")
			if a == 6: #avanza dos
				if !dict.has(lt[b] + str(a)):
					if !dict.has(lt[b] + str(a-1)):
						ps.append(cell + "-S-" + lt[b] + str(a-1))
			elif a == 1: #asciende a reina
				if !dict.has(cell[0] + "1"):
					ps.append(cell + "-" + cell[0] + "1-bq")
			
		elif value == "bb": #ALFIL NEGRO
			var auxA= a+1
			var auxB= b+1
			while auxA <= 7 and auxB <= 7: #avanza arriba-derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA+= 1
				auxB+= 1
				
			auxA= a+1
			auxB= b-1
			while auxA <= 7 and auxB >= 0: #avanza arriba-izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA+= 1
				auxB-= 1
				
			auxA= a-1
			auxB= b-1
			while auxA >= 0 and auxB >= 0: #avanza abajo-izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA-= 1
				auxB-= 1
				
			auxA= a-1
			auxB= b+1
			while auxA >= 0 and auxB <= 7: #avanza abajo-derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA-= 1
				auxB+= 1
			
		elif value == "bh": #CABALLO NEGRO
			var auxA= a + 2
			var auxB= b + 1
			if auxA <= 7 and auxB <= 7:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a + 1
			auxB= b + 2
			if auxA <= 7 and auxB <= 7:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a - 1
			auxB= b - 2
			if auxA >= 0 and auxB >= 0:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a - 2
			auxB= b - 1
			if auxA >= 0 and auxB >= 0:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a + 2
			auxB= b - 1
			if auxA <= 7 and auxB >= 0:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a + 1
			auxB= b - 2
			if auxA <= 7 and auxB >= 0:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a - 2
			auxB= b + 1
			if auxA >= 0 and auxB <= 7:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a - 1
			auxB= b + 2
			if auxA >= 0 and auxB <= 7:
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			
		elif value == "bt": #TORRE NEGRO
			var auxA= a+1
			var auxB= b
			while auxA <= 7: #avanza arriba
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[b] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA+= 1
				
			auxA= a-1
			auxB= b
			while auxA >= 0: #avanza abajo
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA-= 1
				
			auxA= a
			auxB= b-1
			while auxB >= 0: #avanza izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxB-= 1
				
			auxA= a
			auxB= b+1
			while auxB <= 7: #avanza derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxB+= 1
			
		elif value == "bq": #REINA NEGRO
			var auxA= a+1
			var auxB= b
			while auxA <= 7: #avanza arriba
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA+= 1
				
			auxA= a-1
			auxB= b
			while auxA >= 0: #avanza abajo
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA-= 1
			
			auxA= a
			auxB= b-1
			while auxB >= 0: #avanza izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxB-= 1
				
			auxA= a
			auxB= b+1
			while auxB <= 7: #avanza derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxB+= 1
				
			auxA= a+1
			auxB= b+1
			while auxA <= 7 and auxB <= 7: #avanza arriba-derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA+= 1
				auxB+= 1
				
			auxA= a+1
			auxB= b-1
			while auxA <= 7 and auxB >= 0: #avanza arriba-izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA+= 1
				auxB-= 1
				
			auxA= a-1
			auxB= b-1
			while auxA >= 0 and auxB >= 0: #avanza abajo-izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA-= 1
				auxB-= 1
				
			auxA= a-1
			auxB= b+1
			while auxA >= 0 and auxB <= 7: #avanza abajo-derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "b":
						break
				ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] == "w":
						break
				auxA-= 1
				auxB+= 1
			
		elif value == "bk": #REY NEGRO
			if !_enroque:
				continue
				
			var auxA= a+1
			var auxB= b+1
			if auxA <= 7 and auxB <= 7: #arriba derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a+1
			auxB= b
			if auxA <= 7: #arriba 
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a+1
			auxB= b-1
			if auxA <= 7 and auxB >= 0: #arriba izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a
			auxB= b-1
			if auxB >= 0: #izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a-1
			auxB= b-1
			if auxA >= 0 and auxB >= 0: #abajo izquierda
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a-1
			auxB= b
			if auxA >= 0: #abajo 
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a-1
			auxB= b+1
			if auxA >= 0 and auxB <= 7: #abajo derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
			auxA= a
			auxB= b+1
			if auxB <= 7: #derecha
				if dict.has(lt[auxB] + str(auxA+1)):
					var s= dict[lt[auxB] + str(auxA+1)]
					if s[0] != "b":
						ps.append(cell + "-" + lt[auxB] + str(auxA+1))
				else:
					ps.append(cell + "-" + lt[auxB] + str(auxA+1))
					
			if _enroque:
				if cell == "e8": #enrroques
					if dict.has("Rh8") or dict.has("Rb2"):
						if !dict.has("f8"):
							if !dict.has("g8"):
								if dict.has("h8"):
									if dict["h8"] == "bt":
										var arr= _escenarios_blancas(dict, false)
										var apuntan= false
										for i in arr.size():
											var spl= arr[i].rsplit("-")
											if spl[spl.size() - 1] == "e8":
												apuntan= true
												break
											if spl[spl.size() - 1] == "f8":
												apuntan= true
												break
											if spl[spl.size() - 1] == "g8":
												apuntan= true
												break
										if !apuntan:
											ps.append(cell + "-O-h8")
					
					if dict.has("Ra8") or dict.has("Rb2"):
						if !dict.has("b8"):
							if !dict.has("c8"):
								if !dict.has("d8"):
									if dict.has("a8"):
										if dict["a8"] == "bt":
											var arr= _escenarios_blancas(dict, false)
											var apuntan= false
											for i in arr.size():
												var spl= arr[i].rsplit("-")
												if spl[spl.size() - 1] == "e8":
													apuntan= true
													break
												if spl[spl.size() - 1] == "b8":
													apuntan= true
													break
												if spl[spl.size() - 1] == "c8":
													apuntan= true
													break
												if spl[spl.size() - 1] == "d8":
													apuntan= true
													break
											if !apuntan:
												ps.append(cell + "-O-a8")
			
	return ps

func _multiT_minimax(_dict):
	var result= {"eval": 50.001, "move": _dict["move"]}
	var alpha= -1.001
	var beta= 101.001
	var negras= bool(_dict["negras"])
	_dict.erase("negras")
	_dict.erase("move")
	
	if negras: #maximize
		var best_score= -1.001
		beta= _dict["beta"]
		_dict.erase("beta")
		
		var next_move= _escenarios_negras(_dict, true)
		
		if next_move.size() == 0:
			result["eval"]= 50.001
			thinking+= 1
		else:
			for c in next_move.size():
				var new_table= _prepara_tablero(_dict, next_move[c])
				var auxdict= _minimax(new_table, false, alpha, beta, 2)
				var value= float(auxdict["eval"])
				
				if value > best_score:
					best_score= float(value)
					result["eval"]= float(auxdict["eval"])
					
				if best_score > alpha:
					alpha= float(best_score)
					
				if alpha >= beta:
					new_table.clear()
					break
				new_table.clear()
	else: #blancas minimize
		var best_score= 101.001
		alpha= _dict["alpha"]
		_dict.erase("alpha")
		
		var next_move= _escenarios_blancas(_dict, true)
		
		if next_move.size() == 0:
			result["eval"]= 50.001
			thinking+= 1
		else:
			for c in next_move.size():
				var new_table= _prepara_tablero(_dict, next_move[c])
				
				var auxdict= _minimax(new_table, true, alpha, beta, 2)
				var value= float(auxdict["eval"])
				
				if value < best_score:
					best_score= float(value)
					result["eval"]= float(auxdict["eval"])
					
				if best_score < beta:
					beta= float(best_score)
					
				if alpha >= beta:
					new_table.clear()
					break
				new_table.clear()
				
	mutex.lock()
	mt_results.append(result)
	mutex.unlock()
	
func _minimax(_table, _negras, _alpha, _beta, _step):
	var result= {"eval": 50.001 }
	
	if _step >= int($deep.value):
		result["eval"]= float(_eval(_table))
		thinking+= 1
		return result
	 
	if _negras: #maximize
		var best_score= -1.001
		var alpha= -1.001
		var beta= _beta
		var next_move= _escenarios_negras(_table, true)
		
		if next_move.size() == 0:
			result["eval"]= 50.001
			thinking+= 1
		else:
			for c in next_move.size():
				var new_table= _prepara_tablero(_table, next_move[c])
				var auxdict= _minimax(new_table, false, alpha, beta, _step + 1)
				var value= float(auxdict["eval"])
				
				if value > best_score:
					best_score= float(value)
					result["eval"]= float(auxdict["eval"])
					
				if best_score > alpha:
					alpha= float(best_score)
					
				if alpha >= _beta:
					new_table.clear()
					break
				new_table.clear()
	else: #blancas minimize
		var best_score= 101.001
		var alpha= _alpha
		var beta= 101.001
		var next_move= _escenarios_blancas(_table, true)
		
		if next_move.size() == 0:
			result["eval"]= 50.001
			thinking+= 1
		else:
			for c in next_move.size():
				var new_table= _prepara_tablero(_table, next_move[c])
				
				var auxdict= _minimax(new_table, true, alpha, beta, _step + 1)
				var value= float(auxdict["eval"])
				
				if value < best_score:
					best_score= float(value)
					result["eval"]= float(auxdict["eval"])
					
				if best_score < beta:
					beta= float(best_score)
					
				if _alpha >= beta:
					new_table.clear()
					break
				new_table.clear()
				
	return result
	
func _on_move_pressed():
	
	for t in thread.size():
		if thread[t].is_active():
			return
	
	$move.pressed= true
	
	mt_results= []
	mt_moves= []
	thread= []
	thinking= 0
	mt_movesCount= 0
	time= 0
	
	if $TextureButton.pressed: #negras= true
		mt_moves= _escenarios_negras(casillas, true)
	else:
		mt_moves= _escenarios_blancas(casillas, true)
	
	thread_running= true
	
	
func _mueve_visuales(_move):
	for i in 8:
		for i2 in 8:
			get_node("Control/" + lt[i] + str(i2 + 1)).color= Color(0, 0, 0, 0)
	var sa= _move.split("-")
	if sa.size() == 2: #movimiento simple
		
		var texture= _casilla_pieza_textura(casillas[sa[0]])
		var s= Sprite.new()
		s.set_texture(texture)
		s.centered= false
		for ch in get_node("Control/" + sa[1]).get_children():
			ch.queue_free()
		get_node("Control/" + sa[1]).add_child(s)
		for ch in get_node("Control/" + sa[0]).get_children():
			ch.queue_free()
		get_node("Control/" + sa[1]).color= Color(0.8, 0.8, 0, 0.5)
		get_node("Control/" + sa[0]).color= Color(0.8, 0.8, 0, 0.5)
		
	elif sa.size() == 3:
		
		if sa[1] == "O": #enroque
			var piezas= ["wk", "wt"]
			var posiciones= ["e1", "g1", "h1", "f1"]
			
			if sa[2] == "a1":
				posiciones= ["e1", "c1", "a1", "d1"]
			elif sa[2] == "h8":
				piezas= ["bk", "bt"]
				posiciones= ["e8", "g8", "h8", "f8"]
			elif sa[2] == "a8":
				piezas= ["bk", "bt"]
				posiciones= ["e8", "c8", "a8", "d8"]
				
			var texture= _casilla_pieza_textura(piezas[0])
			var s= Sprite.new()
			s.set_texture(texture)
			s.centered= false
			for ch in get_node("Control/" + posiciones[0]).get_children():
				ch.queue_free()
			for ch in get_node("Control/" + posiciones[1]).get_children():
				ch.queue_free()
			get_node("Control/" + posiciones[1]).add_child(s)
			var texture2= _casilla_pieza_textura(piezas[1])
			var s2= Sprite.new()
			s2.set_texture(texture2)
			s2.centered= false
			for ch in get_node("Control/" + posiciones[2]).get_children():
				ch.queue_free()
			for ch in get_node("Control/" + posiciones[3]).get_children():
				ch.queue_free()
			get_node("Control/" + posiciones[3]).add_child(s2)
			
			get_node("Control/" + posiciones[1]).color= Color(0.8, 0.8, 0, 0.5)
			get_node("Control/" + posiciones[3]).color= Color(0.8, 0.8, 0, 0.5)
			
		elif sa[1] == "S": #salto peon
			var texture= _casilla_pieza_textura(casillas[sa[0]])
			var s= Sprite.new()
			s.set_texture(texture)
			s.centered= false
			for ch in get_node("Control/" + sa[2]).get_children():
				ch.queue_free()
			get_node("Control/" + sa[2]).add_child(s)
			for ch in get_node("Control/" + sa[0]).get_children():
				ch.queue_free()
			get_node("Control/" + sa[2]).color= Color(0.8, 0.8, 0, 0.5)
			get_node("Control/" + sa[0]).color= Color(0.8, 0.8, 0, 0.5)
			
		else: #coronar
			var texture= _casilla_pieza_textura(sa[2])
			var s= Sprite.new()
			s.set_texture(texture)
			s.centered= false
			for ch in get_node("Control/" + sa[0]).get_children():
				ch.queue_free()
			for ch in get_node("Control/" + sa[1]).get_children():
				ch.queue_free()
			get_node("Control/" + sa[1]).add_child(s)
			get_node("Control/" + sa[0]).color= Color(0.8, 0.8, 0, 0.5)
			get_node("Control/" + sa[1]).color= Color(0.8, 0.8, 0, 0.5)
			
	elif sa.size() == 4: #captura al paso
		
		var texture= _casilla_pieza_textura(casillas[sa[0]])
		var s= Sprite.new()
		s.set_texture(texture)
		s.centered= false
		for ch in get_node("Control/" + sa[2]).get_children():
			ch.queue_free()
		for ch in get_node("Control/" + sa[3]).get_children():
			ch.queue_free()
		get_node("Control/" + sa[3]).add_child(s)
		for ch in get_node("Control/" + sa[0]).get_children():
			ch.queue_free()
		get_node("Control/" + sa[3]).color= Color(0.8, 0.8, 0, 0.5)
		get_node("Control/" + sa[2]).color= Color(0.8, 0.8, 0, 0.5)
		get_node("Control/" + sa[0]).color= Color(0.8, 0.8, 0, 0.5)

func _on_ItemList_item_selected(index):
	selectingType= $ItemList.get_item_text(index)
	selectingTexture= $ItemList.get_item_icon(index)
	var mousepos = get_viewport().get_mouse_position()
	var s= Sprite.new()
	s.set_texture(selectingTexture)
	s.name= "moving"
	s.position= Vector2(mousepos.x, mousepos.y)
	self.add_child(s, true)
	$ItemList.visible= false

func _casilla(_x, _y):
	if _x == 0 or _y == 0 or _x > 248 or _y > 248:
		return null
	
	if $TextureButton.pressed == false:
		var x= int(_x / 31)
		var y= 7 - int(_y / 31)
		var cell= lt[x] + str(y+1)
		return cell
	else:
		var x= 7 - int(_x / 31)
		var y= int(_y / 31)
		var cell= lt[x] + str(y+1)
		return cell
	
func _eval(_dict):
	var whitepoints= 1
	var blackpoints= 1
	
	var ka= _dict.keys()
	
	for k in ka.size():
		var cell= ka[k]
		var value= str(_dict[cell])
		var l= lt.find(cell[0])
		var n= int(cell[1])
		
		if value == "wp":
			whitepoints+= (int(cell[1]) - 1) * 1 #peon avanzado
			whitepoints+= 10 
			if cell[0] == "e":
				if n == 4:
					whitepoints+= 6
			if n > 2: #peon cubierto por peon
				if l > 0:
					if _dict.has(lt[l - 1] + str(n - 1)):
						if _dict[lt[l - 1] + str(n - 1)] == "wp":
							whitepoints+= 3
				if l < 7:
					if _dict.has(lt[l + 1] + str(n - 1)):
						if _dict[lt[l + 1] + str(n - 1)] == "wp":
							whitepoints+= 3
		elif value == "wb":
			if int(cell[1]) != 1:
				whitepoints+= 7 #alfil desarrollado
			whitepoints+= 30
		elif value == "wh":
			if int(cell[1]) != 1:
				whitepoints+= 5 #caballo desarrollado
			if cell[0] == "h" or cell[0] == "a": #esta tocando pared
				whitepoints-= 5
			whitepoints+= 30
		elif value == "wt":
			whitepoints+= 50
		elif value == "wq":
			whitepoints+= 90
		elif value == "wk":
			whitepoints+= 300
			
		elif value == "bp":
			blackpoints+= int((8 - int(cell[1])) * 1) #peon avanzado
			blackpoints+= 10
			if cell[0] == "e":
				if n == 5:
					blackpoints+= 6
			if n < 7: #peon cubierto por peon
				if l > 0:
					if _dict.has(lt[l - 1] + str(n + 1)):
						if _dict[lt[l - 1] + str(n + 1)] == "bp":
							blackpoints+= 3
				if l < 7:
					if _dict.has(lt[l + 1] + str(n + 1)):
						if _dict[lt[l + 1] + str(n + 1)] == "bp":
							blackpoints+= 3
		elif value == "bb":
			if int(cell[1]) != 8:
				blackpoints+= 7 #alfil desarrollado
			blackpoints+= 30
		elif value == "bh":
			if int(cell[1]) != 8:
				blackpoints+= 5 #caballo desarrollado
			if cell[0] == "h" or cell[0] == "a": #esta tocando pared
				blackpoints-= 5
			blackpoints+= 30
		elif value == "bt":
			blackpoints+= 50
		elif value == "bq":
			blackpoints+= 90
		elif value == "bk":
			blackpoints+= 300
				
	var result= (float(blackpoints) / (whitepoints + blackpoints)) * 100
	return float(result)

func _getkey(_dict, _dict2):
	var key= ""
	var ncount= 0
	_dict2["p"]= 0
	for a in 8:
		for b in 8:
			var cell= lt[b] + str(a+1)
			if !_dict.has(cell):
				return null
			if _dict[cell] == "n":
				ncount+= 1
				if ncount == 9:
					key+= str(ncount)
					ncount= 0
			else:
				if ncount > 0:
					key+= str(ncount)
				key+= _tipopieza_a_letra(_dict[cell])
				ncount= 0
				_dict2["p"]+= 1
	if ncount > 0:
		key+= str(ncount)
	return key

func _tipopieza_a_letra(_tipo):
	if _tipo == "wp":
		return "a"
	elif _tipo == "wt":
		return "b"
	if _tipo == "wh":
		return "c"
	elif _tipo == "wb":
		return "d"
	if _tipo == "wq":
		return "f"
	elif _tipo == "wk":
		return "g"
		
	elif _tipo == "bp":
		return "h"
	elif _tipo == "bt":
		return "i"
	if _tipo == "bh":
		return "j"
	elif _tipo == "bb":
		return "k"
	if _tipo == "bq":
		return "l"
	elif _tipo == "bk":
		return "m"

func _casilla_pieza_textura(_cell):
	if _cell[0] == "w":
		if _cell[1] == "p":
			return wp
		elif _cell[1] == "q":
			return wq
		elif _cell[1] == "h":
			return wh
		elif _cell[1] == "b":
			return wb
		elif _cell[1] == "k":
			return wk
		else:
			return wt
	else:
		if _cell[1] == "p":
			return bp
		elif _cell[1] == "q":
			return bq
		elif _cell[1] == "h":
			return bh
		elif _cell[1] == "b":
			return bb
		elif _cell[1] == "k":
			return bk
		else:
			return bt

func _pon_piezas():
	
	var s= Sprite.new()
	s.set_texture(wt)
	s.centered= false
	casillas["a1"]= "wt"
	$Control/a1.add_child(s)
	
	s= Sprite.new()
	s.set_texture(wt)
	s.centered= false
	casillas["h1"]= "wt"
	$Control/h1.add_child(s)
	
	s= Sprite.new()
	s.set_texture(wb)
	s.centered= false
	casillas["c1"]= "wb"
	$Control/c1.add_child(s)
	
	s= Sprite.new()
	s.set_texture(wb)
	s.centered= false
	casillas["f1"]= "wb"
	$Control/f1.add_child(s)
	
	s= Sprite.new()
	s.set_texture(wh)
	s.centered= false
	casillas["b1"]= "wh"
	$Control/b1.add_child(s)
	
	s= Sprite.new()
	s.set_texture(wh)
	s.centered= false
	casillas["g1"]= "wh"
	$Control/g1.add_child(s)
	
	s= Sprite.new()
	s.set_texture(wq)
	s.centered= false
	casillas["d1"]= "wq"
	$Control/d1.add_child(s)
	
	s= Sprite.new()
	s.set_texture(wk)
	s.centered= false
	casillas["e1"]= "wk"
	$Control/e1.add_child(s)
	
	for i in 8:
		s= Sprite.new()
		s.set_texture(wp)
		s.centered= false
		var cell= "Control/" + lt[i] + str(2)
		casillas[lt[i] + str(2)]= "wp"
		get_node(cell).add_child(s)
	
	s= Sprite.new()
	s.set_texture(bt)
	s.centered= false
	casillas["a8"]= "bt"
	$Control/a8.add_child(s)
	
	s= Sprite.new()
	s.set_texture(bt)
	s.centered= false
	casillas["h8"]= "bt"
	$Control/h8.add_child(s)
	
	s= Sprite.new()
	s.set_texture(bb)
	s.centered= false
	casillas["c8"]= "bb"
	$Control/c8.add_child(s)
	
	s= Sprite.new()
	s.set_texture(bb)
	s.centered= false
	casillas["f8"]= "bb"
	$Control/f8.add_child(s)
	
	s= Sprite.new()
	s.set_texture(bh)
	s.centered= false
	casillas["b8"]= "bh"
	$Control/b8.add_child(s)
	
	s= Sprite.new()
	s.set_texture(bh)
	s.centered= false
	casillas["g8"]= "bh"
	$Control/g8.add_child(s)
	
	s= Sprite.new()
	s.set_texture(bq)
	s.centered= false
	casillas["d8"]= "bq"
	$Control/d8.add_child(s)
	
	s= Sprite.new()
	s.set_texture(bk)
	s.centered= false
	casillas["e8"]= "bk"
	$Control/e8.add_child(s)
	
	for i in 8:
		s= Sprite.new()
		s.set_texture(bp)
		s.centered= false
		var cell= "Control/" + lt[i] + str(7)
		casillas[lt[i] + str(7)]= "bp"
		get_node(cell).add_child(s)
		
	casillas["Rw2"]= 1
	casillas["Rb2"]= 1






