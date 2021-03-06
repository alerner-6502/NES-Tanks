//========================= Variables

// $00-$0f <-- scratch registers

// $10 <-- A controller register, updated every nmi  [ 1st controller ]
// $11 <-- previus controller register ( shifting )

// $12 <-- A controller register, updated every nmi  [ 2nd controller ]
// $13 <-- previus controller register ( shifting )

// $14 <-- Current player controller register, Mux Buffer, 
// $15 <-- Current player previus controller register, Mux Buffer, // used by gameplay loop

// $20 <-- number of players, after color screen it gets multipled by 4

// $21 - $28 <-- array containing each players color and control mode like so: 10CC-C0MM
//               (MM=00=pl1, MM=01=pl2, MM=10=cpu)

// $29 <-- Current player to handle (turn) ( used during gameplay loop )

// $2a <-- Bullet animation flag. 'Why it stopped'. [$00,$04...]-tank index (x4), $ff-ground, $fe-offscreen

// $2b <-- Tank to destroy (index). Used by the 'DestroyTank' subrutine.

// $2c <-- Tank to test (index). Used by the 'DestructionByPit' subrutine.

// $30 <-- Wind magnitude and direction. x00-xxxxx (p/m and 0-31)

// $c0 <-- Nmi frame counter. Continuously incremented every frame ( random number seed )

// $e0 <-- ppu low address
// $e1 <-- ppu high address
// $e2 <-- Byte return ( reading Nt )
// $e3 <-- Byte has been read flag ( cleared every time ) [ Ppu read function ]

// $e4 <-- Number to devide / integer answer
// $e5 <-- Number to devide by / remainder  [ Devider function ]

// $e6 <-- First Number
// $e7 <-- Second Number
// $e8 <-- Answer, LowByte
// $e9 <-- Answer, HighByte [ Multiplier function ]

// $ea <-- X coordinate
// $eb <-- Y coordinate, Answer (LowByte)
// $ec <-- Current NT msb offset ($20,$24,$28 or $2c) Aswer (HighByte) [ Nametable Coordinate function ]

// $f0 <-- ppu low address
// $f1 <-- ppu high address
// $f2 <-- number of bytes to transfer to NT from $0300 buffer ( during NMI )
//         Also a request flag ( nmi clears this once the task is completed ) ( nonzero value = do it )
//         Also a oam dma flag, opposite responce to ppu writes. ( nonzero value = skip it )

// $f3 <-- Nt array low address for LoadMap rutine
// $f4 <-- Nt array high address for LoadMap rutine
// $f5 <-- Byte count

// $f6 <-- Mapper offset for 'RenderImage' subrutine ( first 8K range )

// $fb <-- current X scroll

// $fc <-- Nmi based timer ( decremented every nmi, stops at zero ), can also be used as a wait for nmi

// $fd <-- Game delay speed

// $fe <-- current screen base / $2000 content
// $ff <-- current layers to show / $2001 content

// 0000 to 00ff <-- zero page, scratch registers, function registers and main game memory
// 0100 to 01ff <-- stack
// 0200 to 02ff <-- oam ( during gameplay it is treated as actual sprite data: X,Y,Color,Mode per player)
// 0300 to 03ff <-- ppu buffer
// 0400 to 041f <-- Additional player data arranged in packets of 4 bytes per player:  power, health, rotation, shell selection
// 0420 to 049f <-- General player data arranged in packets of 16 bytes per player: #ofShell... Fuel, Money.
// 0500 to 05ff <-- ground-map Y(X) array for the current gameplay map. Modified at runtime.

//========================== Start

--> #$a000;             // MMC2's fixed bank starts at this location

"@Rst":

//========================== Ppu warm up


SEI;
CLD;          // disable decimal and irq interupts
LDX #$ff;     // initialize stack pointer
TXS;
INX;
STX $2000;    // disable NMI
STX $2001;    // disbale sprites and background, left colomn
STX $4010;    // disable DMC's IRQ

LDX $2002;    // clear before loops

"Vblank1":
LDX $2002;
BPL *Vblank1; // first blank

LDX #$00;
LDA #$ff;
"InitOam":
STA $0200,X;
DEX;
BNE *InitOam; // initialize oam field

"Vblank2":
LDX $2002;
BPL *Vblank2; // second blank



//========================== Init Code


LDA $2002;                    //--- load two palettes
LDA #$3f;
STA $2006;
LDA #$00;
STA $2006;                   // initialize PPU RAM start address
LDX #$00;
"LoadPaletteLoop":
LDA *StartPalettes,X;
STA $2007;
INX;
CPX #$20;
BNE *LoadPaletteLoop;



//------- mapper init (MMC2, ID:09)


LDA #$00;
STA $a000;  // select first 8K at $8000-$9fff

LDA #$00;
STA $b000;  // 4K sprite chr ( latch0-fd )
STA $c000;  // 4K sprite chr ( latch0-fe ) // I'm not using the latch feature, therefore the banks are the same

LDA #$01;
STA $d000;  // 4K backgrnd chr ( latch1-fd )
STA $e000;  // 4K backgrnd chr ( latch1-fe ) // I'm not using the latch feature, therefore the banks are the same

LDA #$00;
STA $f000;  // vertical mirroring


//------------ init program variables


LDA #$00;
STA $f2;   // no bytes to transfer for now
LDA #$90;
STA $fe;   // current base nametable
LDA #$16;
STA $ff;   // current layer
LDA #$00;
STA $fb;   // Y scroll



//------------ enable rendering


LDA #$90;
STA $2000;          // enable NMI and sources ( rendering begins here )

LDA #$16;          // show sprites, but no background for now, left enable, etc
STA $2001;         // sprites must still be rendered otherwise the ppu will stop


//========================== Main loop


//--------------------------- Load Intro screen

LDA #(*IntroScreen,L);
STA $f3;
LDA #(*IntroScreen,H);   // pointer for the array
STA $f4;

LDA #$20;
STA $f1;
LDA #$00;
STA $f0;          // where ppu write rutine should start

JSR *LoadMap;

LDA #$1e;
STA $ff;          // now we can show background ( updated next nmi )

LDA #$c0;
STA $fd;
JSR *GameDelay;   // wait for 2 seconds
JSR *GameDelay;   // wait for 2 seconds

//--------------------------- Load Screen fade out

LDA #$1c;
STA $fd;    // set game delay

LDA #$00;
STA $01;    // scratch counter

"FadeOutLoop":
JSR *GameDelay;
LDX $01;
LDA *FadeOutColors,X;  // load color
STA $0300;             // store color
INX;
STX $01;               // increment color
LDA #$05;
STA $f0;
LDA #$3f;         // chnage pallete color at $3f05
STA $f1;
LDA #$01;
STA $f2;          // 1 byte to transfer
CPX #$03;
BNE *FadeOutLoop;

LDA #$c0;
STA $fd;
JSR *GameDelay;   // wait for 2 seconds

//--------------------------- Prepare next nametable for tank art


LDA #$00;
STA $01;       // value to fill the buffer(scratch register)
STA $02;       // 64-byte packets written counter ( last 64 bytes must be zero )

LDA #$00;
STA $f0;
LDA #$24;
STA $f1;       // nametable to chnage: $2400

"SetupArtNametable":

LDX #$00;
"LoadBufferWithInc":
LDA $01;
LDY $02;                // make an exception after 960 bytes
CPY #$0f;
BNE *SkipAtrForceZero;
LDA #$00;
"SkipAtrForceZero":     // force zero 
STA $0300,X;
INC $01;
INX;
CPX #$40;
BNE *LoadBufferWithInc;  // load buffer with 64 bytes

LDA #$40;
STA $f2;             // 64 bytes to transfer
"WaitForTransfer1":
LDA $f2;
BNE *WaitForTransfer1;

INC $02;             // packets transfered counter

LDA $f1;
CMP #$28;
BNE *SetupArtNametable; // $f1 is incremented by nmi, loop unit nametable is loaded


//--------------------------- Chnage nametable and pre render setup ( preporation for home screen )

LDA #$91;
STA $fe;          // change natebale

LDX #$00;
"InitSpritesLoop":         // 'press start' + zero hit sprite  (11)*4 = 44 bytes
LDA *InitSpritesArr,X;
STA $0200,X;
INX;
CPX #$2c;
BNE *InitSpritesLoop;

JSR *WaitForNmi;  // wait for nametable switch to take place (removes flash glitch)

LDA #$02;
STA $7fff;        // early swap (ensures sprite zero hit)


//--------------------------- FadeIn Home Screen

LDA #$00;
STA $02;          // temporary register for the fade in effect (keeps track of pallet rewrites)

LDA #$02;
STA $f6;          // initate mapper offset for 'renderArtImgae' subrutine

LDA #$18;         // nmi based counter, once it reaches zero we render home screen
STA $fc;

"FadeInHomeScreen":

JSR *RenderArtImage;

LDA #$03;           // fade in is clocked at 60/4
BIT $fc;
BNE *SkipArtFadeIn;
LDA $02;
CMP #$10;
BEQ *SkipArtFadeIn;  // once fade in is done do not rerun it (16 colors)
LDA #$00;
STA $f0;
LDA #$3f;
STA $f1;           // chnage pallete color at $3f00
LDY #$00;
LDX $02;
"FadeInBuffLoadLoop":
LDA *ArtFadeInColors,X;
STA $0300,Y;
INX;
INY;
CPY #$04;
BNE *FadeInBuffLoadLoop;
STX $02;                 // update pallete rewrite counter
LDA #$04;
STA $f2;            // 4 bytes to transfer
"SkipArtFadeIn":

LDA $fc;
BNE *FadeInHomeScreen;


//--------------------------- Render Home screen, flicker message, and wait for the start button edge

LDA #$01;        // two values: 0x21 or 0x01
STA $01;         // temporary oam attributes register that will flicker sprites by moving them behind the background

LDA #$02;
STA $f6;          // initate mapper offset for 'renderArtImgae' subrutine

"RenderHomeScreen":

JSR *RenderArtImage;

LDA $fc;
BNE *SkipFlicker;
LDA #$18;
STA $fc;            // reset nmi basec counter
LDX #$00;
LDA $01;
"SpriteBkgTogle":
STA $0206,X;         // you wanna skip zero sprite of cource
INX; INX;
INX; INX;
CPX #$28;
BNE *SpriteBkgTogle;          // update oam
EOR #$20;
STA $01;             // toggle sprites state ( in front or behind bkg )
"SkipFlicker":

