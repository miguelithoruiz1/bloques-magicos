# Bloques Mágicos 3.0 — «Todo junto» (decisión del usuario, 2026-11-02)

## Estado 3.0.0 — primera entrega (2026-11-02 11:24)
APK TV + celular en Drive, versionCode 12, mismo
firmante que 2.0.2 (instala encima). Incluye: 20
misiones, niveles/estaciones, taller, 16 animales,
pájaros, clima, minimapa, stats, 41 biomas, catálogo
criaturas 246, bandas multiedad, sol día/noche. Tests
3.0 + escena + 2.0 + refactor en verde. DESPUÉS de la 3.0.0: catálogo de bloques 165 ya hecho
(data/blocks.json v2, 6 pestañas nuevas en el
inventario, vetas por bandas y roca madre; tests en
verde). IA ya hecha: temperamentos (passive/neutral/
aggressive con histéresis 8/20), huida con calma 3 s,
aviso de manada, doma v2 (cerca 1×, sigilo 1.5×,
comida en mano 2×), montura de caballo con botón 🐴
y horda con Luna Carmesí cada 8 noches (máx. 24,
separación 0.8); tests en verde. Combate y vitales
ya hechos: salud/maná/estamina/oxígeno/temperatura,
ataque cuerpo a cuerpo + onda con maná, esquiva con
i-frames, jefes con 3 fases, valores del documento
para el jugador (5.5/8.25/2.75, salto 9.0, gravedad
26.0, cuerpo 0.60×1.70, ojo 1.52), muerte sin
permanencia con reaparición; tests en verde.
Razas, forja y estaciones ya hechos: 6 razas con
efectos reales, personaje separado en
bloques3_character.json, forja (acero, espadas con
espíritu), 8 estaciones con bloques 247-254 y
fabricación en cadena, pociones y comida; catálogo
173 bloques; tests en verde. Cuevas, estructuras,
música y foley ya hechos: cuevas en 3 estratos con
4 temas (cristal, hongo, magma), estructuras
(torre, obelisco, portal, árbol, ruina), música
procedural por bioma y foley por material; la
superficie queda intacta y se entra picando o
volando (el suelo por columna no soporta techos);
tests en verde. PENDIENTE todavía: LAN. Push a
GitHub pendiente de completar el documento.

Entrega ÚNICA con todo. Por dentro se construye en orden (uno
a la vez, con test tras cada uno); por fuera sale un solo
paquete: APK TV + celular, Drive y push a main. La 2.0.2 es la
base: todos sus arreglos (luz, HUD, «N», Ajustes) ya están
dentro de esta carpeta, así que la prueba de la 2.0.2 queda
absorbida por la prueba final de la 3.0.

Actualización 11:02 — el usuario subió 3 documentos y amplió el
alcance: TODO lo del GDD + acoplarse a los otros dos
documentos, TODOS los animales, mundo en vivo y 20 misiones.
Esta especificación es la que manda ahora.

Actualización 11:03 — CORRECCIÓN del usuario: el juego NO es
solo para niños; es multiedad (5 a 60+ años, como dice el
GDD) para todo tipo de conocimientos. El filtro «solo para
niños» queda levantado. Adaptación honesta que se mantiene:
el peligro del documento NO entra como combate (sin
enemigos que ataquen, sin hordas, sin jefes, sin facciones
hostiles, sin trampas de daño): entra como NIVEL DE RETO de
aprendizaje. Un niño de 5 años sigue jugando seguro; un
adulto encuentra retos más duros. Si el usuario quiere
combate de verdad después, es otra decisión, no un añadido
silencioso.

## Reglas que NO cambian

- Todo original: ideas generales sí, pero NADA copiado de Cube
  Unbound ni de ningún otro juego (ni arte, ni modelos .vox,
  ni JSON, ni shaders, ni textos de misiones, ni código).
