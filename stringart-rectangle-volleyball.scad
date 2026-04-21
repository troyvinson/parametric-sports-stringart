// Standard Digital File License
//
//Copyright (c) 2026 Troy Vinson
//
//This content is licensed under a Standard Digital File License.
//
//You shall not share, sub-license, sell, rent, host, transfer, or distribute in any way the digital or 3D printed versions of this object, nor any other derivative work of this object in its digital or physical format (including - but not limited to - remixes of this object, and hosting on other digital platforms). The objects may not be used without permission in any way whatsoever in which you charge money, or collect fees.

/* [Volleyball Frame Settings] */
// 1. The total width of the frame (X-axis).
frame_width = 160; // min:100
// 2. The total height of the frame (Y-axis).
frame_height = 160; // min:100
// 3. The thickness of the model from the build plate up (Z-axis).
frame_depth = 30;
// 4. The thickness of the outer frame wall itself.
frame_thickness = 10;
// 5. Controls 2D corner rounding for the X/Y plane.
outer_corner_radius = 5; // [0:1:30]
// 6. Controls interior corner rounding.
inner_corner_radius = 5; // [0:1:30]
// 7. Color of the outer frame
frame_color = "#0055FF"; // color

/* [Center Object] */
// 1. Adjust scale to fit inside the frame.
object_scale_percent = 100; // [1:1:500]
// 2. Fine-tune positioning on the X-axis.
object_offset_x = 0; // [-50:0.5:50]
// 3. Fine-tune positioning on the Y-axis.
object_offset_y = 0; // [-50:0.5:50]

// --- Panel Colors ---
// 4. Face 1 (Top/Bottom) - Outer Strips
f1_outer_color = "#FFFFFF"; // White
// 5. Face 1 (Top/Bottom) - Inner Strip
f1_inner_color = "#FFD700"; // Yellow

// 6. Face 2 (Left/Right) - Outer Strips
f2_outer_color = "#0055FF"; // Blue
// 7. Face 2 (Left/Right) - Inner Strip
f2_inner_color = "#FFFFFF"; // White

// 8. Face 3 (Front/Back) - Outer Strips
f3_outer_color = "#FFD700"; // Yellow
// 9. Face 3 (Front/Back) - Inner Strip
f3_inner_color = "#0055FF"; // Blue

// 10. Color of the flat back (print bed side)
base_color = "#FFFFFF"; // color
// 11. Z-thickness of the base color
base_thickness = 0.6; // [0:0.1:5]

/* [String (Ray) Settings] */
// 1. Number of strings wrapping around one full revolution.
strings_per_row = 24;
// 2. Number of vertical layers of strings.
string_rows = 4;
// 3. Z-axis margin to keep strings away from the top frame face.
string_margin_top = 20; // [0:0.5:10]
// 4. Z-axis margin to keep strings away from the bottom frame face.
string_margin_bottom = 4; // [0:0.5:10]
// 5. Shifts the convergence point of all strings up or down.
convergence_y_offset = 0;
// 6. Offset the angle of every other row for a woven look.
alternate_rotation = true; // [true:false]
// 7. Color of the strings/rays
string_color = "#FFFFFF"; // color

/* [Hidden] */
$fn = 120;
string_embed_percent = 50;
string_clearance = 0.1;
string_width = 0.61; 
string_height = 0.41;

/* Center Void */
void_shape = "Ellipse"; // [None, Ellipse, Rectangle, Hexagon, Heart]
void_width = 20; // [1:0.5:200]
void_height = 20; // [1:0.5:200]

// --- Execution ---
union() {
    color(frame_color) base_frame();
    center_shape();
    color(string_color) rays();
}

// --- Modules ---

module raw_outer_profile() {
    square([frame_width, frame_height], center=true);
}

module outer_profile() {
    safe_r = min(outer_corner_radius, frame_width/2.1, frame_height/2.1);
    if (safe_r > 0) {
        offset(r=safe_r) offset(r=-safe_r) raw_outer_profile();
    } else {
        raw_outer_profile();
    } 
}

module inner_profile() {
    module raw_inner_profile() {
        offset(delta=-frame_thickness) raw_outer_profile();
    }
    safe_r = min(inner_corner_radius, (frame_width-frame_thickness)/2.1, (frame_height-frame_thickness)/2.1);
    if (safe_r > 0) {
        offset(r=safe_r) offset(r=-safe_r) raw_inner_profile();
    } else {
        raw_inner_profile();
    } 
}

module raw_string_pattern(w, h) {
    ray_length = max(frame_width, frame_height) * 2;
    z_max = (frame_depth / 2) - string_margin_top - (string_height / 2);
    z_min = -(frame_depth / 2) + string_margin_bottom + (string_height / 2);
    z_usable = z_max - z_min;
    z_start = (string_rows == 1) ? (z_max + z_min) / 2 : z_min;
    z_step = (string_rows > 1) ? z_usable / (string_rows - 1) : 0;
    
    union() {
        for (r = [0 : string_rows - 1]) {
            z_pos = z_start + r * z_step;
            rot_offset = (alternate_rotation && r % 2 != 0) ? (360/strings_per_row)/2 : 0;
            translate([0, convergence_y_offset, z_pos]) {
                for (s = [0 : strings_per_row - 1]) {
                    rotate([0, 0, s * (360/strings_per_row) + rot_offset])
                        translate([ray_length/2, 0, 0])
                            cube([ray_length, w, h], center=true);
                } 
            }
        }
    }
}

module string_boundary(l_clearance = 0) {
    linear_extrude(height=frame_depth + 2, center=true)
        offset(delta=(-frame_thickness * (1 - (string_embed_percent/100))) + l_clearance) outer_profile();
}

