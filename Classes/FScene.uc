/* ========================================================
 * Copyright 2012-2013 Eliot van Uytfanghe
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ======================================================== */
class FScene extends FComponent;

/** Add objects to this pool that have to be free'd on level change! :TODO: */
var protectedwrite array<FObject> 									ObjectsPool;

// First item = Top page/window.
// Last item = lowest page/window.
var(Scene, Advanced) protectedwrite editinline array<FPage> 		Pages;

var const globalconfig name 										ThemeName;

// Contains a list of style objects
var array<FStyle> 													Styles;

// Reference to the style class named "Global".
var private FStyle 													GlobalStyle;

var protectedwrite transient FComponent 							SelectedComponent;
var protectedwrite transient FComponent 							LastSelectedComponent;

var protectedwrite transient FComponent 							HoveredComponent;
var protectedwrite transient FComponent 							LastHoveredComponent;

var protectedwrite transient FComponent 							ActiveComponent;

/** Whether to pause the game when the scene is visible. */
var(Scene) bool														bPausedWhileVisible;

// DEPRECATED!
var(Scene, Display) deprecated bool									bConsiderAspectRatio;
var(Scene, Functionality) bool										bWiggleScene;
var(Scene, Functionality) bool										bSuppressKeyInput;
var(Scene, Functionality) bool										bLockRotation;

var(Scene, Display) bool											bRenderCursor;
var(Scene, Display) const globalconfig TextureCoordinates			CursorPointCoords;
var(Scene, Display) const globalconfig TextureCoordinates			CursorTouchCoords;
var(Scene, Display) const globalconfig string						CursorsImageName;
var(Scene, Display) Texture2D										CursorsImage;
var(Scene, Display) const globalconfig float						CursorScaling;

var(Scene, Interaction) deprecated globalconfig float				MouseSensitivity;
var(Scene, Interaction) bool										bTimeOutCursor;
var(Scene, Interaction) float										MouseCursorTimeOut;
var(Scene, Interaction) bool										bTimeOutScene;
var(Scene, Interaction) float										MouseSceneTimeOut;

var(Scene, Sound) globalconfig string								ClickSoundName;
var(Scene, Sound) globalconfig string								HoverSoundName;
var SoundCue														ClickSound;
var SoundCue														HoverSound;

var transient IntPoint 												MousePosition;
var transient IntPoint 												LastMousePosition;
var transient Vector2D 												ScreenSize;
var transient Vector2D 												ScreenRatio;

var protectedwrite transient float 									RenderDeltaTime;
var privatewrite transient float 									LastRenderTime;
var privatewrite transient float 									LastMouseMoveTime;
var privatewrite transient float 									LastActivityTime;

var(Scene, Advanced) PostProcessChain 								MenuPostProcessChain;
var protected int 													MenuPostProcessChainIndex;

var transient float 												LastClickTime;
var transient IntPoint 												LastClickPosition;
var transient Rotator 												LastPlayerRotation;

var transient bool 													bCtrl, bAlt, bShift;

`if( `isdefined( DEBUG ) )
	var(Scene, Debug) transient bool 								bDebugModeIsActive;
