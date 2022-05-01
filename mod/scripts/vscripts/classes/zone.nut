untyped
global var BombingZone
global function InitBombingZoneClass

void function InitBombingZoneClass()
{
    class BombingZone {
        name = null
        volumeMins = null
        volumeMaxs = null

        constructor(string name, var volumeMins, vector volumeMax)
        {
            this.name = name
            this.volumeMins = volumeMins
            this.volumeMaxs = volumeMax

            // trigger to warn players to plant bomb
            vector zoneCenter = Vector((this.volumeMins.x + this.volumeMaxs.x)/2, (this.volumeMins.y + this.volumeMaxs.y)/2, (this.volumeMins.z + this.volumeMaxs.z)/2)
            entity bombMsgTrigger = CreateTriggerRadiusMultiple( zoneCenter, 2* Distance( zoneCenter, this.volumeMins ), [], TRIG_FLAG_NONE)
            AddCallback_ScriptTriggerEnter( bombMsgTrigger, void function(entity trigger, entity ent) {
                if (IsValid(ent) && ent.IsPlayer()) {
                    print(ent + " is closed to base " + this.name + ".")
                    
                    // TODO check if player has bomb before sending message
                    Remote_CallFunction_NonReplay(ent, "ServerCallback_AnnounceEnemyBaseNearby")
                }
            } )
        }

        function CheckForBombPlant()
        {
            thread this._CheckForBombPlant()
        }

        function _CheckForBombPlant() {
            table times = {}
            float currTime = Time()
            int bombPlantDelay = 3

            while(true)
            {
                float currTime = Time()
                foreach(player in GetPlayerArray())
                {
                    if (PointIsWithinBounds( player.GetOrigin(), expect vector(this.volumeMins), expect vector(this.volumeMaxs) ) && player.UseButtonPressed())
                    {
                        if (currTime - times[player.GetPlayerName()] >= bombPlantDelay)
                        {
                            // plant bomb
							round.bomb = Bomb(player)

							print(player.GetPlayerName() + " triggered entity action.");
                            player.MovementEnable()
                            return
                        }
                        player.MovementDisable()
                        player.ConsumeDoubleJump()
                    } else
                    {
                        times[player.GetPlayerName()] <- currTime
                        player.MovementEnable()
                    }
                }
                WaitFrame()
            }
        }
    }
}