LDA #$10;            // testing start button
BIT $10;
BEQ *RenderHomeScreen;
BIT $11;
BNE *RenderHomeScreen;  // low->high start button detection



//--------------------------- Render Select screen, handle player number, and wait for the start button edge


LDA #$06;
STA $f6;          // initate mapper offset for 'renderArtImgae' subrutine

LDX #$00;
"SelectSpritesLoop":
LDA *SelectSpritesArr,X;
STA $0204,X;         // you wanna skip zero sprite of cource
INX;
CPX #$28;
BNE *SelectSpritesLoop;      // prepare oam sprites for the select screen


"RenderSelectScreen":

JSR *RenderArtImage;

LDA $10;
AND #$01;     // Right button, I'll get 00 or 01
EOR #$01;     // invert
STA $020e;    // right arrow glows red when right is pressed

LDA $10;
AND #$02;     // Left button, I'll get 00 or 02
LSR; 
EOR #$01;     // invert
STA $0206;    // left arrow glows red when left is pressed

LDA #$01;            // testing start button
BIT $10;
BEQ *NoPlayerIncrement;
BIT $11;
BNE *NoPlayerIncrement;    // low->high right button detection
LDA $0209;
CMP #$08;
BEQ *NoPlayerIncrement;    // 8 player max limit
INC $0209;
"NoPlayerIncrement":

LDA #$02;            // testing start button
BIT $10;
BEQ *NoPlayerDecrement;
BIT $11;
BNE *NoPlayerDecrement;    // low->high right button detection
LDA $0209;
CMP #$02;
BEQ *NoPlayerDecrement;    // 2 player min limit
DEC $0209;
"NoPlayerDecrement":

LDA #$10;            // testing start button
BIT $10;
BEQ *RenderSelectScreen;
BIT $11;
BNE *RenderSelectScreen;  // low->high start button detection


LDA $0209;
STA $20;      // remember the number of players


//--------------------------- Render color select screen


LDX #$00;
"ColorSpritesLoop":
LDA *ColorSpritesArr,X;
STA $0204,X;                // you wanna skip the zero sprite of cource
INX;
CPX #$28;
BNE *ColorSpritesLoop;      // prepare oam sprites for the color select screen

LDA #$04;
STA $0300;
LDA #$0e;
STA $0301;
LDA #$ec;
STA $f0;
LDA #$27;         // chnage atribute entry starintg at $27ec ( to make color examples visible )
STA $f1;
LDA #$02;
STA $f2;          // 2 byte to transfer

JSR *WaitForNmi;  // ppu write request must complete (Unfortunatly, I have to wait a frame!)

LDX #$00;
"FullColorLoop":
LDA *FakePlayableColors,X;
STA $0300,X;
INX;
CPX #$10;
BNE *FullColorLoop;

LDA #$00;
STA $f0;
LDA #$3f;         // chnage background pallete to colorful ( color examples )
STA $f1;          // ...the arrangement is slightly altered from what they will be used in the game
LDA #$10;         // ...this is done to show color sequence correctly while rendering my tank properly
STA $f2;          // 16 bytes to transfer

LDA #$00; 
STA $02;      // temporary register for keeping track of mode selection (pl1=00, pl2=01, cpu=02)

LDA #$0a;
STA $f6;          // initate mapper offset for 'renderArtImgae' subrutine

"RenderColorScreen":

JSR *RenderArtImage;

LDA $10;
AND #$01;     // Right button, I'll get 00 or 01
EOR #$01;     // invert
STA $020e;    // right arrow glows red when right is pressed

LDA $10;
AND #$02;     // Left button, I'll get 00 or 02
LSR; 
EOR #$01;     // invert
STA $0206;    // left arrow glows red when left is pressed

LDA $10;
AND #$04;     // Down button, I'll get 00 or 04
LSR; LSR;
EOR #$01;     // invert
STA $021a;    // Down arrow glows red when left is pressed

LDA $10;
AND #$08;     // Up button, I'll get 00 or 08
LSR; LSR;
LSR;
EOR #$01;     // invert
STA $0216;    // Up arrow glows red when right is pressed

LDX $10;
CPX $11;
BEQ *NoConTrigger;   // buttons changed state (input was made)

CPX #$01;
BNE *NoRightInput;   // right button high
LDA $0213;
CMP #$b8;
BEQ *NoRightInput;  // maximum boundry
CLC;
ADC #$08;
STA $0213;           // move cursor right
"NoRightInput":

CPX #$02;
BNE *NoLeftInput;   // left button high
LDA $0213;
CMP #$80;
BEQ *NoLeftInput;   // minimum boundry
SEC;
SBC #$08;
STA $0213;           // move cursor left
"NoLeftInput":

CPX #$04;
BNE *NoDownInput;   // down button high
LDA $02;
BEQ *NoDownInput;   // minimum boundry
DEC $02;
"NoDownInput":

CPX #$08;
BNE *NoUpInput;   // up button high
LDA $02;
CMP #$02;
BEQ *NoUpInput;    // maximum boundry
INC $02;
"NoUpInput":

LDA $88;
LDA $02;             // we shall now update our letters
ASL; ASL;            // multiply index by 4 to get the offset into the letter array
TAX;
LDA *ModeLetters,X;
STA $021d;           // 1st letter
INX;
LDA *ModeLetters,X;
STA $0221;           // 2nd letter
INX;
LDA *ModeLetters,X;
STA $0225;           // 3rd letter

"NoConTrigger":

LDA #$10;            // testing start button
BIT $10;
BEQ *JumpToRenderColorScreen;
BIT $11;
BNE *JumpToRenderColorScreen;  // low->high start button detection

LDA $02;                 // get current player mode via temp register (00=pl1, 01=pl2, 02=cpu)
ORA $0213;               // or it with the current color ( based on cursor's X position )
LDX $0209;               // load current player (initially 0x01)
STA $20,X;               // store state to game settings array
INC $0209;
CPX $20;                 // compare to the number of players
BEQ *EndRenderColorScreen;
"JumpToRenderColorScreen":
JMP *RenderColorScreen;
"EndRenderColorScreen":  // cuz branch couldn't reach

DEC $0209;               // corecting for the last INC. 
                         // If this isn't done you will see a chnage to player 3 as the screen fades out
LDA #$01;
STA $020e;
STA $0206;
STA $021a;
STA $0216;    // "Un-red" Right, left, down and up buttons


//--------------------------- Color Screen fade out


LDA #$00;
STA $02;          // temporary register for the fade in effect (keeps track of pallet rewrites)

LDA #$0a;
STA $f6;          // initate mapper offset for 'renderArtImgae' subrutine

LDA #$18;         // nmi based counter, once it reaches zero we render begin gameplay preporation
STA $fc;

"FadeOutColorScreen":

JSR *RenderArtImage;

LDA #$03;           // fade in is clocked at 60/4
BIT $fc;
BNE *SkipArtFadeOut;
LDA $02;
CMP #$40;
BEQ *SkipArtFadeOut;  // once fade in is done do not rerun it (4steps * 16 colors)
LDA #$00;
STA $f0;
LDA #$3f;
STA $f1;           // chnage pallete color at $3f00
LDY #$00;
LDX $02;
"FadeOutBuffLoadLoop":
LDA *ArtFadeOutColors,X;
STA $0300,Y;
INX;
INY;
CPY #$10;
BNE *FadeOutBuffLoadLoop;
STX $02;                 // update pallete rewrite counter
LDA #$10;
STA $f2;            // 16 bytes to transfer
"SkipArtFadeOut":

LDA $fc;
BNE *FadeOutColorScreen;

LDA #$10;           // I'll hide sprites before rearengemnt by 'blacking' out their pallete.
STA $f2;            // 16 bytes to transfer to the sprite palette (buffer is already loaded with black from the last write
                    // and ppu start address is automaticaly at the coorect start location from the last write)
JSR *WaitForNmi;    // ensures that the write occured


//--------------------------- GAMEPLAY STARTS HERE

//--------------------------- Game preporation

JSR *GameDelay;            // spontaneous release after blackout (visual effect)

// I will now prepare the gamefield nametable at ppu addr $2000 again.
// $2800 ($2400 with vertical mirroring) nametable arangement will be preserved for future art. 


//------------ Initialize Cross-Game player data ( Money, Weapon count )

LDX #$00;
"InitGarageLoop":
LDA *GarageInit,X;
STA $0420,X;
STA $0430,X;
STA $0440,X;
STA $0450,X;
STA $0460,X;
STA $0470,X;
STA $0480,X;
STA $0490,X;
INX;
CPX #$10;
BNE *InitGarageLoop;


//------------ Load Ground Map into Ram

LDX #$00;
"GroundRamLoad":
LDA *Map1Ground,X;
STA $0500,X;
INX;
BNE *GroundRamLoad;


//------------ Prepare sprite oam


/-=-= Tanks

LDA $20;
ASL; ASL;
STA $01;                   // temp register of players*4

LDA #$ff;
STA $e4;
LDA $20;                   // 0xff / #players
STA $e5;
JSR *DevideFunction;       // $e4 now has the X seporation distance between tanks 

LDA #$08;
STA $04;                   // temp register of the last used X

LDY #$00;                  // we will now initiate player oam
"InitiatePlayerOam":

LDA $04;
TAX;                       // value we want to use, put it away temporaraly
CLC;
ADC $e4;
STA $04;                   // calculate future value
TXA;
STA $0207,Y;               //-- X position
CLC;
ADC #$03;                  // recenter relative to ank's center

TAX;
LDA $0500,X;               // get grounnd map from pre-loaded ram
SEC;
SBC #$08;                  // raise tanks by a sprite height
STA $0204,Y;               //-- Y position

TYA;
LSR; LSR;                  // convert Y's +4 into +1
TAX;
LDA $21,X;                 // get game settings for the current player
STA $02;                   // store to temp register

AND #$08;
ORA #$37;                  // mask, lowest bit of the color
STA $0205,Y;               //-- Tile (~Atributes)

