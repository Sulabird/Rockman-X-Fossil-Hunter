#[
Rockman-X-Fossil-Hunter
Copyright (C) 2026 Sulabird

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
]#

import ../entities

var metTimer: int

proc metEnemy*(npc, target: base): updateNpc =
  var update: updateNpc
  var name: string = "Met"

  if metTimer > 0:
    metTimer -= 1
    if metTimer == 1:
      update.updateNeeded = true

  if player(target).fire:
    if target.pos[1] + target.colY2 >= npc.pos[1] + npc.colY2:
      if target.pos[1] + target.colY2 <= npc.pos[1] + npc.colY2 + 24:
        name = name & "_HIDE"
        npc.textureName = name
        update.updateNeeded = true
        metTimer = 21

  if target.pos[0] + target.colX2 / 2 < npc.pos[0] + npc.colX2 / 2:
    if npc.facing == 1 or update.updateNeeded: 
      npc.facing = -1
      npc.textureName = name & "_LEFT"
      update.updateNeeded = true
  else: 
    if npc.facing == -1 or update.updateNeeded:
      npc.facing = 1
      npc.textureName = name & "_RIGHT"
      update.updateNeeded = true
  
  if update.updateNeeded:
    update.npcData = npc

  return update