`endif

delegate OnPageRemoved( FPage sender );
delegate OnPageAdded( FPage sender );

delegate OnPostRenderPages( Canvas C );

final function InitializeScene( FIController sceneController )
{
	Controller = sceneController;

	GlobalStyle = new (none, "(" $ ThemeName $ ")" $ "Global") class'FStyle';

	Initialize( none );
}

protected function InitializeComponent()
{
	local FPage page;

	super.InitializeComponent();
	foreach Pages( page )
	{
		page.Initialize( self );
	} 	

	LoadConfigurations();
}

function Refresh()
{
	super.Refresh();
	LocalPlayer(Controller.Player().Player).ViewportClient.GetViewportSize( ScreenSize );	
}

protected function LoadConfigurations()
{
	if( ClickSoundName != "" )
	{
		ClickSound = SoundCue(DynamicLoadObject( ClickSoundName, class'SoundCue', true ));
	}

	if( HoverSoundName != "" )
	{
		HoverSound = SoundCue(DynamicLoadObject( HoverSoundName, class'SoundCue', true ));
	}

	if( CursorsImageName != "" )
	{
		CursorsImage = Texture2D(DynamicLoadObject( CursorsImageName, class'Texture2D', true ));
	}
}

function Update( float DeltaTime )
{
	if( bLockRotation )
	{
		// Lock the rotation so the player does not change its rotation when the mouse moves!
		Player().SetRotation( LastPlayerRotation );
	}

	if( bRenderCursor )
	{
		UpdateMouse( DeltaTime );
	}

	super.Update( DeltaTime );
	UpdatePages( DeltaTime );
}

protected function UpdatePages( float DeltaTime )
{
	local FPage page;
	
	foreach Pages( page )
	{
		// HACK: Use RenderDeltaTime as DeltaTime is always -1???
		page.Update( RenderDeltaTime );
	} 
}

protected function UpdateMouse( float DeltaTime )
{
	local Vector2D vector2DMP;

	LastMousePosition = MousePosition;
	vector2DMP = LocalPlayer(Player().Player).ViewportClient.GetMousePosition();
	MousePosition.X = vector2DMP.X;
	MousePosition.Y = vector2DMP.Y;
	if( MousePosition != LastMousePosition && OnMouseMove != none )
	{
		LastMouseMoveTime = `STime;
		LastActivityTime = `STime;
		OnMouseMove( self, DeltaTime );
		if( ActiveComponent != none && ActiveComponent.OnMouseMove != none )
		{
			ActiveComponent.OnMouseMove( self, DeltaTime );
		}
	}
		
	if( bWiggleScene )
	{
		UpdateWiggle( DeltaTime );
	}
}

protected function UpdateWiggle( float DeltaTime )
{
	local float diff;
	
	if( MousePosition.X <= 64.0 )
	{
		diff = FInterpTo( RelativePosition.X, 0.1, RenderDeltaTime, 1.0 - (MousePosition.X/65.0) );
		SetPos( diff, RelativePosition.Y );
	}
	else
	{
		diff = FInterpTo( RelativePosition.X, 0.0, RenderDeltaTime, 2.0 );
		SetPos( diff, RelativePosition.Y );
	}
	
	if( (CalcWidth() - MousePosition.X) <= 64.0 )
	{
		diff = FInterpTo( RelativePosition.X, -0.1, RenderDeltaTime, 1.0 - ((CalcWidth() - MousePosition.X)/65.0) );
		SetPos( diff, RelativePosition.Y );
	}
	else
	{
		diff = FInterpTo( RelativePosition.X, 0.0, RenderDeltaTime, 2.0 );
		SetPos( diff, RelativePosition.Y );
	}
	
	if( MousePosition.Y <= 64.0 )
	{
		diff = FInterpTo( RelativePosition.Y, 0.1, RenderDeltaTime, 1.0 - (MousePosition.Y/65.0) );
		SetPos( RelativePosition.X, diff );
	}
	else
	{
		diff = FInterpTo( RelativePosition.Y, 0.0, RenderDeltaTime, 2.0 );
		SetPos( RelativePosition.X, diff );
	}
	
	if( (CalcHeight() - MousePosition.Y) <= 64.0 )
	{
		diff = FInterpTo( RelativePosition.Y, -0.1, RenderDeltaTime, 1.0 - ((CalcHeight() - MousePosition.Y)/65.0) );
		SetPos( RelativePosition.X, diff );
	}
	else
	{
		diff = FInterpTo( RelativePosition.Y, 0.0, RenderDeltaTime, 2.0 );
		SetPos( RelativePosition.X, diff );
	}
}

protected function MouseMove( FScene scene, float DeltaTime )
{
	local FPage page;
	local bool bCollided;

	foreach Pages( page )
	{
		if( page.CanRender() && !bCollided && page.CanInteract()
			&& page.IsHover( MousePosition, HoveredComponent ) )
		{
			if( (HoveredComponent != none 
				&& (HoveredComponent.bEnableCollision
					`if( `isdefined( DEBUG ) )
						 || bDebugModeIsActive 
					`endif
					)
				) 
			)
			{
				bCollided = true;
				if( LastHoveredComponent != HoveredComponent )
				{
					HoveredComponent.Hover();
					if( LastHoveredComponent != none )
					{
						LastHoveredComponent.Unhover();
					}
					LastHoveredComponent = HoveredComponent;
				}
			}
			break;
		}
	}	

	if( !bCollided )
	{
		// Unhovered?
		if( LastHoveredComponent != none )
		{
			LastHoveredComponent.Unhover();
			LastHoveredComponent = none;	
		}
		HoveredComponent = none;
	}
}

