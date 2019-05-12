#include <Date.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <Inet.au3>
#include <packetStringFunctions.au3>
#include <String.au3>

;//HOTKEYS
HotKeySet("{ENTER}","onMessageSendShortcutPress")

;//local $test[4][2] = [["package_type","user_add"],["username","testnamexyz"],["date","16:09"],["message_from_server","Hallo!"]]
;//convertPackageStringToArray(convertArrayToPackageString($test))
;//MsgBox(0,"",convertArrayToPackageString($test))

Opt("GUIOnEventMode",1)

global $FORM_mainchat
global $BTN_sendMessage
global $INPUT_message
global $EDIT_chatHistory

guiCreateMainchatWindow()

TCPStartup()

global const $SERVER_IP = "127.0.0.1"
global const $SERVER_PORT = 1234
global $server_socket = TCPConnect($SERVER_IP,$SERVER_PORT)
if ( @error ) Then
	ConsoleLogError("Es konnte keine Verbindung zum Server aufgebaut werden.")
;~ 	Exit
EndIf

while 1
	local $server_message = TCPRecv($server_socket,2048)
	if ( $server_message <> "" ) Then
		messageAddToChatHistory($server_message)
	EndIf
WEnd

Func guiCreateMainchatWindow()
	$FORM_mainchat = GUICreate("Chat", 615, 437, 427, 157)
	$BTN_sendMessage = GUICtrlCreateButton("Senden", 536, 406, 75, 25)
	$INPUT_message = GUICtrlCreateInput("", 8, 408, 521, 21)
	$EDIT_chatHistory = GUICtrlCreateEdit("", 8, 8, 601, 393)
	GUISetOnEvent($GUI_EVENT_CLOSE,"onGuiMainchatClose")
	GUICtrlSetOnEvent($BTN_sendMessage,"onBtnSendMessageClick")
	GUISetState(@SW_SHOW)
EndFunc

Func onBtnSendMessageClick()
	local $message = GUICtrlRead($INPUT_message)
	if ( StringInStr($message,"username.change") == 1 ) Then
		local $splitted = StringSplit($message,"-",2)
		if ( @error ) then
			Return
		EndIf
		local $name = $splitted[1]
		sendRenameRequest($name)
	Else
		messageSend($message)
		GUICtrlSetData($INPUT_message,"")
	EndIf
EndFunc

Func onGuiMainchatClose()
	TCPCloseSocket($server_socket)
	TCPShutdown()
	exit
EndFunc

Func ConsoleLogError($error)
	ConsoleWriteError(_NowTime(5) & "  FEHLER: " & $error & @CRLF)
EndFunc

Func ConsoleLog($log)
	ConsoleWrite($log & @CRLF)
EndFunc

Func messageSend($message_content)
	$message_bytes = TCPSend($server_socket,$message_content)
	if ( $message_bytes == 0 or @error ) Then
		ConsoleLogError("Das Packet mit dem Inhalt " & $message_content & " konnte nicht gesendet werden.")
		return False
	EndIf
	return True
EndFunc

Func checkRenameRequest($name)
	if ( StringInStr($name,"") or StringLen($name) < 2 ) Then
		return False
	EndIf
	return True
EndFunc

Func sendRenameRequest($name)
	local $renamePackage[2][2] = [["package_type","client_rename"],["username",$name]]
	$request = TCPSend($server_socket,convertArrayToPackageString($renamePackage))
	GUICtrlSetData($INPUT_message,"")
	if ( $request == 0 or @error ) Then
		ConsoleLogError("Die Anfrage einer Umbenennung konnte nicht an den Server gesendet werden.")
		return False
	EndIf
EndFunc

Func messageAddToChatHistory($message_content)
	GUICtrlSetData($EDIT_chatHistory,GUICtrlRead($EDIT_chatHistory) & @CRLF & $message_content)
EndFunc

Func onMessageSendShortcutPress()
	local $active_control = ControlGetFocus($FORM_mainchat)
	if ( $active_control == "Edit1" ) Then
		onBtnSendMessageClick()
	EndIf
EndFunc