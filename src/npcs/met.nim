import ../entities

proc metEnemy*(npc, player: base): updateNpc =
  var update: updateNpc

  if player.pos[0] + player.colX2 / 2 < npc.pos[0] + npc.colX2 / 2:
    if npc.facing == 1: 
      npc.facing = -1
      npc.textureName = "Met_LEFT"
      update.updateNeeded = true
  else: 
    if npc.facing == -1:
      npc.facing = 1
      npc.textureName = "Met_RIGHT"
      update.updateNeeded = true
  
  if update.updateNeeded:
    update.npcData = npc

  return update