protected function ResetCanvas( Canvas C )
{
	C.Reset();
	C.SetPos( 0.0, 0.0 );
	C.SetOrigin( 0.0, 0.0 );
	C.SetClip( C.SizeX, C.SizeY );
}

function Render( Canvas C )
{	
	RenderDeltaTime = `STimeSince( LastRenderTime );
	
	// Resolution has been changed!
	if( C.SizeX != ScreenSize.X )
	{
		ScreenSize.X = C.SizeX;
		ScreenSize.Y = C.SizeY;
	}
	
	// Don't put this in CanRender(), if CanRender() returns false, then Update() won't be called 
	//	and therefor no mouse position update.
	if( bTimeOutScene && `STimeSince( LastActivityTime ) > MouseSceneTimeOut )
	{
		goto end;
	}
	
	ResetCanvas( C );	
	Refresh();
	
	`if( `isdefined( DEBUG ) )
		if( bDebugModeIsActive )
		{
			RenderGrid( C );
		}
	`endif

	RenderPages( C );
	OnPostRenderPages( C );

	if( HoveredComponent != none && HoveredComponent.ToolTipComponent != none && HoveredComponent.ToolTipComponent.CanRender() )
	{
		HoveredComponent.ToolTipComponent.Render( C );	
	}
	
	`if( `isdefined( DEBUG ) )
		if( bDebugModeIsActive )
		{
			RenderGridBar( C, false );
			RenderGridBar( C, true );
		}
		RenderDebug( C );
	`endif

	if( bRenderCursor && (!bTimeOutCursor || `STimeSince( LastActivityTime ) < MouseCursorTimeOut) )
	{
		RenderCursor( C );
	}
	
	end:
	LastRenderTime = `STime;
}

protected function RenderGrid( Canvas C )
{
	const gridSize = 28;
	local int gridRows, gridColumns;
	local float X, Y;
	local int i;
	
	gridRows = SizeY/gridSize;
	gridColumns = SizeX/gridSize;	
	
	// Grid color
	C.SetDrawColor( 40, 40, 40, 74 );
	
	X = PosX;
	Y = PosY;
	for( i = 0; i < gridRows; ++ i )
	{
		Y += gridSize;
		C.SetPos( X, Y );
		C.DrawRect( SizeX, 1 );
	}
	
	X = PosX;
	Y = PosY;
	for( i = 0; i < gridColumns; ++ i )
	{
		X += gridSize;
		C.SetPos( X, Y );
		C.DrawRect( 1, SizeY );
	}
}

protected function RenderGridBar( Canvas C, bool bVertical )
{
	const gridSnap = 6.00;
	local float gridAmount;
	local float X, Y;
	local float XL, YL;
	local int i;
	local string s;
	
	gridAmount = bVertical ? SizeY/gridSize : SizeX/gridSize;
	X = PosX;
	Y = PosY;

	C.SetPos( X, Y );
	C.SetDrawColor( 255, 255, 255, 150 );
	if( bVertical )
	{
		C.SetPos( X, Y + gridSize );
		C.DrawRect( gridSize, SizeY - gridSize );
	}
	else
	{
		C.DrawRect( SizeX, gridSize );
	}
	
	C.SetDrawColor( 200, 0, 0, 200 );
	if( bVertical )
	{
		C.SetPos( X + (gridSize - 1), Y + gridSize );
		C.DrawRect( 1, SizeY - gridSize );
	}
	else
	{
		C.SetPos( X + gridSize, Y + (gridSize - 1) );
		C.DrawRect( SizeX - gridSize, 1 );	
	}
	
	X = PosX;
	Y = PosY;
	C.Font = Font'EngineFonts.TinyFont';
	for( i = 1; i < SizeX/gridSize - 1; ++ i )
	{
		C.SetDrawColor( 140, 0, 0, 200 );
		if( bVertical )
		{
			Y += gridSize;
			C.SetPos( X + gridSize*0.5, Y );
			C.DrawRect( gridSize*0.5, 1 );	
		}
		else
		{
			X += gridSize;
			C.SetPos( X, Y + gridSize*0.5 );
			C.DrawRect( 1, gridSize*0.5 );	
		}
		
		s = string(int(((gridSize*i)/(gridSize*(gridAmount)))*100));
		if( int(s) < 10 )
		{
			s = "0" $ s;
		}
		C.StrLen( s, XL, YL );
		if( bVertical )
		{
			C.SetPos( (X + gridSize*0.5) - XL*0.5, Y - YL*0.5 );
		}
		else
		{
			C.SetPos( X - XL*0.5, (Y + gridSize*0.5) - YL*0.5 );
		}
		C.SetDrawColor( 70, 70, 70, 200 );
		C.DrawText( s );
	}
	
	C.SetDrawColor( 0, 0, 200 );
	if( bVertical )
	{
		C.SetPos( PosX, MousePosition.Y - MousePosition.Y%gridSnap );
		C.DrawRect( gridSize, 1 );
	}
	else
	{
		C.SetPos( MousePosition.X - MousePosition.X%gridSnap, PosY );
		C.DrawRect( 1, gridSize );
	}
}

protected function RenderPages( Canvas C )
{
	local int i;
	
	for( i = Pages.Length - 1; i >= 0; -- i )
	{
		if( Pages[i].CanRender() )
		{
			Pages[i].Render( C );
		}
	}
}

protected function RenderDebug( Canvas C )
{
	C.SetPos( 0, 0 );
	C.DrawColor = class'HUD'.default.WhiteColor;
	C.DrawColor.A = 100;
	C.Font = class'Engine'.static.GetTinyFont();
	C.DrawText( "Hovering:" $ HoveredComponent, true );
	C.DrawText( "Selected:" $ SelectedComponent, true );
	if( HoveredComponent != none )
	{
		C.DrawText( "Parent:" $ HoveredComponent.Parent, true );
		if( HoveredComponent.Style != none )
		{
			C.DrawText( "Style:" $ HoveredComponent.Style, true );	
		}
	}
	C.DrawText( "Pooled Objects:" @ ObjectsPool.Length );
}

protected function RenderCursor( Canvas C )
{
	local float cursorSizeX, cursorSizeY;
	
	// Fun stuff.
	//if( SelectedComponent != none )
	//{
		//Player().myHUD.Canvas = C;
		//Player().myHUD.Draw2DLine( 
			//SelectedComponent.CalcLeft() + SelectedComponent.CalcWidth()*0.5, 
			//SelectedComponent.CalcTop() + SelectedComponent.CalcHeight()*0.5,
			//MousePosition.X, MousePosition.Y,
			//class'HUD'.default.RedColor
		//);
	//}
	
	C.SetPos( MousePosition.X, MousePosition.Y );
	C.DrawColor = class'HUD'.default.WhiteColor;
	if( HoveredComponent != none && HoveredComponent.bEnableClick )
	{
		cursorSizeX = CursorTouchCoords.UL * CursorScaling;
		cursorSizeY = CursorTouchCoords.VL * CursorScaling;
	
		C.DrawTile( CursorsImage, cursorSizeX, cursorSizeY, 
			CursorTouchCoords.U, CursorTouchCoords.V, CursorTouchCoords.UL, CursorTouchCoords.VL 
		);
	} 
	else
	{
		cursorSizeX = CursorPointCoords.UL * CursorScaling;
		cursorSizeY = CursorPointCoords.VL * CursorScaling;
		
		C.DrawTile( CursorsImage, cursorSizeX, cursorSizeY, 
			CursorPointCoords.U, CursorPointCoords.V, CursorPointCoords.UL, CursorPointCoords.VL 
		);
	}
	
	`if( `isdefined( DEBUG ) )
		if( bDebugModeIsActive )
		{
			C.SetDrawColor( 240, 240, 240, 200 );
			
			C.SetPos( MousePosition.X, MousePosition.Y + cursorSizeY + 8 );	
			C.Font = Font'EngineFonts.TinyFont';
			C.DrawText( "X:" @ MousePosition.X );

			C.SetPos( MousePosition.X + cursorSizeX + 8, MousePosition.Y );	
			C.DrawText( "Y:" @ MousePosition.Y );

			if( HoveredComponent != none )
			{
				C.SetPos( MousePosition.X, MousePosition.Y + cursorSizeY + 8 + 32 );	
				C.DrawText( "CX:" @ HoveredComponent.GetLeft(), true );	
				C.DrawText( "CY:" @ HoveredComponent.GetTop(), true );	
			}
		}
	`endif
}

/*function UpdateSceneRatio()
{
	if( bConsiderAspectRatio ^^ bDebugModeIsActive )
	{
		if( true )	// TODO: Proper detection
		{
			ScreenRatio.X = Size.X / 1280.f;
			ScreenRatio.Y = Size.Y / 720.f;
		}
		else
		{
			ScreenRatio.X = Size.X / 1024.f;
			ScreenRatio.Y = Size.Y / 768.f;
		}
	}
	else
	{
		ScreenRatio.X = 1.0;
		ScreenRatio.Y = 1.0;
	}

	//SetSize( 
		//ScreenSize.X * ScreenRatio.X / ScreenSize.X,
		//ScreenSize.Y * ScreenRatio.Y / ScreenSize.Y
	//);

	//SetPos( 
		//((ScreenSize.X - CalcWidth()) * ScreenRatio.X * 0.5) / ScreenSize.X, 
		//((ScreenSize.Y - CalcHeight()) * ScreenRatio.Y * 0.5) / ScreenSize.Y
	//);
}*/

protected function float CalcHeight()
{
	return ScreenSize.Y * RelativeSize.Y;
}

protected function float CalcWidth()
{
	return ScreenSize.X * RelativeSize.X;
}

protected function float CalcTop()
{
	return CalcHeight() * RelativePosition.Y;
}

protected function float CalcLeft()
{
	return CalcWidth() * RelativePosition.X;
}

final simulated function FPage OpenPage( class<FPage> pageClass )
{
	local FPage page;

	page = new( self ) pageClass;
	Assert( page != none );

	page.SetVisible( true );
	AddPage( page );
	return page;
}

final function AddPage( FPage page )
{
	if( Pages.Find( page ) != INDEX_NONE )
		return;

	`if( `isdefined( DEBUG ) )
		Player().ClientMessage( "AddedPage:" @ page );
	`endif

	page.Initialize( self );

	Pages.InsertItem( 0, page );
	OnPageAdded( page );

	page.Opened();	
}

final function RemovePage( FPage page )
{	
	`if( `isdefined( DEBUG ) )
		Player().ClientMessage( "RemovedPage:" @ page );
	`endif

	page.Closed();

	Pages.RemoveItem( page );
	OnPageRemoved( page );
}

final simulated function ClosePage( optional bool bCloseAll )
{
	if( Pages.Length == 0 )
	{
		return;
	}
	
	if( bCloseAll )
	{
		EmptyPages();
	}
	else
	{
		RemovePage( Pages[0] );
	}
}

final function EmptyPages()
{
	local FPage page;

	foreach Pages( page )
	{
		page.Closed();
		page.Parent = none;
	}
	Pages.Length = 0;
	OnPageRemoved( none );
}

protected function PageAdded( FPage sender )
{
	SetVisible( true );
}

protected function PageRemoved( FPage sender )
{
	if( Pages.Length == 0 )
	{
		SetVisible( false );
	}
}

function bool CanUnpause()
{
	return !bVisible;
}

function OnVisibleChanged( FComponent sender )
{
	if( bVisible )
	{
		Player().PlayerInput.ResetInput();
		if( MenuPostProcessChainIndex == INDEX_NONE && MenuPostProcessChain != none )
		{
			MenuPostProcessChainIndex = LocalPlayer(Player().Player).InsertPostProcessingChain( MenuPostProcessChain, 0, false ) ? 0 : INDEX_NONE;
		}

		if( bPausedWhileVisible )
			Player().SetPause( true, CanUnpause );

		LastPlayerRotation = Player().Rotation;
	}
	else
	{
		if( MenuPostProcessChainIndex != INDEX_NONE )
		{
			LocalPlayer(Player().Player).RemovePostProcessingChain( MenuPostProcessChainIndex );
			MenuPostProcessChainIndex = INDEX_NONE;
		}

		if( bPausedWhileVisible )
			Player().SetPause( false, CanUnpause );
	}
}

function bool KeyInput( name Key, EInputEvent EventType )
{
	local FComponent inputComponent;
	
	LastActivityTime = `STime;
	
	if( SelectedComponent != none && SelectedComponent != self )
	{
		if( EventType == IE_Released )
		{
			switch( Key )
			{
				case 'Spacebar':
				case 'Enter':
					SelectedComponent.OnClick( SelectedComponent );
					break;
			}
		}

		if( SelectedComponent.OnKeyInput != none && SelectedComponent.OnKeyInput( Key, EventType ) )
		{
			return true;
		}
	}

	if( EventType == IE_Pressed )
	{
		switch( Key )
		{
			case 'LeftMouseButton':
				if( HoveredComponent != none )
				{
					HoveredComponent.Active();
					HoveredComponent.OnMouseButtonPressed( HoveredComponent );

					ActiveComponent = HoveredComponent;
				}
				break;

			case 'RightMouseButton':
				if( HoveredComponent != none )
				{
					HoveredComponent.Active();
					HoveredComponent.OnMouseButtonPressed( HoveredComponent, true );

					ActiveComponent = HoveredComponent;
				}
				break;

			case 'LeftControl':
			case 'RightControl':
				bCtrl = true;
				break;

			case 'LeftAlt':
			case 'RightAlt':
				bAlt = true;
				break;

			case 'LeftShift':
			case 'RightShift':
				bShift = true;
				`if( `isdefined( DEBUG ) )
					bDebugModeIsActive = true;
				`endif
				break;
		}
	}
	else if( EventType == IE_Released )
	{
		switch( Key )
		{
			case 'LeftMouseButton':
				if( ActiveComponent != none )
				{
					inputComponent = ActiveComponent;	
					ActiveComponent = none;
				}
				else inputComponent = HoveredComponent;

				if( inputComponent != none )
				{
					if( inputComponent == HoveredComponent )
					{
						`if( `isdefined( DEBUG ) )
							if( bCtrl )
							{
								Player().ConsoleCommand( "editobject name=" $ inputComponent );
								break;
							}
						`endif

						if( `STimeSince( LastClickTime ) <= Player().PlayerInput.DoubleClickTime )
						{
							inputComponent.OnDoubleClick( inputComponent );
						}
						else
						{
							inputComponent.OnClick( inputComponent );
						}
					}
					inputComponent.UnActive();
					inputComponent.OnMouseButtonRelease( inputComponent );
					LastClickTime = `STime;
					LastClickPosition = MousePosition;

					if( !inputComponent.bEnableClick )
					{
						break;
					}
				}
				if( inputComponent == HoveredComponent )
				{
					OnClick( inputComponent );
				}
				break;

			case 'RightMouseButton':
				if( ActiveComponent != none )
				{
					inputComponent = ActiveComponent;	
					ActiveComponent = none;
				}
				else inputComponent = HoveredComponent;

				if( inputComponent == HoveredComponent )
					OnClick( inputComponent, true );

				LastClickPosition = MousePosition;

				if( inputComponent != none )
				{
					inputComponent.UnActive();
					inputComponent.OnMouseButtonRelease( inputComponent, true );
				}
				break;

			case 'MouseScrollUp':
				if( HoveredComponent != none )
				{
					HoveredComponent.BubbleMouseWheelInput( HoveredComponent, true );
				}
				break;

			case 'MouseScrollDown':
				if( HoveredComponent != none )
				{
					HoveredComponent.BubbleMouseWheelInput( HoveredComponent, false );
				}
				break;	
				
			case 'LeftControl':
			case 'RightControl':
				bCtrl = false;
				break;

			case 'LeftAlt':
			case 'RightAlt':
				bAlt = false;
				break;

			case 'LeftShift':
			case 'RightShift':
				bShift = false;
				`if( `isdefined( DEBUG ) )
					bDebugModeIsActive = false;
				`endif
				break;	
		}
	}
	
	//if( ActiveComponent != none && ActiveComponent != self && ActiveComponent != SelectedComponent )
	//{
		//return ActiveComponent.OnKeyInput( Key, EventType );
	//}
	return bSuppressKeyInput;
}

function bool CharInput( string Unicode )
{
	if( SelectedComponent != none && SelectedComponent != self )
	{
		if( SelectedComponent.OnCharInput != none )
		{
			return SelectedComponent.OnCharInput( Unicode );
		}
	}	
	return false;
}

function Click( FComponent sender, optional bool bRight )
{
	SelectedComponent = sender;
	if( SelectedComponent != none )
	{
		PlayClickSound();
		SelectedComponent.Focus();
		if( FWindow(SelectedComponent) != none )
		{
			RemovePage( FWindow(SelectedComponent) );
			AddPage( FWindow(SelectedComponent) );
		}
	}

	if( LastSelectedComponent != none && LastSelectedComponent != SelectedComponent )
	{
		LastSelectedComponent.UnFocus();
	}
	LastSelectedComponent = SelectedComponent;
}

function ComponentFocussed( FComponent sender );
function ComponentUnfocussed( FComponent sender );

function ComponentHovered( FComponent sender )
{
	PlayHoverSound();

	if( sender.ToolTipComponent != none )
	{
		sender.ToolTipComponent.AttachToPosition( MousePosition, ScreenSize );
	}
}

function ComponentUnhovered( FComponent sender )
{
}

protected final function PlayHoverSound()
{
	Player().ClientPlaySound( HoverSound );
}

protected final function PlayClickSound()
{
	Player().ClientPlaySound( ClickSound );
}

function Free()
{
	FreeObjects();

	// Styles were added to the ObjectsPool as well so no need to iterate them.
	Styles.Length = 0;

	// To make sure we remove postprocess and undo pause.
	SetVisible( false );
	Pages.Length = 0;
	MenuPostProcessChain = none;

	CursorsImage = none;
	ClickSound = none;
	HoverSound = none;
	
	ActiveComponent = none;
	HoveredComponent = none;
	SelectedComponent = none;
	LastSelectedComponent = none;
	LastHoveredComponent = none;
	GlobalStyle = none;

	OnPageRemoved = none;
	OnPageAdded = none;
	OnPostRenderPages = none;
	super.Free();
}

/** Adds an object to the pool. All objects in the pool can then be free'd calling Free(). */
final function AddToPool( FObject formObject )
{
	if( ObjectsPool.Find( formObject ) == INDEX_NONE )
	{
		ObjectsPool.AddItem( formObject );
	}
}

final function FreeObject( FObject formObject )
{
	formObject.Free();
	ObjectsPool.RemoveItem( formObject );
}

final function FreeObjects()
{
	local FObject fObj;
	
	`Log( "Free'ing" @ ObjectsPool.Length @ "objects!" );
	foreach ObjectsPool( fObj )
	{
		if( fObj == self )
			continue;

		fObj.Free();
	}
	ObjectsPool.Length = 0;
}

private final function RegisterStyle( FStyle styleObject )
{
	styleObject.Initialize();
	Styles.AddItem( styleObject );

	AddToPool( styleObject );
}

final function FStyle GetStyle( string styleIdentifier, class<FStyle> newStyleClass, optional FStyle inheritedTemplate = GlobalStyle )
{
	local FStyle newStyle;
	local string inheritedStyleClassName;
	local int rightMostHyphenIndex;

	// See if it was created previously.
	foreach Styles( newStyle )
	{
		if( string(newStyle.Name) == styleIdentifier )
		{
			return newStyle;
		}
	}

	// See if this style inherits multiple styles
	// For example: Button-TabButton, inherit = Button
	rightMostHyphenIndex = InStr( styleIdentifier, "-", true );
	if( rightMostHyphenIndex != INDEX_NONE && InStr( styleIdentifier, ":" ) == INDEX_NONE )
	{
		inheritedStyleClassName = Left( styleIdentifier, rightMostHyphenIndex );
		newStyle = GetStyle( inheritedStyleClassName, newStyleClass, inheritedTemplate );
		if( newStyle != none )
		{
			inheritedTemplate = newStyle;
		}
	}

	//`Log( "StyleIdentifier:" @ styleIdentifier @ "StyleInheritance:" @ inheritedStyleClassName );
	
	// Neither of the above was true so create a new style inheriting the global style.
	newStyle = new (none, "(" $ ThemeName $")" $ styleIdentifier) newStyleClass (inheritedTemplate);
	newStyle.Inheritance = inheritedTemplate;
	RegisterStyle( newStyle );
	return newStyle;
}

defaultproperties
{
	RelativePosition=(X=0.0,Y=0.0)
	RelativeSize=(X=1.0,Y=1.0)

	OnKeyInput=KeyInput
	OnCharInput=CharInput
	OnClick=Click
	OnMouseMove=MouseMove
	OnPageAdded=PageAdded
	OnPageRemoved=PageRemoved
	OnHover=ComponentHovered
	OnUnhoverComponentUnhovered
	OnFocus=ComponentFocussed
	OnUnFocus=ComponentUnfocussed

	bVisible=false
	bRenderCursor=true
	bConsiderAspectRatio=false
	bPausedWhileVisible=false
	bWiggleScene=false
	bSuppressKeyInput=true
	bLockRotation=true
	
	bTimeOutCursor=true
	MouseCursorTimeOut=3.0
	bTimeOutScene=true
	MouseSceneTimeOut=15.0

	MenuPostProcessChainIndex=INDEX_NONE
}