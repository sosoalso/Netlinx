
PROGRAM_NAME='yeoul'


/**
 * FILE LAST MODIFIED ON : 04/01/2018
 * 
 * HISTORY
 *     V 1.0 INITIAL
 *     V 1.0.1 ADD SOME FUNCTIONS..
 */

/////////////////
define_constant//
/////////////////

dev DV_LOG = 0:1:0;

// MODERO FUNCTION
char MODERO_CMD_PAGE_FLIP[]   = 'PAGE-';
char MODERO_CMD_POPUP_SHOW[]  = 'PPON-';
char MODERO_CMD_POPUP_HIDE[]  = 'PPOF-';

char MODERO_CMD_POPUP_CLOSE_ALL[]            = '@PPX';
char MODERO_CMD_POPUP_CLOSE_ALL_ON_PAGE[]    = '@PPA-';
char MODERO_CMD_POPUP_CLOSE_GROUP[]          = '^PCL-';

char MODERO_CMD_BUTTON_ASSIGN_TEXT[]         = '^TXT-';
char MODERO_CMD_BUTTON_ASSIGN_UNICODE_TEXT[] = '^UNI-';
char MODERO_CMD_BUTTON_APPEND_TEXT[]         = '^BAT-';
char MODERO_CMD_BUTTON_APPEND_UNICODE_TEXT[] = '^BAU-';

// MENU FUNCTION

char PAGELIST[8][2] =
{
    {'1'}, {'2'}, {'3'}, {'4'}, {'5'}, {'6'}, {'7'}, {'8'}
};

char SIDEBARLIST[8][3] =
{
    {'01'}, {'02'}, {'03'}, {'04'}, {'05'}, {'06'}, {'07'}, {'08'}
};

char POPUPBODYLIST[8][8][4] =
{
    { {'101'}, {'102'}, {'103'}, {'104'}, {'105'}, {'106'}, {'107'}, {'108'} },
    { {'201'}, {'202'}, {'203'}, {'204'}, {'205'}, {'206'}, {'207'}, {'208'} },
    { {'301'}, {'302'}, {'303'}, {'304'}, {'305'}, {'306'}, {'307'}, {'308'} },
    { {'401'}, {'402'}, {'403'}, {'404'}, {'405'}, {'406'}, {'407'}, {'408'} },
    { {'501'}, {'502'}, {'503'}, {'504'}, {'505'}, {'506'}, {'507'}, {'508'} },
    { {'601'}, {'602'}, {'603'}, {'604'}, {'605'}, {'606'}, {'607'}, {'608'} },
    { {'701'}, {'702'}, {'703'}, {'704'}, {'705'}, {'706'}, {'707'}, {'708'} },
    { {'801'}, {'802'}, {'803'}, {'804'}, {'805'}, {'806'}, {'807'}, {'808'} }
};

integer BTN_MENU[8]    = { 101, 102, 103, 104, 105, 106, 107, 108 };
integer BTN_SIDEBAR[8] = { 201, 202, 203, 204, 205, 206, 207, 208 };

/////////////////
define_variable//
/////////////////

integer yeoulDebugMode = 0;

/////////////////////
// define_function //
/////////////////////

    // MODERO
define_function SetPage(dev tp, char pageName[])
{ SendCommand(tp, "MODERO_CMD_PAGE_FLIP, pageName"); }

define_function SetPagePrevious(dev tp)
{ SendCommand(tp, "MODERO_CMD_PAGE_FLIP"); }

define_function EnablePopup(dev tp, char popupName[])
{ SendCommand(tp, "MODERO_CMD_POPUP_SHOW, popupName"); }

define_function DisablePopup(dev tp, char popupName[])
{ SendCommand(tp, "MODERO_CMD_POPUP_HIDE, popupName"); }

define_function DisableAllPopups(dev tp)
{ SendCommand(tp, "MODERO_CMD_POPUP_CLOSE_ALL"); }

