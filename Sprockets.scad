/*	Sprockets v1.1

	Sprocket construction module by Shawn Steele (c) 2013
	License on Sprockets.scad is MS-PL http://opensource.org/licenses/ms-pl

	Modified by Dallen Wilson (c) 2019 to add auto-generation of keyway slot and setscrew holes.
	Uses threads.scad from https://dkprojects.net/openscad-threads/
	License on threads.scad is GPL-3

	Shawn Steele created Sprockets.scad to make sprockets for L3-G0 model, http://L3-G0.blogspot.com,
	Please attribute above if redistributing/modifying.

	http://www.gizmology.net/sprockets.htm has some geometry on sprockets.

	Version history:
	v1.1 (2019-12-09): Added keyway and setscrew hole generation
	v1.0 (2013-12-06): Original file by Shawn Steele, sourced from https://www.thingiverse.com/thing:197896/

	Usage:

	use <sprockets.scad>
	sprocket (size, teeth, bore, hub_diameter, hub_height, keyway, setscrew);

	size:						ANSI Roller Chain Standard Sizes, default 25, or motorcycle sizes,
								or 1 for bike w/derailleur or 2 for bike w/o derailleur
	teeth:					Number of teeth on the sprocket, default 9
	bore:					Bore diameter, inches (Chain sizes seem to favor inches), default 5/16
	hub_diameter:		Hub diameter, inches, default 0
	hub_height:			Hub height TOTAL, default 0.
	keyway:				1 to generate a hole for a key, default 0.
								Keyway size automatically calculated using data from tables available at:
								http://linngear.com/wp-content/uploads/2013/06/Std-Bore-Kwy-and-SS-size-info.pdf
	setscrew:				1 to generate a hole for a setscrew, default 0.
								Setscrew size automatically calculated using data from tables available at:
								https://www.rollerchain4less.com/sprocket-tolerances-and-standards
								Note: Will echo warnings if hub height/diameter are not large enough to fit a set screw.

	TODO: Add sanity checks for hub size / bore size / pitch / teeth based on charts at:
	http://taylormhc.com/wp-content/uploads/2016/11/Sprocket-Engineering-Data.pdf

	You may also need to tweak some of the fudge factors, depending on your printer, etc.  See the constants below.

	Example usage in your own .scad file:
	use <sprockets.scad>
	$fn = 180;
	sprocket(40, 10, 1.125, 0, 0, 0, 0);
*/

use <threads.scad>

// Adjust these if it's too tight/loose on your printer,
// These seem to be OK on my Replicator 1
FUDGE_BORE = 0;						// mm to fudge the edges of the bore
FUDGE_ROLLER = 0;					// mm to fudge the hole for the rollers
FUDGE_TEETH = 1;						// Additional rounding of the teeth (0 is theoretical,
														// my rep 1 seems to need 1 on medium.)

SETSCREW_MIN_TEETH = 3;		// Minimum threads wanted in setscrew hole

ECHO_WARNINGS = 1;					// Echos warnings to console, eg hub not big enough for set screw
ECHO_DEBUG = 0;						// Echos debug information to console, eg various calculated measurements

function inches2mm(inches) = inches * 25.4;
function mm2inches(mm) = mm / 25.4;

module sprocket(size=25, teeth=9, bore=5/16, hub_diameter=0, hub_height=0, keyway=0, setscrew=0)
{
	bore_radius_mm = inches2mm(bore)/2;
	hub_radius_mm = inches2mm(hub_diameter)/2;
	hub_height_mm = inches2mm(hub_height);

    sprocket_thickness = get_thickness(size);
    hub_thickness = ((hub_diameter - bore) / 2);
    hub_usable = (hub_height - sprocket_thickness);

    kw_width = get_keyway_width (bore);
    kw_depth = get_keyway_depth (kw_width);

    ss_width = get_setscrew_width (bore);
    ss_length = hub_thickness + mm2inches (2);
    ss_pitch = get_setscrew_pitch (ss_width);