LDA $02;
LSR; LSR;
LSR; LSR;                  // upper two bits of color
AND #$03;
STA $03;                   // store it away for a moment
LDA $02;
ASL; ASL;
AND #$0c;                  // mask it, now we have two mode bits
ORA $03;
STA $0206,Y;               //-- Atributes (+ control placed into unemplemeted bits: 0000-MMCC)

INY; INY;
INY; INY;                  // each oam entry is 4 bytes long
CPY $01;                   // compare to the total number of players*4
BNE *InitiatePlayerOam;


LDA #$ff;                  // prepare write value, Y value is already there
"CleanUnusedSprites":
CPY #$20;
BEQ *EndCleanUnusedSprites;
STA $0204,Y;
INY;
JMP *CleanUnusedSprites;   // fill up the rest (unused tank sprites) with 0xff up untill cursor sprites
"EndCleanUnusedSprites":

ASL $20;
ASL $20;                   // make players*4 permannent


//-=-= Cursors


LDX #$00;
"LoadCursorsLoop":
LDA *MyGameCursors,X;
STA $0224,X;
INX;
CPX #$0c;                  // 12+16 bytes to copy
BNE *LoadCursorsLoop;      // turrent angle linear cursor
"LoadCursorsLoop2":      
LDA *MyGameCursors,X;      // late in game implementation, thus two loops
STA $0228,X;               // I'm actually begin writing to $0234 (but cuz X=$0c from the previous loop: $0234=$0228+$0c)
INX;
CPX #$1c;                   // 16 extra bytes to copy
BNE *LoadCursorsLoop2;      // turrent angle linear cursor

//-=-= Update


JSR *WaitForNmi;           // allows OAM to update (removes old sprites fadeout glitch)


//------------ Prepare additional player data

LDX #$00;
"PlayfieldInitLoop":
LDA *PlayfieldInit,X;
STA $0400,X;
STA $0404,X;
STA $0408,X;
STA $040c,X;
STA $0410,X;
STA $0414,X;
STA $0418,X;
STA $041c,X;         // 8 player intialization, too bothered to make this loop smaller
INX;
CPX #$04;
BNE *PlayfieldInitLoop;


//-------- Load map into ppu


LDA #(*Map1Screen,L);
STA $f3;
LDA #(*Map1Screen,H);      // pointer for the array
STA $f4;

LDA #$20;
STA $f1;
LDA #$00;
STA $f0;                   // ppu write function start address

JSR *LoadMap;              // load map


//------- prepare nametable and tiles ( aka mapper )

LDA #$90;
STA $fe;                   // change nametable back to $2000

LDA #$0e;
STA $d000;                 // 4K backgrnd chr
STA $e000;                 // no latch feature  // select Map1 background bank (4K)


//------- Load Palettes


LDX #$00;
"Map1PaletteBuffLoad":
LDA *Map1PaletteInit,X;
STA $0300,X;
INX;
CPX #$20;
BNE *Map1PaletteBuffLoad;  // load buffer with atribute 

LDA #$3f;
STA $f1;
LDA #$00;
STA $f0;                   // ppu write function start address

STX $f2;                   // request , number of bytes to send

JSR *WaitForNmi;           // wait for the transfer to complete

LDA #$10;
STA $fd;                // set up game delay (for movement)

LDA #$00;
STA $29;                // initialize first player

JSR *IndicateCurrentPlayer;

//--------------------------- Game loop

"PlayersTurnLoop":

LDA #$00;
STA $14;
STA $15;                // no input at first

LDX $29;
LDA $0206,X;            // load current player atributes
AND #$0c;               // filter out the mode

CMP #$00;
BNE *SkipContrl1Source;
LDX $10;
STX $14;
LDX $11;
STX $15;                // load controller 1 data into mux buffer
"SkipContrl1Source":

CMP #$04;
BNE *SkipContrl2Source;
LDX $12;
STX $14;
LDX $13;
STX $15;                // load controller 1 data into mux buffer
"SkipContrl2Source":


LDA #$08;
STA $fd;                // set up game delay  for TURRET!


LDA $14;                 // Right+!A button test ( turret rotation )
AND #$81;
CMP #$01;
BNE *SkipTurretRight;
LDX $29;
LDA $0402,X;             // load current rotation value
BEQ *SkipTurretRight;    // 0 degrees min
DEC $0402,X;             // decrement angle
JSR *HandleTurretDisplay;
JSR *GameDelay;
"SkipTurretRight":


LDA $14;                 // Left+!A button test ( turret rotation )
AND #$82;
CMP #$02;
BNE *SkipTurretLeft;
LDX $29;
LDA $0402,X;             // load current rotation value
CMP #$b4;
BEQ *SkipTurretLeft;     // 180 degrees max
INC $0402,X;             // increment angle
JSR *HandleTurretDisplay;
JSR *GameDelay;
"SkipTurretLeft":


LDA #$10;
STA $fd;                // set up game delay for EVERYTHING else


LDA $14;                  // Up button test ( increase power )
AND #$08;
CMP #$08;
BNE *SkipPowerUp;
LDX $29;
LDA $0400,X;              // load current power value
CMP $0401,X;              // compare against current health
BEQ *SkipPowerUp;         // skip power up if current power matches the current health
INC $0400,X;              // increment power
JSR *HandlePowerDisplay;
JSR *GameDelay;
"SkipPowerUp":


LDA $14;                  // Down button test ( decrease power )
AND #$04;
CMP #$04;
BNE *SkipPowerDown;
LDX $29;
LDA $0400,X;               // load current power value
BEQ *SkipPowerDown;        // 0 power min
DEC $0400,X;               // decrement power
JSR *HandlePowerDisplay;
JSR *GameDelay;
"SkipPowerDown":


LDA $14;               // Right+A button test ( tank movement )
AND #$81;
CMP #$81;
BNE *SkipMoveRight;
LDA $29;
ASL; ASL;
TAX;
LDA $042e,X;            // load current player's fuel
BEQ *SkipMoveRight;     // don't move if there's no fuel
LDX $29;
LDA $0207,X;            // load current sprite's X position
CMP #$f8;
BCS *SkipMoveRight;     // can't move off the right side of the screen
LDA $0207,X;            // load SPRITE's current X position
CLC;
ADC #$03;               // add 3 to it ( recenter sprite ), real current X position
TAY;
LDA $0500,Y;               // load current Y position (ground map)
INY;                       // next X position
SEC;
SBC $0500,Y;               // subtract next Y position from current position
BMI *DeployParachuteTest1; // if next Y is greater then current Y then there are no uphill limitations, however there might be parachutes
CMP #$06;
BCC *AllowRightMovement;   // if the difference in levels is smaller than 6, then allow the movement to be made.
DEC $0207,X;
DEC $0207,X;              // decrement X position once. But actually doing it twice to counter the addition that follows.
DEY; DEY;                 // same principle
JMP *AllowRightMovement;  // jump over the parachute rutine (parachute whwn failing to climb glitch)
"DeployParachuteTest1":
CMP #$f8;                 // maximum downhill slope
BCS *AllowRightMovement;
INC $0207,X;              // increment the sprite's X position directly
JSR *ParachuteTanks;
JMP *SkipMoveRight;
"AllowRightMovement":
INC $0207,X;             // increment the sprite's X position directly
LDA $0500,Y;             // Y-register already contains the next "centered srite" X position
SEC;
SBC #$08;                // tank elevation (offset)
STA $0204,X;             // update Sprite's Y
CMP #$d8;
LDA $29;
ASL; ASL;
TAX;                    // convert x's *4 into *16 ( cuz player's garage spans 16 bytes instead of typical 4 )
DEC $042e,X;            // decrease fuel
JSR *HandleFuelDisplay;
JSR *GameDelay;
"SkipMoveRight":


LDA $14;               // Left+A button test ( tank movement )
AND #$82;
CMP #$82;
BNE *SkipMoveLeft;
LDA $29;
ASL; ASL;
TAX;
LDA $042e,X;            // load current player's fuel
BEQ *SkipMoveLeft;      // don't move if there's no fuel
LDX $29;
LDA $0207,X;
BEQ *SkipMoveLeft;      // can't move off the left side of the screen
LDA $55;
LDA $0207,X;            // load SPRITE's current X position
CLC;
ADC #$03;               // add 3 to it ( recenter sprite ), real current X position
TAY;
LDA $0500,Y;            // load current Y position (ground map)
DEY;                    // next X position
SEC;
SBC $0500,Y;               // subtract next Y position from current position
BMI *DeployParachuteTest2; // if next Y is greater then current Y then there are no uphill limitations, parachutes may still be deployed
CMP #$06;
BCC *AllowLeftMovement;    // if the difference in levels is smaller than 6, then allow the movement to be made.
INC $0207,X;
INC $0207,X;             // increment X position once. But actually doing it twice to counter the decrementation that follows.
INY; INY;                // same principle
JMP *AllowLeftMovement;  // jump over the parachute rutine (parachute whwn failing to climb glitch)
"DeployParachuteTest2":
CMP #$f8;                 // maximum downhill slope
BCS *AllowLeftMovement;
DEC $0207,X;              // increment the sprite's X position directly
JSR *ParachuteTanks;
JMP *SkipMoveLeft;
"AllowLeftMovement":
DEC $0207,X;             // increment the sprite's X position directly
LDA $0500,Y;             // Y-register already contains the next "centered srite" X position
SEC;
SBC #$08;                // tank elevation (offset)
STA $0204,X;             // update Sprite's Y
LDA $29;
ASL; ASL;
TAX;                    // convert x's *4 into *16 ( cuz player's garage spans 16 bytes instead of typical 4 )
DEC $042e,X;            // decrease fuel
JSR *HandleFuelDisplay;
JSR *GameDelay;
"SkipMoveLeft":

LDA $29;
STA $2c;                 // pass current player index to the subrutine variable
JSR *DestructionByPit;
LDA $2c;
CMP #$ff;
BEQ *PlayerChange1;      // next player if current player fell into a pit

LDA #$20;                // Select button test ( weapon select )
BIT $14;
BEQ *SkipWeaponChange;
BIT $15;
BNE *SkipWeaponChange;
LDX $29;
INC $0403,X;             // increment current weapon index
LDA $0403,X;
CMP #$0e;
BNE *SkipResetWeapon;
LDA #$00;
STA $0403,X;
"SkipResetWeapon":       // 14 weapons in total, selection rotation
JSR *HandleWeaponDisplay;
"SkipWeaponChange":


