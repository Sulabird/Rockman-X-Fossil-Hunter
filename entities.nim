import os, strutils, strformat

type
  collisionData = object
    up*, right*, down*, left*: bool

  base* = ref object of RootObj
    variant*: string
    textureName*: string
    facing*: float = 1
    colX1*, colY1*: float
    colX2*, colY2*: float
    vel*, maxVel*, accel*, maxAccel*, size*, pos*: array[2, float]
    activeCollision*: collisionData
  
  player* = ref object of base
    isGrounded*: bool
    jumpBuffer*, maxJumpBuffer*: int
    dashBuffer*, maxDashBuffer*: int

  projectile* = ref object of base

  store = object
    name: string
    value: float

var eStore: seq[store]
var gCount, wCount, fCount: int

proc storeMatching*(name: string): float = 
  if eStore.len > 0:
    for i in 0 .. eStore.len - 1:
      if eStore[i].name == name:
        return eStore[i].value

proc storeAdd*(name: string, value: float) =
  var newStore: store
  newStore.name = name
  newStore.value = value
  eStore.add(newStore)

proc getWC*(): int =
  return wCount + 1

proc updateFire*(): bool =
  if fCount > 0:
    fCount -= 1
  else: return true

proc updateWalk*(): bool =
  gCount += 1
  if gCount == 10:
    gCount = 0
    wCount += 1
    return true

proc resetWalk*() =
  gCount = 0
  wCount = 0

proc directionalSprites*(
  name: string, facing: float, vel: float,
  ground, fire: bool, slide: float
): string =

  var name: string = name.split("_")[0]
  var f: string
  if fire == true:
    fCount = 15
  if fCount > 0:
    f = "_FIRE"
  else:
    fCount = 0

  case facing
  of -1:
    if slide != 1:
      if fileExists(&"textures/{name}_LEFT_SLIDE{f}.png"):
        return &"{name}_LEFT_SLIDE{f}"

    if ground == false:
      if fileExists(&"textures/{name}_LEFT_AIR{f}.png"):
        return &"{name}_LEFT_AIR{f}"

    elif vel <= -1:
      if fileExists(&"textures/{name}_LEFT_WALK_{wCount}{f}.png"):
        return &"{name}_LEFT_WALK_{wCount}{f}"
      else: wCount = 0

    if fileExists(&"textures/{name}_LEFT{f}.png"):
      return &"{name}_LEFT{f}"

  of 1:
    if slide != 1:
      if fileExists(&"textures/{name}_RIGHT_SLIDE{f}.png"):
        return &"{name}_RIGHT_SLIDE{f}"

    if ground == false:
      if fileExists(&"textures/{name}_RIGHT_AIR{f}.png"):
        return &"{name}_RIGHT_AIR{f}"

    elif vel >= 1:
      if fileExists(&"textures/{name}_RIGHT_WALK_{wCount}{f}.png"):
        return &"{name}_RIGHT_WALK_{wCount}{f}"
      else:
        wCount = 0  

    if fileExists(&"textures/{name}_RIGHT{f}.png"):
      return &"{name}_RIGHT{f}"
  else: 
    return name

proc updateCollision*(target: string): array[4, float] =
  var target: string = target
  if target.contains("_FIRE"):
    target = target[0 .. ^6]

  if fileExists(&"collision/{target}"):
    let data: seq[string] = readFile(&"collision/{target}")[0 .. ^2].split(',')
    var newValues: array[4, float]
    for i in 0 .. 3:
      newValues[i] = data[i].parseFloat
    return newValues
  else:
    return [0,0,48,48]

proc createEntity*(pos: array[2, float], target: string, pf: float): base =
  let target: string = target

  if fileExists(target):
    var newEntity: base

    let 
      entityData: seq[string] = readFile(target).splitLines
      size:       seq[string] = entityData[2].split(' ')[1 .. 2]
      col:        seq[string] = entityData[3].split(' ')[1 .. 4]
      accel:      seq[string] = entityData[4].split(' ')[1 .. 2]
      vel:        seq[string] = entityData[5].split(' ')[1 .. 2]

    let variant: string = entityData[1].split(' ')[1]

    case variant
    of "player":
      newEntity = player()
      let jump: seq[string] = entityData[6].split(' ')[1 .. 2]
      let dash: seq[string] = entityData[7].split(' ')[1 .. 2]
      player(newEntity).jumpBuffer = jump[0].parseInt
      player(newEntity).maxJumpBuffer = jump[1].parseInt
      player(newEntity).dashBuffer = dash[0].parseInt
      player(newEntity).maxDashBuffer = dash[1].parseInt

    of "projectile": newEntity = projectile()
    else: newEntity = base()

    newEntity.textureName = entityData[0].split(' ')[1]
    newEntity.variant = variant
    newEntity.size[0] = size[0].parseFloat
    newEntity.size[1] = size[1].parseFloat
    newEntity.colX1 = col[0].parseFloat
    newEntity.colY1 = col[1].parseFloat
    newEntity.colX2 = col[2].parseFloat
    newEntity.colY2 = col[3].parseFloat
    newEntity.maxAccel[0] = accel[0].parseFloat * pf
    newEntity.maxAccel[1] = accel[1].parseFloat * pf
    newEntity.maxVel[0] = vel[0].parseFloat * pf
    newEntity.maxVel[1] = vel[1].parseFloat * pf
    newEntity.pos = pos

    return newEntity
