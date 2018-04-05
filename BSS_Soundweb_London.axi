PROGRAM_NAME='BSS_Soundweb_London'

//THIS PROGRAM WAS WRITTEN AND TESTED BY THE MANUFACTURER
//THIS MODULE IS DESIGNED TO CONTROL ALL BSS AUDIO SOUNDWEB LONDON HARDWARE
//VIA RS232 OR TCP/IP
//BLU-16
//BLU-32
//BLU-80
//BLU-120
//BLU-160
//BLU-320
//BLU-800
        //ADDED ROOM_COMBINE FUNCTIONALITY
        //ADDED BUG FIXES (T=0 IN DATA:ONLINE, I=T IN PROCESS_FEEDBACK, 'GET_EVENT' IN SET FUNCTIONS)
        //IMPROVED DATA RECEIVING EVENTS TO HANDLE THE DATA:ONLINE SUBSCRIBE TRAFFIC LOAD
        //UPDATED HELP FILE

//PLEASE READ THE MODULE HELP DOCUMENT LOCATED IN THE DIRECTORY!!!  THIS FILE IS ALSO MAPPED IN THE NETLINX STUDIO "OTHER" TREE

//BSS_Basic_Example FILE SHOWS EXAMPLE OF CONTROL ON ALL PROCESSING OBJECTS


//SE 2/15/08
//updated to version 2.1 JJ 7/29/10
//updated to version 2.2 JJ 1/28/11

(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)
(* REV HISTORY:                                            *)
(***********************************************************)

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

#IF_NOT_DEFINED dvSOUNDWEB
dvSOUNDWEB = 0:23:0
#END_IF

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

(**************** STRING FORMATING CONSTANTS ******************************************** *)
STX = $02; ETX = $03;
ACK = $06; NAK = $15;
ESC = $1B; //ESCAPE CHAR
ET = $88; //EVENT
(******************************************************************************************)

(*******************  DEVICE AND PARAMETER CONSTANTS - MUST KEEP ***************************************************)
(*******************************************************************************************************************)
//THESE CONSTANTS ARE USED FOR 'FRIENDLY' PARAMETER FUNCTION CALLS.
//SEE EXAMPLE PROGRAM BELOW FOR USE.  SEE HELP FILE FOR ADDITIONAL EXAMPLES

(*  DEVICE CONSTANTS FOR <DEVICE> FUNCTION PARAMETER *)
AUTOMIXER = 1; MIXER = 2;MM = 4; ROUTER =6; METER = 7; SOURCE_SELECTOR = 8; SOURCE_MATRIX = 9;
N_GAIN = 10; INPUT_CARD = 11; OUTPUT_CARD = 12; ROOM_COMBINE = 26; TELEPHONE = 27; LOGIC = 1;

(* PARAMETER CONSTANTS <PARAM> FUNCTION PARAMETER  *)
UNMUTE = 0; MUTE = 1; ROUTE = 1; GAIN = 3;UNROUTE = 0;
POLARITY_ON = 1; POLARITY_OFF = 0; LOGIC = 1;

(* PARAMETER CONSTANTS SPECIFICALLY FOR 'SET_MIXER' <PARAM> FUNCTION PARAMETER  *)
SOLO= 13;GROUP = 14;AUX = 15; OVERRIDE = 16; AUTO = 17; AUX_GAIN = 18;
PAN = 19; OFF_GAIN = 20;GROUP_GAIN = 21;

(* PARAMETER CONSTANTS SPECIFICALLY FOR 'SET_ROOMCOMBINE' <PARAM> FUNCTION PARAMETER  *)
SOURCE_MUTE = 30; BGM_MUTE = 31; MASTER_MUTE = 32; SOURCE_GAIN = 33; BGM_GAIN = 34; MASTER_GAIN = 35, BGM_SELECT = 36;
PARTITION = 37;

(* PARAMETER CONSTANTS SPECIFICALLY FOR 'SET_TELEPHONE' <PARAM> FUNCTION PARAMETER  *)
BUTTON_0 = 38; BUTTON_1 = 39; BUTTON_2 = 40; BUTTON_3 = 41; BUTTON_4 = 42; BUTTON_5 = 43; BUTTON_6 = 44;
BUTTON_7 = 45; BUTTON_8 = 46; BUTTON_9 = 47; T_PAUSE = 48; CLEAR = 49; INTERNATIONAL = 50; BACKSPACE = 51;
REDIAL = 52; FLASH = 53; SPEED_DIAL_STORE_SELECT = 54; SPEED_DIAL_SELECT = 55; TX_MUTE = 56; RX_MUTE = 57;
DIAL_HANGUP = 58; AUTO_ANSWER = 59; TX_GAIN = 60; RX_GAIN = 61; DTMF_GAIN = 62; DIAL_TONE_GAIN = 63;
RING_GAIN = 64; TELEPHONE_NUMBER = 65; INCOMING_CALL = 66; ASTERISK = 67; POUND = 68;

(* PARAMETER CONSTANTS SPECIFICALLY FOR 'SET_PRESET' <PARAM> FUNCTION PARAMETER  *)
DEVICE_PRESET = 1; PARAMETER_PRESET = 2;

(* PARAMETER CONSTANTS ONLY WHEN <DEVICE> == INPUT_CARD || OUTPUT_CARD *)
//GAIN IS ALSO VALID BUT ALREADY DEFINED ABOVE
PHANTOM = 22; REFERENCE = 23; ATTACK = 24; RELEASED = 25;

(* GENERAL FORMAT CONSTANTS *)
A=1;B=2;C=3;D=4; //INPUT_CARD DENOTIONS
L = 1; R = 3;//LEFT CHANNEL, RIGHT CHANNEL FOR MIXERS/AUTOMIXERS
(*******************************************************************************************************************)
(*******************************************************************************************************************)