LDA #$40;                  // B button test    ( fire cannon )
BIT $14;                   // get current player's control ( from mux buffer )
BEQ *SkipPlayerChange;
BIT $15;
BNE *SkipPlayerChange;     // change player on B button trigger
LDX $29;
LDA $0403,X;               // get current weapon index
STA $01;
LDA $29;
ASL; ASL;
CLC;
ADC $01;
TAX;
LDA $0420,X;               // number of a specific weapon the current player has
BEQ *SkipPlayerChange;     // can't fire if you got zero ammo of the current weapon
DEC $0420,X;               // one less ammo
JMP *PlayerChange;
"SkipPlayerChange":

JMP *PlayersTurnLoop;


//---- next turn

"PlayerChange":

//---- bullet animation

JSR *AnimateBullet;

JSR *DamageTanks;

JSR *BreakGround;

JSR *ParachuteTanks;

//---- next player counter

"PlayerChange1":

LDA $29;                // load current player register
"FindLivingPlayer":
CLC;
ADC #$04;               // go to the next player
CMP $20;                // total number of players
BCC *SkipTurnLoop;      // skip if smaller
LDA #$00;               // return to player 1 if all had their turn
"SkipTurnLoop":
TAY;
LDX $0401,Y;
BEQ *FindLivingPlayer;  // load player's health, if it's zero, then find the next one
STA $29;                // update current player register

//---- label

LDX $29;
LDA $0206,X;               // load current player atributes
AND #$0c;                  // filter out the mode
TAX;                       // we'll now load pl1 or pl2 or cpu based on this value ( Mode is naturally a multiple of 4 )
LDA *PlayerLabels,X;
STA $0300; INX;
LDA *PlayerLabels,X;
STA $0301; INX;
LDA *PlayerLabels,X;       // overwriting the player label
STA $0302;

LDA #$20;
STA $f1;
LDA #$41;
STA $f0;                   // we'll modify the current player label in the nametable
LDA #$03;
STA $f2;                   // 3 bytes to send ( the ribbon )
JSR *WaitForNmi;           // forces controller to update // prevents trigger leaks

JSR *HandleWeaponDisplay;  // weapon

JSR *HandleFuelDisplay;    // fuel

JSR *HandleTurretDisplay;  // cannon rotation

JSR *HandleHealthDisplay;  // health

JSR *HandlePowerDisplay;   // power

JSR *HandleWind;           // wind

JSR *IndicateCurrentPlayer;

//---- return

JMP *PlayersTurnLoop;


//--------------------------- End

"Forever":    //------------ Stop ( for developing )
JMP *Forever;  //-----------


//========================== Game Subrutines


"HandleFuelDisplay":    // <-- Internal subrutine, saves code
LDA $29;
ASL; ASL;
TAX;                    // convert x's *4 into *16 ( cuz player's garage spans 16 bytes instead of typical 4 )
LDA $042e,X;            // load current player's fuel
STA $e4;
LDA #$0a;
STA $e5;
JSR *DevideFunction;    // fuel value: e4 now has tens and e5 units ( decimal system )
LDA $e4;
ORA #$b0;
STA $0300;
LDA $e5;
ORA #$b0;
STA $0301;              // mask it for the correspoding tile and overwrite the buffer
LDA #$20;
STA $f1;
LDA #$58;
STA $f0;                // we'll modify the current player fuel in the nametable
LDA #$02;
STA $f2;                // 2 bytes to send
JSR *WaitForNmi;
RTS;

//---

"HandleTurretDisplay":  // <-- Internal subrutine, saves code
LDX $29;
LDA $0402,X;            // get current players turret rotation
STA $e4;
LDA #$17;
STA $e5;
JSR *DevideFunction;    // turret rotation is devided by 23 to get the sprite index
LDA $e4;
ORA #$c0;               // tile mask for background
STA $0300;              // tank icon calculated
LDX $29;
LDA $0205,X;            // load player's tile index
AND #$f8;               // erase the least significant 3 bits ( but preseve the rest! )
ORA $e4;                // overwrite these 3bits with new idex;
STA $0205,X;            // update player's tile index
LDX $29;
LDA $0402,X;            // get current players turret rotation
STA $e4;
LDA #$64;
STA $e5;
JSR *DevideFunction;    // e4 has hundereds and e5 has tens and units
LDA $e4;
ORA #$b0;               // tile mask
STA $0301;              // store hundereds
LDA $e5;
STA $e4;
LDA #$0a;
STA $e5;
JSR *DevideFunction;    // e4 has tens and e5 has units
LDA $e4;
ORA #$b0;               // tile mask
STA $0302;              // store tens
LDA $e5;
ORA #$b0;               // tile mask
STA $0303;              // store units
LDA #$b4;               // load 180 dec          ( CALCULATE LINEAR CURSOR )
LDX $29;                // current player
SEC;
SBC $0402,X;            // calculate: 180-angle
STA $e4;
LDA #$06;
STA $e5;               
JSR *DevideFunction;    // calculate (180-angle)/6  (one pixel per 6 degrees)
LDA #$50;
CLC;
ADC $e4;                // add pixel number to the $50 offset
STA $0227;              // update linear cursor's X position   ( END CALCULATE LINEAR CURSOR )
LDA #$20;
STA $f1;
LDA #$4a;
STA $f0;                // we'll modify the current players rotation angle in the nametable
LDA #$04;
STA $f2;                // 4 bytes to send
JSR *WaitForNmi;
RTS;

//----

"HandleWeaponDisplay":  // <-- Internal subrutine, saves code
LDX $29;
LDA $0403,X;               // get current weapon index
STA $01;                 // move new weapon index to a temporary register
ORA #$f0;
STA $0300;               // we prepared the appropriate tile for the buffer
LDA #$ca;                // constant boundry tile
STA $0301;
LDA $29;
ASL; ASL;
CLC;
ADC $01;
TAX;
LDA $0420,X;             // now we have the ultimate index for the number of a specific weapon the current player has
STA $e4;
LDA #$0a;
STA $e5;
JSR *DevideFunction;     // convert to dec ( e4 now has tens and e5 has units )
LDA $e4;
ORA #$b0;
STA $0302;
LDA $e5;
ORA #$b0;
STA $0303;              // mask it for the correspoding tile and overwrite the buffer
LDA #$20;
STA $f1;
LDA #$51;
STA $f0;                // we'll modify the current player ammo# and ammo icon in the nametable
LDA #$04;
STA $f2;                // 4 bytes to send
JSR *WaitForNmi;
RTS;

//---

"HandlePowerDisplay":   // <-- Internal subrutine, saves code
LDX $29;
LDA $0400,X;            // get player's power value
STA $e4;
LDA #$0a;
STA $e5;
JSR *DevideFunction;    // power value: e4 now has tens and e5 units ( decimal system )
LDA $e4;
ORA #$b0;
STA $0300;              // mask it for the correspoding tile and overwrite the buffer
LDA $e5;
ORA #$b0;
STA $0301;              // mask it for the correspoding tile and overwrite the buffer
LDX $29;                // ( CALCULATE LINEAR CURSOR )
LDA #$63;
SEC;
SBC $0400,X;            // get: 99 - player's power value
STA $e4;
LDA #$07;
STA $e5;
JSR *DevideFunction;    // 1 pixel per 7 powers
LDA $e4;
ORA #$40;               // mask for sprite tiles
STA $0229;
STA $022d;              // update tiles
LDA #$0a;
CLC;
ADC $e4;                // max value + offset
STA $0228;
STA $022c;              // ( END CALCULATE LINEAR CURSOR ) // update position  
LDA #$20;
STA $f1;
LDA #$47;
STA $f0;                // we'll modify the current player power level in the nametable
LDA #$02;
STA $f2;                // 2 bytes to send
JSR *WaitForNmi;
RTS;

//---

"HandleHealthDisplay":         // <-- Internal subrutine, saves code
LDX $29;                       // get current player index (multiple of 4)
LDA #$63;
SEC;
SBC $0401,X;                   // get: 99 - player's health value
STA $e4;
LDA #$07;
STA $e5;
JSR *DevideFunction;           // 1 step per 7 powers
LDY $e4;                       // load answer
LDA *HealthBarTransitionsU,Y;
STA $0235;                     // top-left
STA $0239;                     // top-right                  
LDA *HealthBarTransitionsL,Y;
STA $023d;                     // bottom-left
STA $0241;                     // bottom-right
LDX $29;                       // get current player index again (JSR destroyed the last one)
LDA $0401,X;                   // get player's health value
CMP $0400,X;                   // compare player's power to their health
BCS *SkipPowerDeduction;       // if power is > than health
LDA $0401,X;
STA $0400,X;                   // make power = health
"SkipPowerDeduction":
RTS;


//---

"HandleWind":
LDA $c0;               // load random seed
AND #$9f;              // 100-11111 (p/m and 0-31)
STA $30;               // store to wind register
ROL; ROL;              // ms-bit to ls-bit
AND #$01;              // clear everythign else
CLC;
ADC #$db;              // choice between $db and $dc  (sprite masks)
STA $0300;
LDA $30;
AND #$1f;              // mask the lowest 5 bits
STA $e4;
LDA #$0a;
STA $e5;
JSR *DevideFunction;     // convert to dec ( e4 now has tens and e5 has units )
LDA $e4;
ORA #$b0;
STA $0301;
LDA $e5;
ORA #$b0;
STA $0302;              // mask it for the correspoding tile and overwrite the buffer
LDA #$20;
STA $f1;
LDA #$5c;
STA $f0; 
LDA #$03;
STA $f2;                // 3 bytes to send
JSR *WaitForNmi;
RTS;

//---


"IndicateCurrentPlayer":

LDX $29;
LDA $0204,X;            // get player's Y position (tank sprite)
SEC;
SBC #$14;               // my arrow must be well above the tank
STA $0230;              // initiate arrow's Y
LDA #$51;
STA $0231;              // initiate arrow's tile ID
LDA #$03;
STA $0232;              // initiate arrow's attributes
LDA $0207,X;            // get player's X position (tank sprite)
STA $0233;              // initiate arrow's X

LDA #$18;
STA $fd;                // set up game delay for down arrow else