- Sin combate, sin peligro, sin castigos, sin monstruos que
  asusten: el juego es para un niño de 5 años. Por eso el
  catálogo de 246 especies del documento de arquitectura NO
  entra completo: entran todas las especies AMIGABLES (16, ver
  abajo); monstruos, jefes, tiburones, momias, hordas y
  niveles de peligro quedan FUERA. Si el usuario quiere
  versiones amigables de alguno después, se añaden como
  amigos, no como enemigos.
- Sin sombras (el stick onn manda), sin tocar 1.15 ni la 2.0:
  esta línea vive solo en `~/workspace/bloques-3.0/`.
- Version: 3.0.0, versionCode 12, mismo paquete y mismo
  certificado (instala encima, conserva progreso).

## Acoplamiento a los 3 documentos (qué entra y qué no)

### GDD Bloques Mágicos (Aprendizaje Acelerado, Godot 4)
- 4 cámaras: YA EXISTEN (FIRST, SECOND/Feynman, THIRD, TOP).
- Crafteo semántico: ENTRA en el Taller (Amarillo+Azul=Verde,
  M+A=sílaba MA, ver recetas).
- Lógica Viva: ya existe la pestaña; las misiones de sumas la
  usan (detectar 4 bloques en fila ya existe en refactor_main).
- Repetición espaciada: YA EXISTE (SpacedRepetitionManager).
- Método Feynman: YA EXISTE (noche + 2ª persona + antorchas).
- Plaza con portales: YA EXISTE en 1.15 (hub.tscn), intacta.
- Gamificación (puntos, niveles, insignias, misiones): ENTRA
  (20 misiones + niveles + estrellas, ver abajo).
- Pomodoro / BioRhythm (temporizador de sesiones): FUERA de
  la 3.0 — necesita una decisión de UX (¿el juego interrumpe
  al niño a los 20 minutos?) que el usuario no ha tomado.
- Tycoon / Obbies / multijugador / cuevas / ciudades: FUERA
  de la 3.0 (sistemas enteros, no caben en una entrega).

### Arquitectura Motor Voxel 3D (referencia, NO es Cube)
- Guardado diferencial: YA EXISTE (SaveV2 + v1).
- CreatureSystem / PetSystem: ENTRA adaptado (16 animales
  amigos con IA IDLE/WANDER/FOLLOW, domesticación 3.5 s).
- WeatherSystem: ENTRA adaptado (lluvia/nieve solo visual,
  sin tormentas ni castigos; ver Mundo vivo).
- WorldMap: ENTRA como minimapa (sin niebla de guerra: el
  mapa dibuja el terreno generado, que ya es del jugador).
- Chunks 32×32×32 / regiones 1024²: NO se reconstruye el
  motor en la 3.0; nuestro mundo por radio + guardado
  diferencial es la misma idea a nuestra escala.
- Modelos .vox: FUERA por regla del usuario (nada ajeno);
  animales y pájaros son cubos procedurales propios.
- Audio procedural: NO se cambia el banco .ogg (105 voces)
  que ya funciona; los efectos nuevos usan tonos generados
  como ya hace GameModeManager.

### Guía Aprendizaje Rápido (neurociencia)
- Ya vive en el juego: repetición espaciada, Feynman,
  recuperación activa (palabras y sumas con bloques),
  mentalidad de crecimiento (sin castigos, pista suave).
- La 3.0 lo hace visible: las misiones mezclan colores,
  números y letras (entrelazado) en vez de pedir 20 sumas
  seguidas, y cada misión celebra el intento, no solo el
  acierto perfecto.

## Los sistemas de la 3.0

### 1. HUD completo + minimapa
- Barra superior: Pausa, Cámara, Taller (🔨), Misiones (🎯),
  estrellas, nivel/EXP y «Día N · Estación · ☀/🌙 · clima».
- Minimapa arriba-derecha dibujado DESDE los datos de
  nuestro terreno (superficie por columna + color del
  bloque), punto del jugador en el centro, norte arriba.
  Refresco máximo 2 veces por segundo y solo si el jugador
  se movió: barato para el stick.
