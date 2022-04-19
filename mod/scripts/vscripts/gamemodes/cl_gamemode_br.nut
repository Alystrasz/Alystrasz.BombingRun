global function Cl_BR_Init
global function ServerCallback_AnnounceBombPlanted


void function Cl_BR_Init() {

}

void function ServerCallback_AnnounceBombPlanted()
{
	string announcementString = "Bomb planted"
	string announcementSubString = "Bomb has been planted!"
	
	AnnouncementData announcement = Announcement_Create( announcementString )
	Announcement_SetSubText( announcement, announcementSubString )
	Announcement_SetTitleColor( announcement, <1,0,0> )
	Announcement_SetPurge( announcement, true )
	Announcement_SetPriority( announcement, 200 ) //Be higher priority than Titanfall ready indicator etc
	Announcement_SetSoundAlias( announcement, SFX_HUD_ANNOUNCE_QUICK )
	Announcement_SetStyle( announcement, ANNOUNCEMENT_STYLE_QUICK )
	AnnouncementFromClass( GetLocalViewPlayer(), announcement )
}
