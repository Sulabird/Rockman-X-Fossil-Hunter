import std/[os, sequtils, strutils, strformat, math]
import kirpi, entities

const
  bits: int = 16
  pFact: float = bits.toFloat / 64
  gravity: float = 1.5 * pFact
  directions: array[4, string] = ["up", "down", "left", "right"]

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
  eSeq: seq[base]
  slide, oldSlide, oldFacing: float
  direction: string
  scrollDirection, lockDash, moved, fire: bool
  dashMult, k: float
  displacement, z: int
  screenHeight, screenWidth: int

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
  scrollSet[1] = screenHeight / 2
  if startHeight == 0: 
    scrollSet[1] = eSeq[0].pos[1] + eSeq[0].size[1]

  scrollSet[0] = screenWidth / 2
  textures.setLen(loadTextures.len - 1)

  for i in 0 .. loadTextures.len - 2:
    let tileMatch: seq[string] = loadTextures[i].split('|')
    for j in 0 .. walkTextures.len - 1:
      if walkTextures[j][1].split('.')[0] == tileMatch[1]:
        textures[i] = newTexture("textures/" & walkTextures[j][1], Nearest)
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

proc collision(id: int, direction: string, hit: bool, ovr: array[4, int]): bool =
  let 
    posX: float = eSeq[id].pos[0]
    posY: float = eSeq[id].pos[1] - startHeight
    lowerYBound: int = (posY + eSeq[id].colY1).toInt + ovr[0]
    upperYBound: int = (posY + eSeq[id].colY2).toInt - 1 + ovr[1]

  var lowerXBound: int = (posX + eSeq[id].colX1).toInt + ovr[2]
  var upperXBound: int = (posX + eSeq[id].colX2).toInt - 1 + ovr[3]

  case direction
  of "right":
    for i in lowerYBound .. upperYBound:
      if checkTile((posX + eSeq[id].colX2).toInt, i) != ' ':
        if hit:
          eSeq[id].vel[0] = 0
          if eSeq[id].accel[0] > 0:
            eSeq[id].accel[0] = 0
        eSeq[id].activeCollision.right = true
        return true
    eSeq[id].activeCollision.right = false

  of "left":
    for i in lowerYBound .. upperYBound:
      if checkTile((posX + eSeq[id].colX1).toInt - 1, i) != ' ':
        if hit:
          eSeq[id].vel[0] = 0
          if eSeq[id].accel[0] < 0:
            eSeq[id].accel[0] = 0
        eSeq[id].activeCollision.left = true
        return true
    eSeq[id].activeCollision.left = false

  of "down":
    var phantom: bool
    if id == 0 and hit and slide == 1:
      lowerXBound -= 1
      upperXBound += 1
      phantom = true

    for i in lowerXBound .. upperXBound:
      var skip: bool
      if checkTile(i, (posY + eSeq[id].colY2).toInt) != ' ':
        if phantom == true:
          if i - lowerXBound < 1 or i >= upperXBound - 1:
            if checkTile(i, (posY + eSeq[id].colY2).toInt - 1) != ' ':
              skip = true
        
        if skip == false:
          if hit:
            eSeq[id].vel[1] = 0
            if eSeq[id].accel[1] > 0:
              eSeq[id].accel[1] = 0
          eSeq[id].activeCollision.down = true
          return true
    eSeq[id].activeCollision.down = false

  of "up":
    for i in lowerXBound .. upperXBound:
      if checkTile(i, (posY + eSeq[id].colY1).toInt - 1) != ' ':
        if hit:
          eSeq[id].vel[1] = 0
          if eSeq[id].accel[1] < 0:
            eSeq[id].accel[1] = 0
        eSeq[id].activeCollision.up = true
        return true
    eSeq[id].activeCollision.up = false