LDA #$0a;
STA $01;                // my counter ( Game delay damages X,Y and $00 )
"DropArrowLoop":
INC $0230;              // lower arrow
JSR *GameDelay;
DEC $01;
BNE *DropArrowLoop;

LDA #$10;
STA $fd;                // set up game delay for EVERYTHING else

LDA #$ff;
STA $0230;
STA $0233;              // move arrow offscreen

RTS;

//---

"AnimateBullet":

LDA #$ff;
STA $2a;                // 'Why the bullet stopped' (Ground collision by default ID=ff)

LDX $29;
LDA $0400,X;            // get player's power value
CLC;
ADC #$10;               // add this constnat to improve gameplay
STA $00;
LDA $0402,X;            // get player's rotation value
STA $01;

LDA $0204,X;            // get player's Y position
CLC;
ADC #$03;               // recenter it ( exists the tank )
STA $0230;              // initiate bullet's Y
LDA $0207,X;            // get player's X position
CLC;
ADC #$03;               // recenter it ( exists the tank )
STA $0233;              // initiate bullet's X
LDA #$27;
STA $0231;              // initiate bullet's sprite
LDA #$00;
STA $0232;              // initiate bullet's attributes

LDX $01;                // get angle
LDA *Cosine,X;          // get cosine multiplier
STA $02;                // temporarily store it to Hspeed
LDA *Sine,X;            // get sine multiplier
STA $03;                // temporarily store it to Vspeed

LDY #$00;
"Hirizontal&VerticalLoop":      // calculate Power*sin(angle)  and Power*cos(angle)
LDA #$00;
STA $06;
STA $07;                // initiate multiplier temp registers ($06) and ($07)
LDA $0002,Y;            // get sine or cosine multiplier
TAX;
"MultiplierLoop":
CPX #$00;
BEQ *StopMultiplication;
CLC;
LDA $06;                // get lower byte of the multiplier result
ADC $00;                // add power
STA $06;
LDA $07;
ADC #$00;
STA $07;                // add carry to higher byte of the multiplier result
DEX;
JMP *MultiplierLoop;
"StopMultiplication":
LDA $07;
STA $0002,Y;            // the high byte is the result ( = Power * sine(angle) ) becuase after multiplying by *sine we need to devide by 256, 
INY;                    // aka the lower byte can be discarded.
CPY #$02;
BNE *Hirizontal&VerticalLoop;


LDA #$00;
STA $07;                 // from now on this register will represent the vertical direction flag. After vertical speed will be lowered to zero by (gravity)
                         // this flag will flip (signifying negative direction) and the vertical direction will now increase. The bullet will fall back to earth.

STA $04;
STA $05;                 // reset H and V averegers

LDA $29;
STA $08;                 // the bullet is initially inside the owner (tank collision detection)

"MovementLoop":          // Movement is achieved by adding speed to an "avereger". Avereger has the following form: xxx-xxxxx.
                         // top 3 bits are added to sprite's current position then cleared every NMI, bottom 5 bits remain for the next addition.
                         // The top speed is: 0xe0. Which is equivalent to to 420pix/sec. 
                         // Minimum speed is 0x01 (omiting 0x00). Which is equivaent to 1.87pix/sec

CLC;
LDA $04;                 // load Horizontal avereger
ADC $02;                 // add horizontal speed to it
TAX;                     // make a temporary copy
AND #$1f;                // clear top 3 bits
STA $04;                 // update Horizontal avereger
TXA;                     // retrieve the temporary copy
LSR; LSR;
LSR; LSR;
LSR;                     // top 3 bits are shifter down 5 times, top 5 bits are automatically cleared.
STA $06;                 // put it away for now into a temp register that is no longer used.
LDA $01;                 // load rotation
CMP #$5a;                // compare to 90 degrees
BCS *DoLeftDir;          // if angle is smaller then move the ball right
CLC;
LDA $0233;
ADC $06;                 // now add these 3 bits to bullet's X position
STA $0233;               // update X position
BCC *EndBullDir;         // 'branching outside range' fix
JMP *TerminateAnimation; // stop animation if bullet flies outside the left side of the screen
"DoLeftDir":
SEC;
LDA $0233;
SBC $06;                 // now subtract these 3 bits to bullet's X position
STA $0233;               // update X position
BCS *EndBullDir;         // stop animation if bullet flies outside the right side of the screen
JMP *TerminateAnimation; // read the comment above ('branching outside range' fix)
"EndBullDir":

CLC;
LDA $05;                 // load Vertical avereger
ADC $03;                 // add vertical speed to it
TAX;                     // make a temporary copy
AND #$1f;                // clear top 3 bits
STA $05;                 // update Vertical avereger
TXA;                     // retrieve the temporary copy
LSR; LSR;
LSR; LSR;
LSR;                     // top 3 bits are shifter down 5 times, top 5 bits are automatically cleared.
STA $06;                 // put it away for now into a temp register that is no longer used.
LDA $07;                 // load bullet vertical direction flag
BEQ *DoUpDir;            // if 0x00, then move bullet up. Otherwise, move bullet down
CLC;
LDA $0230;
ADC $06;                 // now add these 3 bits to bullet's Y position
STA $0230;               // update Y position
CMP #$e8;
BCS *TerminateAnimation; // stop animation if bullet flies outside the bottom side of the screen ( Max Y for Nt - 1, 29 tiles, NOT 32!)
JMP *EndBullVDir;        // I'm using Nt - 1 because the "break ground" subrutine draws a tile just bellow to ensure destruction
"DoUpDir":
SEC;
LDA $0230;
SBC $06;                 // now subtract these 3 bits to bullet's Y position
STA $0230;               // update Y position
BCC *TerminateAnimation; // stop animation if bullet flies outside the top side of the screen
"EndBullVDir":

LDA $03;                 // Gravity effects begin now. load vertical speed
BNE *SkipFlipDirection;  // flip vertical direction if vertical speed reaches zero
LDA #$ff;
STA $07;                 // set flag                 
"SkipFlipDirection":

LDA $07;
BNE *BulletSpeedIncrease;  // decrease or "increase" bullet speed according to the direction flag.
DEC $03;
JMP *EndBulletSpeed;
"BulletSpeedIncrease":
INC $03;
"EndBulletSpeed":

JSR *WaitForNmi;         // speed delay and oam update

LDA $0233;               // load bullet's X position  
TAX;
LDA $0500,X;             // load ground level above flying bullet
CMP $0230;               // compare against bullet's Y position
BCC *EndAnimation;

LDX #$00;                    // load number of player (multiple of 4) (TANK COLLISION DETECTION STARTS HERE)
"PlayerHitCheckLoop":
LDA $0233;                   // load bullet's X position
SEC;
SBC $0207,X;                 // subtract tank's X position
BCC *CheckNextPlayerHit;     // if tank's X was greater than bullet's
CMP #$09;
BCS *CheckNextPlayerHit;     // exit if difference between the two X's is greater than 8
LDA $0230;                   // load bullet's Y position
SEC;
SBC $0204,X;                 // subtract tank's Y position
BCC *CheckNextPlayerHit;     // if tank's Y was greater than bullet's
CMP #$09;
BCS *CheckNextPlayerHit;     // exit if difference between the two Y's is greater than 8
CPX $08;
BEQ *EndPlayerHitCode;       // the bullet is still within the owner ($08 was initialized just before the moving loop)
STX $2a;                     // hit ID = tank index (multiple of 4)
JMP *EndAnimation;
"CheckNextPlayerHit":
INX; INX;
INX; INX;                    // cheap increment by 4
CPX $20;                     // compare against the number of players
BNE *PlayerHitCheckLoop;     // (TANK COLLISION DETECTION ENDS)
LDA #$ff;
STA $08;                     // bullet has left the owner and is somewhere in the air. The owner can now damage himself.
"EndPlayerHitCode":

JMP *MovementLoop;

"TerminateAnimation":    // the jump to location when bullet flies of screen
LDA #$fe;
STA $2a;                 // 'Why the bullet stopped' (indicate that bullet went off limits ID=fe)

"EndAnimation":
LDA #$2f;
STA $0231;               // make bullet invisible (transparent sprite)
RTS;


//---


"DamageTanks":
LDX $2a;                 // load bullet's 'Why it stopped' id
CPX #$80;                // Id's above or equal to $80 are nature related
BCS *EndDamageTanks;
LDA #$18;
STA $fd;                 // set game delay 
LDA $0204,X;             // load tank's Y
STA $0200;               // set explosion sprite Y
LDA $0207,X;             // load tank's X
STA $0203;               // set explosion sprite X
LDA #$01;
STA $0202;               // set explosion sprite attributes
LDA #$62;                // begin bullet impact explosion
STA $0201;
JSR *GameDelay;
LDA #$2f;                // hide sprite
STA $0201;
LDA $0401,X;             // begin new health calculation
SEC;
SBC #$10;
STA $0401,X;             // subtract damage from tank's health
BEQ *BeginDeath;         // zero is considered death
BCS *EndDamageTanks;     // bellow zero health begins now
"BeginDeath":

LDA #$80;
STA $fd;                 // long delay
JSR *GameDelay;          // delay before the second explosion
LDA #$18;
STA $fd;                 // back to short delay
LDA $2a;
STA $2b;                 // pass tank index to the destroy tank subrutine
JSR *DestroyTank;

"EndDamageTanks":
LDA #$ff;
STA $0200;
STA $0203;               // hide explosion sprite somewhere
RTS;


//---


"DestroyTank":           // explosion animation and oam/ram clearance

PHA;
TXA;
PHA;
TYA;
PHA; // push A,X,Y to stack

LDX $2b;                 // load tank's index
LDA $0204,X;             // load tank's Y
STA $0200;               // set explosion sprite Y
LDA $0207,X;             // load tank's X
STA $0203;               // set explosion sprite X
LDA #$01;
STA $0202;               // set explosion sprite attributes

LDX #$62;
"ExplosionExandLoop":
STX $0201;               // explosion sprite loop
JSR *GameDelay;          // uses stack to preserve X,Y and A
INX;
CPX #$66;
BNE *ExplosionExandLoop;
LDY $2b;                 // reload tank index
LDA #$2f;                 // null sprite
STA $0205,Y;             // hide tank under explosion
DEX;
"ExplosionImplodeLoop":
STX $0201;               // explosion sprite loop
JSR *GameDelay;          // uses stack to preserve X,Y and A
DEX;
CPX #$61;
BNE *ExplosionImplodeLoop;

