import std/[os, sequtils, strutils, strformat, math]
import kirpi

const
  screenWidth: int = 800
  screenHeight: int = 600
  bits: int = 64
  gravity: float = 1.5

type entity = object
  textureName: string
  posX, posY: float
  colX1, colY1: float
  colX2, colY2: float
  accelX, accelY: float
  velX, velY: int
  maxAccelX, maxAccelY: float
  maxVelX, maxVelY: int
  isGrounded: bool
  jumpBuffer: int
  maxJumpBuffer: int

var 
  accelXMult, accelYMult: int = 1
  textures: seq[Texture]
  textureList: seq[seq[string]]
  scrollX, scrollY: float
  startHeight: float
  map: seq[string]
  scrollLeft, scrollRight: bool
  scrollUp, scrollDown: bool
  scrollWidth: float
  scrollHeight: float
  upperX, upperY: int
  entities: seq[entity]
  blankEntitiy: entity
  slide: float

entities.add(blankEntitiy)
entities[0].textureName = "Rockman_X"
entities[0].colX1 = 0
entities[0].colY1 = 6
entities[0].colX2 = 64
entities[0].colY2 = 128
entities[0].jumpBuffer = 15
entities[0].maxAccelX = 5
entities[0].maxAccelY = 50
entities[0].maxVelX = 5
entities[0].maxVelY = 10
entities[0].maxjumpBuffer = 15

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
  
  entities[0].posX = startPosition[0].parseFloat * bits.toFloat
  entities[0].posY = startHeight + startPosition[1].parseFloat * bits.toFloat
  scrollHeight = screenHeight div 2
  if startHeight == 0: 
    scrollHeight = entities[0].posY + 2 * bits.toFloat

  scrollWidth = screenWidth div 2
  textures.setLen(loadTextures.len - 1)

  for i in 0 .. loadTextures.len - 2:
    let tileMatch: seq[string] = loadTextures[i].split('|')
    for j in 0 .. walkTextures.len - 1:
      if walkTextures[j][1].split('.')[0] == tileMatch[1]:
        textures[i] = newTexture("textures/" & walkTextures[j][1])
        textureList.add(tileMatch)
        break

proc setScrollBounds(x, y: bool) =
  if x == true:
    let lowerScrollX: float = scrollX / bits.toFloat
    if lowerScrollX <= 0: scrollLeft = false
    else: scrollLeft = true

    let upperScrollX: float = lowerScrollX + screenWidth.toFloat / bits.toFloat
    if upperScrollX >= upperX.toFloat + 1: scrollRight = false
    else: scrollRight = true

  if y == true:
    let lowerScrollY: float = (scrollY - startHeight) / bits.toFloat
    if lowerScrollY <= 0: scrollUp = false
    else: scrollUp = true

    let upperScrollY: float = lowerScrollY + screenHeight / bits
    if upperScrollY >= upperY.toFloat + 1: scrollDown = false
    else: scrollDown = true

proc drawMap(name: string) =
  var 
    lowerXBound: int = scrollX.toInt div bits
    upperXBound: int = lowerXBound + screenWidth div bits + 1
    lowerYBound: int = (scrollY - startHeight).toInt div bits
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
      draw(tile, tileX - scrollX, tileY - scrollY)
  
  for id in 0 .. entities.len - 1:
    draw(
      match(entities[id].textureName, 1), 
      entities[id].posX - scrollX, 
      entities[id].posY - scrollY
    )

proc checkTile(x, y: int): char =
  # This will include adjusting tile hitboxes eventually
  return map[(y / bits).trunc.toInt][(x / bits).trunc.toInt]

proc collision(id: int, direction: string, hit: bool): bool =
  let 
    posX: float = entities[id].posX
    posY: float = entities[id].posY - startHeight
    lowerYBound: int = (posY + entities[id].colY1).toInt
    upperYBound: int = (posY + entities[id].colY2).toInt - 1
    lowerXBound: int = (posX + entities[id].colX1).toInt
    upperXBound: int = (posX + entities[id].colX2).toInt - 1

  case direction
  of "right":
    for i in lowerYBound .. upperYBound:
      if checkTile((posX + entities[id].colX2).toInt, i) != ' ':
        if hit == true:
          entities[id].velX = 0
          if entities[id].accelX > 0:
            entities[id].accelX = 0
        return true

  of "left":
    for i in lowerYBound .. upperYBound:
      if checkTile((posX + entities[id].colX1).toInt - 1, i) != ' ':
        if hit == true:
          entities[id].velX = 0
          if entities[id].accelX < 0:
            entities[id].accelX = 0
        return true

  of "down":
    for i in lowerXBound .. upperXBound:
      if checkTile(i, (posY + entities[id].colY2).toInt) != ' ':
        entities[id].isGrounded = true
        if hit == true:
          entities[id].velY = 0
          if entities[id].accelY < 0:
            entities[id].accelY = 0
        return true

  of "up":
    for i in lowerXBound .. upperXBound:
      if checkTile(i, (posY + entities[id].colY1).toInt - 1) != ' ':
        if hit == true:
          entities[id].velY = 0
          if entities[id].accelY < 0:
            entities[id].accelY = 0
        return true