proc move(id: int, scroll: bool) =
  for i in 0 .. 1:
    var accel: float = eSeq[id].accel[i]
    if accel.abs != 0:
      let accelDirection: float = accel / accel.abs
      let maxAccel: float = eSeq[id].maxAccel[i]
      if accel.abs > maxAccel:
        accel = maxAccel * accelDirection
        eSeq[id].accel[i] = accel

    eSeq[id].vel[i] += accel
    var vel: int = eSeq[id].vel[i].trunc.toInt
    var checkedCollision: array[4, int]
    if vel.abs != 0:
      let velDirection: int = vel div vel.abs
      var maxVel: int = eSeq[id].maxVel[i].toInt
      if vel.abs > maxVel:
        eSeq[id].accel[i] = 0
        vel = maxVel * velDirection
        eSeq[id].vel[i] = vel.toFloat

      if vel < 0:
        if i == 0:
          eSeq[id].facing = -1
          direction = "left"
          checkedCollision[2] = 1
        else: 
          direction = "up"
          checkedCollision[0] = 1
        k = -1
        z = 0

      else:
        if i == 0:
          eSeq[id].facing = 1
          direction = "right"
          checkedCollision[3] = 1
        else: 
          direction = "down"
          checkedCollision[1] = 1
        k = 1
        z = 1
        
      for j in 0 .. vel.abs:
        setScrollBounds(i)
        if i == 0: scrollDirection = scrollHorizontal[z]
        else: scrollDirection = scrollVertical[z]
        if collision(id, direction, true, [0,0,0,0]) == false:
          if scroll == true:
            if scrollDirection == true:
              if k == -1:
                if eSeq[id].pos[i] + (eSeq[id].size[i] / 2) - scrollPos[i] <= scrollSet[i]:
                  scrollPos[i] -= 1
              else:
                if eSeq[id].pos[i] + (eSeq[id].size[i] / 2) - scrollPos[i] >= scrollSet[i]:
                  scrollPos[i] += 1            
          eSeq[id].pos[i] += k
          moved = true
        else:
          eSeq[id].vel[i] = 0
          break

    if moved:
      moved = false
      for i in 0 .. 3:
        if checkedCollision[i] == 0:
          discard collision(id, directions[i], false, [0,0,0,0])

proc updateAll(scrollTarget: int) =
  displacement = 0
  for id in 0 .. eSeq.len - 1:
    let eDex: int = id - displacement
    let variant: string = eSeq[eDex].variant

    var skip: bool
    if variant == "projectile":
      if eSeq[eDex].accel[0] == 0:
        if eSeq[eDex].vel[0] == 0:
          eSeq.delete(eDex)
          displacement += 1
          skip = true

    if skip == false:
      var scrollScreen: bool
      if id == scrollTarget: scrollScreen = true
      move(eDex, scrollScreen)

    if variant == "player":
      let groundStatus: bool = eSeq[eDex].activeCollision.down
      var air: bool
      if player(eSeq[eDex]).isGrounded != groundStatus:
        air = true
        if player(eSeq[eDex]).isGrounded == false:
          player(eSeq[eDex]).dashBuffer = player(eSeq[eDex]).maxDashBuffer
        player(eSeq[eDex]).isGrounded = groundStatus

      var checkFire, checkLeft, checkRight, force: bool
      force = updateFire()
      if eSeq[eDex].vel[0] != 0 and groundStatus: force = updateWalk()
      else: resetWalk()

      if eDex == 0 and force == false:
        checkFire = fire
        if eSeq[0].facing != oldFacing: force = true
        if slide != oldSlide: force = true

      if eSeq[eDex].facing == 1 and eSeq[eDex].activeCollision.right == false: checkRight = true
      if eSeq[eDex].facing == -1 and eSeq[eDex].activeCollision.left == false: checkLeft = true

      if checkRight or checkLeft or eSeq[eDex].vel[0].trunc == 0:
        if force or air or checkFire:
          let newName: string = directionalSprites(
            eSeq[eDex].textureName,
            eSeq[eDex].facing,
            eSeq[eDex].vel[0],
            groundStatus,
            fire,
            slide
          )

          if eSeq[eDex].textureName != newName:
            eSeq[eDex].textureName = newName
            let newBox: array[4, float] = updateCollision(newName)
            eSeq[eDex].colX1 = newBox[0]
            eSeq[eDex].colY1 = newBox[1]
            eSeq[eDex].colX2 = newBox[2]
            eSeq[eDex].colY2 = newBox[3]
 
proc checkSlide(direction: string): bool =
  if eSeq[0].activeCollision.down == true:
    return false

  if isKeyDown(C) and player(eSeq[0]).jumpBuffer != player(eSeq[0]).maxJumpBuffer:
    return false

  if collision(0, direction, true, [24,0,0,0]) == true:
    if player(eSeq[0]).isGrounded == false:
      player(eSeq[0]).isGrounded = true
      slide = 0.3
      if isKeyPressed(C):
        slide = 1
        player(eSeq[0]).isGrounded = false
        player(eSeq[0]).jumpBuffer -= 1
        case direction
        of "right": eSeq[0].accel[0] -= 1
        of "left": eSeq[0].accel[0] += 1
      if eSeq[0].vel[1] < 0: eSeq[0].vel[1] = 0
      if eSeq[0].accel[1] < 0: eSeq[0].accel[1] = 0

    return true

proc load() =
  setFullScreenMode(true)

  let
    w: float = getWidth()
    h: float =  getHeight()
    sx: float = w / 480
    sy: float = h / 270

  screenWidth = (w / sx).toInt
  screenHeight = (h / sy).toInt

  setFullScreenMode(false)

  scale(sx,sy)
  eSeq.add(createEntity([0.0, 0.0], "entities/RockmanX", pFact))
  storeAdd("maxVelX", eSeq[0].maxVel[0])
  storeAdd("maxVelY", eSeq[0].maxVel[1])
  storeAdd("maxAccelX", eSeq[0].maxAccel[0])
  loadMap("test")