- Contador de fps pequeño (para reportar rendimiento real).

### 2. 20 misiones «Aventuras para empezar» (textos propios)
1. Primeros bloques — Pon 3 bloques.
2. Un amigo nuevo — Hazte amigo de 1 animal.
3. Palabra mágica — Forma 1 palabra con letras.
4. Cuenta conmigo — Resuelve 1 suma con bloques.
5. Explorador — Aléjate 30 bloques del inicio.
6. Pequeño arquitecto — Pon 10 bloques de Construcción.
7. En lo más alto — Sube a 12 bloques de altura.
8. Noche de antorchas — Pon 1 antorcha de noche.
9. Manos a la obra — Fabrica 1 cosa en el Taller.
10. Arcoíris — Pon bloques de 5 colores distintos.
11. Cuenta hasta diez — Pon 10 bloques de números.
12. Letras viajeras — Pon bloques de 5 letras distintas.
13. Doble creación — Fabrica 2 cosas en el Taller.
14. Manada de amigos — Hazte amigo de 3 animales.
15. Gran constructor — Pon 50 bloques en total.
16. Gran viajero — Aléjate 100 bloques del inicio.
17. Segunda palabra — Forma 2 palabras con letras.
18. Matemático — Resuelve 3 sumas con bloques.
19. Noche estrellada — Pon 5 antorchas de noche.
20. Leyenda — Alcanza el nivel 5.
Cada misión = 1 estrella + 15 EXP. Panel modal con progreso.
Guardado en `user://bloques3_quests.json`.

### 3. Todos los animales amigos (16, cubos propios)
Oveja, perro, pollo y slime (ya existen) + vaca, cerdo,
gato, conejo, pato, rana, caballo, tortuga, ciervo, loro,
capibara y pingüino. Todos con la misma regla amable:
acercarse 3.5 s = amigo, te sigue, sin comida ni requisitos
escondidos. Aparecen alrededor del punto de inicio.
Los 246 del documento incluyen hostiles y jefes: fuera.

### 4. Mundo en vivo
- 5 pájaros ambientales (cubos propios, alas que aletean,
  vuelan en círculos cerca del jugador, sin colisión).
- Animales que deambulan solos (IA WANDER ya existe) y te
  siguen cuando son amigos (FOLLOW ya existe).
- Día de ~10 minutos + contador de día + estaciones cada
  5 días (Primavera, Verano, Otoño, Invierno, en ciclo).
- Clima solo visual: lluvia suave o nieve según la
  estación, con partículas alrededor del jugador. Sin
  tormentas, sin rayos, sin efectos sobre el jugador.
- Sol con energía alta de día y baja de noche (el sol de
  la 2.0.1 se mueve, no se reemplaza).

### 5. Taller (crafteo) + niveles
Recetas propias (bloques 90-93 solo se consiguen aquí):
- Estrella dorada (90): 3 amarillos + 2 cristales brillo.
- Corazón (91): 3 rojos + 1 rosado.
- Farol (92): 1 antorcha + 1 vidrio.
- Verde (13, mezcla GDD): 1 amarillo + 1 azul.
- Sílaba MA (93, GDD): 1 letra M + 1 letra A.
Regla igual que al colocar: en Creativo gratis, en
Supervivencia descuenta del inventario. Lo fabricado va al
slot seleccionado de la hotbar.
Niveles: EXP por colocar (1), palabra/suma/amigo/crafteo
(10), misión (15). Subir de nivel pide 20 + (nivel-1)*15
EXP. Guardado en `user://bloques3_levels.json`.

### 6. Todos los biomas (11 base + zonas 1-6)
El documento de arquitectura nombra 11 biomas base y define
los 26 especiales SOLO por zonas de distancia (no les pone
nombre uno a uno en el texto extraíble): no se inventan
nombres ni se finge que están listados. Implementación:
- Seleccionables en Ajustes (se suman a los 8 que ya hay):
  océano, río, pantano, tundra nevada, sabana, desierto y
  jungla = 7 nuevos (playa, llanura, bosque y montaña ya
  existían como playa_mar, pradera_verde, bosque_magico y
  montana_nevada, y no se duplican). Total: 15 biomas.
