import os, strutils

type
  entity* = object
    variant*: string
    textureName*: string
    facing*: float = 1
    colX1*, colY1*: float
    colX2*, colY2*: float
    isGrounded*: bool
    jumpBuffer*, maxJumpBuffer*: int
    dashBuffer*, maxDashBuffer*: int
    vel*, maxVel*: array[2, int]
    accel*, maxAccel*, size*, pos*: array[2, float]

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
  
proc createEntity*(pos: array[2, float], target: string): entity =
  let target: string = "entities/" & target

  if fileExists(target):
    var newEntitiy: entity

    let 
      entityData: seq[string] = readFile(target).splitLines
      size:       seq[string] = entityData[2].split(' ')[1 .. 2]
      col:        seq[string] = entityData[3].split(' ')[1 .. 4]
      jump:       seq[string] = entityData[4].split(' ')[1 .. 2]
      dash:       seq[string] = entityData[5].split(' ')[1 .. 2]
      accel:      seq[string] = entityData[6].split(' ')[1 .. 2]
      vel:        seq[string] = entityData[7].split(' ')[1 .. 2]

    newEntitiy.textureName = entityData[0].split(' ')[1]
    newEntitiy.variant = entityData[1].split(' ')[1]
    newEntitiy.size[0] = size[0].parseFloat
    newEntitiy.size[1] = size[1].parseFloat
    newEntitiy.colX1 = col[0].parseFloat
    newEntitiy.colY1 = col[1].parseFloat
    newEntitiy.colX2 = col[2].parseFloat
    newEntitiy.colY2 = col[3].parseFloat
    newEntitiy.jumpBuffer = jump[0].parseInt
    newEntitiy.maxJumpBuffer = jump[1].parseInt
    newEntitiy.dashBuffer = dash[0].parseInt
    newEntitiy.maxDashBuffer = dash[1].parseInt
    newEntitiy.maxAccel[0] = accel[0].parseFloat
    newEntitiy.maxAccel[1] = accel[1].parseFloat
    newEntitiy.maxVel[0] = vel[0].parseInt
    newEntitiy.maxVel[1] = vel[1].parseInt
    newEntitiy.pos = pos

    return newEntitiy
