untyped
global var BombingZone
global function InitBombingZoneClass

void function InitBombingZoneClass()
{
    class BombingZone {
        name = null
        volumeMins = null
        volumeMaxs = null
        indicator = null

        constructor(string name, int team, var volumeMins, vector volumeMax)
        {
            this.name = name
            this.volumeMins = volumeMins
            this.volumeMaxs = volumeMax

            // trigger to warn players to plant bomb
            vector zoneCenter = Vector((this.volumeMins.x + this.volumeMaxs.x)/2, (this.volumeMins.y + this.volumeMaxs.y)/2, (this.volumeMins.z + this.volumeMaxs.z)/2)
            entity bombMsgTrigger = CreateTriggerRadiusMultiple( zoneCenter, 2* Distance( zoneCenter, this.volumeMins ), [], TRIG_FLAG_NONE)
            AddCallback_ScriptTriggerEnter( bombMsgTrigger, void function(entity trigger, entity ent) {
                if (IsValid(ent) && ent.IsPlayer()) {
                    if (ent.GetPlayerNetInt( "numSuperRodeoGrenades" ) == 0)
                        return

                    print(ent.GetPlayerName() + " has a bomb and is closed to base " + this.name + ".")
                    Remote_CallFunction_NonReplay(ent, "ServerCallback_AnnounceEnemyBaseNearby")
                }
            } )

            // initialize UI indicator
            this.indicator = CreateEntity( "prop_dynamic" )
            // this.indicator.SetValueForModelKey( $"models/dev/empty_model.mdl" )
            this.indicator.SetValueForModelKey( $"models/robots/mobile_hardpoint/mobile_hardpoint.mdl" )
            this.indicator.kv.modelscale = 0
            vector indicatorPos = zoneCenter
            indicatorPos.z = expect float(this.volumeMaxs.z + 400);
            this.indicator.SetOrigin( indicatorPos )
            this.indicator.SetAngles( <0,0,0> )
            // this.indicator.kv.solid = SOLID_VPHYSICS
            DispatchSpawn( this.indicator )
            SetTeam( expect entity(this.indicator), team )
        }

        function CheckForBombPlant()
        {
            thread this._CheckForBombPlant()
        }

        function _CheckForBombPlant() {
            table times = {}
            float currTime = Time()
            int bombPlantDelay = 3
            entity bombHolder = null

            while(true)
            {
                float currTime = Time()
                foreach(player in GetPlayerArray())
                {
                    if (PointIsWithinBounds( player.GetOrigin(), expect vector(this.volumeMins), expect vector(this.volumeMaxs) ))
                    {
                        // display plant bomb message if player has bomb
                        if (player.GetPlayerNetInt( "numSuperRodeoGrenades") != 0 && bombHolder == null) {
                            Remote_CallFunction_NonReplay(player, "ServerCallback_BombCanBePlantedHint")
                            bombHolder = player
                        }

                        if (player.UseButtonPressed())
                        {
                            if (currTime - times[player.GetPlayerName()] >= bombPlantDelay)
                            {
                                // plant bomb
                                round.bomb = Bomb(player)

                                print(player.GetPlayerName() + " triggered entity action.");
                                player.MovementEnable()

                                // send message to all players
                                PlayDialogueToAllPlayers (player.GetTeam(), "lts_bombPlantedAtk", "lts_bombPlantedDef")
                                return
                            }
                            player.MovementDisable()
                            player.ConsumeDoubleJump()
                        }

                        else {
                            times[player.GetPlayerName()] <- currTime
                            player.MovementEnable()
                        }
                    }
                    
                WaitFrame()
            }
        }
    }
}
