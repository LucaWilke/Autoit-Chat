#include-once
#include <Array.au3>
#include <String.au3>

;//local $test[4][2] = [["package_type","user_add"],["username","testname"],["date","16:09"],["message_from_server","Hallo!"]]
;//////////////COMMANDS\\\\\\\\\\\\\\\\\\\\;
;//(SERVER TO CLIENT)
;//TODO: ADD COMMANDS
;//(CLIENT TO SERVER)
;//Neue Nachricht senden = Da findet gar keine Konvertierung in ein Array statt, es wird einfach der Inhalt der Nachricht als Paket an den Server gesendet.
;//Namen aktualisieren = [["package_type","client_rename"],["username","xyz"]]
;//////////////////\\\\\\\\\\\\\\\\\\\\\\\\;

local $newparam = "|"
local $equals = "~"

Func convertArrayToPackageString($array)
	;//Aufbau: [["package_type",...],[key,wert],...] -> "package_type=irgendwas[NEWPARAM]key=wert"
	;//Beispiel: [["package_type","message_send"],["message_content","Lol, das ist eine Nachricht!"]] -> "package_type=message_send[NEWPARAM]message_content=..."...
	local $packageString = ""
	for $height = 0 to UBound($array,1)-1 step 1
		for $width = 0 to UBound($array,2)-1 step 1
			local $content = $array[$height][$width]
			$packageString = $packageString & $content
			if ( $width == 0 ) Then
				$packageString = $packageString & $equals
			elseif ( $width == 1 and $height < UBound($array,1)-1 ) Then
				$packageString = $packageString & $newparam
			EndIf
		Next
	Next
	return $packageString
EndFunc

Func convertPackageStringToArray($packageString)
	local $values = StringSplit($packageString,$newparam,2)
	if ( @error ) Then
		SetError(1)
		return False
	EndIf
	local $packageArray[UBound($values,1)][2]
	for $i = 0 to UBound($values)-1 step 1
		local $var = StringSplit($values[$i],$equals,2)
		if ( @error ) Then
			SetError(1)
			return False
		EndIf
		local $var_name = $var[0]
		local $var_value = $var[1]
		$packageArray[$i][0] = $var_name
		$packageArray[$i][1] = $var_value
	Next
	return $packageArray
EndFunc

Func getPackageClientRename($packageArray)
	;//return ( $packageArray[0][1] == "client_rename" ) ? true : false
	if ( $packageArray[0][1] == "client_rename" ) Then
		return True
	EndIf
	return False
EndFunc


;//getters & setters
Func getNewParam()
	return $newparam
EndFunc