- Cada bioma nuevo es DATOS en la tabla de biomas
  (base/amplitud/montañas, bloque de superficie, decoración):
  océano = agua extensa; río = cauce de agua dulce; pantano
  = lodo y nenúfares; tundra = nieve y pinos nevados;
  sabana = hierba seca y acacias; desierto = arena y
  cactus; jungla = vegetación densa y loros.
- Zonas 1-6 por distancia al origen (0,0): el HUD muestra
  «Zona N · Nv. de reto» según lo lejos que camine el
  jugador (Zona 1 cerca del inicio, Zona 6 muy lejos).
  El nivel de reto sube con la distancia, como en el
  documento, pero sin enemigos: a más zona, retos de
  aprendizaje más duros (palabras y sumas de la banda
  de edad superior).

### 7. Multiedad (bandas 5-7 / 8-12 / 13+)
Selector en la pantalla de título, guardado en ajustes.
Efectos reales en la 3.0 (no un texto decorativo):
- Palabras invocables: 5-7: SOL, CASA; 8-12: +ARBOL,
  PUENTE, MAMA, PAPA; 13+: +LIBRO, MUNDO (voz por letras,
  que ya existe para todas las letras).
- Operaciones: 5-7: + y −; 8-12: + , − y ×; 13+: + , −, ×
  y ÷ (bloque 44 nuevo «÷», solo divisiones exactas y
  sin dividir por cero; si no es exacta, no cuenta).
- Misiones: las mismas 20 para todas las edades; la banda
  abre o cierra el contenido que las alimenta.
- Áreas de conocimiento en la 3.0: colores, números,
  letras y palabras, operaciones, lógica (operadores y
  pestaña Lógica Viva) y memoria (repetición espaciada).
  Fuera de la 3.0: simulador financiero/Tycoon, modo
  idiomas completo e inglés conversacional (las voces de
  colores en inglés del banco quedan como activo para
  3.1, no se finge un modo que no existe).

### 8. Rendimiento
- Radio de generación por defecto 20 (antes 24) si el
  usuario no tiene uno guardado: ~1/3 menos de columnas.
- Minimapa, pájaros y clima con presupuesto fijo.
- Meta honesta: medir fps reales en celular y stick con
  la 3.0; NO prometer 60 fps sin medir.

## Archivos nuevos (scripts/refactor/)
- `quest_system.gd` (QuestSystem: 20 misiones),
  `level_system.gd` (LevelSystem), `workshop.gd`
  (Workshop: recetas puras), `minimap.gd` (Minimap),
  `ambient_birds.gd` (AmbientBirds),
  `weather_system.gd` (WeatherSystem: clima visual).
- Cambios: `friendly_animal.gd` (16 especies),
  `ui_controller.gd` (botones, paneles, stats),
  `refactor_main.gd` (cableado, ganchos, 16 spawns,
  día/estación/clima), `voxel_world_generator.gd`
  (bloques 90-93: color, etiqueta, malla individual),
  `project.godot` (3.0.0 / vc 12).
- Test: `tests/refactor/test_3_0.gd` (misiones, niveles,
  recetas, estaciones, colores de bloques nuevos).

## Orden interno
1. quest/level/workshop + test → 2. animales + pájaros →
3. clima + día/estación + minimapa → 4. taller + bloques
44, 90-93 → 5. biomas nuevos + zonas + bandas de edad →
6. cableado HUD → 7. tests en verde → 8. export
TV+celular (receta 2.0.2: copia fresca, apktool FUERA del
proyecto, verificar 0 archivos «apktool», firma, MD5) →
9. Drive → 10. push a main con tarjeta de aprobación →
11. entrega.

