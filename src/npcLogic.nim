#[
Rockman-X-Fossil-Hunter
Copyright (C) 2026 Sulabird

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
]#

import entities, strutils
import npcs/met

var update: updateNpc

proc calcNpc*(npc, player: base): updateNpc =
  case npc.textureName.split('_')[0]
  of "Met": update = metEnemy(npc, player)
  else: discard
  return update
