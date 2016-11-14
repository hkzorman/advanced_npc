# advanced_npc
Advanced NPC framework for Minetest, based on mobs_redo

Habilidades:
- Encontrar puertas, abrirlas y cerrarlas
- Subir escaleras
- Tener multiples conversaciones, y posibilidad de tener variables que indiquen distintos momentos para distintas conversaciones
- Intercambiar productos con el jugador
  - A cambio de algo
  - Como regalo
- Tener objetos favoritos y despreciados, en distintas etapas
- Tener una puntuacion de relacion con el jugador y con otros NPC
- Poder enamorarse de un jugador/NPC
- Estar relacionados como familia con jugador o NPC
- Hacer diferentes tareas durante el dia, segun la hora: (ejemplos)
   - Día: Tener oficio
      - Granjero
      - Minero
      - Leñador
   - Noche: Estar en la cama 
   - Tarde: Vender/comprar artículos
- Pueda ir a distintas localizaciones
- Sentirse atraido a miembros de algun grupo en particular (de manera que puedan reunirse)
- Sentirse atraido a ciertos nodos en ciertas horas del dia (de manera que puedan reunirse)
- Capaces de domesticar y ser dueños de aninales
- Capaces de ser dueños de cofres, puertas y llaves 
- Capaces de montar y correr en trenes, al igual que en caballo
- Construir algo en equipo
- Tener edades: niño, adulto, anciano


Detalles de implementacion
- Artículos favoritos/despreciados:
   - Escoger 2 artículos al azar; 1 muy apreciado/odiado, 1 apreciado un poco/odiado un poco. El primero afectará el nivel de relación en una cantidad ±2x, el segundo ±x
   - Estos artículos serán escogidos de acuerdo al sexo, y a la edad del NPC, y estarán definidos en una tabla
   - Un cambio de edad causará un cambio en estos artículos

- Relaciones
   - Solo pueden ocurrir entre caracteres de sexo opuesto
   - Pueden ocurrir entre jugador y NPC o NPC y NPC
   - Los regalos diarios afectan la puntuación de relación
   - Se compone de 6 niveles. Cada nivel el NPC dirá comentarios más afectusos (si se trata de un jugador)
   - Al alcanzar el 6to nivel, el NPC no podá ser afectado por regalos. Si el jugador le obsequia un artículo de compromiso al NPC, el NPC se casará en algún momento (no lo aceptará de lae primera)
   - Al casarse, el NPC seguirá ciertas ordenes (aunque no siempre, del 1-10 donde el 1 es no lo hará y el 10 es lo hará) del jugador/NPC:
      - Seguir (9)
      - Quedarse en un lugar (9)
      - Preparar comida (8)
      - Comprar/vender algún objeto (8)
      - Tomar un oficio (7, si el NPC ya tenía oficio entonces 4)
      - 
   - ���