(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

VOLATILE INTEGER bDEBUG_FLAG
VOLATILE CHAR cBUFFER[1000] //COMM PORT BUFFER
VOLATILE INTEGER nAttempts= 0     // counts the number of times we iterate before we should have received a full message
VOLATILE INTEGER STARTUP; //FLAG USED IN DEFINE_START ROUTINE
VOLATILE INTEGER T; //NUMBER OF TIMES 'SUBSCRIBE' OR 'SUBSCRIBE %' CALLED FROM DATA_EVENT:ONLINE.  USED FOR FB[] <FEEDBACK> ARRAY POPULATING IN SUBSCRIBE AND SUBSCRIBE% FOR TRUE FEEDBACK PURPOSES
VOLATILE INTEGER iGAIN_FRACTION; //USED IN PROCESS FEEDBACK FOR ROUNDING PURPOSES ON SET_GAIN%

//SEE HELP FILE FOR COMPLETE DESCRIPTION OF FB[][]
CHAR FB[10][12]; //FEEDBACK ARRAY - MUST MANUALLY ASSIGN DIMENSION OF ROWS[1] IF OVER 200 VARIABLES ARE USED FOR TRUE FEEDBACK (ie MAKE LARGER IF NEEDED); COLUMN[2] MUST ALWAYS BE 12!!

char cServerAddress[15] = '192.168.1.206' // IP Address of the ZonePro
LONG lServerPort = 1023 // port of the Box

INTEGER SIX_RECEIVED = 0;

(********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)

DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

DEFINE_CALL 'SET_VAL'(CHAR OBJECT[6],INTEGER DEVICE,INTEGER INPUT, INTEGER OUTPUT,INTEGER PARAM,INTEGER VALUE)
{
    LOCAL_VAR INTEGER S_V;//STATE VAR
    LOCAL_VAR INTEGER S_VLOW;//LOW BYTE OF S_V
    LOCAL_VAR INTEGER S_VHIGH;//HIGH BYTE OF S_V
    LOCAL_VAR CHAR MY_DATA[4]; //FOUR BYTE DATA FIELD THAT HOLDS THE VALUE OF THE S_V
    LOCAL_VAR CHAR MY_STRING[13];//COMPLETE MESSAGE BEFORE BEING PADDED WITH STX,CHECKSUM,ETX, AND SPECIAL CHAR SUBSITUTION
    LOCAL_VAR CHAR EVENT; //DETERMINES DATA TYPE FOR S_V
    LOCAL_VAR CHAR GET_EVENT;//DETERMINES DATA TYPE FOR GET S_V

    IF(DEVICE = OUTPUT_CARD || DEVICE = INPUT_CARD)
    {
        EVENT = $8D;  // FOR SENDING PERCENT VALUES
        GET_EVENT = $8E;//FOR GETTING PERCENT VALUES
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
        MY_DATA = "0,VALUE,0,0"; //when using percent only 2nd Data byte is utilized for range 0-100
    }
    ELSE
    {
        EVENT = $88; //FOR SENDING DISCRETE VALUES
        GET_EVENT = $89; //FOR GETTING DISCRETE VALUES
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
        MY_DATA = "$00,$00,$00,VALUE"; //when using discrete the only value is 0 or 1 (on/off)
    }

    IF(S_V != 65535){//error check
        MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
        CALL 'CHECKSUM'(MY_STRING)

        //THESE STATEMENTS ARE ESSENTIALLY A 'GET' STATEMENT.  AFTER SENDING STRING GET_VALUE.
        MY_STRING = "GET_EVENT,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";
        CALL 'CHECKSUM'(MY_STRING) //GET_FUNCTION FOR FEEDBACK
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: Set Val - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }
}

DEFINE_CALL 'SET_MIXER'(CHAR OBJECT[6], INTEGER INPUT, INTEGER OUTPUT, INTEGER PARAM, INTEGER VALUE)
//                  OBJECT = NODE+VD+OBJECT;PARAM = MUTE, SOLO, AUX, GROUP,OVERRIDE,AUTO,AUX ;VALUE = MUTE <1>,UNMUTE <0>,ROUTE <1>,UNROUTE <0>
{
    LOCAL_VAR INTEGER S_V;//STATE VAR
    LOCAL_VAR INTEGER S_VLOW;//LOW BYTE OF DATA
    LOCAL_VAR INTEGER S_VHIGH;//HIGH BYTE OF DATA
    LOCAL_VAR INTEGER DEVICE;//SPECIFIES TYPE OF DEVICE BEING PASSED TO 'GET_SV'
    LOCAL_VAR CHAR MY_DATA[4];
    LOCAL_VAR LONG MY_PERCENT;
    LOCAL_VAR CHAR MY_STRING[13];
    LOCAL_VAR CHAR EVENT;
    LOCAL_VAR CHAR GET_EVENT;//DETERMINES DATA TYPE FOR GET S_V

    DEVICE = MIXER;
    IF(PARAM = PAN || PARAM = OFF_GAIN || PARAM = AUX_GAIN || PARAM = GROUP_GAIN)
    {
        EVENT = $8D; //FOR SENDING PERCENT VALUES
        GET_EVENT = $8E;//FOR GETTING PERCENT VALUES
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
        MY_DATA = "0,VALUE,0,0";
    }
    ELSE
    {
        EVENT = $88; //FOR DISCRETE VALUES
        GET_EVENT = $89;//FOR GETTING Discrete VALUES
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
        MY_DATA = "$00,$00,$00,VALUE";
    }

    IF(S_V != 65535){//error check
        MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
        CALL 'CHECKSUM'(MY_STRING)

        //THESE STATEMENTS ARE ESSENTIALLY A 'GET' STATEMENT.  AFTER SENDING STRING GET_VALUE.
        //GET_FUNCTION FOR FEEDBACK
        MY_STRING = "GET_EVENT,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";
        CALL 'CHECKSUM'(MY_STRING)
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: Set Mixer - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }
}

DEFINE_CALL 'SET_ROOMCOMBINE'(CHAR OBJECT[6], INTEGER INPUT, INTEGER OUTPUT, INTEGER PARAM, INTEGER VALUE)
//           OBJECT = NODE+VD+OBJECT;PARAM = SOURCE_GAIN,BGM_GAIN, MASTER_GAIN, SOURCE_MUTE, BGM_MUTE, MASTER_MUTE,BGM_SELECT, ;VALUE = MUTE <1>,UNMUTE <0>,ROUTE <1>,UNROUTE <0> FOR DISCRETES; 0-100 <PERCENT> FOR GAINS; 0-# OF BGM INPUTS FOR BGM_SELECT
{
    LOCAL_VAR INTEGER S_V;//STATE VAR
    LOCAL_VAR INTEGER S_VLOW;//LOW BYTE OF DATA
    LOCAL_VAR INTEGER S_VHIGH;//HIGH BYTE OF DATA
    LOCAL_VAR INTEGER DEVICE;
    LOCAL_VAR CHAR MY_DATA[4];
    LOCAL_VAR LONG MY_PERCENT;
    LOCAL_VAR CHAR MY_STRING[13];
    LOCAL_VAR CHAR EVENT;

    DEVICE = ROOM_COMBINE;
    IF(PARAM = SOURCE_GAIN || PARAM = BGM_GAIN || PARAM = MASTER_GAIN )
    {
        EVENT = $8D; //FOR SENDING PERCENT VALUES
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
        MY_DATA = "0,VALUE,0,0";
    }
    ELSE
    {
        EVENT = $88; //FOR DISCRETE VALUES
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
        MY_DATA = "$00,$00,$00,VALUE";
    }

    IF(S_V != 65535){//error check
        MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
        CALL 'CHECKSUM'(MY_STRING)

        //THESE STATEMENTS ARE ESSENTIALLY A 'GET' STATEMENT.  AFTER SENDING STRING GET_VALUE.
        //GET_FUNCTION FOR FEEDBACK
        IF (EVENT = $88) //DISCRETE
            MY_STRING = "$89,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";
        ELSE //PERCENT
            MY_STRING = "$8E,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";

        CALL 'CHECKSUM'(MY_STRING)
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: Set Room combine - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }
}
DEFINE_CALL 'SET_TELEPHONE'(CHAR OBJECT[6],INTEGER INPUT, INTEGER OUTPUT,INTEGER PARAM,INTEGER VALUE)
{
    LOCAL_VAR INTEGER S_V;//STATE VAR
    LOCAL_VAR INTEGER S_VLOW;//LOW BYTE OF S_V
    LOCAL_VAR INTEGER S_VHIGH;//HIGH BYTE OF S_V
    LOCAL_VAR INTEGER DEVICE;//SPECIFIES TYPE OF DEVICE BEING PASSED TO 'GET_SV'
    LOCAL_VAR CHAR MY_DATA[4]; //FOUR BYTE DATA FIELD THAT HOLDS THE VALUE OF THE S_V
    LOCAL_VAR CHAR MY_STRING[13];//COMPLETE MESSAGE BEFORE BEING PADDED WITH STX,CHECKSUM,ETX, AND SPECIAL CHAR SUBSITUTION
    LOCAL_VAR CHAR EVENT; //DETERMINES DATA TYPE FOR S_V
    LOCAL_VAR CHAR GET_EVENT;//DETERMINES DATA TYPE FOR GET S_V

    DEVICE = TELEPHONE
    OUTPUT = 0;
    IF(PARAM = TX_GAIN || PARAM = RX_GAIN || PARAM = DIAL_TONE_GAIN || PARAM = RING_GAIN || PARAM = DTMF_GAIN)
    {
        EVENT = $8D;  // FOR SENDING PERCENT VALUES
        GET_EVENT = $8E;//FOR GETTING PERCENT VALUES
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
        MY_DATA = "0,VALUE,0,0"; //when using percent only 2nd Data byte is utilized for range 0-100
    }
    ELSE IF(PARAM = TX_MUTE || PARAM = RX_MUTE || PARAM = AUTO_ANSWER)
    {
        EVENT = $88; //FOR SENDING DISCRETE VALUES
        GET_EVENT = $89; //FOR GETTING DISCRETE VALUES
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
        MY_DATA = "$00,$00,$00,VALUE"; //when using discrete the only value is 0 or 1 (on/off) unless using auto_answer
    }
    ELSE // These are buttons need to send a message of value 1 and then another message with value 0
    {
        EVENT = $88; //FOR SENDING DISCRETE VALUES
        GET_EVENT = $89; //FOR GETTING DISCRETE VALUES
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
        MY_DATA = "$00,$00,$00,$01"; //send 1 to push button\

        IF(S_V != 65535){//error check
            MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
            CALL 'CHECKSUM'(MY_STRING)
        }
        ELSE{
            SEND_STRING 0,"'BSS_ERROR: Set TELEPHONE - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
        }
        MY_DATA = "$00,$00,$00,$00"; //send 0 to release button
    }

    IF(S_V != 65535){//error check
        MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
        CALL 'CHECKSUM'(MY_STRING)

        //THESE STATEMENTS ARE ESSENTIALLY A 'GET' STATEMENT.  AFTER SENDING STRING GET_VALUE.
        IF(PARAM = TX_GAIN || PARAM = RX_GAIN || PARAM = DIAL_TONE_GAIN || PARAM = RING_GAIN || PARAM = DTMF_GAIN || PARAM = TX_MUTE || PARAM = RX_MUTE || PARAM = AUTO_ANSWER)
        {
            MY_STRING = "GET_EVENT,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";
            CALL 'CHECKSUM'(MY_STRING) //GET_FUNCTION FOR FEEDBACK
        }
        IF(PARAM = DIAL_HANGUP) // special get for DIAL_HANGUP
        {
            S_V = 126;
            S_VLOW =  LO_BYTE(S_V);//LOW BYTE
            S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
            MY_STRING = "GET_EVENT,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";
            CALL 'CHECKSUM'(MY_STRING) //GET_FUNCTION FOR FEEDBACK
        }
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: Set TELEPHONE - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }
}

DEFINE_CALL 'SET_GAIN'(CHAR OBJECT[6],INTEGER DEVICE,INTEGER INPUT, INTEGER OUTPUT, SLONG VALUE)
{                  //  OBJECT = NODE+VD+OBJECT; DEVICE = MM <MANUAL MIXER>,AUTOMIXER, MIXER, GAIN<ENTER 0 IN INPUT AND OUTPUT FIELD TO SPECIFY SINGLE CHANNEL GAIN DEVICE>, N_GAIN :VALUE = -300,000 <-> 100,000
    LOCAL_VAR INTEGER S_V;//STATE VAR
    LOCAL_VAR INTEGER S_VLOW; //LOW BYTE OF DATA
    LOCAL_VAR INTEGER S_VHIGH; //HIGH BYTE OF DATA
    LOCAL_VAR CHAR MY_DATA[4]; //DATA VALUE
    LOCAL_VAR INTEGER GAIN_A[4]; //CREATE ARRAY TO RETURN LONG GAIN BYTES BY_REF
    LOCAL_VAR CHAR MY_STRING[13];
    LOCAL_VAR CHAR EVENT;
    LOCAL_VAR INTEGER PARAM;

    EVENT = $88;
    PARAM = GAIN;

    S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
    S_VLOW =  LO_BYTE(S_V);//LOW BYTE
    S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
    CALL 'SLONG_BYTES'(VALUE,GAIN_A)
    MY_DATA = "GAIN_A[1],GAIN_A[2],GAIN_A[3],GAIN_A[4]"; //MUST CONVERT INTO RECEIVING TYPE
    MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
    IF(S_V != 65535){//error check
        CALL 'CHECKSUM'(MY_STRING)
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: Set Gain - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }
}

DEFINE_CALL 'SET_GAIN%'(CHAR OBJECT[6],INTEGER DEVICE,INTEGER INPUT, INTEGER OUTPUT, INTEGER PERCENT) //1% = 1/3dB
{                  //  OBJECT = NODE+VD+OBJECT, DEVICE = MM <MANUAL MIXER>,AUTOMIXER, MIXER, GAIN<ENTER 0 IN INPUT AND OUTPUT FIELD TO SPECIFY SINGLE CHANNEL GAIN DEVICE>, N_GAIN :PERCENT = 0.0 - 100.0
    LOCAL_VAR INTEGER S_V;//STATE VAR
    LOCAL_VAR INTEGER S_VLOW;
    LOCAL_VAR INTEGER S_VHIGH;
    LOCAL_VAR CHAR MY_DATA[4]; //DATA VALUE
    LOCAL_VAR INTEGER GAIN_A[4]; //CREATE ARRAY TO RETURN LONG GAIN BYTES BY_REF
    LOCAL_VAR CHAR MY_STRING[13];
    LOCAL_VAR LONG MY_PERCENT;
    LOCAL_VAR CHAR EVENT;
    LOCAL_VAR INTEGER PARAM;

    EVENT = $8D; //Set_Percent
    PARAM = GAIN;

    S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
    S_VLOW =  LO_BYTE(S_V);//LOW BYTE
    S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
    MY_DATA = "0,PERCENT,0,0"

    IF(S_V != 65535){//error check
        MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
        CALL 'CHECKSUM'(MY_STRING)

        //THESE STATEMENTS ARE ESSENTIALLY A 'GET' STATEMENT.  AFTER SENDING STRING GET_VALUE.
        //UNCOMENT NEXT TWO LINES IF THE PROGRAMMER WISHES TO RECEIVE A RESPONSE TO EVERY GAIN STRING SENT.
        MY_STRING = "$8E,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00"; //$8E Get_Percent
        CALL 'CHECKSUM'(MY_STRING) //GET_FUNCTION FOR FEEDBACK
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: Set Gain% - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }

}


DEFINE_CALL 'SET_PRESET'(INTEGER PRESET_TYPE,INTEGER PRESET_NUMBER)
{
LOCAL_VAR CHAR SEND[10];
LOCAL_VAR CHAR EVENT;

    IF(PRESET_TYPE = PARAMETER_PRESET)
        EVENT = $8C;
    ELSE IF (PRESET_TYPE = DEVICE_PRESET)
        EVENT = $8B;
    ELSE //ERROR MESSAGE TO CONSOLE
        SEND_COMMAND 0,"'BSS_ERROR: Set_Preset - PARAM TYPE NOT FOUND.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"

    SEND = "EVENT,$0,$0,$0,PRESET_NUMBER";
    CALL 'CHECKSUM'(SEND)

}
DEFINE_CALL 'SUBSCRIBE'(CHAR OBJECT[6],INTEGER DEVICE,INTEGER INPUT, INTEGER OUTPUT,INTEGER PARAM) //CALL THIS IF YOU WANT LONDON TO SEND PARAMETER UPDATES
{  //                  OBJECT = NODE+VD+OBJECT, SV = STATE VAR; PARAM = GAIN <3>,MUTE <1>,UNMUTE <0>,ROUTE <1>,UNROUTE <0>
    LOCAL_VAR INTEGER S_V;
    LOCAL_VAR INTEGER S_VLOW;
    LOCAL_VAR INTEGER S_VHIGH;
    LOCAL_VAR INTEGER i;
    LOCAL_VAR CHAR EVENT;
    LOCAL_VAR CHAR MY_DATA[4];
    LOCAL_VAR CHAR MY_STRING[13];


    EVENT = $89; //EVENT FOR SUBSCRIBE REGULAR

    IF(DEVICE == TELEPHONE && PARAM == DIAL_HANGUP) // need to subscribe to a different SV then you use to push the button.
    {
        S_V = 126
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
    }
    ELSE
    {
        S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
        S_VLOW =  LO_BYTE(S_V);//LOW BYTE
        S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
    }

    IF (PARAM = METER)
        PARAM =100;//METER SUBSCRIPTION RATE
    ELSE
        PARAM = 0;//ALL OTHER TYPES MUST HAVE DATA = 0 WHEN SUBSCRIBING

    MY_DATA = "$00,$00,$00,PARAM"; //SUBSCRIBE MESSAGE WITH 100ms <ONLY FOR METERS>
    MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";

    IF (STARTUP) //IF CALLED FROM STARTUP EVENT.  THESE ARE VARIABLES YOU WANT TO PARSE FEEDBACK FOR.
    {
        T = T+1; //GLOBAL
        FB[T] = "OBJECT,S_VHIGH,S_VLOW,MY_DATA";
    }
    IF(S_V != 65535){//error check
        CALL 'CHECKSUM'(MY_STRING)//SEND SUBSCRIBE MESSAGE
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: SUBSCRIBE - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }
}

DEFINE_CALL 'SUBSCRIBE%'(CHAR OBJECT[6],INTEGER DEVICE,INTEGER INPUT, INTEGER OUTPUT,INTEGER PARAM) //CALL THIS IF YOU WANT LONDON TO SEND PARAMETER UPDATES
{  //                  OBJECT = NODE+VD+OBJECT, SV = STATE VAR; PARAM = GAIN <3>,MUTE <1>,UNMUTE <0>,ROUTE <1>,UNROUTE <0>
    LOCAL_VAR INTEGER S_V;
    LOCAL_VAR INTEGER S_VLOW;
    LOCAL_VAR INTEGER S_VHIGH;
    LOCAL_VAR CHAR EVENT;
    LOCAL_VAR CHAR MY_RATE[4];
    LOCAL_VAR CHAR MY_STRING[13];

    EVENT = $8E; //EVENT FOR SUBSCRIBE PERCENT

    S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
    S_VLOW =  LO_BYTE(S_V);//LOW BYTE
    S_VHIGH = HI_BYTE(S_V); //HIGH BYTE

    IF (PARAM == METER)
        PARAM =100;
    ELSE
        PARAM = 0;

    MY_RATE = "$00,$00,$00,PARAM"; //SUBSCRIBE MESSAGE WITH 100ms ONLY FOR METERS
    MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_RATE";

    IF (STARTUP) //IF CALLED FROM STARTUP EVENT.  THESE ARE VARIABLES YOU WANT TO PARSE FEEDBACK FOR.
    {
        T = T+1; //GLOBAL
        FB[T] = "OBJECT,S_VHIGH,S_VLOW,MY_RATE";
    }
    IF(S_V != 65535){//error check
        CALL 'CHECKSUM'(MY_STRING)//SEND SUBSCRIBE MESSAGE
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: SUBSCRIBE% - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }
}

DEFINE_CALL 'UN_SUBSCRIBE'(CHAR OBJECT[6],INTEGER DEVICE,INTEGER INPUT, INTEGER OUTPUT,INTEGER PARAM) //CALL THIS IF YOU WANT LONDON TO SEND PARAMETER UPDATES
{  //                  OBJECT = NODE+VD+OBJECT, SV = STATE VAR; PARAM = GAIN <3>,MUTE <1>,UNMUTE <0>,ROUTE <1>,UNROUTE <0>
    LOCAL_VAR INTEGER S_V;
    LOCAL_VAR INTEGER S_VLOW;
    LOCAL_VAR INTEGER S_VHIGH;
    LOCAL_VAR CHAR EVENT;
    LOCAL_VAR CHAR MY_RATE[4];
    LOCAL_VAR CHAR MY_STRING[13];

    EVENT = $8A; //EVENT FOR UN_SUBSCRIBE REGULAR

    S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
    S_VLOW =  LO_BYTE(S_V);//LOW BYTE
    S_VHIGH = HI_BYTE(S_V); //HIGH BYTE

    IF (PARAM = METER)
        PARAM =100;
    ELSE
        PARAM = 0;

    MY_RATE = "$00,$00,$00,PARAM"; //SUBSCRIBE MESSAGE WITH 100ms ONLY FOR METERS
    MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_RATE";
    IF (STARTUP) //IF CALLED FROM STARTUP_EVENT (OR DATA_EVENT:ONLINE).  THESE ARE VARIABLES YOU WANT TO PARSE FEEDBACK FOR.
    {
        T = T+1; //GLOBAL
        FB[T] = "OBJECT,S_VHIGH,S_VLOW,MY_RATE";
    }
    IF(S_V != 65535){//error check
        CALL 'CHECKSUM'(MY_STRING)//SEND SUBSCRIBE MESSAGE//SEND SUBSCRIBE MESSAGE
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: UN SUBSCRIBE - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }

}

DEFINE_CALL 'UN_SUBSCRIBE%'(CHAR OBJECT[6],INTEGER DEVICE,INTEGER INPUT, INTEGER OUTPUT,INTEGER PARAM) //CALL THIS IF YOU WANT LONDON TO SEND PARAMETER UPDATES
{  //                  OBJECT = NODE+VD+OBJECT, SV = STATE VAR; PARAM = GAIN <3>,MUTE <1>,UNMUTE <0>,ROUTE <1>,UNROUTE <0>
    LOCAL_VAR INTEGER S_V;
    LOCAL_VAR INTEGER S_VLOW;
    LOCAL_VAR INTEGER S_VHIGH;
    LOCAL_VAR CHAR EVENT;
    LOCAL_VAR CHAR MY_RATE[4];
    LOCAL_VAR CHAR MY_STRING[13];


    EVENT = $8F; //EVENT FOR UN_SUBSCRIBE PERCENT


    S_V = GET_SV(DEVICE,INPUT,OUTPUT,PARAM)
    S_VLOW =  LO_BYTE(S_V);//LOW BYTE
    S_VHIGH = HI_BYTE(S_V); //HIGH BYTE
    PARAM = 0;
    MY_RATE = "$00,$00,$00,PARAM"; //SUBSCRIBE MESSAGE WITH 100ms ONLY FOR METERS
    MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_RATE";

    IF (STARTUP) //IF CALLED FROM STARTUP_EVENT (OR DATA_EVENT:ONLINE).  THESE ARE VARIABLES YOU WANT TO PARSE FEEDBACK FOR.
    {
        T = T+1; //GLOBAL
        FB[T] = "OBJECT,S_VHIGH,S_VLOW,MY_RATE";
    }
    IF(S_V != 65535){//error check
        CALL 'CHECKSUM'(MY_STRING)//SEND SUBSCRIBE MESSAGE//SEND SUBSCRIBE MESSAGE
    }
    ELSE{
        SEND_STRING 0,"'BSS_ERROR: UN SUBSCRIBE% - SV incorrect. MESSAGE NOT SENT.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
    }
}

DEFINE_CALL 'CHECKSUM'(CHAR MY_STRING[13]) //CALCULATE CHECKSUM AND SEND STRING
{
LOCAL_VAR CHAR SEND[26];
LOCAL_VAR INTEGER I;
LOCAL_VAR CHAR CS;

    SEND = ""; CS = 0;

    FOR (I=1;I <= LENGTH_ARRAY(MY_STRING);I++)
    {
        CS = (CS BXOR MY_STRING[I]); //CHECKSUM;

        IF (IS_SPECIAL(MY_STRING[I])) //CHECK FOR SPECIAL CHARS
            SEND = "SEND,$1B,(MY_STRING[I]+128)"; //CONCATENATE ESCAPE CHAR AND SPECIAL CHAR
        ELSE
            SEND = "SEND,MY_STRING[I]";

    }

    IF(IS_SPECIAL(CS))//CHECK TO MAKE SURE CALCULATED CHECKSUM IS NOT A SPECIAL CHAR
        SEND = "STX,SEND,$1B,(CS+128),ETX";
    ELSE
        SEND = "STX,SEND,CS,ETX";

    SEND_STRING dvSOUNDWEB, SEND;

        IF(bDEBUG_FLAG==2) // if full debug ON, print everything...
            fnLOG_HEX(SEND,LENGTH_STRING(SEND),'--> SENT')
}

DEFINE_CALL 'SLONG_BYTES'(SLONG intGAIN, INTEGER GAIN_A[4]) //TAKES SLONG AND RETURNS INTEGER 32BIT VALUE IN 4 CHAR CHARACTERS
{
    LOCAL_VAR INTEGER INT;
    LOCAL_VAR INTEGER HINT;
    LOCAL_VAR LONG LINT;
    LOCAL_VAR INTEGER LHI_BYTE;
    LOCAL_VAR INTEGER LLO_BYTE;
    LOCAL_VAR INTEGER ULO_BYTE;
    LOCAL_VAR INTEGER UHI_BYTE;

    INT = TYPE_CAST(intGAIN); //GET LOW 16 BITS FROM SLONG
    LINT = TYPE_CAST(intGAIN); //GET UPPER 16 BITS FROM SLONG
    LHI_BYTE = HI_BYTE(INT); //LOWER HI_BYTE
    LLO_BYTE = LO_BYTE(INT); //LOWER LO_BYTE

    LINT = LINT >> 16;
    HINT = TYPE_CAST(LINT)
    UHI_BYTE = HI_BYTE(HINT); //UPPER HI_BYTE
    ULO_BYTE = LO_BYTE(HINT); //UPPER LO_BYTE

    GAIN_A[1] = UHI_BYTE; //GAIN_A IS THE RETURN ARRAY OF VALUES BY_REF
    GAIN_A[2] = ULO_BYTE;
    GAIN_A[3] = LHI_BYTE;
    GAIN_A[4] = LLO_BYTE;
}

DEFINE_CALL 'LONG_BYTES'(LONG intGAIN, INTEGER GAIN_A[4]) //TAKES LONG AND RETURNS INTEGER 32BIT VALUE IN 4 CHAR CHARACTERS
{
    LOCAL_VAR INTEGER INT;
    LOCAL_VAR INTEGER HINT;
    LOCAL_VAR LONG LINT;
    LOCAL_VAR INTEGER LHI_BYTE;
    LOCAL_VAR INTEGER LLO_BYTE;
    LOCAL_VAR INTEGER ULO_BYTE;
    LOCAL_VAR INTEGER UHI_BYTE;

    INT = TYPE_CAST(intGAIN); //GET LOW 16 BITS FROM SLONG
    LINT = TYPE_CAST(intGAIN); //GET UPPER 16 BITS FROM SLONG
    LHI_BYTE = HI_BYTE(INT); //LOWER HI_BYTE
    LLO_BYTE = LO_BYTE(INT); //LOWER LO_BYTE

    LINT = LINT >> 16;
    HINT = TYPE_CAST(LINT)
    UHI_BYTE = HI_BYTE(HINT); //UPPER HI_BYTE
    ULO_BYTE = LO_BYTE(HINT); //UPPER LO_BYTE

    GAIN_A[1] = UHI_BYTE; //GAIN_A IS THE RETURN ARRAY OF VALUES BY_REF
    GAIN_A[2] = ULO_BYTE;
    GAIN_A[3] = LHI_BYTE;
    GAIN_A[4] = LLO_BYTE;
}

DEFINE_FUNCTION CHAR[1] FOUR_BITS_TOSTRING(LONG convert)
{
    LOCAL_VAR CHAR number[1];
    number = "";
    switch(convert){
        case 0:{ // 0
            number = '0';
            break;
        }
        case 1:{
            number = '1';
            break;
        }
        case 2:{
            number = '2';
            break;
        }
        case 3:{
            number = '3';
            break;
        }
        case 4:{
            number = '4';
            break;
        }
        case 5:{
            number = '5';
            break;
        }
        case 6:{
            number = '6';
            break;
        }
        case 7:{
            number = '7';
            break;
        }
        case 8:{
            number = '8';
            break;
        }
        case 9:{
            number = '9';
            break;
        }
        case 10:{
            number = '#';
            break;
        }
        case 11:{
            number = '*';
            break;
        }
        case 12:{
            number = ',';
            break;
        }
        case 13:{
            number = '+';
            break;
        }
        case 14:{
            number = '';
            break;
        }
        case 15:{
            number = '';
            break;
        }
    }
    return (number);
}
DEFINE_FUNCTION CHAR[32] DISPLAY_NUMBER(CHAR first[12],char second[12],char third[12],char fourth[12])
{
    //need to do in order from 67 to 64.
    LOCAL_VAR CHAR Number[32]
    LOCAL_VAR CHAR String_1[8]
    LOCAL_VAR CHAR String_2[8]
    LOCAL_VAR CHAR String_3[8]
    LOCAL_VAR CHAR String_4[8]
    String_1 = "FOUR_BITS_TOSTRING((first[9]>>4) & $0F),FOUR_BITS_TOSTRING((first[9]) & $0F),FOUR_BITS_TOSTRING((first[10]>>4) & $0F),FOUR_BITS_TOSTRING((first[10]) & $0F),FOUR_BITS_TOSTRING((first[11]>>4) & $0F),FOUR_BITS_TOSTRING((first[11]) & $0F),FOUR_BITS_TOSTRING((first[12]>>4) & $0F),FOUR_BITS_TOSTRING((first[12]) & $0F)";
    String_2 = "FOUR_BITS_TOSTRING((second[9]>>4) & $0F),FOUR_BITS_TOSTRING((second[9]) & $0F),FOUR_BITS_TOSTRING((second[10]>>4) & $0F),FOUR_BITS_TOSTRING((second[10]) & $0F),FOUR_BITS_TOSTRING((second[11]>>4) & $0F),FOUR_BITS_TOSTRING((second[11]) & $0F),FOUR_BITS_TOSTRING((second[12]>>4) & $0F),FOUR_BITS_TOSTRING((second[12]) & $0F)";
    String_3 = "FOUR_BITS_TOSTRING((third[9]>>4) & $0F),FOUR_BITS_TOSTRING((third[9]) & $0F),FOUR_BITS_TOSTRING((third[10]>>4) & $0F),FOUR_BITS_TOSTRING((third[10]) & $0F),FOUR_BITS_TOSTRING((third[11]>>4) & $0F),FOUR_BITS_TOSTRING((third[11]) & $0F),FOUR_BITS_TOSTRING((third[12]>>4) & $0F),FOUR_BITS_TOSTRING((third[12]) & $0F)";
    String_4 = "FOUR_BITS_TOSTRING((fourth[9]>>4) & $0F),FOUR_BITS_TOSTRING((fourth[9]) & $0F),FOUR_BITS_TOSTRING((fourth[10]>>4) & $0F),FOUR_BITS_TOSTRING((fourth[10]) & $0F),FOUR_BITS_TOSTRING((fourth[11]>>4) & $0F),FOUR_BITS_TOSTRING((fourth[11]) & $0F),FOUR_BITS_TOSTRING((fourth[12]>>4) & $0F),FOUR_BITS_TOSTRING((fourth[12]) & $0F)";
    switch(first[8])
    {
        case 100:
        {
            switch(second[8])
            {
                case 101:
                {
                    if(third[8] == 102)
                    {
                        Number = "String_4,String_3,String_2,String_1";
                    }
                    else
                    {
                        Number = "String_3,String_4,String_2,String_1";
                    }
                }
                case 102:
                {
                    if(third[8] == 101)
                    {
                        Number = "String_4,String_2,String_3,String_1";
                    }
                    else
                    {
                        Number = "String_3,String_2,String_4,String_1";
                    }
                }
                case 103:
                {
                    if(third[8] == 101)
                    {
                        Number = "String_2,String_4,String_3,String_1";
                    }
                    else
                    {
                        Number = "String_2,String_3,String_4,String_1";
                    }
                }
            }
        }
        case 101:
        {
            switch(second[8])
            {
                case 100:
                {
                    if(third[8] == 102)
                    {
                        Number = "String_4,String_3,String_1,String_2";
                    }
                    else
                    {
                        Number = "String_3,String_4,String_1,String_2";
                    }
                }
                case 102:
                {
                    if(third[8] == 100)
                    {
                        Number = "String_4,String_2,String_1,String_3";
                    }
                    else
                    {
                        Number = "String_3,String_2,String_1,String_4";
                    }
                }
                case 103:
                {
                    if(third[8] == 100)
                    {
                        Number = "String_2,String_4,String_1,String_3";
                    }
                    else
                    {
                        Number = "String_2,String_3,String_1,String_4";
                    }
                }
            }
        }
        case 102:
        {
            switch(second[8])
            {
                case 100:
                {
                    if(third[8] == 101)
                    {
                        Number = "String_4,String_1,String_3,String_2";
                    }
                    else
                    {
                        Number = "String_3,String_1,String_4,String_2";
                    }
                }
                case 101:
                {
                    if(third[8] == 100)
                    {
                        Number = "String_4,String_1,String_2,String_3";
                    }
                    else
                    {
                        Number = "String_3,String_1,String_2,String_4";
                    }
                }
                case 103:
                {
                    if(third[8] == 100)
                    {
                        Number = "String_2,String_1,String_4,String_3";
                    }
                    else
                    {
                        Number = "String_2,String_1,String_3,String_4";
                    }
                }
            }
        }
        case 103:
        {
            switch(second[8])
            {
                case 100:
                {
                    if(third[8] == 101)
                    {
                        Number = "String_1,String_4,String_3,String_2";
                    }
                    else
                    {
                        Number = "String_1,String_3,String_4,String_2";
                    }
                }
                case 101:
                {
                    if(third[8] == 100)
                    {
                        Number = "String_1,String_4,String_2,String_3";
                    }
                    else
                    {
                        Number = "String_1,String_3,String_2,String_4";
                    }
                }
                case 102:
                {
                    if(third[8] == 100)
                    {
                        Number = "String_1,String_2,String_4,String_3";
                    }
                    else
                    {
                        Number = "String_1,String_2,String_3,String_4";
                    }
                }
            }
        }
    }
    fnLOG_HEX(String_1,LENGTH_ARRAY(String_1),"'String_1 = '");
    fnLOG_HEX(String_2,LENGTH_ARRAY(String_2),"'String_2 = '");
    fnLOG_HEX(String_3,LENGTH_ARRAY(String_3),"'String_3 = '");
    fnLOG_HEX(String_4,LENGTH_ARRAY(String_4),"'String_4 = '");
    fnLOG_HEX(Number,LENGTH_ARRAY(Number),"'Number = '");
    return Number;
}
DEFINE_CALL 'SET_NUMBER'(CHAR OBJECT[6],CHAR NUMBER[32])
{
    LOCAL_VAR INTEGER i;
    LOCAL_VAR INTEGER j;
    LOCAL_VAR CHAR newArray[32];

    LOCAL_VAR INTEGER S_VLOW;//LOW BYTE OF S_V
    LOCAL_VAR INTEGER S_VHIGH;//HIGH BYTE OF S_V
    LOCAL_VAR CHAR MY_DATA[4]; //FOUR BYTE DATA FIELD THAT HOLDS THE VALUE OF THE S_V
    LOCAL_VAR CHAR MY_STRING[13];//COMPLETE MESSAGE BEFORE BEING PADDED WITH STX,CHECKSUM,ETX, AND SPECIAL CHAR SUBSITUTION
    LOCAL_VAR CHAR EVENT; //DETERMINES DATA TYPE FOR S_V
    LOCAL_VAR CHAR GET_EVENT;//DETERMINES DATA TYPE FOR GET S_V

    newArray = "$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F,$F";//F is blank so start with an array of all blank.
    j=32; // There is a max of 32 digits allowed by the BLU
    for(i=LENGTH_ARRAY(NUMBER);i>0;i--){//add the phone number to the end of the array
        newArray[j] = STRING_TO_FOUR_BITS(NUMBER[i]) // need to convert some of the chars to hex like +
        j--;
    }
    //send the number to the device and get the value back this requires 8 messages to be sent 4 to send the number and then 4 get messages.
    EVENT = $88; //FOR SENDING DISCRETE VALUES
    GET_EVENT = $89; //FOR GETTING DISCRETE VALUES
    S_VLOW =  $64;//LOW BYTE
    S_VHIGH = $00; //HIGH BYTE
    MY_DATA = "newArray[25]<<4+newArray[26],newArray[27]<<4+newArray[28],newArray[29]<<4+newArray[30],newArray[31]<<4+newArray[32]"; //Set up the last 8 digits

    MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
    CALL 'CHECKSUM'(MY_STRING)

    //get message
    MY_STRING = "GET_EVENT,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";
    CALL 'CHECKSUM'(MY_STRING) //GET_FUNCTION FOR FEEDBACK

    S_VLOW =  $65;//LOW BYTE
    MY_DATA = "newArray[17]<<4+newArray[18],newArray[19]<<4+newArray[20],newArray[21]<<4+newArray[22],newArray[23]<<4+newArray[24]"; //

    MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
    CALL 'CHECKSUM'(MY_STRING)

    //get message
    MY_STRING = "GET_EVENT,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";
    CALL 'CHECKSUM'(MY_STRING) //GET_FUNCTION FOR FEEDBACK

    S_VLOW =  $66;//LOW BYTE
    MY_DATA = "newArray[9]<<4+newArray[10],newArray[11]<<4+newArray[12],newArray[13]<<4+newArray[14],newArray[15]<<4+newArray[16]"; //

    MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
    CALL 'CHECKSUM'(MY_STRING)

    //get message
    MY_STRING = "GET_EVENT,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";
    CALL 'CHECKSUM'(MY_STRING) //GET_FUNCTION FOR FEEDBACK

    S_VLOW =  $67;//LOW BYTE
    MY_DATA = "newArray[1]<<4+newArray[2],newArray[3]<<4+newArray[4],newArray[5]<<4+newArray[6],newArray[7]<<4+newArray[8]"; //

    MY_STRING = "EVENT,OBJECT,S_VHIGH,S_VLOW,MY_DATA";
    CALL 'CHECKSUM'(MY_STRING)

    //get message
    MY_STRING = "GET_EVENT,OBJECT,S_VHIGH,S_VLOW,$00,$00,$00,$00";
    CALL 'CHECKSUM'(MY_STRING) //GET_FUNCTION FOR FEEDBACK

}
DEFINE_FUNCTION CHAR STRING_TO_FOUR_BITS(CHAR convert)
{
    LOCAL_VAR CHAR number;
    number = $F;
    switch(convert){
        case '0':{ // 0
            number = $0;
            break;
        }
        case '1':{
            number = $1;
            break;
        }
        case '2':{
            number = $2;
            break;
        }
        case '3':{
            number = $3;
            break;
        }
        case '4':{
            number = $4;
            break;
        }
        case '5':{
            number = $5;
            break;
        }
        case '6':{
            number = $6;
            break;
        }
        case '7':{
            number = $7;
            break;
        }
        case '8':{
            number = $8;
            break;
        }
        case '9':{
            number = $9;
            break;
        }
        case '#':{
            number = $A;
            break;
        }
        case '*':{
            number = $B;
            break;
        }
        case ',':{
            number = $C;
            break;
        }
        case '+':{
            number = $D;
            break;
        }
        default:{
            number = $F;
            break;
        }
    }
    return (number);
}
DEFINE_CALL 'PROCESS_FEEDBACK'(CHAR RECEIVED_STRING[13])
{
    LOCAL_VAR CHAR EVENT;
    LOCAL_VAR CHAR NODE[2];
    LOCAL_VAR CHAR VD;
    LOCAL_VAR CHAR OBJECT[3];
    LOCAL_VAR CHAR SV[2];
    LOCAL_VAR CHAR MY_DATA[4];
    LOCAL_VAR CHAR RECEIVED[13]; //TEST
    LOCAL_VAR INTEGER I,J; //COUNTERS
    LOCAL_VAR CHAR CS; //CHECKSUM
    STACK_VAR INTEGER INDEX //DEBUG
    STACK_VAR CHAR HEX_DATA[100] // MAX SIZE


    EVENT = TYPE_CAST(LEFT_STRING(RECEIVED_STRING,1));
(*//DEBUG
    NODE = MID_STRING(RECEIVED_STRING,2,2);
    VD = MID_STRING(RECEIVED_STRING,4,1);
    OBJECT = MID_STRING(RECEIVED_STRING,5,3);
    SV = MID_STRING(RECEIVED_STRING,8,2);
*)
    RECEIVED_STRING = MID_STRING(RECEIVED_STRING,2,LENGTH_STRING(RECEIVED_STRING));  //CHOP OFF EVENT

    MY_DATA = RIGHT_STRING(RECEIVED_STRING,4);

    FOR (I = 1;I<=T;I++)//T is assigned in startup by the order and number of 'subscribes' called
    {
        IF(LEFT_STRING(RECEIVED_STRING,8)== LEFT_STRING(FB[I],8))//HiQnet address and SV of each object; elements 9-12 are the values of the SV
        {//MATCH - POPULATE VALUES IN FB[] FOR TRUE FEEDBACK
            FB[I][9] = MY_DATA[1];
            FB[I][10] = MY_DATA[2];
            FB[I][11] = MY_DATA[3];
            FB[I][12] = MY_DATA[4];

            IF (EVENT = $8D)//SET%
            {
                iGAIN_FRACTION =  TYPE_CAST(MID_STRING(FB[I],11,1))*256 + TYPE_CAST(MID_STRING(FB[I],12,1)) //TAKE THE FRACTIONAL PART OF THE GAIN FADER TO DECIDE WHETHER TO ROUND UP OR DOWN FOR CLOSEST INTEGER AND SEND TO TP
                IF (iGAIN_FRACTION > 32767)//ROUND UP TO NEXT INTEGER
                    FB[I][10] = FB[I][10]+1
            }

            I=T //DUMP OUT OF THE LOOP
        }
    }

(*
//DEBUG
//SEND_STRING 0, "'SV ', ITOHEX(TYPE_CAST(SV[1]<<8)+SV[2]), 'DATA ',ITOHEX(TYPE_CAST(MY_DATA[1]<<32)+TYPE_CAST(MY_DATA[2]<<16)+TYPE_CAST(MY_DATA[3]<<8)+MY_DATA[4])"
    HEX_DATA = "";
    FOR(INDEX=1;INDEX<=LENGTH_STRING(RECEIVED_STRING);INDEX++)
    {
        HEX_DATA="HEX_DATA,FORMAT(' $%02X',RECEIVED_STRING[INDEX])"
        //HEX_DATA="HEX_DATA,FORMAT(' #%d',RECEIVED_STRING[INDEX])" //decimal
    }
        SEND_STRING 0,"'STRING ',HEX_DATA"
*)

}



DEFINE_FUNCTION INTEGER GET_SV(INTEGER DEVICE,INTEGER INPUT, INTEGER OUTPUT,INTEGER PARAM) //GET STATE VARIABLE
{
LOCAL_VAR INTEGER intSV;

SELECT
 {
    ACTIVE ((DEVICE == AUTOMIXER)||(DEVICE == MIXER))://TO CONTROL INPUT CHANNEL PUT CHANNEL NUMBER IN 'INPUT' AND PUT 0 IN FOR OUTPUT;
    {                                              // TO CONTROL OUTPUT PUT 0 IN INPUT AND L <1> OR R <3> IN OUTPUT
        IF(!(INPUT==0)&&(OUTPUT==0)) //OUTPUT FIELD = 0 SO MEANS ADJUST INPUT VALUES
        {
            IF (PARAM == MUTE )
                intSV= 1+((INPUT-1)*100);
            ELSE IF (PARAM == GAIN)
                intSV = ((INPUT-1)*100);
            ELSE IF (PARAM == SOLO)
                intSV = (INPUT -1)*100 + 4;
            ELSE IF (PARAM == OVERRIDE)
                intSV = (INPUT-1)*100+5;
            ELSE IF (PARAM == AUTO)
                intSV = (INPUT-1)*100+7;
            ELSE IF (PARAM == PAN)
                intSV = ((INPUT-1)*100+2);
            ELSE IF (PARAM == OFF_GAIN)
                intSV = ((INPUT -1)*100+6);
            ELSE{ //ERROR MESSAGE TO CONSOLE
                SEND_STRING 0,"'BSS_ERROR: Set Mixer - PARAM TYPE NOT FOUND FOR NON-ZERO <INPUT> AND 0 <OUTPUT>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
                intSV = 65535; //error code.
            }
        }
        ELSE IF((INPUT == 0) && (!(OUTPUT ==0))) //INPUT FIELD = 0 SO ADJUST OUTPUT VALUES (MASTER OUTPUTS)
        {
            IF (PARAM == MUTE)
                intSV = 20000 + OUTPUT; //MUTE MASTER OUTPUT 20001 = LEFT; 20003 = RIGHT
            ELSE IF(PARAM == GAIN)
                intSV = 20000 + OUTPUT - 1; //MUTE MASTER OUTPUT 20000 = LEFT; 20002 = RIGHT
            ELSE IF(PARAM == AUX)
                intSV = (OUTPUT-1)*10 + 10002;
            ELSE IF(PARAM == GROUP)
                intSV = (OUTPUT-1)*10+11001;
            ELSE IF(PARAM == AUX_GAIN)
                intSV = ((OUTPUT-1)*10 + 10001);
            ELSE IF(PARAM = GROUP_GAIN)
                intSV = ((OUTPUT-1)*10+11000);
            ELSE{ //ERROR MESSAGE TO CONSOLE
                SEND_STRING 0,"'BSS_ERROR: Set Mixer - PARAM TYPE NOT FOUND FOR NON-ZERO <OUTPUT> AND 0 <INPUT>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
                intSV = 65535; //error code.
            }
        }
        ELSE IF(PARAM == GROUP)
                intSV = (INPUT-1)*100 + (OUTPUT-1)+40;//ROUTE TO GROUP
        ELSE{ //ERROR MESSAGE TO CONSOLE
            SEND_STRING 0,"'BSS_ERROR: Set Mixer - PARAM TYPE NOT FOUND FOR 0 <INPUT> AND 0 <OUTPUT>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
            intSV = 65535; //error code.
        }

    }
    ACTIVE (DEVICE == ROOM_COMBINE)://TO CONTROL INPUT CHANNEL PUT CHANNEL NUMBER IN 'INPUT' AND PUT 0 IN FOR OUTPUT
    {
        IF(!(INPUT==0)&&(OUTPUT==0)) //OUTPUT FIELD = 0 SO MEANS ADJUST INPUT VALUES
        {
            IF (PARAM == SOURCE_MUTE)
                intSV = (INPUT-1)*50+256
            ELSE IF (PARAM == BGM_MUTE)
                intSV = (INPUT-1)*50+258
            ELSE IF (PARAM == SOURCE_GAIN)
                intSV = (INPUT-1)*50+255
            ELSE IF (PARAM == BGM_GAIN)
                intSV = (INPUT-1)*50+257
            ELSE IF (PARAM == BGM_SELECT)//BACKGROUND MUSIC
                intSV = (INPUT-1)*50+259
            ELSE IF (PARAM == PARTITION)
                intSV = (INPUT-1)
            ELSE IF (PARAM == GROUP)
                intSV = (INPUT-1)*50 + 250
            ELSE{ //ERROR MESSAGE TO CONSOLE
                SEND_STRING 0,"'BSS_ERROR: Room Combine - PARAM TYPE NOT FOUND FOR NON-ZERO <INPUT> AND 0 <OUTPUT>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
                intSV = 65535; //error code.
            }
        }
        ELSE IF((INPUT == 0) && (!(OUTPUT == 0))) //INPUT FIELD = 0 SO ADJUST OUTPUT VALUES (MASTER OUTPUTS)
        {
            IF (PARAM == MASTER_MUTE)
                intSV = (OUTPUT -1)*50+254
            ELSE IF (PARAM == MASTER_GAIN)
                intSV = (OUTPUT -1)*50+252
            ELSE{ //ERROR MESSAGE TO CONSOLE
                SEND_STRING 0,"'BSS_ERROR: Room Combine - PARAM TYPE NOT FOUND FOR 0 <INPUT> AND NON-ZERO <OUTPUT>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
                intSV = 65535; //error code.
            }
        }
        ELSE{ //INPUT AND OUTPUT PARAMETERS ARE BOTH 0
            SEND_STRING 0,"'BSS_ERROR: Message not supported for Room Combine. Either input or output MUST be = 0.  SEE HELP FILE.'"
            intSV = 65535; //error code.
        }

    }
    ACTIVE ((DEVICE == ROUTER)||(DEVICE == MM)):
    {
        IF (PARAM == MUTE || PARAM == UNMUTE)
            intSV = (INPUT-1)+((OUTPUT-1)*128);
        ELSE IF (PARAM == GAIN)
            intSV = (INPUT+16383)+((OUTPUT-1)*128);
        ELSE{ //ERROR MESSAGE TO CONSOLE
            SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE = ROUTER || MIXER.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
            intSV = 65535; //error code.
        }
    }
    ACTIVE (DEVICE == N_GAIN):
    {
        IF (OUTPUT == 0) //N_GAIN DEVICE; ADJUST INPUT
        {
            IF (PARAM == MUTE || PARAM == UNMUTE)
                intSV = (INPUT-1)+32;
            ELSE IF (PARAM == GAIN)
                intSV = INPUT-1;
            ELSE{ //ERROR MESSAGE TO CONSOLE
                SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE = N_GAIN <OUTPUT == 0>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
                intSV = 65535; //error code.
            }
        }
        ELSE IF (INPUT == 0) //N_GAIN DEVICE; ADJUST MASTER OUTPUT
        {
            IF (PARAM == MUTE || PARAM == UNMUTE)
                intSV = 97;
            ELSE IF (PARAM == GAIN)
                intSV = 96;
            ELSE{ //ERROR MESSAGE TO CONSOLE
                SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE = N_GAIN <INPUT == 0>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
                intSV = 65535; //error code.
            }
        }
        ELSE{ //ERROR MESSAGE TO CONSOLE
            SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE = N_GAIN <INPUT != 0> <OUTPUT != 0>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
            intSV = 65535; //error code.
        }
    }
    ACTIVE (DEVICE == GAIN):
    {
        IF ((OUTPUT == 0) && (INPUT == 1)) //SINGLE GAIN DEVICE
        {
            IF (PARAM == MUTE || PARAM == UNMUTE)
                intSV = 1;
            ELSE IF (PARAM == GAIN)
                intSV = 0;
            ELSE IF (PARAM == POLARITY_ON || PARAM == POLARITY_OFF)
                intSV = 2;
            ELSE{ //ERROR MESSAGE TO CONSOLE
                SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE = GAIN <OUTPUT == 0>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
                intSV = 65535; //error code.
            }
        }
        ELSE{ //ERROR MESSAGE TO CONSOLE
            SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE = GAIN <OUTPUT != 0>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
            intSV = 65535; //error code.
        }
    }
    ACTIVE (DEVICE == SOURCE_SELECTOR):
    {
        intSV = 0;
    }
    ACTIVE (DEVICE == SOURCE_MATRIX):
    {
        intSV = (INPUT - 1);
    }
    ACTIVE (DEVICE == INPUT_CARD):
    {
        IF(PARAM == GAIN)
        {
            IF(INPUT == 1)
                intSV = 4;
            ELSE IF(INPUT == 2)
                intSV = 10;
            ELSE IF(INPUT == 3)
                intSV = 16;
            ELSE IF(INPUT == 4)
                intSV = 22;
            ELSE{ //ERROR MESSAGE TO CONSOLE
                SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE = GAIN <INPUT != 1,2,3,or 4>.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
                intSV = 65535; //error code.
            }
        }
        ELSE IF(PARAM == METER)
            intSV = (INPUT-1)*6;
        ELSE IF(PARAM == PHANTOM)
            INTSV = (INPUT-1)*6+5;
        ELSE IF(PARAM == REFERENCE)
            intSV = (INPUT-1)*6+1;
        ELSE IF(PARAM == ATTACK)
            intSV = (INPUT-1)*6+2;
        ELSE IF(PARAM == RELEASED)
            intSV = (INPUT-1)*6+3;
        ELSE{ //ERROR MESSAGE TO CONSOLE
            SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
            intSV = 65535; //error code.
        }
    }
    ACTIVE (DEVICE == OUTPUT_CARD):
    {
        IF(PARAM == METER)
            intSV = (INPUT-1)* 4;
        ELSE IF(PARAM == REFERENCE)
            intSV = (INPUT-1)*4+1;
        ELSE IF(PARAM == ATTACK)
            intSV = (INPUT-1)*4+2;
        ELSE IF(PARAM == RELEASED)
            intSV = (INPUT-1)*4+3;
        ELSE{ //ERROR MESSAGE TO CONSOLE
            SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
            intSV = 65535; //error code.
        }
    }
    ACTIVE (DEVICE == METER):
    {
        IF(PARAM == METER)
            intSV = 0;
        ELSE{ //ERROR MESSAGE TO CONSOLE
            SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
            intSV = 65535; //error code.
        }
    }
    ACTIVE (DEVICE == TELEPHONE):
    {
        IF(PARAM == SPEED_DIAL_STORE_SELECT)
            intSV = (INPUT-1)*7+204;
        ELSE IF(PARAM == SPEED_DIAL_SELECT)
            intSV = (INPUT-1)*7+205;
        ELSE IF(PARAM == TELEPHONE_NUMBER)
            intSV = 104-INPUT
        ELSE{
            switch(PARAM)
            {
                CASE BUTTON_0:
                {
                    intSV = 104;
                    break;
                }
                CASE BUTTON_1:
                {
                    intSV = 105;
                    break;
                }
                CASE BUTTON_2:
                {
                    intSV = 106;
                    break;
                }
                CASE BUTTON_3:
                {
                    intSV = 107;
                    break;
                }
                CASE BUTTON_4:
                {
                    intSV = 108;
                    break;
                }
                CASE BUTTON_5:
                {
                    intSV = 109;
                    break;
                }
                CASE BUTTON_6:
                {
                    intSV = 110;
                    break;
                }
                CASE BUTTON_7:
                {
                    intSV = 111;
                    break;
                }
                CASE BUTTON_8:
                {
                    intSV = 112;
                    break;
                }
                CASE BUTTON_9:
                {
                    intSV = 113;
                    break;
                }
                CASE T_PAUSE:
                {
                    intSV = 116;
                    break;
                }
                CASE CLEAR:
                {
                    intSV = 118;
                    break;
                }
                CASE INTERNATIONAL:
                {
                    intSV = 117;
                    break;
                }
                CASE BACKSPACE:
                {
                    intSV = 119;
                    break;
                }
                CASE REDIAL:
                {
                    intSV = 120;
                    break;
                }
                CASE FLASH:
                {
                    intSV = 123;
                    break;
                }
                CASE TX_MUTE:
                {
                    intSV = 140;
                    break;
                }
                CASE TX_GAIN:
                {
                    intSV = 141;
                    break;
                }
                CASE RX_MUTE:
                {
                    intSV = 143;
                    break;
                }
                CASE RX_GAIN:
                {
                    intSV = 144;
                    break;
                }
                CASE DTMF_GAIN:
                {
                    intSV = 146;
                    break;
                }
                CASE DIAL_TONE_GAIN:
                {
                    intSV = 148;
                    break;
                }
                CASE RING_GAIN:
                {
                    intSV = 147;
                    break;
                }
                CASE DIAL_HANGUP:
                {
                    intSV = 121;
                    break;
                }
                CASE AUTO_ANSWER:
                {
                    intSV = 124;
                    break;
                }
                CASE INCOMING_CALL:
                {
                    intSV = 122;
                    break;
                }
                CASE ASTERISK:
                {
                    intSV = 115;
                    break;
                }
                CASE POUND:
                {
                    intSV = 114;
                    break;
                }
                DEFAULT:
                {
                    SEND_STRING 0,"'BSS_ERROR: Set TELEPHONE - PARAM TYPE NOT FOUND FOR DEVICE.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
                    intSV = 65535; //error code.
                    break;
                }
            }
        }
    }
    ACTIVE (DEVICE == LOGIC):
    {
        IF(PARAM == LOGIC)
            intSV = 1;
        ELSE{ //ERROR MESSAGE TO CONSOLE
            SEND_STRING 0,"'BSS_ERROR: Set Val - PARAM TYPE NOT FOUND FOR DEVICE.  SEE HELP FILE FOR SUPPORTED MESSAGE TYPES'"
            intSV = 65535; //error code.
        }
    }
 }

RETURN intSV;
}
DEFINE_FUNCTION INTEGER IS_SPECIAL(CHAR SPECIAL_CHAR) //CHECK FOR SPECIAL CHARACTERS
{
LOCAL_VAR INTEGER intSPECIAL;


    IF ((SPECIAL_CHAR < 2) || (SPECIAL_CHAR > 27))
        intSPECIAL = 0;
    ELSE
    {
        SELECT
        {
            ACTIVE (SPECIAL_CHAR = $02): {intSPECIAL = 1;}
            ACTIVE (SPECIAL_CHAR = $03): {intSPECIAL = 1;}
            ACTIVE (SPECIAL_CHAR = $06): {intSPECIAL = 1;}
            ACTIVE (SPECIAL_CHAR = $15): {intSPECIAL = 1;}
            ACTIVE (SPECIAL_CHAR = $1B): {intSPECIAL = 1;}
        }
    }

RETURN intSPECIAL;
}

DEFINE_FUNCTION INTEGER HI_BYTE(INTEGER IBYTE)//RETURN INTEGER BITS 9-16 IN SINGLE CHAR
{
    LOCAL_VAR INTEGER intHBYTE;

    intHBYTE = TYPE_CAST(IBYTE >> 8); //HIGH BYTE

    RETURN intHBYTE;
}

DEFINE_FUNCTION INTEGER LO_BYTE(INTEGER IBYTE) //RETURN INTEGER BITS 1-8 IN SINGLE CHAR
{
    LOCAL_VAR INTEGER intLBYTE;

    intLBYTE = TYPE_CAST(IBYTE << 8);
    intLBYTE = TYPE_CAST(intLBYTE >> 8); //LOW BYTE

    RETURN intLBYTE;
}

DEFINE_FUNCTION INTEGER scaleRange(LONG Num_In, LONG Min_In, LONG Max_In, LONG Min_Out, LONG Max_Out)
{

    LOCAL_VAR LONG Val_In
    LOCAL_VAR LONG Range_In
    LOCAL_VAR LONG Range_Out
    LOCAL_VAR LONG Whole_Num
    LOCAL_VAR FLOAT Num_Out


    Val_In = (Num_In/65536)         //Convert received number to percent range
    IF(Val_In == Min_In)            // Handle endpoints
        {Num_Out = Min_Out}
    ELSE IF(Val_In == Max_In)
        {Num_Out = Max_Out}
    ELSE                            // Otherwise scale...
    {
        Range_In = Max_In - Min_In      // Establish input range
        Range_Out = Max_Out - Min_Out   // Establish output range
        Val_In = Val_In - Min_In        // Remove input offset
        Num_Out = Val_In * Range_Out    // Multiply by output range
        Num_Out = Num_Out / Range_In    // Then divide by input range
        Num_Out = Num_Out + Min_Out     // Add in minimum output value
        Whole_Num = TYPE_CAST(Num_Out)  // Store the whole number only of the result
        IF (Num_Out >= 0 AND (((Num_Out - Whole_Num)* 100.0) >= 50.0))
        {
            Num_Out++ // round up
        }
        ELSE IF (Num_Out < 0 AND (((Num_Out - Whole_Num) * 100.0) <= -50.0))
        {
            Num_Out-- // round down
        }
    }
    Return TYPE_CAST(Num_Out)
}

DEFINE_FUNCTION LONG CHAR_LONGVAL(CHAR VALUE[4]) //TAKES A CHAR[4] ARRAY AND RETURNS A LONG
{
LOCAL_VAR INTEGER NUM1;
LOCAL_VAR INTEGER NUM2;
LOCAL_VAR INTEGER NUM3;
LOCAL_VAR INTEGER NUM4;
LOCAL_VAR LONG L_INT;

    NUM1 = VALUE[1];
    NUM2 = VALUE[2];
    NUM3 = VALUE[3];
    NUM4 = VALUE[4];

    L_INT = (NUM1*2^24)+(NUM2*65536)+(NUM3*256)+NUM4;

RETURN L_INT;
}
DEFINE_FUNCTION fnLOG_HEX(CHAR cDATA[], INTEGER LENGTH, CHAR cMESSAGE[]) // USED FOR HEX LOGGING TO TELNET
{
    STACK_VAR INTEGER INDEX
    STACK_VAR CHAR HEX_DATA[5000] // MAX SIZE
    FOR(INDEX=1;INDEX<=LENGTH;INDEX++)
        HEX_DATA="HEX_DATA,FORMAT(' $%02X',cDATA[INDEX])"
    WHILE(LENGTH_STRING(HEX_DATA))
      {
        SEND_STRING 0,"cMESSAGE,GET_BUFFER_STRING(HEX_DATA,80)"
      }

}

DEFINE_FUNCTION fnLOG_DEC(CHAR cDATA[], INTEGER LENGTH, CHAR cMESSAGE[]) // USED FOR DECIMAL LOGGING
{
    STACK_VAR INTEGER INDEX
    STACK_VAR CHAR DEC_DATA[300]
    IF(LENGTH>100)
       LENGTH=100
    FOR(INDEX=1;INDEX<=LENGTH;INDEX++)
        DEC_DATA="DEC_DATA,FORMAT(' #%d',cDATA[INDEX])"
    SEND_STRING 0,"cMESSAGE,DEC_DATA"
    SET_LENGTH_STRING(DEC_DATA,0)
}
DEFINE_FUNCTION INTEGER fnParseRx(CHAR cBUFFER[])
{
    LOCAL_VAR INTEGER J; //RECEIVE LOOP VAR
    LOCAL_VAR INTEGER GOT_ESCAPE;
    LOCAL_VAR CHAR R_SP; //RECEIVE SPECIAL CHARACTER
    LOCAL_VAR CHAR R_CS; //RECEIVE CHECKSUM
    LOCAL_VAR CHAR RECEIVE[25]; //TOTAL REAL RECEIVED MESSAGE AFTER CONVERTING SPECIAL CHARS
    LOCAL_VAR CHAR TEMP[25]; //PARSING TEMP VAR
    LOCAL_VAR CHAR T_CS; //TRANSMITTED CHECKSUM

        IF (LEFT_STRING(cBUFFER,1) = "ACK")//CHECK FOR ACK
        {
            GET_BUFFER_CHAR(cBUFFER)//REMOVE FROM BUFFER
            //IF(bDEBUG_FLAG==2) SEND_STRING 0,"' ACK'"
            SIX_RECEIVED = TRUE
            RETURN TRUE
            //DO STUFF HERE FOR CORRECTLY TRANSMITTED STRING
        }
        ELSE IF (LEFT_STRING(cBUFFER,1) = "NAK")//CHECK FOR NAK
        {
            GET_BUFFER_CHAR(cBUFFER)//REMOVE FROM BUFFER
            IF(bDEBUG_FLAG==2) SEND_STRING 0,"' NAK'"
            RETURN TRUE
            //DO STUFF HERE FOR INCORRECT TRANSMITTED STRING
        }
        ELSE IF((cBUFFER[1] == "STX") && (FIND_STRING(cBUFFER,"ETX",1))) //FULL MESSAGE
        {
            //SEND_STRING 0, "'FULL MESSAGE RECEIVED '"
            nAttempts = 0
            TEMP = REMOVE_STRING(cBUFFER,"ETX",1)//REMOVE STRING TO ETX
            TEMP = MID_STRING(TEMP,2,(LENGTH_STRING(TEMP)-2));//CHOP OFF STX/ETX
            RECEIVE = "";//INITIALIZE
            R_CS = 0;//INITIALIZE

            IF((MID_STRING(TEMP,(LENGTH_STRING(TEMP)-1),1)) = $1B) //CS IS SPECIAL CHAR
            {
                T_CS = (TYPE_CAST(RIGHT_STRING(TEMP,1))-128)
                TEMP = MID_STRING(TEMP,1,(LENGTH_STRING(TEMP)-2))
            }
            ELSE
            {
                T_CS = TYPE_CAST(RIGHT_STRING(TEMP,1))
                TEMP = MID_STRING(TEMP,1,(LENGTH_STRING(TEMP)-1))//THE (-1) IS TO REMOVE THE CHECKSUM FROM CALCULATIONS
            }
            FOR (J = 1;J <= LENGTH_STRING(TEMP);J++) //REPLACE SPECIAL CHARS AND GENERATE CHECKSUM
            {
                IF (TEMP[J] = "$1B") //ESCAPE CHAR
                    GOT_ESCAPE = 1;
                ELSE
                {
                    IF (GOT_ESCAPE)
                    {
                        R_SP = (TEMP[J]-128);
                        R_CS = R_CS BXOR R_SP;
                        RECEIVE = "RECEIVE,R_SP";
                        GOT_ESCAPE = 0;
                    }
                    ELSE
                    {
                        R_CS = R_CS BXOR TEMP[J];
                        RECEIVE = "RECEIVE,TEMP[J]";
                    }
                }
            }
            IF (R_CS == T_CS)//MAKE SURE CHECKSUM = RECEIVED CHECKSUM AND MESSAGE IS RIGHT SIZE
                CALL 'PROCESS_FEEDBACK'(RECEIVE)
            ELSE IF (bDEBUG_FLAG==2)
                SEND_STRING 0,"'BSS MESSAGE: BAD CHECKSUM OR MESSAGE LENGTH'"

            RETURN TRUE
        }//FULL MESSAGE
        ELSE IF(cBUFFER[1]=="STX") // If we have received STX but the message is too short to be validated
        {
            nAttempts++
            IF(nAttempts>=5)
            {
                nAttempts = 0
                cBUFFER='' // clear the buffer after 5 failed attemps to receive a full message
                SEND_STRING 0, "'BSS MESSAGE: "ONLY STX RECEIVED: Partial Message" DUMPED '"
            }
            RETURN FALSE
        }
        ELSE // unrecognized reply...
        {
            nAttempts = 0
            cBUFFER = ''
            RETURN FALSE
            SEND_STRING 0, "'BSS MESSAGE: "UNRECOGNIZED REPLY" DUMPED '"
        }
}