## Mapa completo del documento (SIN RECORTES, orden 2026-11-02)
El usuario ordenó no saltarse ni recortar ningún punto
del documento de arquitectura. La 3.0 es la edición
completa. Adaptación única que NO es recorte: el
documento describe un motor en C++ con shaders GLSL y
modelos .vox; en Godot se implementa la MISMA idea con
nuestra tecnología (MultiMesh con color por vértice en
vez de vértices empaquetados; cubos procedurales propios
en vez de .vox ajenos, que además es regla del usuario:
nada copiado). La escala del mundo (altura 0-14, radio
20-24) se mantiene: cambiarla rompería el juego entero;
los sistemas (chunks, regiones, zonas) se aplican a
nuestra escala.
1. Módulos (game/data/ui/audio/world/save/net): la
   estructura de scripts/refactor/ ya los refleja; falta
   el módulo net (ver 8).
2. Audio procedural: tonos generados ya existen
   (GameModeManager); falta música por bioma (escalas
   pentatónicas) y foley por material (foley.json).
3. Espacio: bloque 1³, chunk 32², columna, región
   1024² para guardado (SaveV2 ya guarda por regiones
   16×16; se documenta la equivalencia de escala).
   Terreno: clima/bioma por ruido, ríos, caminos,
   ciudades, mazmorras, cuevas en 3 estratos con 5
   temas, vetas por bandas de profundidad, 80+
   estructuras, EditStore (diferencial, ya existe).
4. Render: color por vértice sin atlas UV (ya existe
   en MultiMesh); luz coloreada por bloques emisivos
   (antorcha 14, cristal 11, portal 8: ya en catálogo).
5. Bloques 160+: catálogo en datos (blocks.json) con
   nombre, color, dureza, forma, luz y sonido; todos
   colocables desde pestañas por categoría; vetas
   subterráneas por bandas en el terreno.
6. Criaturas 246: HECHO (data/creatures.json +
   creature_catalog.gd + tests): 22 pacíficas + 20
   depredadores + 40 fantásticas/jefes + 50 de
   facciones (10×5 roles) + 106 variantes por bioma
   + 8 únicos = 246. Falta: IA completa (temperamentos,
   manadas, huida, persecución, hordas con FlowField),
   animación por arquetipos (quadruped/biped/avian/
   serpent/arachnid/aquatic/hopper, ya en datos),
   domesticación con comida favorita (5.4) y monturas.
7. Avatar: 6 razas con estadísticas y pasivas
   (humano, elfo, enano, orco, frogman, gólem);
   forja de escultura de armas (cubos materiales y
   espíritus); personaje separado del mundo
   (personaje.json: nivel, EXP, monedas, habilidades,
   equipo, mascota activa).
8. Jugador: AABB 0.60×1.70, ojo 1.52, caminar 5.5,
   sprint 8.25, agachado 2.75, trepar 4.5, nadar 4.2,
   gravedad 26, salto 9.0, esquiva con i-frames, ala
   delta + térmicas; vitales (salud, maná, estamina,
   oxígeno, temperatura); TouchHud con editor (mover
   botones, tamaño, opacidad); artesanía por 8
   estaciones (mano, carpintería, horno, yunque,
   telar, alquimia, cocina/fogata, forja de escultura).
9. Multijugador LAN: UDP puerto 27016, ReliableLink,
   descubrimiento multicast, 1-7 jugadores,
   transferencia de ediciones al entrar y paquetes de
   estado (jugadores, mascotas, barcas, hordas, cofres,
   cultivos, combate). Verificación real: necesita 2
   dispositivos del usuario; en VM solo se prueba el
   protocolo, no la partida entre dos pantallas.
10. Guía práctica 1-7: ya aplicada (color por vértice,
    guardado diferencial, criaturas modulares con
    animación sinusoidal, anillos de distancia,
    domesticación por cercanía+comida, auto-step y ala
    delta, personaje separado).
