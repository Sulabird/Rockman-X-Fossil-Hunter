import os, strutils, strformat

type
  base* = ref object of RootObj
    variant*: string
    textureName*: string
    facing*: float
    colX1*, colY1*: float
    colX2*, colY2*: float
    vel*, maxVel*: array[2, int]
    accel*, maxAccel*, size*, pos*: array[2, float]
  
  player* = ref object of base
    isGrounded*: bool
    jumpBuffer*, maxJumpBuffer*: int
    dashBuffer*, maxDashBuffer*: int

  projectile* = ref object of base

  store = object
    name: string
    value: float

var eStore: seq[store]

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

proc directionalSprites*(name: string, facing: float): string =
  var name: string = name
  if name.contains("_LEFT"):
    name = name[0 .. ^6]
  elif name.contains("_RIGHT"):
    name = name[0 .. ^7]

  case facing
  of -1:
    if fileExists(&"textures/{name}_LEFT.png"):
      return name & "_LEFT"
  of 1:
    if fileExists(&"textures/{name}_RIGHT.png"):
      return name & "_RIGHT"
  else: discard

  return name

proc createEntity*(pos: array[2, float], target: string): base =
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
    newEntity.maxAccel[0] = accel[0].parseFloat
    newEntity.maxAccel[1] = accel[1].parseFloat
    newEntity.maxVel[0] = vel[0].parseInt
    newEntity.maxVel[1] = vel[1].parseInt
    newEntity.pos = pos

    return newEntity