proc update(dt: float) =
  oldSlide = slide
  oldFacing = eSeq[0].facing

  if player(eSeq[0]).isGrounded == true or slide != 1:
    if isKeyPressed(V):
      lockDash = false

    if isKeyDown(V) and player(eSeq[0]).dashBuffer > 0 and lockDash == false or isKeyDown(C) and isKeyDown(V):
      if dashMult != 1.5:
        dashMult = 1.5
        eSeq[0].maxVel[0] = 1.5 * storeMatching("maxVelX")
        eSeq[0].maxAccel[0] = 1.5 * storeMatching("maxAccelX")
      if lockDash == false:
        if slide == 1:
          eSeq[0].accel[0] += storeMatching("maxAccelX") * eSeq[0].facing
          player(eSeq[0]).dashBuffer -= 1
    else:
      if not isKeyDown(V):
        player(eSeq[0]).dashBuffer = player(eSeq[0]).maxDashBuffer
      if dashMult != 1:
        dashMult = 1
        eSeq[0].maxVel[0] = storeMatching("maxVelX")
        eSeq[0].maxAccel[0] = storeMatching("maxAccelX")
  else:
    if isKeyDown(V): lockDash = true
    else: lockDash = false

  if isKeyDown(RIGHT):
    if checkSlide("right") == false:
      eSeq[0].facing = 1
      if player(eSeq[0]).isGrounded == true:
        slide = 1 
        eSeq[0].accel[0] += 2 * dashMult * pFact
      elif slide != 1: slide = 1
      else: eSeq[0].accel[0] += 0.2 * dashMult * pFact
    else: eSeq[0].facing = -1

  elif not isKeyDown(LEFT):
    slide = 1
    if eSeq[0].vel[0] > 0:
      if player(eSeq[0]).isGrounded == true: eSeq[0].accel[0] -= pFact
      else: eSeq[0].accel[0] -= pFact / (2 * dashMult)
      if eSeq[0].vel[0] + eSeq[0].accel[0] <= 0:
        eSeq[0].accel[0] = 0
        eSeq[0].vel[0] = 0

  if isKeyDown(LEFT):
    if checkSlide("left") == false:
      eSeq[0].facing = -1
      if player(eSeq[0]).isGrounded == true:
        slide = 1
        eSeq[0].accel[0] -= 2 * dashMult * pFact
      elif slide != 1: slide = 1
      else: eSeq[0].accel[0] -= 0.2 * dashMult * pFact
    else: eSeq[0].facing = 1

  elif not isKeyDown(RIGHT):
    slide = 1
    if eSeq[0].vel[0] < 0:
      if player(eSeq[0]).isGrounded == true: eSeq[0].accel[0] += pFact
      else: eSeq[0].accel[0] += pFact / (2 * dashMult)
      if eSeq[0].vel[0] + eSeq[0].accel[0] >= 0:
        eSeq[0].accel[0] = 0
        eSeq[0].vel[0] = 0

  if isKeyDown(C):
    if player(eSeq[0]).isGrounded == true or player(eSeq[0]).jumpBuffer < player(eSeq[0]).maxJumpBuffer:
      if player(eSeq[0]).jumpBuffer > 0:
        eSeq[0].accel[1] -= 1.2 * (player(eSeq[0]).jumpBuffer / player(eSeq[0]).maxJumpBuffer)
        player(eSeq[0]).jumpBuffer -= 1
      else:
        player(eSeq[0]).dashBuffer = 0
        eSeq[0].accel[1] = gravity * slide
  else:
    if player(eSeq[0]).isGrounded == true:
      player(eSeq[0]).jumpBuffer = player(eSeq[0]).maxJumpBuffer
    else:
      player(eSeq[0]).dashBuffer = 0
      player(eSeq[0]).jumpBuffer = 0
    eSeq[0].accel[1] = gravity * slide

  if isKeyPressed(X):
    fire = true
    var px: float = eSeq[0].pos[0]
    if eSeq[0].facing == 1:
      px += bits.toFloat + 24
    else:
      px -= bits.toFloat - 8
    let py: float = eSeq[0].pos[1] + bits / 2 + 16
    eSeq.add(createEntity([px, py], "projectiles/lemonShot", pFact))
    eSeq[^1].accel[0] = eSeq[0].facing
  else:
    fire = false

  if isKeyPressed(ESCAPE):
    quit()
 
  eSeq[0].maxVel[1] = storeMatching("maxVelY") * slide

  updateAll(0)

proc draw() =
  clear(Black)
  setColor(White)
  drawMap("test")

proc config(appSettings:var AppSettings) =
  appSettings.window.width = screenWidth
  appSettings.window.height = screenHeight
  appSettings.window.borderless = true

run("Rockman X Fossil Hunter",load,update,draw,config)