	if (( setscrew > 0 ) && ( ECHO_WARNINGS > 0 ))
	{
		if ( ss_width > hub_usable )
		{
			echo ("Hub not tall enough to fit a setscrew!");
			echo ("Min hub height:", sprocket_thickness + mm2inches(4) + ss_width);
			echo ("Cur hub height:", hub_height);
		}

		// TODO: Check hub thickness to ensure enough threads to be useful
		if ( (ss_pitch * hub_thickness)  < SETSCREW_MIN_TEETH)
		{
			echo ("Hub not thick to allow enough setscrew threads!");
			echo ("Min hub diameter:", ((SETSCREW_MIN_TEETH / ss_pitch) * 2) + bore);
			echo ("Cur hub diameter:", hub_diameter);

			if ( ECHO_DEBUG > 0 )
			{
				echo ("Minimum setscrew threads-in-hub:", SETSCREW_MIN_TEETH);
				echo ("Current threads-in-hub:", (ss_pitch * hub_thickness));
			}
		}
	}

	difference()
	{
		union()
		{
			sprocket_plate(size, teeth);
			if (hub_diameter != 0 && hub_height != 0)
				cylinder(h=hub_height_mm, r=hub_radius_mm);
		}

		// Make sure the bore goes through everything
		if (bore != 0)
		{
			translate([0,0,-1])
			cylinder(h=2+hub_height_mm+inches2mm(sprocket_thickness), r=bore_radius_mm+FUDGE_BORE);

			if (keyway != 0)
			{
				translate([-bore_radius_mm, 0, 0])
				cube([inches2mm(kw_depth), inches2mm(kw_width),(inches2mm(get_thickness(size))+hub_height_mm)*3],true);
			}

			if (setscrew != 0)
			{
				if (( keyway > 0 ) && ( ECHO_WARNINGS > 0 ))
				{
					keywall_thickness = hub_thickness - kw_depth;

					if ( (ss_pitch * keywall_thickness)  < SETSCREW_MIN_TEETH)
					{
						echo ("Hub not thick to allow enough setscrew threads in keyway!");
						echo ("Min hub diameter:", (((SETSCREW_MIN_TEETH / ss_pitch) + kw_depth ) * 2) + bore);
						echo ("Cur hub diameter:", hub_diameter);

						if ( ECHO_DEBUG > 0 )
						{
							echo ("Min setscrew threads-in-hub:", SETSCREW_MIN_TEETH);
							echo ("Cur threads-in-hub:", (ss_pitch * keywall_thickness));
							echo ("Cur hub thickness:", hub_thickness);
							echo ("Cur keyway thickness:", keywall_thickness);
							echo ("Min keyway thickness:", SETSCREW_MIN_TEETH / ss_pitch);
						}
		}

				}
				// Keyway setscrew
				rotate ([0, 90, 0])
				translate ([-inches2mm(sprocket_thickness+((hub_usable)/2)), 0, -(bore_radius_mm+inches2mm(ss_length)-1)])
				english_thread (ss_width, ss_pitch, ss_length, true);

				// 90-offset from keyway
				rotate ([90, 0, 0])
				translate ([0, inches2mm(sprocket_thickness+((hub_usable)/2)), bore_radius_mm-1])
				render () english_thread (ss_width, ss_pitch, ss_length, true);
			}
		}
	}

	if ( ECHO_DEBUG > 0 )
	{
		echo ("Chain size:", size);
		echo ("Bore size:", bore);
		if (keyway != 0)
		{
			echo ("Key width:", kw_width);
			echo ("Key depth:", kw_depth);
		}

		if (setscrew != 0)
		{
			echo ("ss_width:", ss_width);
			echo ("ss_length:", ss_length);
			echo ("ss_pitch:", ss_pitch);
		}
	}
}

module sprocket_plate(size, teeth)
{
	angle = 360/teeth;
	pitch=inches2mm(get_pitch(size));
	roller=inches2mm(get_roller_diameter(size)/2);
	thickness=inches2mm(get_thickness(size));
	outside_radius = inches2mm(get_pitch(size)*(0.6+1/tan(180/teeth))) / 2;
	pitch_radius = inches2mm(get_pitch(size)/sin(180/teeth)) / 2;

