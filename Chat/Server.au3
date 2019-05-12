#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>
#include <Array.au3>
#include <Inet.au3>
#include <packetStringFunctions.au3>
#include <Date.au3>
#include <ListEditGui.au3>

Opt("GUIOnEventMode",1)

;//FORM_serverStartup
$FORM_serverStartup = GUICreate("Server", 217, 111, 737, 227)
$INPUT_serverIp = GUICtrlCreateInput("127.0.0.1", 80, 8, 121, 21)
$LBL_serverIp = GUICtrlCreateLabel("Server ip", 8, 8, 46, 17)
$INPUT_serverPort = GUICtrlCreateInput("1234", 80, 48, 121, 21)
$LBL_serverPort = GUICtrlCreateLabel("Server port", 8, 48, 56, 17)
$BTN_startOrStopServer = GUICtrlCreateButton("Server starten", 8, 80, 85, 25)
$LBL_serverStatus = GUICtrlCreateLabel("Server ist offline.", 96, 84, 101, 20)
GUICtrlSetFont(-1, 10, 400, 0, "MS Sans Serif")
LblServerStatusUpdateState(false)
btnServerStatusUpdateState(false)
;//Gui Events
GUISetOnEvent($GUI_EVENT_CLOSE,"onGuiServerStartupClose",$FORM_serverStartup)
GUICtrlSetOnEvent($BTN_startOrStopServer,"onBtnStartOrStopServerClick")

;//Show connect window
GUISetState(@SW_SHOW,$FORM_serverStartup)

;//Server variables
global $SERVER_IP = "undefined"
global $SERVER_PORT = "undefined"
global $server = "undefined"
global $server_running = false
global const $SERVER_MAX_CLIENTS = 30
global $server_sockets[$SERVER_MAX_CLIENTS]
global $client_names[$SERVER_MAX_CLIENTS]
$server_sockets = ArrayFill1d($server_sockets,-1)
$client_names = ArrayFill1d($client_names,"Unbenannter Nutzer")

global $username_blacklist[5] = ["pimmel","arschloch","fotze","hitler","fick"] ;//LOL

;//server loop
While 1
	serverUpdate()
WEnd

;//Gui Events
Func onGuiServerStartupClose()
	$server_running = false
	serverStop()
;~ 	TCPShutdown()
	exit
EndFunc

Func onGuiServerIncomingMessagesClose()
	;//Stop server
	$server_running = false
	btnServerStatusUpdateState(false)
	LblServerStatusUpdateState(false)
	serverStop()
	guiRemoveAdminWindow()
	TCPShutdown()
	MsgBox(0,"Getrennt","Der Server ist nun offline.")
EndFunc


;//Gui Control events
Func onBtnStartOrStopServerClick()
	if ( serverGetOnlineStatus() == false ) Then
		;//Start server
		local $ip_custom = GUICtrlRead($INPUT_serverIp)
		local $port_custom = Number(GUICtrlRead($INPUT_serverPort))
		if ( serverCheckInput($ip_custom,$port_custom) == false ) Then
			MsgBox(0,"Fehler","Gib eine gültige IP Adresse, bzw. Port ein.")
			return
		EndIf
		if ( serverStart($ip_custom,$port_custom) == true ) Then
			MsgBox(0,"Verbunden","Der Server ist nun online.")
			LblServerStatusUpdateState(true)
			btnServerStatusUpdateState(true)
			$server_running = true
			guiCreateAdminWindow()
		Else
			MsgBox(0,"Fehler","Der Server konnte nicht online gehen. Womöglich wird dein angegebender Port bereits genutzt.")
			LblServerStatusUpdateState(false)
			btnServerStatusUpdateState(false)
			$server_running = false
			return
		EndIf
		serverUpdateVariables($ip_custom,$port_custom)
	else
		;//Stop server
		$server_running = false
		btnServerStatusUpdateState(false)
		LblServerStatusUpdateState(false)
		serverStop()
		guiRemoveAdminWindow()
		TCPShutdown()
		MsgBox(0,"Getrennt","Der Server ist nun offline.")
   EndIf
EndFunc