LDA #$ff;
LDX $2b;                 // relad the tank we are destroying
STA $0204,X;
STA $0206,X;
STA $0207,X;             // clear tank's sprite
LDA #$00;
STA $0401,X;             // zero out tank's health bar

LDA #$ff;
STA $0200;
STA $0203;               // hide explosion sprite somewhere

PLA;
TAY;
PLA;
TAX;
PLA;  // pull A,X,Y from stack

RTS;


//---


"DestructionByPit":      // destoy tank if tank falls low enough

PHA;
TXA;
PHA;
TYA;
PHA;                       // push A,X,Y to stack

LDX $2c;                   // load tank index
LDA $0204,X;               // load tank Y
CMP #$e0;
BCC *SkipPitDestruction;
STX $2b;                   // tank do testroy index
LDA #$ff;
STA $2c;                   // 'tank destroyed' flag
JSR *DestroyTank;
"SkipPitDestruction":

PLA;
TAY;
PLA;
TAX;
PLA;                       // pull A,X,Y from stack

RTS;


//---


"BreakGround":          // first we'll calculate the cooresponding "tile coordinate"

LDA $2a;
CMP #$ff;
BNE *EndBreakGround;    // break ground only when the bulled was stopped by the ground (ID=00)

LDA $0233;              // get bullet's X
STA $ea;
LDA $0230;              // get bullet's Y
CLC;
ADC #$08;               // one tile down ( a hole is always made )
STA $eb;
LDA #$20;               // current nametable offset
STA $ec;
JSR *NtCoordinateFunction;
LDA $c0;                // load "random" number. ( Continuos Nmi based counter )
AND #$03;               // remove everything but the low 2 bits
STA $02;                // move to a temporary regiter
CLC;
ADC #$e4;               // create an offsift ( one of 4 HOLE sprites )
STA $0300;              // load ppu write buffer
"HoleSpritesLoop":      // the bottom sprite will be the hole, everything above will be null
LDA $eb;
STA $f0;
STA $e0;                // we'll read from the location we are about to midify ( ppu Nt read )
LDA $ec;
STA $f1;                // transfer the coordinates
STA $e1;                // we'll read from the location we are about to midify ( ppu Nt read )
LDA #$01;
STA $f2;                // 1 byte to transfer
JSR *WaitForNmi;
SEC;
LDA $eb;
SBC #$20;               // by subtracting 32 we elevate one sprite up within the nametable
STA $eb;
LDA $ec;
SBC #$00;               // borrow from the msb
STA $ec;
LDA #$4b;               // hole sprite ID   ( NULL )
STA $0300;              // null sprites for the next cylces of the loop
LDA $e2;                // load the value of the last replaced sprite
CMP #$4b;
BNE *HoleSpritesLoop;   // if last replaced sprite was a NULL sprite, then stop making a hole.     

LDA $0233;              // get bullet's X
AND #$f8;               // tile quantization
STA $00;
LDA $0230;              // get bullet's Y
CLC;
ADC #$08;               // one tile down ( a hole is always made )
AND #$f8;               // tile quantization
STA $01;

LDA $02;                // get the random number we used in the last step
ASL; ASL; ASL;          // multiply by 8 to get the hole type offset ( 8 entries per hole )
TAY;
LDX $00;                // load quantized X
"ModifyGroundMapLoop":  // we'll now modify the ground map by chnaging it in a tile like fashion
LDA $01;                // load quantized Y
CLC;
ADC *GroundHole,Y;      // add ground hole depth to it
STA $0500,X;            // modify ground level
INX;
INY;
TYA;
AND #$07;               // check if the lowest three bits are all zero ( aka, we counted more than 8 )
BNE *ModifyGroundMapLoop;

"EndBreakGround":
RTS;


//---


"ParachuteTanks":

LDA #$00;
LDX #$00;
"InitializeTaskArrayLoop":
STA $08,X;
INX;
CPX #$08;
BNE *InitializeTaskArrayLoop;  // Each of these 8 bytes represents a tank. The value is the number of pixels to decend a tank. Zero means that the task is finished. 

LDX #$00;               //  X will index the Tank OAM
"RecordTaskArrayValuesLoop":
LDA $0207,X;            // load tank SPRITE's current X position
CMP #$ff;
BEQ *SkipParachuteSpriteLoad;   // unused tank sprite oam set, skip alltoger
CLC;
ADC #$03;               // add 3 to it ( recenter sprite ), real current X position
TAY;
LDA $0500,Y;            // load current Y position (ground map)
SEC;
SBC $0204,X;            // subtract tanks sprite position position from ground position
SEC;
SBC #$08;               // remember that the tank's top left coordinate used is elevated
STA $00;                // temporarily put the result away
TXA;
LSR; LSR;
TAY;                    // convert from +4 incrementation to +1 incremetation
LDA $00;
STA $0008,Y;              // fill the TaskArray
CMP #$00;
BEQ *SkipParachuteSpriteLoad; // if these is no change in elevation then don't deploy parachutes
LDA $0207,X;                  // load tank SPRITE's current X position
STA $0247,X;                  // initialize parachute's X position (Sprite)
LDA #$03;
STA $0246,X;                  // initialize parachute's attributes (Sprite)
LDA #$50;
STA $0245,X;                  // initialize parachute's tile ID (Sprite)
LDA $0204,X;                  // load tank SPRITE's current Y position
SEC;
SBC #$05;                     // parachute touches the tank
STA $0244,X;                  // initialize parachute's Y position (Sprite)
"SkipParachuteSpriteLoad":
INX; INX;
INX; INX;
CPX #$20;               // scan through all tanks
BNE *RecordTaskArrayValuesLoop;

"ProcessUnitilAllDone":
LDX #$00;               // X will index the TaskArray
LDA #$00;
STA $01;                // my all done flag. When an action is performed it gets set
"ProcessAllElements":
LDA $08,X;                // load task value
BEQ *NextElement;         // if the value is zero, then the task is either completed or was never issued
STX $00;                  // temporarily put X away
TXA;
ASL; ASL;
TAX;                      // convert +1 into +4 indexing
INC $0204,X;
INC $0244,X;              // decent parachute and tank

STX $2c;                  // prepare the tank index for the pit death test
JSR *DestructionByPit;    // stack preserves elements
LDA $2c;
CMP #$ff;
BNE *LocalSkip10;
STA $59;
LDX $00;
LDA #$01;
STA $08,X;                // final step (parachute decent will no longer handle 
"LocalSkip10":

LDX $00;                  // restore my usual X
INC $01;                  // set the action flag (incrementation means nothing, we are setting it)
DEC $08,X;                // decrement the element (task is being performed once)
BNE *NextElement;
STX $00;                  // (Removing the parachute begins here) temporarily put X away
TXA;
ASL; ASL;
TAX;                      // convert +1 into +4 indexing
LDA #$ff;
STA $0244,X;
STA $0245,X;
STA $0246,X;
STA $0247,X;              // complitely clear the OAM area
LDX $00;                  // restore my usual X
"NextElement":
INX;
CPX #$08;                 // scan through all tanks (tasks)
BNE *ProcessAllElements;
JSR *GameDelay;
LDA $01;
BNE *ProcessUnitilAllDone;  // check flag

RTS;


//========================== General Subrutines


"GameDelay":       //=-=-=-=-= Delay
PHA;
TXA;
PHA;
TYA;
PHA; // push A,X,Y to stack
LDY $fd;
LDX #$00;
"GDelayLoop":
LDA ($00),Y;
LDA ($00),Y;
LDA ($00),Y;
LDA ($00),Y;   // 20 cycles
DEX;
BNE *GDelayLoop;
DEY;
BNE *GDelayLoop;
PLA;
TAY;
PLA;
TAX;
PLA;  // pull A,X,Y from stack
RTS;


"CustomDelay": //=-=-=-=-= Small custom delay
DEX;
BNE *CustomDelay;
DEY;
BNE *CustomDelay;
RTS;


"DevideFunction": //-=-=-=-=-=-= Devider function, doesn't use temporary registers!
LDX #$00;
LDA $e5;
BEQ *EndDivLoop;  // skip devision if devider is zero
LDA $e4;
"DivLoop":
CMP $e5;
BCC *EndDivLoop;
SEC;
SBC $e5;
INX;
JMP *DivLoop;
"EndDivLoop":
STX $e4;          // store away the answer
STA $e5;          // store away the remainder
RTS;


"MultiplyFunction":
LDA #$00;
STA $e8;
STA $e9;          // reset low and high bytes of the answer
LDX $e6;          // load first multiplier
"MultiplyFLoop":
CPX #$00;
BEQ *EndMultiplyF;
CLC;
LDA $e8;
ADC $e7;
STA $e8;          // add second multiplier to the answer's low byte
LDA $e9;
ADC #$00;
STA $e9;          // add carry to answer's high byte
DEX;
JMP *MultiplyFLoop;
"EndMultiplyF":
RTS;


"NtCoordinateFunction":
LSR $ea; 
LSR $ea; 
LSR $ea;          // calculate X/8 to get the tile X coordinate
LDA $eb;
AND #$f8;
STA $eb;          // equivaent to: (Y/8)*8
LSR $ec;
LSR $ec;          // shifting ms byte left twice, before shifting it twice to the right
ASL $eb;
ROL $ec;
ASL $eb;
ROL $ec;          // multiply [(Y/8)*8] by 4 ( shifting twice ) and carry the ms bits into $ec. Equivalent: (Y/8)*32
CLC;
LDA $eb;
ADC $ea;
STA $eb;          // add X tile coordinate
LDA $ec;
ADC #$00;
STA $ec;          // add carry to high byte
RTS;


"WaitForNmi":  //-=-=-=-=- Waits for NMI to complete
LDA #$01;
STA $fc;            // set nmi wait flag
"WaitForNmiLoop":
LDA $fc;
BNE *WaitForNmiLoop;
RTS;



"LoadMap":      //=-=-=-=-= Decompresses and loads data during nmi ( Any Nt size )
                //          ( meant to be offscreen, cpu is completely dedicated )