module string_void(l_clearance = 0) {
    translate([0, convergence_y_offset, 0])
        linear_extrude(height=frame_depth * 3, center=true) {
            offset(delta=-l_clearance) {
                if (void_shape == "Ellipse") {
                    scale([void_width/void_height, 1]) circle(d=void_height);
                } else if (void_shape == "Rectangle") {
                    square([void_width, void_height], center=true);
                } else if (void_shape == "Hexagon") {
                    circle(d=void_width, $fn=6);
                }
            }
        }
}

module bounded_string_pattern(w, h, l_clearance = 0) {
    difference() {
        intersection() {
            string_boundary(l_clearance);
            raw_string_pattern(w, h);
        }
        if (void_shape != "None") {
            string_void(l_clearance);
        }
    }
}

module base_frame() {
    difference() {
        linear_extrude(height=frame_depth, center=true) {
            difference() {
                outer_profile();
                inner_profile();
            } 
        }
        if (string_clearance > 0) {
            bounded_string_pattern(
                string_width + (string_clearance * 2), 
                string_height + (string_clearance * 2), 
                string_clearance
            );
        }
    }
}

module center_shape() {
    center_shape_solid();
}

module rays() {
    bounded_string_pattern(string_width, string_height);
}

module volleyball_dome(radius, b_thick=0.6, b_color="#FFFFFF") {
    
    w = radius * 0.268; 
    seam_width = radius * 0.025; 

    module ring(ring_radius) {
        rotate_extrude($fn=120) translate([ring_radius, 0, 0]) circle(d=seam_width, $fn=16);
    }

    module local_major_seam_cutter() {
        rotate([45, 0, 0]) ring(radius);
        rotate([-45, 0, 0]) ring(radius);
        rotate([0, 45, 0]) ring(radius);
        rotate([0, -45, 0]) ring(radius);
    }

    module minor_seam_cutter() {
        minor_r = sqrt(radius*radius - w*w);
        translate([0, w, 0]) rotate([90, 0, 0]) ring(minor_r);
        translate([0, -w, 0]) rotate([90, 0, 0]) ring(minor_r);
    }

    module mask_face() {
        hull() {
            cube(0.01, center=true);
            translate([0, 0, radius*2]) cube([radius*4, radius*4, 0.01], center=true);
        }
    }

    module mask_strip_center() {
        cube([radius*3, w*2, radius*3], center=true);
    }

    // Includes an override argument to force the entire face block to render in one color
    module face_panels(outer_color, inner_color, override="") {
        c_inner = override == "" ? inner_color : override;
        c_outer = override == "" ? outer_color : override;
        
        module carved_face() {
            intersection() {
                difference() {
                    sphere(r=radius, $fn=120);
                    local_major_seam_cutter();
                    minor_seam_cutter(); 
                }
                mask_face();
            }
        }
        
        color(c_inner) {
            intersection() {
                carved_face();
                mask_strip_center();
            }
        }
        color(c_outer) {
            difference() {
                carved_face();
                mask_strip_center();
            }
        }
    }

    orient_x = 35;
    orient_y = 25;
    orient_z = 15;
    
    module string_cut() {
        if (string_clearance > 0) {
            scale_factor = (object_scale_percent / 100);
            scale([1/scale_factor, 1/scale_factor, 1/scale_factor])
                translate([-object_offset_x, -object_offset_y, frame_depth/2])
                    bounded_string_pattern(
                        string_width + (string_clearance * 2), 
                        string_height + (string_clearance * 2), 
                        string_clearance
                    );
        }
    }

    module oriented_volleyball(override="") {
        rotate([orient_x, orient_y, orient_z]) {
            union() {
                face_panels(f1_outer_color, f1_inner_color, override); 
                rotate([180, 0, 0]) face_panels(f1_outer_color, f1_inner_color, override); 

                rotate([0, 90, 90]) face_panels(f2_outer_color, f2_inner_color, override); 
                rotate([0, -90, 90]) face_panels(f2_outer_color, f2_inner_color, override); 

                rotate([-90, 0, 90]) face_panels(f3_outer_color, f3_inner_color, override); 
                rotate([90, 0, 90]) face_panels(f3_outer_color, f3_inner_color, override); 
            }
        }
    }

    module colored_dome_half() {
        difference() {
            oriented_volleyball();
            translate([0, 0, -radius]) 
                cube([radius*3, radius*3, radius*2], center=true);
            string_cut();
        }
    }

    module white_dome_half() {
        difference() {
            oriented_volleyball(override=b_color);
            translate([0, 0, -radius]) 
                cube([radius*3, radius*3, radius*2], center=true);
            string_cut();
        }
    }

    // Slices the dome and explicitly colors the bottom layer block
    if (b_thick > 0) {
        difference() {
            colored_dome_half();
            translate([0, 0, b_thick/2 - 0.05]) 
                cube([radius*3, radius*3, b_thick + 0.1], center=true);
        }
        intersection() {
            white_dome_half();
            translate([0, 0, b_thick/2]) 
                cube([radius*3, radius*3, b_thick], center=true);
        }
    } else {
        colored_dome_half();
    }
}

module center_shape_solid() {
    scale_factor = (object_scale_percent / 100);
    // Inverse division ensures the bottom thickness remains true to the raw millimeter 
    // setting even if the user drastically shrinks or expands the ball's overall scale.
    true_base_thickness = base_thickness / scale_factor;
    
    translate([object_offset_x, object_offset_y, -frame_depth/2]) {
        scale([scale_factor, scale_factor, scale_factor])
            volleyball_dome(55, true_base_thickness, base_color);
    }
}