;//Server functions
Func serverUpdate()
	;//Nehme Verbindungen / neue Clients an
	for $i = 0 to UBound($server_sockets)-1
		if ( $server_sockets[$i] > -1 ) Then
			ContinueLoop
		Else
			local $socket = TCPAccept($server)
			$server_sockets[$i] = $socket
			ExitLoop
		EndIf
	Next
	;//Nachrichten empfangen
	for $i = 0 to UBound($server_sockets)-1
		local $message = TCPRecv($server_sockets[$i],2048)
		if ( $message <> "" ) Then
			local $packageArray = convertPackageStringToArray($message)

			;//SENDE NACHRICHT AN ALLE CLIENTS
			if ( $packageArray == false ) Then
				serverSendMessageToAllClients($message,$client_names[$i])

			;//NENNE USER UM; Vorher prüfen, ob der Name gültig ist.
			elseif ( getPackageClientRename($packageArray) == true ) Then
				local $username_current = $client_names[$i]
				local $username_new = $packageArray[1][1]
				if ( checkUsernameRequest($username_new) == true ) Then
					serverSendMessageToAllClients($username_current & " hat sich in " & $username_new & " umbenannt.")
					$client_names[$i] = $username_new
				else
					serverSendMessageToClient("Du konntest nicht in " & $username_new & " umbenannt werden, da sich in diesem Namen Inhalte der Username-blacklist befinden.",$server_sockets[$i])
				EndIf
			EndIf

		EndIf
	Next
EndFunc

Func serverSendMessageToAllClients($message_content,$sender_name = "Server")
	local $final_message = _Now() & " " & $sender_name & ": " & $message_content
	for $i = 0 to UBound($server_sockets)-1
		local $send = TCPSend($server_sockets[$i],$final_message)
		if ( @error or $send == 0 ) Then
			$server_sockets[$i] = -1
		EndIf
	Next
EndFunc

Func serverSendMessageToClient($message_content,$toClient,$sender_name = "Server")
	local $final_message = _Now() & " " & $sender_name & ": " & $message_content
	local $send = TCPSend($toClient,$final_message)
	if ( @error or $send == 0 ) Then
		;//TODO: Socket zum Client auf -1 setzen.
	EndIf
EndFunc

Func serverUpdateVariables($ip,$port)
	$SERVER_IP = $ip
	$SERVER_PORT = $port
EndFunc

Func serverGetOnlineStatus()
	return ($server_running == true) ? true : false
EndFunc

Func serverCheckInput($ip,$port)
	if ( serverStart($ip,$port) == True ) Then
		serverStop()
		return true
	Else
		return false
	EndIf
EndFunc

Func serverStart($ip,$port)
	TCPStartup()
	$server = TCPListen($ip,$port)
	if ( @error ) Then
		TCPShutdown()
		return false
	EndIf
	return True
EndFunc

Func serverStop()
	$server = "undefined"
	$SERVER_IP = "undefined"
	$SERVER_PORT = "undefined"
	$server_running = false
	TCPShutdown()
EndFunc



;//Check Functions
Func checkUsernameRequest($username)
	for $i = 0 to UBound($username_blacklist)-1 step 1
		local $blacklistEntryInUsername = StringInStr($username,$username_blacklist[$i])
		if ( $blacklistEntryInUsername <> 0 ) Then
			return False
		EndIf
	Next
	return True
EndFunc



;//Gui Control Functions
Func guiCreateAdminWindow()
	global $FORM_adminWindow = GUICreate("Chatverwaltung", 615, 437, 191, 123)
	global $BTN_editUsernameBlacklist = GUICtrlCreateButton("Username-blacklist bearbeiten", 8, 8, 163, 25)
	GUISetOnEvent($GUI_EVENT_CLOSE,"onGuiServerIncomingMessagesClose")
	GUICtrlSetOnEvent($BTN_editUsernameBlacklist,"onBtnEditUsernameBlacklistClick")
	GUISetState(@SW_SHOW,$FORM_adminWindow)
EndFunc

Func guiRemoveAdminWindow()
	GUIDelete($FORM_adminWindow)
EndFunc

Func onBtnEditUsernameBlacklistClick()
	;//TODO: GRAFISCHE GUI ANZEIGEN; IN FORM EINER LISTE; EINTRÄGE KÖNNEN HINZUGEFÜGT UND GELÖSCHT WERDEN; IN EINER EXTRA INCLUDE LIBRARY; UM CODE ZU SPAREN UND SIE SPÄTER WIEDERVERWENDEN ZU KÖNNEN;
EndFunc

Func LblServerStatusUpdateState($online)
	if ( $online == true ) Then
		GUICtrlSetData($LBL_serverStatus,"Server ist online.")
		GUICtrlSetBkColor($LBL_serverStatus, $COLOR_GREEN)
	Else
		GUICtrlSetData($LBL_serverStatus,"Server ist offline.")
		GUICtrlSetBkColor($LBL_serverStatus, $COLOR_RED)
	EndIf
EndFunc

Func btnServerStatusUpdateState($online)
	if ( $online == true ) Then
		GUICtrlSetData($BTN_startOrStopServer,"Server beenden.")
	Else
		GUICtrlSetData($BTN_startOrStopServer,"Server starten.")
	EndIf
EndFunc


;//Help methods
Func ArrayFill1d($array,$value)
	for $i = 0 to UBound($array)-1 step 1
		$array[$i] = $value
	Next
	return $array
EndFunc