LDA #$00;
STA $f5;        // reset bytes counter

LDY #$00;        //null offset ( actual indexing will be performed via $f3 and $f4 )

"HeaderLoop":
JSR *IncPointer;
LDA ($f3),Y;
TAX;
BEQ *EndDecomp;
BMI *UniqueLoop;    // go to unique 

INX; INX;          // +2 correction
JSR *IncPointer;
LDA ($f3),Y;    // value to be repeated
"RepeatsLoop":
JSR *OutputStage;
DEX;
BNE *RepeatsLoop;
JMP *HeaderLoop;

"UniqueLoop":
JSR *IncPointer;
LDA ($f3),Y;    // value to be repeated
JSR *OutputStage;
INX;
BNE *UniqueLoop;
JMP *HeaderLoop;

"OutputStage":
STX $00; // save x reg

LDX $f5;
STA $0300,X; // store value
INX;
STX $f5;     // increment byte count
CPX #$40;
BNE *EndOutputStage;
STX $f2;
LDX #$00;
STX $f5;     // request and reset byte count
"WaitForTransfer":
LDX $f2;
BNE *WaitForTransfer;

"EndOutputStage":
LDX $00; // restore x reg
RTS;

"IncPointer":
INC $f3;
BNE *EndIncPointer;
INC $f4;
"EndIncPointer":
RTS;

"EndDecomp":
RTS;



"RenderArtImage":  //-=-=-=-=-=-=-=- renders bitmap by switching mappers midline

CLC;
LDA #$40;
"WaitWhileHit":
BIT $2002;
BNE *WaitWhileHit;  // wait while hit
"WaitWhileNotHit":
BIT $2002;
BEQ *WaitWhileNotHit;  // wait while no hit
	LDA $f6;
	STA $d000;  // 4K backgrnd chr
	STA $e000;  // no latch feature
LDX #$1e;
LDY #$06;
JSR *CustomDelay;
	ADC #$01;
	STA $d000;  // 4K backgrnd chr
	STA $e000;  // no latch feature
LDX #$a4;
LDY #$06;
JSR *CustomDelay;
	ADC #$01;
	STA $d000;  // 4K backgrnd chr
	STA $e000;  // no latch feature
LDX #$a3;
LDY #$06;
JSR *CustomDelay;
	ADC #$01;
	STA $d000;  // 4K backgrnd chr
	STA $e000;  // no latch feature    // small window for cpu usage begins now
RTS;


//========================== Nmi handle

"@Nmi":

PHA;
TXA;
PHA;
TYA;
PHA; // push A,X,Y to stack


//------------ Oam Dma transfer

LDA $f2;
CMP #$20;
BCS *SkipOamDma;  // oam deactivates if ppu write has more than 32 bytes to handle
LDA #$00;
STA $2003;
LDA #$02;
STA $4014;        // begin oam dma
"SkipOamDma":


//------------ Ppu ram read (single byte)

LDA $2002;
LDA $e1;
STA $2006;
LDA $e0;
STA $2006;
LDA $2007;
LDA $2007;  // read twice because nes ppu is glitchy af
STA $e2;    // get byte from ppu
LDA #$00;
STA $e3;    // clear read flag


//------------ Ppu ram write

LDA $f2;
BEQ *SkipPpuWrite;

LDA $2002;
LDA $f1;
STA $2006;
LDA $f0;
STA $2006;

CLC;
LDA $f0;
ADC $f2;
STA $f0;
LDA $f1;
ADC #$00;
STA $f1;  // increment next start address

LDY $f2;
LDX #$00;
"PpuWriteLoop":
LDA $0300,X;
STA $2007;
INX;
DEY;
BNE *PpuWriteLoop;  // loop cycles: 4+4+2+2+3(+1) = 15(16) // 2200/16 = 137
STY $f2;            // In theory I should be able to write 128 bytes per nmi, however, this game doesn't need this.
                    // 1024 bytes (nametable) will be written within 0.266 sec
                    // The loop can be further improved by letting X be the indexer and counter at the same time
"SkipPpuWrite":


//------------ Set current nametable, scroll and layers


LDA $fe;
STA $2000;  

LDA $ff;
STA $2001;

LDA $2002;
LDA $fb;
STA $2005;   // X scroll
LDA #$00;
STA $2005;   // Y scroll


//------------ Controller latch


LDA #$01;
STA $4016;
LDA #$00;
STA $4016; // latch controller buttons ( both controllers )

LDA $10;
STA $11;  // previus state, controller 1

LDX #$08;
"LoadController1":
LDA $4016;          // read controller bit
LSR;                // move bit to carry
ROL $10;            // shift carry into memory
DEX;                // repeat 8 times
BNE *LoadController1;

LDA $12;
STA $13;  // previus state, controller 2

LDX #$08;
"LoadController2":
LDA $4017;          // read controller bit
LSR;                // move bit to carry
ROL $12;            // shift carry into memory
DEX;                // repeat 8 times
BNE *LoadController2;



//------------ nmi based counter ( stops at zero )

LDA $fc;
BEQ *SkipNmiDec;
DEC $fc;            // decrement nmi counter
"SkipNmiDec":


//------------ random seed counter

INC $c0;

//------------ return from interrupt


PLA;
TAY;
PLA;
TAX;
PLA;  // pull A,X,Y from stack

RTI;


//========================= Irq handle

"@Irq":

RTI;

//========================= Arrays


//-------- Game Setup

"FadeOutColors":
ARR {$10,$00,$0f};

"ArtFadeInColors":
ARR {$0f,$0f,$0f,$09,$0f,$0f,$09,$19,$0f,$09,$19,$29,$0f,$19,$29,$3a};  // 4 steps for a single sub-palette

"InitSpritesArr":
ARR {$04,$ff,$00,$f0};  // zero hit sprite
ARR {$6e,$19,$01,$6f,$6e,$1b,$01,$77,$6e,$0e,$01,$7f,$6e,$1c,$01,$87,$6e,$1c,$01,$8f};  // "PRESS"
ARR {$77,$1c,$01,$70,$77,$1d,$01,$77,$77,$0a,$01,$7f,$77,$1b,$01,$87,$77,$1d,$01,$8e};  // "START"

"SelectSpritesArr":
ARR {$72,$29,$01,$96,$72,$02,$01,$a0,$72,$2a,$01,$aa,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff};
ARR {$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff}; // clears

"ColorSpritesArr":
ARR {$9f,$29,$01,$70,$72,$01,$01,$9c,$9f,$2a,$01,$c8,$9f,$2d,$01,$80,$8f,$2b,$01,$a0}; // LftC,Pl,RihC,Cur,Up
ARR {$8f,$2c,$01,$b0,$8f,$19,$01,$80,$8f,$15,$01,$88,$8f,$01,$01,$90,$ff,$ff,$ff,$ff}; // Dwn,P,L,1,---

"StartPalettes":
ARR {$0f,$0f,$0f,$0f,$0f,$20,$10,$20,$0f,$00,$10,$20,$0f,$00,$10,$20}; // Background
ARR {$0f,$16,$10,$20,$0f,$0f,$10,$20,$0f,$00,$10,$20,$0f,$00,$10,$20}; // Sprite

"FakePlayableColors":
ARR {$0f,$19,$29,$3a,$0f,$16,$28,$3a,$0f,$12,$24,$3a,$0f,$00,$20,$3a};  // only for color select screen

"ModeLetters":
ARR {$19,$15,$01,$00,$19,$15,$02,$00,$0c,$19,$1e,$00}; // letter id's: P,L,1,0,P,L,2,0,C,P,U,0 ( zero pads cuz x4 is simpler than x3 when indexing)

"ArtFadeOutColors":
ARR {$0f,$09,$19,$2a,$0f,$06,$18,$2a,$0f,$02,$14,$2a,$0f,$0f,$00,$2a}; // 1st step for the complete background palette
ARR {$0f,$0f,$09,$1a,$0f,$0f,$08,$1a,$0f,$0f,$04,$1a,$0f,$0f,$0f,$1a}; // 2nd step
ARR {$0f,$0f,$0f,$0a,$0f,$0f,$0f,$0a,$0f,$0f,$0f,$0a,$0f,$0f,$0f,$0a}; // 3rd step
ARR {$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f}; // 4th step  ( no image )

"TruePlayableColors":
ARR {$0f,$3a,$19,$3a,$0f,$16,$28,$3a,$0f,$12,$24,$3a,$0f,$00,$20,$3a};  // real in game sprite colors with sky background

"IntroScreen":
ARR {$00}; // dummy
ARR {$7f,$ff,$4a,$ff,$fb,$1d,$0a,$17,$14,$1c,$76,$ff,$f4,$00,$1b,$12,$10,$12,$17,$0a,$15,$ff,$0b,$22,$24,$31,$ff,$f3,$16,$0a,$1d,$11};
ARR {$12,$1c,$0f,$1e,$17,$25,$0c,$18,$16,$74,$ff,$f8,$19,$18,$1b,$1d,$ff,$0b,$22,$24,$33,$ff,$f2,$0a,$17,$0a,$1d,$18,$15,$22,$ff,$15};
ARR {$0e,$1b,$17,$0e,$1b,$35,$ff,$fc,$02,$00,$01,$08,$79,$ff,$fa,$0e,$17,$13,$18,$22,$26,$7f,$ff,$29,$ff,$ff,$ff};
ARR {$36,$55,$05,$05,$ff,$05};  // atribute
ARR {$00};  // end


//--------------- Gameplay General

"GarageInit":
ARR {$63,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$63,$10}; // 14 shells, fuel and money

"PlayfieldInit":
ARR {$63,$63,$b4,$00}; // power, health, rotation, shell selection

"PlayerLabels":
ARR {$ba,$bb,$b1,$00,$ba,$bb,$b2,$00,$bc,$bd,$be,$00}; // PL1_,PL2_,CPU_

"StandardRibbon":
ARR {$ba,$bb,$b1,$00,$df,$e2,$b9,$b9,$00,$c7,$b1,$b8,$b0,$00,$d3,$c8,$f0,$ca,$b9,$b9,$ca,$d7,$d8,$b9,$b9}; // player stats

