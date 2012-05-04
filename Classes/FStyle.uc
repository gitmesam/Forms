/*
   Copyright 2012 Eliot van Uytfanghe

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
/** A style object, where all the styles are configured with element objects. 
	A style object is shared between more than one FComponent! */
class FStyle extends FObject
	perobjectconfig
	config(Forms);

/** The texture to be used as the component's background/image (If supported) */
var(Style, Display) editinline Texture2D Image;
var config const string ImageName;

/** The material to be used as the component's image (If supported) */
var(Style, Display) editinline Material Material;
var config const string MaterialName;

var(Style, Colors) const Color ImageColor;
var(Style, Colors) const Color HoverColor;
var(Style, Colors) const Color FocusColor;
var(Style, Colors) const Color ActiveColor;
var(Style, Colors) const Color DisabledColor;

/** Collection of elements to render after the associated component(s). */
var protectedwrite editinline array<FElement> Elements;

function Initialize()
{
	if( ImageName != "" )
	{
		Image = Texture2D(DynamicLoadObject( ImageName, class'Texture2D', true ));
	}

	if( MaterialName != "" )
	{
		Material = Material(DynamicLoadObject( MaterialName, class'Material', true ));
	}

	InitializeElements();
	
	`if( `isdefined( DEBUG ) )
		SaveConfig();
	`endif
}

function InitializeElements()
{
	local int i;

	for( i = 0; i < Elements.Length; ++ i )
	{
		Elements[i].Initialize();
	}
}

function Render( Canvas C );

function RenderElements( Canvas C, FComponent Object )
{
	local int i;

	for( i = 0; i < Elements.Length; ++ i )
	{
		Elements[i].RenderElement( C, Object );
	}
}

function Free()
{
	Elements.Length = 0;
}

defaultproperties
{
	ImageColor=(R=255,G=255,B=255,A=255)
	HoverColor=(R=255,G=255,B=0,A=255)
	FocusColor=(R=100,G=100,B=100,A=255)
	ActiveColor=(R=200,G=200,B=200,A=255)
	DisabledColor=(R=0,G=0,B=0,A=255)
}