define_function DisableAllPopupsOnPage(dev tp, char pageName[])
{ SendCommand(tp, "MODERO_CMD_POPUP_CLOSE_ALL_ON_PAGE, pageName"); }

define_function DisablePopupOnGroup(dev tp, char popupGroupName[])
{ SendCommand(tp, "MODERO_CMD_POPUP_CLOSE_GROUP, popupGroupName"); }

define_function SetButtonText(dev tp, integer btnAdrCde, char nonUnicodeTextString[])
{  SendCommand(tp, "MODERO_CMD_BUTTON_ASSIGN_TEXT, itoa(btnAdrCde), ',0,', nonUnicodeTextString"); }

define_function SetButtonTextAppend(dev tp, integer btnAdrCde, char nonUnicodeTextString[])
{ SendCommand(tp, "MODERO_CMD_BUTTON_APPEND_TEXT, itoa(btnAdrCde), ',0,', nonUnicodeTextString"); }

define_function SetButtonTextUnicode(dev tp, integer btnAdrCde, char unicodeTextString[])
{ SendCommand(tp, "MODERO_CMD_BUTTON_ASSIGN_UNICODE_TEXT, itoa(btnAdrCde), ',0,', unicodeTextString"); }

define_function SetButtonTextUnicodeAppend(dev tp, integer btnAdrCde, char unicodeTextString[])
{ SendCommand(tp, "MODERO_CMD_BUTTON_APPEND_UNICODE_TEXT, itoa(btnAdrCde), ',0,', unicodeTextString"); }


define_function Log(char send[])
{
    send_string DV_LOG, send;
}
// send str cmd w/ debugging func.

define_function char[100] SendString(dev device, char send[])
{
    send_string device, send;
    if (yeoulDebugMode) Log("'SendString(), ', DevToString(device), ', ', send, '--end'");
	return send;
}

define_function char[100] SendCommand(dev device, char send[])
{
    send_command device, send;
    if (yeoulDebugMode) Log("'SendCommand(), ', DevToString(device), ', ', send, '--end'");
	return send;
}

define_function integer SendLevel(dev device, integer level, integer value)
{
    send_level device, level, value;
    if (yeoulDebugMode) Log("'SendLevel(), ', DevToString(device), ', ', 'level--', itoa(level), ', ', 'value--', itoa(value)");
	return value;
}

define_function integer SetState(dev device, integer ch, integer state)
{
    if (state) on[device, ch];
    else       off[device, ch];
    if (yeoulDebugMode) Log("'SetState(), ', DevToString(device), ', ', 'ch--', itoa(ch), 'SetState==', itoa(state), ' state==', itoa([device, ch] == 1)");
	return state;
}

define_function integer SetStateFromValue(dev device, integer ch, integer value)
{
    [device, ch] = value;
    if (yeoulDebugMode) Log("'SetState(), ', DevToString(device), ', ', 'ch--', itoa(ch), 'SetState==', itoa(value), ' state==', itoa([device, ch] == 1)");
    return value;
}

define_function SetPulse(dev device, integer ch, integer pulsetime)
{
    set_pulse_time(pulsetime);
    pulse[device, ch];
    if (yeoulDebugMode) Log("'SetPulse(), ', DevToString(device)");
}





define_function char[11] DevToString(dev device)
{
    return "itoa(device.number), ':', itoa(device.port), ':', itoa(device.system)";
}



define_function integer Func255to100Scaler(integer value)
{
    double value_double;
    value_double = type_cast(value);
        
    if (value_double > 255.0 || value_double < 0.0) {
        return 0;
    }
    else {
        return type_cast(0 + ((value - 0) * ((100 - 0) / (255 - 0))));
    }
}

define_function integer Func100to255Scaler(integer value)
{
    double value_double;
    value_double = type_cast(value);
        
    if (value_double > 100.0 || value_double < 0.0) {
        return 0;
    }
    else {
        return type_cast(0 + ((value - 0) * ((255 - 0) / (100 - 0))));
    }
}

//////////////
define_start//
//////////////

////////////////
define_program//
////////////////
{}