proc move(id: int, scroll: bool) =
  entities[id].isGrounded = collision(id, "down", false)

  var accelX: float = entities[id].accelX
  var accelY: float = entities[id].accelY

  if accelX.abs != 0:
    let accelXDirection: float = accelX / accelX.abs
    let maxAccelX: float = entities[id].maxAccelX
    if accelX.abs > maxAccelX: 
      accelX = maxAccelX * accelXDirection
      entities[id].accelX = accelX
 
  if accelY.abs != 0:
    let accelYDirection: float = accelY / accelY.abs
    let maxAccelY: float = entities[id].maxAccelY
    if accelY.abs > maxAccelY:
      accelY = maxAccelY * accelYDirection
      entities[id].accelY = accelY

  entities[id].velX += accelX.trunc.toInt * accelXMult
  entities[id].velY += accelY.trunc.toInt * accelYMult

  var velX: int = entities[id].velX
  var velY: int = entities[id].velY

  if velX.abs != 0: 
    let velXDirection: int = velX div velX.abs
    var maxVelX: int = entities[id].maxVelX
    if velX.abs > maxVelX:
      velX = maxVelX * velXDirection
      entities[id].velX = velX

    for i in 0 .. velX.abs:
      setScrollBounds(true, false)
      if velX > 0:
        if collision(id, "right", true) == false:
          if scroll == true:
            if scrollRight == true:
              if entities[id].posX + bits div 2 - scrollX >= scrollWidth:
                scrollX += 1
          entities[id].posX += 1

      if velX < 0:
        if collision(id, "left", true) == false:
          if scroll == true:
            if scrollLeft == true:
              if entities[id].posX + bits div 2 - scrollX <= scrollWidth:
                scrollX -= 1
          entities[id].posX -= 1

  if velY.abs != 0:
    let velYDirection: int = velY div velY.abs
    let maxVelY: int = (entities[id].maxVelY.toFloat * slide).toInt + 1
    if velY.abs > maxVelY:
      velY = maxVelY * velYDirection
      entities[id].velY = velY

    for i in 0 .. velY.abs:
      setScrollBounds(false, true)
      if velY > 0:
        if collision(id, "down", true) == false:
          if scroll == true:
            if scrollDown == true:
              if entities[id].posY + bits.toFloat - scrollY >= scrollHeight:
                scrollY += 1
          entities[id].posY += 1

      if velY < 0:
        if collision(id, "up", true) == false:
          if scroll == true:
            if scrollUp == true:
              if entities[id].posY + bits.toFloat - scrollY <= scrollHeight:
                scrollY -= 1
          entities[id].posY -= 1

proc load() =
  loadMap("test")

var storeMVX: int = entities[0].maxVelX

proc update(dt: float) =
  if entities[0].isGrounded == true or slide != 1:
    if isKeyDown(V):
      entities[0].maxVelX = 2 * storeMVX
      accelXMult = 2
    elif entities[0].isGrounded or slide != 1:
      entities[0].maxVelX = storeMVX
      accelXMult = 1

  if isKeyDown(RIGHT):
    if collision(0, "right", true) == true:
      if entities[0].isGrounded == false:
        entities[0].isGrounded = true
        if isKeyPressed(C):
          entities[0].isGrounded = false
          entities[0].jumpBuffer -= 1
          entities[0].accelX -= 1.5
        slide = 0.05
        if entities[0].velY < 0: entities[0].velY = 0
        if entities[0].accelY < 0: entities[0].accelY = 0

    else: 
      slide = 1 
      if entities[0].isGrounded == true:
        if entities[0].velY < 0: entities[0].velY = 0
        if entities[0].accelY < 0: entities[0].accelY = 0
      entities[0].accelX += 0.3

  elif not isKeyDown(LEFT):
    slide = 1
    if entities[0].velX > 0:
      entities[0].accelX -= 5
      if entities[0].velX + entities[0].accelX.trunc.toInt <= 0:
        entities[0].accelX = 0
        entities[0].velX = 0

  if isKeyDown(LEFT):
    if collision(0, "left", true) == true:
      if entities[0].isGrounded == false:
        entities[0].isGrounded = true
        if isKeyPressed(C): 
          entities[0].isGrounded = false
          entities[0].jumpBuffer -= 1
          entities[0].accelX += 1.5
        slide = 0.05
        if entities[0].velY < 0: entities[0].velY = 0
        if entities[0].accelY < 0: entities[0].accelY = 0

    else: 
      slide = 1
      if entities[0].isGrounded == true:
        if entities[0].velY > 0: entities[0].velY = 0
        if entities[0].accelY > 0: entities[0].accelY = 0
      entities[0].accelX -= 0.3

  elif not isKeyDown(RIGHT):
    slide = 1
    if entities[0].velX < 0:
      entities[0].accelX += 2
      if entities[0].velX + entities[0].accelX.trunc.toInt >= 0:
        entities[0].accelX = 0
        entities[0].velX = 0

  if isKeyDown(C):
    if isKeyPressed(C): slide = 1
    if entities[0].isGrounded == true or entities[0].jumpBuffer < entities[0].maxJumpBuffer:
      if entities[0].jumpBuffer > 0:
        entities[0].accelY -= 20
        entities[0].jumpBuffer -= 1
      else:
        entities[0].accelY = gravity * slide + 1
  else:
    if entities[0].isGrounded == true:
      entities[0].jumpBuffer = entities[0].maxJumpBuffer
    else:
      entities[0].jumpBuffer = 0
    entities[0].accelY = gravity * slide + 1

  if isKeyPressed(ESCAPE):
    quit()
  
  move(0, true)

proc draw() =
  clear(Black)
  setColor(White)
  drawMap("test")

proc config(appSettings:var AppSettings) =
  appSettings.window.width=screenWidth
  appSettings.window.height=screenHeight

run("sample game",load,update,draw,config)
