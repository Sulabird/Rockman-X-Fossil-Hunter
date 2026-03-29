import std/[os, sequtils, strutils, strformat, math]
import kirpi, entities

const
  screenWidth: int = 1920
  screenHeight: int = 1080
  bits: int = 64
  gravity: float = 1.5

var 
  textures: seq[Texture]
  textureList: seq[seq[string]]
  scrollPos: array[2, float]
  startHeight: float
  map: seq[string]
  scrollHorizontal: array[2, bool]
  scrollVertical: array[2, bool]
  scrollSet: array[2, float]
  upperX, upperY: int
  eSeq: seq[entity]
  slide: float
  direction: string
  scrollDirection: bool
  dashMult: float
  displacement: int

let walkTextures: seq[tuple[kind: PathComponent, path: string]] = 
  toSeq(walkDir("textures", relative = true))

proc match(search: string, option: int): Texture =
  for i in 0 .. textureList.len - 1:
    if textureList[i][option] == search:
      return textures[i]

proc loadMap(name: string) =
  map = readFile("maps/" & name & "/main").splitLines
  upperX = map[0].len - 1
  upperY = map.len - 2

  for i in 0 .. upperY:
    if map[i][0] == 'A':
      startHeight = (screenHeight - bits * (i + 1)).toFloat
      break

  let 
    loadTextures: seq[string] = 
      readFile("maps/" & name & "/textures").splitLines
    startPosition: seq[string] =
      readFile("maps/" & name & "/start").splitLines[0].split(',')
  
  eSeq[0].pos[0] = startPosition[0].parseFloat * bits.toFloat
  eSeq[0].pos[1] = startHeight + startPosition[1].parseFloat * bits.toFloat
  scrollSet[1] = screenHeight div 2
  if startHeight == 0: 
    scrollSet[1] = eSeq[0].pos[1] + eSeq[0].size[1]

  scrollSet[0] = screenWidth div 2
  textures.setLen(loadTextures.len - 1)

  for i in 0 .. loadTextures.len - 2:
    let tileMatch: seq[string] = loadTextures[i].split('|')
    for j in 0 .. walkTextures.len - 1:
      if walkTextures[j][1].split('.')[0] == tileMatch[1]:
        textures[i] = newTexture("textures/" & walkTextures[j][1])
        textureList.add(tileMatch)
        break

proc setScrollBounds(i: int) =
  if i == 0:
    let lowerScrollX: float = scrollPos[0] / bits.toFloat
    if lowerScrollX <= 0: scrollHorizontal[0] = false
    else: scrollHorizontal[0] = true

    let upperScrollX: float = lowerScrollX + screenWidth.toFloat / bits.toFloat
    if upperScrollX >= upperX.toFloat + 1: scrollHorizontal[1] = false
    else: scrollHorizontal[1] = true

  else:
    let lowerScrollY: float = (scrollPos[1] - startHeight) / bits.toFloat
    if lowerScrollY <= 0: scrollVertical[0] = false
    else: scrollVertical[0] = true

    let upperScrollY: float = lowerScrollY + screenHeight / bits
    if upperScrollY >= upperY.toFloat + 1: scrollVertical[1] = false
    else: scrollVertical[1] = true

proc drawMap(name: string) =
  var 
    lowerXBound: int = scrollPos[0].toInt div bits
    upperXBound: int = lowerXBound + screenWidth div bits + 1
    lowerYBound: int = (scrollPos[1] - startHeight).toInt div bits
    upperYBound: int = lowerYBound + screenHeight div bits + 1

  if lowerXBound < 0: lowerXBound = 0
  if upperXBound > upperX: upperXBound = upperX
  if lowerYBound < 0: lowerYBound = 0
  if upperYBound > upperY: upperYBound = upperY

  for y in lowerYBound .. upperYBound:
    for x in lowerXBound .. upperXBound:
      let tile = match(&"{map[y][x]}", 0)
      let tileY: float = startHeight + (y.toFloat * bits.toFloat)
      let tileX: float = x.toFloat * bits.toFloat
      draw(tile, tileX - scrollPos[0], tileY - scrollPos[1])
  
  for id in 0 .. eSeq.len - 1:
    draw(
      match(eSeq[id].textureName, 1), 
      eSeq[id].pos[0] - scrollPos[0], 
      eSeq[id].pos[1] - scrollPos[1]
    )

proc checkTile(x, y: int): char =
  # This will include adjusting tile hitboxes eventually
  let my: int = (y / bits).trunc.toInt
  let mx: int = (x / bits).trunc.toInt
  if my >= 0 and my < map.len and mx >= 0 and mx < map[0].len:
    return map[(y / bits).trunc.toInt][(x / bits).trunc.toInt]
  else:
    return '*'