	if ( ECHO_DEBUG > 0 )
	{
		echo("Pitch=", mm2inches(pitch));
		echo("Pitch mm=", pitch);
		echo("Roller=", mm2inches(roller));
		echo("Roller mm=", roller);
		echo("Thickness=", mm2inches(thickness));
		echo("Thickness mm=", thickness);

		echo("Outside diameter=", mm2inches(outside_radius * 2));
		echo("Outside diameter mm=", outside_radius * 2);
		echo("Pitch Diameter=", mm2inches(pitch_radius * 2));
		echo("Pitch Diameter mm=", pitch_radius * 2);
	}

	middle_radius = sqrt(pow(pitch_radius,2) - pow(pitch/2,2));

	// rotating the fudge is going to put curves in a funny place
	fudge_teeth_x = FUDGE_TEETH * cos(angle/2);
	fudge_teeth_y = FUDGE_TEETH * sin(angle/2);

	difference()
	{
		union()
		{
			// Main plate
			//cylinder(r=pitch_radius-roller+.1, h=thickness);

			intersection()
			{
				// Trim outer points
				translate([0,0,-1])
				//cylinder(r=outside_radius,h=thickness+2);	//logic for shorter teeth
				cylinder(r=pitch_radius-roller+pitch/2, h=thickness+2);

				// Main section
				union()
				{
					// Build the teeth
					for (sprocket=[0:teeth-1])
					{
						// Rotate current sprocket by angle
						rotate([0,0,angle*sprocket])
						intersection()
						{
							translate([-fudge_teeth_x,pitch_radius-fudge_teeth_y,0])
							cylinder(r=pitch-roller-FUDGE_ROLLER-FUDGE_TEETH,h=thickness);

							rotate([0,0,angle])
							translate([fudge_teeth_x,pitch_radius-fudge_teeth_y,0])
							cylinder(r=pitch-roller-FUDGE_ROLLER-FUDGE_TEETH,h=thickness);
						}
					}

					// Make sure to fill the gap in the bottom
					for (sprocket=[0:teeth-1])
					{
						rotate([0,0,angle*sprocket-angle/2])
						translate([-pitch/2,-.01,0])
						cube([pitch,middle_radius+.01,thickness]);
					}
				}
			}
		}

		// Remove holes for the rollers
		for (sprocket=[0:teeth-1])
		{
			rotate([0,0,angle*sprocket])
			translate([0,pitch_radius,-1])
			cylinder(r=roller+FUDGE_ROLLER,h=thickness+2);

			// I used this for debugging the geometry, it draws guide lines
			//rotate([0,0,angle*sprocket])
			//draw_guides(roller, thickness, pitch, height);
		}
	}

	// guide line for pitch radius
	//cylinder(h=.1,r=outside_radius);
	//cylinder(h=.2,r=pitch_radius);
}

/*
// I used this for debugging the geometry, it draws guide lines
module draw_guides(roller, thickness, pitch, height)
{
	translate([0,-.05,0])
	cube([50,0.1,1]);
	translate([0,pitch-.05,0])
	cube([50,0.1,1]);
	translate([0,-pitch-.05,0])
	cube([50,0.1,1]);
}*/

function get_pitch(size) =
	// ANSI
	size == 25 ? 1/4 :
	size == 35 ? 3/8 :
	size == 40 ? 1/2 :
	size == 41 ? 1/2 :
	size == 50 ? 5/8 :
	size == 60 ? 3/4 :
	size == 80 ? 1 :
	// Bike
	size == 1 ? 1/2 :
	size == 2 ? 1/2 :
	// Motorcycle
	size == 420 ? 1/2 :
	size == 425 ? 1/2 :
	size == 428 ? 1/2 :
	size == 520 ? 5/8 :
	size == 525 ? 5/8 :
	size == 530 ? 5/8 :
	size == 630 ? 3/4 :
	// unknown
	0;