"MyGameCursors":
ARR {$07,$2e,$00,$50,$0a,$40,$00,$28,$0a,$40,$40,$30};                 // turrent linear cursor, two power linear cursors
ARR {$0a,$2f,$02,$28,$0a,$2f,$42,$30,$12,$2f,$02,$28,$12,$2f,$42,$30}; // four power-health limit sprites (top-right, top-left, bottom-left, bottom-right)

"GroundHole":
ARR {$00,$02,$03,$03,$03,$03,$02,$01}; // depth values for the ground hole sprite
ARR {$01,$02,$03,$02,$02,$03,$03,$02};
ARR {$01,$03,$04,$04,$03,$02,$02,$01};
ARR {$00,$01,$02,$02,$03,$04,$04,$01}; // four such holes

"Sine":
ARR {$00,$04,$08,$0d,$11,$16,$1a,$1f,$23,$28,$2c,$30,$35,$39,$3d,$42,$46,$4a,$4f,$53,$57,$5b,$5f,$64,$68,$6c,$70,$74,$78,$7c,$7f,$83};

ARR {$87,$8b,$8f,$92,$96,$9a,$9d,$a1,$a4,$a7,$ab,$ae,$b1,$b5,$b8,$bb,$be,$c1,$c4,$c6,$c9,$cc,$cf,$d1,$d4,$d6,$d9,$db,$dd,$df,$e2,$e4};

ARR {$e6,$e8,$e9,$eb,$ed,$ee,$f0,$f2,$f3,$f4,$f6,$f7,$f8,$f9,$fa,$fb,$fc,$fc,$fd,$fe,$fe,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff};

ARR {$fe,$fe,$fd,$fc,$fc,$fb,$fa,$f9,$f8,$f7,$f6,$f4,$f3,$f2,$f0,$ee,$ed,$eb,$e9,$e8,$e6,$e4,$e2,$df,$dd,$db,$d9,$d6,$d4,$d1,$cf,$cc};

ARR {$c9,$c6,$c4,$c1,$be,$bb,$b8,$b5,$b1,$ae,$ab,$a7,$a4,$a1,$9d,$9a,$96,$92,$8f,$8b,$87,$83,$80,$7c,$78,$74,$70,$6c,$68,$64,$5f,$5b};

ARR {$57,$53,$4f,$4a,$46,$42,$3d,$39,$35,$30,$2c,$28,$23,$1f,$1a,$16,$11,$0d,$08,$04,$00};

"Cosine":
ARR {$ff,$ff,$ff,$ff,$ff,$ff,$fe,$fe,$fd,$fc,$fc,$fb,$fa,$f9,$f8,$f7,$f6,$f4,$f3,$f2,$f0,$ee,$ed,$eb,$e9,$e8,$e6,$e4,$e2,$df,$dd,$db}; // 181 entries

ARR {$d9,$d6,$d4,$d1,$cf,$cc,$c9,$c6,$c4,$c1,$be,$bb,$b8,$b5,$b1,$ae,$ab,$a7,$a4,$a1,$9d,$9a,$96,$92,$8f,$8b,$87,$83,$80,$7c,$78,$74}; // format: xx/ff = fraction

ARR {$70,$6c,$68,$64,$5f,$5b,$57,$53,$4f,$4a,$46,$42,$3d,$39,$35,$30,$2c,$28,$23,$1f,$1a,$16,$11,$0d,$08,$04,$00,$04,$08,$0d,$11,$16};

ARR {$1a,$1f,$23,$28,$2c,$30,$35,$39,$3d,$42,$46,$4a,$4f,$53,$57,$5b,$5f,$64,$68,$6c,$70,$74,$78,$7c,$7f,$83,$87,$8b,$8f,$92,$96,$9a};

ARR {$9d,$a1,$a4,$a7,$ab,$ae,$b1,$b5,$b8,$bb,$be,$c1,$c4,$c6,$c9,$cc,$cf,$d1,$d4,$d6,$d9,$db,$dd,$df,$e2,$e4,$e6,$e8,$e9,$eb,$ed,$ee};

ARR {$f0,$f2,$f3,$f4,$f6,$f7,$f8,$f9,$fa,$fb,$fc,$fc,$fd,$fe,$fe,$ff,$ff,$ff,$ff,$ff,$ff};

"HealthBarTransitionsU":
ARR {$2f,$52,$53,$54,$55,$56,$57,$58,$59,$59,$59,$59,$59,$59,$59};  // upper left and right
"HealthBarTransitionsL":
ARR {$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$5a,$5b,$5c,$5d,$5e,$5f};  // lower left and right

"SimpleExplosionSequence":
ARR {$62,$63,$64,$65,$64,$63,$62,$2f};

//--------------- Playmaps


"Map1PaletteInit":
ARR {$00,$29,$20,$21,$00,$10,$20,$21,$00,$31,$20,$21,$00,$0f,$26,$31}; // Background
ARR {$00,$0f,$3a,$1a,$00,$0f,$16,$28,$00,$0f,$12,$24,$00,$0f,$10,$20}; // Sprite

"Map1Screen":
ARR {$00}; // dummy
ARR {$23,$00,$fe,$de,$e3,$01,$00,$02,$dd,$f6,$00,$d2,$cd,$c9,$d0,$c9,$c9,$ce,$d5,$d6,$07,$00,$e2,$ba,$bb,$b1,$00,$df,$e2,$b9,$b9,$00};
ARR {$c7,$b1,$b8,$b0,$00,$d3,$c8,$f0,$ca,$b9,$b9,$ca,$d7,$d8,$b9,$b9,$00,$00,$dc,$b9,$b9,$04,$00,$fe,$e0,$e1,$06,$00,$f7,$d4,$cc,$cb};
ARR {$d1,$cb,$cb,$cf,$d9,$da,$69,$00,$f9,$01,$02,$03,$04,$05,$06,$07,$17,$00,$ff,$08,$02,$09,$fe,$0a,$0b,$17,$00,$fa,$0c,$0d,$0e,$0f};
ARR {$10,$11,$09,$00,$f9,$01,$02,$03,$04,$05,$06,$07,$17,$00,$ff,$08,$02,$09,$fe,$0a,$0b,$17,$00,$fa,$0c,$0d,$0e,$0f,$10,$11,$2a,$00};
ARR {$fe,$12,$13,$1a,$00,$fb,$14,$15,$16,$17,$18,$19,$00,$fa,$19,$1a,$1b,$09,$1c,$1d,$07,$00,$fb,$14,$1e,$1f,$20,$21,$09,$00,$fd,$22};
ARR {$23,$24,$01,$09,$ff,$25,$06,$00,$f9,$26,$27,$28,$09,$09,$29,$2a,$07,$00,$fd,$2b,$2c,$2d,$03,$09,$ff,$2e,$04,$00,$fc,$2f,$30,$31};
ARR {$1b,$02,$09,$fe,$32,$33,$04,$00,$f4,$34,$35,$36,$37,$38,$39,$3a,$09,$3b,$3c,$3d,$3e,$01,$00,$f4,$3f,$40,$41,$42,$09,$43,$09,$09};
ARR {$44,$45,$46,$47,$01,$00,$fd,$48,$49,$4a,$03,$4b,$fe,$4c,$4d,$01,$4b,$eb,$4e,$4f,$00,$50,$51,$52,$53,$54,$55,$4c,$56,$57,$58,$59};
ARR {$5a,$5b,$5c,$00,$5d,$5e,$5f,$0b,$4b,$fe,$60,$61,$0b,$4b,$ff,$62,$0b,$4b,$fe,$63,$64,$0a,$4b,$fa,$65,$4b,$66,$4b,$4b,$67,$09,$4b};
ARR {$f9,$68,$69,$6a,$6b,$6c,$4b,$6d,$01,$4b,$ea,$6e,$6f,$70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7a,$7b,$4b,$4b,$7c,$7d,$7e,$4b,$4b};
ARR {$7f,$02,$41,$e4,$80,$81,$82,$83,$84,$85,$86,$87,$88,$89,$8a,$8b,$41,$8c,$41,$8d,$8e,$41,$41,$8f,$90,$91,$92,$93,$94,$95,$96,$97};
ARR {$7f,$41,$32,$41,$ff,$41};
ARR {$06,$ff,$0e,$aa,$0e,$55,$15,$00,$ff,$00}; // atribute
ARR {$00}; // end

"Map1Ground":
ARR {$b9,$b9,$ba,$bb,$bb,$bc,$bd,$bd,$be,$bf,$bf,$bf,$c0,$c1,$c1,$c1,$c2,$c3,$c6,$c6,$c6,$c6,$c6,$c6,$c6,$c6,$c6,$c6,$c5,$c5,$c5,$c5};
ARR {$c5,$c5,$c6,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c6,$c5,$c5,$c3,$c3,$c1,$c1,$c0,$c0,$c0,$bf,$c0,$c0,$c0,$c1,$c1,$c1,$c1,$c1};
ARR {$c1,$c2,$c2,$c3,$c3,$c3,$c2,$c2,$c1,$c0,$c0,$bf,$bd,$bc,$bb,$ba,$b9,$b9,$b8,$b8,$b8,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7};
ARR {$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b8,$b8,$b8,$b7,$b7,$b7,$b7,$b8,$b8,$b8,$b8,$b9,$b9,$b9,$b9,$ba,$ba,$ba,$bb,$bd,$bd};
ARR {$bd,$be,$be,$bd,$bc,$bc,$bc,$bc,$bc,$bd,$bd,$bd,$bd,$bd,$bf,$c0,$c0,$c0,$c0,$c0,$c0,$bf,$bf,$be,$be,$be,$be,$be,$be,$bf,$bf,$c0};
ARR {$c0,$c0,$c0,$bf,$be,$bd,$bd,$bd,$bc,$bc,$bd,$bd,$be,$be,$be,$be,$be,$bc,$bb,$ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba,$bb,$bb};
ARR {$bb,$bb,$bb,$bb,$ba,$ba,$b9,$b9,$b9,$b9,$b9,$b9,$b9,$b9,$b9,$b8,$b8,$b8,$b8,$b7,$b7,$b7,$b7,$b8,$b9,$b9,$b9,$b9,$b9,$b9,$b8,$b8};
ARR {$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b7,$b8,$b8,$b9,$b9,$b9,$b9,$b9,$b8,$b8,$b8,$b8,$b7,$b6,$b6,$b6,$b6,$b6,$b6,$b6};