proc collision(id: int, direction: string, hit: bool): bool =
  let 
    posX: float = eSeq[id].pos[0]
    posY: float = eSeq[id].pos[1] - startHeight
    lowerYBound: int = (posY + eSeq[id].colY1).toInt
    upperYBound: int = (posY + eSeq[id].colY2).toInt - 1
    lowerXBound: int = (posX + eSeq[id].colX1).toInt
    upperXBound: int = (posX + eSeq[id].colX2).toInt - 1

  case direction
  of "right":
    for i in lowerYBound .. upperYBound:
      if checkTile((posX + eSeq[id].colX2).toInt, i) != ' ':
        if hit == true:
          eSeq[id].vel[0] = 0
          if eSeq[id].accel[0] > 0:
            eSeq[id].accel[0] = 0
        return true

  of "left":
    for i in lowerYBound .. upperYBound:
      if checkTile((posX + eSeq[id].colX1).toInt - 1, i) != ' ':
        if hit == true:
          eSeq[id].vel[0] = 0
          if eSeq[id].accel[0] < 0:
            eSeq[id].accel[0] = 0
        return true

  of "down":
    for i in lowerXBound .. upperXBound:
      if checkTile(i, (posY + eSeq[id].colY2).toInt) != ' ':
        eSeq[id].isGrounded = true
        if hit == true:
          eSeq[id].vel[1] = 0
          if eSeq[id].accel[1] > 0:
            eSeq[id].accel[1] = 0
        return true

  of "up":
    for i in lowerXBound .. upperXBound:
      if checkTile(i, (posY + eSeq[id].colY1).toInt - 1) != ' ':
        if hit == true:
          eSeq[id].vel[1] = 0
          if eSeq[id].accel[1] < 0:
            eSeq[id].accel[1] = 0
        return true


var k: float
var z: int
proc move(id: int, scroll: bool): bool =
  eSeq[id].isGrounded = collision(id, "down", false)
  if eSeq[id].variant == "projectile":
    if eSeq[id].accel[0] == 0:
      eSeq.delete(id)
      displacement += 1
      return true

  for i in 0 .. 1:
    var accel: float = eSeq[id].accel[i]
    if accel.abs != 0:
      let accelDirection: float = accel / accel.abs
      let maxAccel: float = eSeq[id].maxAccel[i]
      if accel.abs > maxAccel:
        accel = maxAccel * accelDirection
        eSeq[id].accel[i] = accel

    eSeq[id].vel[i] += accel.trunc.toInt
    var vel: int = eSeq[id].vel[i]
    if vel.abs != 0: 
      let velDirection: int = vel div vel.abs
      var maxVel: int = eSeq[id].maxVel[i]
      if vel.abs > maxVel:
        eSeq[id].accel[i] = 0
        vel = maxVel * velDirection
        eSeq[id].vel[i] = vel

      if vel < 0:
        if i == 0:
          eSeq[id].facing = -1
          direction = "left"
        else: direction = "up"
        k = -1
        z = 0

      else:
        if i == 0:
          eSeq[id].facing = 1
          direction = "right"
        else: direction = "down"
        k = 1
        z = 1
        
      for j in 0 .. vel.abs:
        setScrollBounds(i)
        if i == 0: scrollDirection = scrollHorizontal[z]
        else: scrollDirection = scrollVertical[z]
        if collision(id, direction, true) == false:
          if scroll == true:
            if scrollDirection == true:
              if k == -1:
                if eSeq[id].pos[i] + (eSeq[id].size[i] / 2) - scrollPos[i] <= scrollSet[i]:
                  scrollPos[i] -= 1
              else:
                if eSeq[id].pos[i] + (eSeq[id].size[i] / 2) - scrollPos[i] >= scrollSet[i]:
                  scrollPos[i] += 1            
          eSeq[id].pos[i] += k

proc moveAll(scrollTarget: int) =
  displacement = 0
  for id in 0 .. eSeq.len - 1:
    if id == scrollTarget: discard move(id - displacement, true)
    else: discard move(id - displacement, false)
 
proc checkSlide(direction: string): bool =
  if collision(0, direction, true) == true:
    if eSeq[0].isGrounded == false:
      eSeq[0].isGrounded = true
      slide = 0.05
      if isKeyPressed(C):
        slide = 1
        eSeq[0].isGrounded = false
        eSeq[0].jumpBuffer -= 1
        case direction
        of "right":
          eSeq[0].accel[0] -= 1.5 * dashMult
        of "left":
          eSeq[0].accel[0] += 1.5 * dashMult
      if eSeq[0].vel[1] < 0: eSeq[0].vel[1] = 0
      if eSeq[0].accel[1] < 0: eSeq[0].accel[1] = 0
    return true

