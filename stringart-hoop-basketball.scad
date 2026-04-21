/* [Basketball Frame Settings] */
// 1. The total width of the round frame.
frame_width = 160; // min:100
// 2. The thickness of the model from the build plate up (Z-axis).
frame_depth = 30; 
// 3. The thickness of the outer frame wall itself.
frame_thickness = 10;
// 4. Controls 2D corner rounding for the X/Y plane (softens the flat bottom corners).
outer_corner_radius = 5; // [0:1:30]
// 5. Controls interior corner rounding.
inner_corner_radius = 5; // [0:1:30]
// 6. Color of the outer frame
frame_color = "#ff6a13"; // color

/* [Center Object] */
// 1. Adjust scale to fit inside the frame.
object_scale_percent = 100; // [1:1:500]
// 2. Fine-tune positioning on the X-axis.
object_offset_x = 0; // [-50:0.5:50]
// 3. Fine-tune positioning on the Y-axis.
object_offset_y = 0; // [-50:0.5:50]
// 4. Color of the basketball
object_color = "#ff6a13"; // color
// 5. Color of the grooves/seams
seam_color = "#000000"; // color

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
string_color = "#000000"; // color

/* [Hidden] */
$fn = 120;
string_embed_percent = 50;
string_clearance = 0.1;
string_width = 0.61; 
string_height = 0.41;

/* Center Void */
// 1. Removes the chaotic center convergence point.
void_shape = "Ellipse"; // [None, Ellipse, Rectangle, Hexagon, Heart]
// 2. Width of the center string cut.
void_width = 20; // [1:0.5:200]
// 3. Height of the center string cut.
void_height = 20; // [1:0.5:200]


// Mathematically derive flat bottom boundary 
// Lowered the cut line to 90% (from 75%) to make the flat footprint narrower while retaining stability.
flat_bottom_y = -(frame_width / 2) * 0.90; 
frame_height = (frame_width / 2) - flat_bottom_y;

// --- Execution ---
union() {
    color(frame_color) base_frame();
    center_shape();
    color(string_color) rays();
}

// --- Modules ---

module raw_outer_profile() {
    w = frame_width;
    intersection() {
        circle(d=w);
        translate([0, (w * 1.5)/2 + flat_bottom_y])
            square([w * 1.5, w * 1.5], center=true);
    }
}

module outer_profile() {
    safe_r = min(outer_corner_radius, frame_width/2.1);
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
    safe_r = min(inner_corner_radius, (frame_width-frame_thickness)/2.1);
    if (safe_r > 0) {
        offset(r=safe_r) offset(r=-safe_r) raw_inner_profile();
    } else {
        raw_inner_profile();
    } 
}

module raw_string_pattern(w, h) {
    ray_length = frame_width * 2;
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

module basketball_dome(radius, seam_width=1.5) {
    
    // Generates the true 8-panel basketball seams with continuous topological loops
    module seams_geom(w) {
        // 1. Equator
        rotate_extrude($fn=120) translate([radius, 0, 0]) circle(r=w, $fn=16);
        
        // 2. Vertical Meridian
        rotate([0, 90, 0]) rotate_extrude($fn=120) translate([radius, 0, 0]) circle(r=w, $fn=16);

        // 3. Side Swoops (Continuous spherical loops)
        step = 3;
        for (dir = [1, -1]) {
            for (alpha = [0 : step : 359]) {
                // b dynamically shifts the angle away from the X-axis
                // Creates a loop that is wide at the equator and narrow near the poles
                b1 = 60 - 18 * cos(2 * alpha);
                b2 = 60 - 18 * cos(2 * (alpha + step));
                
                // Map the spherical geometry into Cartesian space
                x1 = dir * radius * cos(b1);
                y1 = radius * sin(b1) * cos(alpha);
                z1 = radius * sin(b1) * sin(alpha);
                
                x2 = dir * radius * cos(b2);
                y2 = radius * sin(b2) * cos(alpha + step);
                z2 = radius * sin(b2) * sin(alpha + step);
                
                hull() {
                    translate([x1, y1, z1]) sphere(r=w, $fn=10);
                    translate([x2, y2, z2]) sphere(r=w, $fn=10);
                }
            }
        }
    }

    // Apply a tilt to present the iconic swoops dynamically in the frame
    orient_x = 35;
    orient_y = 25;
    orient_z = 55;
    
    // Inverse transform to pull global string geometry into this local space
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

    // The orange leather geometry
    color(object_color) {
        difference() {
            sphere(r=radius, $fn=120);
            
            rotate([orient_x, orient_y, orient_z]) seams_geom(seam_width + 0.1);
            
            translate([0, 0, -radius]) 
                cube([radius*3, radius*3, radius*2], center=true);
                
            string_cut();
        }
    }
    
    // The raised/colored black seams filling the negative space
    color(seam_color) {
        difference() {
            intersection() {
                sphere(r=radius, $fn=120); 
                rotate([orient_x, orient_y, orient_z]) seams_geom(seam_width);
            }
            translate([0, 0, -radius]) 
                cube([radius*3, radius*3, radius*2], center=true);
                
            string_cut();
        }
    }
}

module center_shape_solid() {
    scale_factor = (object_scale_percent / 100);
    translate([object_offset_x, object_offset_y, -frame_depth/2]) {
        scale([scale_factor, scale_factor, scale_factor])
            basketball_dome(50);
    }
}