function get_roller_diameter(size) =
	// ANSI
	size == 25 ? .130 :
	size == 35 ? .200 :
	size == 40 ? 5/16 :
	size == 41 ? .306 :
	size == 50 ? .400 :
	size == 60 ? 15/32 :
	size == 80 ? 5/8 :
	// Bike
	size == 1 ? 5/16 :
	size == 2 ? 5/16 :
	// Motorcycle
	size == 420 ? 5/16 :
	size == 425 ? 5/16 :
	size == 428 ? .335 :
	size == 520 ? .400 :
	size == 525 ? .400 :
	size == 530 ? .400 :
	size == 630 ? 15/32 :
	// unknown
	0;

// I think there's a formula for this, but by the
// time I realized that I already had the table...
function get_thickness(size) =
	// ANSI
	size == 25 ? .110 :
	size == 35 ? .168 :
	size == 40 ? .284 :
	size == 41 ? .227 :
	size == 50 ? .343 :
	size == 60 ? .459 :
	size == 80 ? .575 :
	// Bike
	size == 1 ? .110 :
	size == 2 ? .084 :
	// Motorcycle
	size == 420 ? .227 :
	size == 425 ? .284 :
	size == 428 ? .284 :
	size == 520 ? .227 :
	size == 525 ? .284 :
	size == 530 ? .343 :
	size == 630 ? .343 :
	// unknown
	0;

// get_keyway_width, get_keyway_depth based on chart at:
// http://linngear.com/wp-content/uploads/2013/06/Std-Bore-Kwy-and-SS-size-info.pdf
// get_setscrew_width, get_setscrew_pitch based on chart at:
// https://www.rollerchain4less.com/sprocket-tolerances-and-standards

// Returns keyway width in inches based on bore/shaft diameter
function get_keyway_width (bore) =
    bore <= 0.375 ? 0:			// 3/8 and below			: No keyway
    bore <= 0.5625 ? 0.125:	// 9/16 and below			: 1/8
    bore <= 0.875 ? 0.1875:	// 7/8 and below			: 3/16
    bore <= 1.25 ? 0.250:		// 1-1/4 and below		: 1/4
    bore <= 1.375 ? 0.3125:	// 1-3/8 and below		: 5/16
    bore <= 1.75 ? 0.375:		// 1-3/4 and below		: 3/8
    bore <= 2.25 ? 0.5:			// 2-1/4 and below		: 1/2
    bore <= 2.75 ? 0.625:		// 2-3/4 and below		: 5/8
    bore <= 3.25 ? 0.75:		// 3-1/4 and below		: 3/4
    bore <= 3.75 ? 0.875:		// 3-3/4 and below		: 7/8
    bore <= 4.5 ? 1:				// 4-1/2 and below		: 1
    bore <= 5.5 ? 1.25:			// 5-1/2 and below		: 1-1/4
    bore <= 6.5 ? 1.5:			// 6-1/2 and below		: 1-1/2
    bore <= 7.5 ? 1.75:			// 7-1/2 and below		: 1-3/4
    bore <= 8.9375 ? 2:			// 8-15/16 and below	: 2
    bore <= 10.9375 ? 2.5:	// 10-15/16 and below	: 2 1/2
    0;

// Returns keyway depth based on keyway width
function get_keyway_depth (width) = width / 2;

// Returns width of setscrew based on bore/shaft diameter
function get_setscrew_width (bore) =
	bore <= 0.375 ? 0.0:			// 3/8 and below		: No setscrew
	bore <= 0.5625 ? 0.1875:	// 9/16 and below		: 10-24
	bore <= 0.875 ? 0.25:			// 7/8 and below		: 1/4-10
	bore <= 1.25 ? 0.3125:		// 1-1/4 and below	: 5/16-18
	bore <= 1.75 ? 0.375:			// 1-3/8 and below	: 3/8-16
	bore <= 2.75 ? 0.5:				// 2-3/4 and below	: 1/2-13
	bore <= 3.25 ? 0.625:			// 3-1/4 and below	: 5/8-11
	0;

// Returns threads-per-inch based on setscrew width
function get_setscrew_pitch (ss_width) =
	ss_width <= 0.1875 ? 24:
	ss_width <= 0.25 ? 10:
	ss_width <= 0.3125 ? 18:
	ss_width <= 0.375 ? 16:
	ss_width <= 0.5 ? 13:
	ss_width <= 0.625 ? 11:
	0;