proc load() =
  eSeq.add(createEntity([0.0, 0.0], "Rockman_X"))
  storeAdd("maxVelX", eSeq[0].maxVel[0].toFloat)
  storeAdd("maxVelY", eSeq[0].maxVel[1].toFloat)
  storeAdd("maxAccelX", eSeq[0].maxAccel[0])
  loadMap("test")

proc update(dt: float) =
  if eSeq[0].isGrounded == true or slide != 1:
    if isKeyDown(V) and eSeq[0].dashBuffer > 0:
      dashMult = 2
      eSeq[0].maxVel[0] = 2 * storeMatching("maxVelX").toInt
      eSeq[0].maxAccel[0] = 2 * storeMatching("maxAccelX")
      if slide == 1:
        eSeq[0].accel[0] += storeMatching("maxAccelX") * eSeq[0].facing
        eSeq[0].dashBuffer -= 1
    else:
      if not isKeyDown(V):
        eSeq[0].dashBuffer = eSeq[0].maxDashBuffer
      dashMult = 1
      eSeq[0].maxVel[0] = storeMatching("maxVelX").toInt
      eSeq[0].maxAccel[0] = storeMatching("maxAccelX")

  if isKeyDown(RIGHT):
    if checkSlide("right") == false:
      if eSeq[0].isGrounded == true:
        slide = 1 
        if eSeq[0].vel[1] < 0: eSeq[0].vel[1] = 0
        if eSeq[0].accel[1] < 0: eSeq[0].accel[1] = 0 
        eSeq[0].accel[0] += 2 * dashMult
      elif slide != 1:
        slide  = 1
        eSeq[0].accel[0] += 1 * dashMult
      else:
        eSeq[0].accel[0] += 0.3 * dashMult
    else:
      eSeq[0].facing = -1

  elif not isKeyDown(LEFT):
    slide = 1
    if eSeq[0].vel[0] > 0:
      eSeq[0].accel[0] -= 5
      if eSeq[0].vel[0] + eSeq[0].accel[0].trunc.toInt <= 0:
        eSeq[0].accel[0] = 0
        eSeq[0].vel[0] = 0

  if isKeyDown(LEFT):
    if checkSlide("left") == false:
      if eSeq[0].isGrounded == true:
        slide = 1
        if eSeq[0].vel[1] > 0: eSeq[0].vel[1] = 0
        if eSeq[0].accel[1] > 0: eSeq[0].accel[1] = 0
        eSeq[0].accel[0] -= 2 * dashMult
      elif slide != 1:
        slide = 1
        eSeq[0].accel[0] -= 1 * dashMult
      else:
        eSeq[0].accel[0] -= 0.3 * dashMult
    else:
      eSeq[0].facing = 1

  elif not isKeyDown(RIGHT):
    slide = 1
    if eSeq[0].vel[0] < 0:
      eSeq[0].accel[0] += 2
      if eSeq[0].vel[0] + eSeq[0].accel[0].trunc.toInt >= 0:
        eSeq[0].accel[0] = 0
        eSeq[0].vel[0] = 0

  if isKeyDown(C):
    if eSeq[0].isGrounded == true or eSeq[0].jumpBuffer < eSeq[0].maxJumpBuffer:
      if eSeq[0].jumpBuffer > 0:
        eSeq[0].accel[1] -= 20
        eSeq[0].jumpBuffer -= 1
      else:
        eSeq[0].accel[1] = gravity * slide + 1
  else:
    if eSeq[0].isGrounded == true:
      eSeq[0].jumpBuffer = eSeq[0].maxJumpBuffer
    else:
      eSeq[0].jumpBuffer = 0
    eSeq[0].accel[1] = gravity * slide + 1

  if isKeyPressed(X):
    eSeq.add(createEntity(eSeq[0].pos, "lemonShot"))
    eSeq[^1].accel[0] = eSeq[0].facing

  if isKeyPressed(ESCAPE):
    quit()
 
  eSeq[0].maxVel[1] = (storeMatching("maxVelY") * slide).toInt + 1

  #move(0, true)
  moveAll(0)

proc draw() =
  clear(Black)
  setColor(White)
  drawMap("test")

proc config(appSettings:var AppSettings) =
  appSettings.window.width = screenWidth
  appSettings.window.height = screenHeight
  appSettings.window.fullscreen = true

run("Rockman X Fossil Hunter",load,update,draw,config)
