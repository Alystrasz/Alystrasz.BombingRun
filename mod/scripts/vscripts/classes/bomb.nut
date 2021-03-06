untyped
global function InitBombClass
global var Bomb

void function InitBombClass()
{
	/**
	 * This gameobject is a bomb that spawns on the level floor when a player holding a bomb 
	 * item plants it in the enemy base.
	 * It will tick (e.g. emit a light flash and a sound) several times before exploding, giving
	 * the win to the team who planted it.
	 * Players of the opposite team can defuse it, which will grant them the win.
	 **/
    class Bomb {
		origin = null
		terrorist = null
		bomb = null
        delay = 0
		light = null

		constructor (entity player)
		{
			this.terrorist = player
			this.origin = player.GetOrigin()
            this.delay = 3

			// Give credit to whoever planted the bomb
			player.AddToPlayerGameStat( PGS_TITAN_KILLS, 1 )

			// Remove bomb from his inventory
			SetPlayerBombCount( player, 0 )

			foreach(entity online in GetPlayerArray()) {
                Remote_CallFunction_NonReplay(online, "ServerCallback_AnnounceBombPlanted")
            }

			// create gameobject on map floor
            entity bomb = CreateEntity( "prop_dynamic" )
            bomb.SetValueForModelKey($"models/weapons/at_satchel_charge/at_satchel_charge.mdl")
            bomb.SetOrigin( player.GetOrigin() )
            bomb.SetAngles( < -90, 0, 0> )
            bomb.kv.solid = SOLID_VPHYSICS
            DispatchSpawn( bomb )
            this.bomb = bomb

            SendTeamMessage( "Bomb has been planted by " + player.GetPlayerName() + ".", player.GetTeam() )

            thread this._StartExplosionCountdown()

            // set bomb as defusable
            bomb.SetUsable()
            bomb.SetUsableByGroup( "pilot" )
            bomb.SetUsePrompts( "Hold %use% to defuse bomb", "Hold %use% to defuse bomb" )
            thread this._CheckHoldState()
		}

		/**
		 * This allows to trigger some code if a player kept use button hold for a given 
		 * time (in seconds).
		 **/
		function _CheckHoldState()
		{
			table times = {}
			float currTime = Time()
			vector origin = expect entity(this.bomb).GetOrigin()

			while(GamePlayingOrSuddenDeath())
			{
				float currTime = Time()
				foreach(player in GetPlayerArray())
				{
					if (player.GetPlayerName() in times && player.UseButtonPressed() && Distance(origin, player.GetOrigin()) < 80)
					{
						if (currTime - times[player.GetPlayerName()] >= this.delay)
						{
							round.bombHasBeenDefused = true
							this.bomb.UnsetUsable()

							// greenlight bomb indicator
							if (this.light)
								this.light.Destroy()
							this.light = expect entity(this._CreateLight(origin, "50 255 50"))

							SendTeamMessage( player.GetPlayerName() + " has defused the bomb.", player.GetTeam() )
							SetWinner(player.GetTeam())

							// Give credit to whoever defused the bomb
							player.AddToPlayerGameStat( PGS_DEFENSE_SCORE, 1 )

							PlayDialogueToAllPlayers (player.GetTeam(), "lts_bombDefusedDef", "lts_bombDefusedAtk")

							return
						}
						player.MovementDisable()
						player.ConsumeDoubleJump()
						var timeLeft = format("%.1f", (this.delay - (currTime - times[player.GetPlayerName()])).tofloat())
						this.bomb.SetUsePrompts( "Hold %use% to defuse bomb (" + timeLeft + "s)", "Hold %use% to defuse bomb (" + timeLeft + "s)" )
					} else
					{
						times[player.GetPlayerName()] <- currTime
						this.bomb.SetUsePrompts( "#GAMEMODE_BR_BOMB_DEFUSE_PROMPT", "#GAMEMODE_BR_BOMB_DEFUSE_PROMPT" )
						player.MovementEnable()
					}
				}
				WaitFrame()
			}
		}

		/**
		 * This allows the bomb to check if current round is over, not to explode if other bomb 
		 * exploded previously to this one.
		 **/
		function _CurrentRoundIsOver()
		{
			return round.bombHasBeenDefused || GetGameState() == eGameState.WinnerDetermined;
		}

		/**
		 * Creates a light of desired color, from a bomb's position.
		 * Light origin is adapted to match the satchel model light position.
		 **/
		function _CreateLight(vector pos, string color)
		{
			vector lightpos = pos
			lightpos.z += 3.6
			lightpos.y += 1.7
			lightpos.x -= 0.65
			return CreateLightSprite (lightpos, <0,0,0>, color, 0.2)
		}

		/**
		 * Emits a "bip" sound and a white light flash on a given position.
		 * `lastSeconds` argument is used when bomb is close from explosion; this will emit a
		 * different sound when flag is raised.
		 **/
		function _Bip(vector pos, bool lastSeconds)
		{
			EmitSoundAtPosition( TEAM_UNASSIGNED, pos, lastSeconds ? "ui_ingame_markedfordeath_countdowntoyouaremarked" : "ui_ingame_markedfordeath_countdowntomarked")
			WaitFrame()
			entity light = expect entity(this._CreateLight(pos, "255 255 255"))
			WaitFrame()
			light.Destroy()
		}

		/**
		 * Starts current bomb explosion countdown.
		 * It will tick (e.g. emit a light flash and a sound) several times before exploding, giving
	 	 * the win to the team who planted it.
		 * Bomb countdown duration can be configured through several configuration variables.
		 **/
		function _StartExplosionCountdown() 
		{
			vector origin = expect entity(this.bomb).GetOrigin()
			int two_second_bips_count = GetConVarInt("br_bomb_2sec_ticks_count")
			int one_second_bips_count = GetConVarInt("br_bomb_1sec_ticks_count")
			int half_second_bips_count = GetConVarInt("br_bomb_halfsec_ticks_count")

			// set round duration to bomb explosion time
			SetServerVar( "roundEndTime", Time() + (two_second_bips_count * 2) + (one_second_bips_count) + (half_second_bips_count * 0.5) + 0.1)

			for (int i=0; i<two_second_bips_count; i+=1) {
				if (round.bombHasBeenDefused) return;
				thread this._Bip(origin, false)
				wait 2
			}

			// constant white light
			this.light = expect entity(this._CreateLight(origin, "255 255 255"))
			for (int i=0; i<one_second_bips_count; i+=1) {
				if (this._CurrentRoundIsOver()) return;
				thread this._Bip(origin, false)
				wait 1
			}

			// constant red light
			this.light.Destroy()
			this.light = expect entity(this._CreateLight(origin, "255 0 0"))

			for (int i=0; i<half_second_bips_count; i+=1) {
				if (this._CurrentRoundIsOver()) return;
				thread this._Bip(origin, true)
				wait 0.5
			}

			if (this._CurrentRoundIsOver()) return;

			// if it blows, team who planted it wins
			SetWinner ( expect entity(this.terrorist).GetTeam() )
			thread this._TriggerExplosion()
		}

		/**
		 * Does the boom.
		 * This will kill all players within range, no matter their team.
		 **/
		function _TriggerExplosion()
		{
			int innerRadius = 0
			int outerRadius = 1000
			int normalDamage = 1000
			int heavyArmorDamage = 2000

			thread __CreateFxInternal( TITAN_NUCLEAR_CORE_FX_1P, null, "", expect vector(this.origin), Vector(0,RandomInt(360),0), C_PLAYFX_SINGLE, null, 1, expect entity(this.terrorist) )
			thread __CreateFxInternal( TITAN_NUCLEAR_CORE_FX_3P, null, "", expect vector(this.origin + Vector( 0, 0, -100 )), Vector(0,RandomInt(360),0), C_PLAYFX_SINGLE, null, 6, expect entity(this.terrorist) )
			
			// shake camera and emit some sounds
			CreateShake(expect entity(this.bomb).GetOrigin())
			EmitSoundAtPosition( TEAM_IMC, expect vector(this.origin), "titan_nuclear_death_explode" )
			EmitSoundAtPosition( TEAM_MILITIA, expect vector(this.origin), "titan_nuclear_death_explode" )

			RadiusDamage_DamageDef( damagedef_nuclear_core,
				this.origin,						// origin
				this.terrorist,						// owner
				this.bomb,							// inflictor
				normalDamage,						// normal damage
				heavyArmorDamage,					// heavy armor damage
				innerRadius,						// inner radius
				outerRadius,						// outer radius
				0 )									// dist from attacker

			this.bomb.Hide()
			this.bomb.NotSolid()
			this.bomb.UnsetUsable()
		}

		/**
         * Destroys all entities related to this bomb.
         * This is called between rounds to ensure there are no several bombs in a single round.
         **/
		function Destroy()
		{
			this.bomb.Hide()
			this.bomb.NotSolid()
			this.bomb.UnsetUsable()
			if (this.light != null)
				this.light.Destroy()
		}
	}
}
