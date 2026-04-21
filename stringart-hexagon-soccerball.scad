/* [Hexagon Frame Settings] */
// 1. The total point-to-point width of the outer frame.
frame_width = 180; // min:100
// 2. The thickness of the model from the build plate up (Z-axis).
frame_depth = 30; // 
// 3. The thickness of the outer frame wall itself.
frame_thickness = 10;
// 4. Controls 2D corner rounding for the X/Y plane.
outer_corner_radius = 5; // [0:1:30]
// 5. Controls interior corner rounding.
inner_corner_radius = 5; // [0:1:30]
// 6. Color of the outer frame
frame_color = "#000000"; // color

/* [Center Object] */
// 1. Adjust scale to fit inside the frame (preserves aspect ratio).
object_scale_percent = 100; // [1:1:500]
// 2. Fine-tune positioning if the auto-center needs a slight nudge on the X-axis.
object_offset_x = 0; // [-50:0.5:50]
// 3. Fine-tune positioning if the auto-center needs a slight nudge on the Y-axis.
object_offset_y = 0; // [-50:0.5:50]
// 4. Color of the main ball hexagons
object_color = "#FFFFFF"; // color
// 5. Color of the soccer ball pentagons
pentagon_color = "#000000"; // color

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
// High resolution for smooth curves.
$fn = 120; 
// Variables locked from user adjustment.
string_embed_percent = 50; 
string_clearance = 0.1; 
string_width = 0.61; 
string_height = 0.41;

/* Center Void */
void_shape = "Ellipse";
void_width = 20;
void_height = 20;

// Mathematically derive the flat-to-flat height based on the point-to-point width
frame_height = frame_width * sin(60);

// --- Execution ---
union() {
    color(frame_color) base_frame();
    center_shape();
    color(string_color) rays();
} 

// --- Modules ---

module raw_outer_profile() {
    // OpenSCAD's default 6-sided circle is pointy on the X-axis and sits flat on the Y-axis.
    circle(d=frame_width, $fn=6);
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

module center_shape_solid() {
    scale_factor = (object_scale_percent / 100);

    translate([object_offset_x, object_offset_y, -frame_depth/2]) {
        // Removed the color() wrapper from here so the child module handles it
        scale([scale_factor, scale_factor, scale_factor])
            soccer_ball_dome(50);
    }
}

module raw_string_pattern(w, h) {
    ray_length = max(frame_width, frame_height) * 1.5;
    
    // Calculate exact min and max Z coordinates based on independent top/bottom margins
    z_max = (frame_depth / 2) - string_margin_top - (string_height / 2);
    z_min = -(frame_depth / 2) + string_margin_bottom + (string_height / 2);
    z_usable = z_max - z_min;
    
    // Determine start point and step distance
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

module heart2d(w, h) {
    S = 100;
    y_max = (S * sqrt(2) / 4) + (S / 2);
    y_min = -S * sqrt(2) / 2;
    y_center = (y_max + y_min) / 2;
    
    resize([w, h])
    translate([0, -y_center])
    union() {
        rotate([0, 0, 45]) square(S, center=true);
        translate([-S*sqrt(2)/4, S*sqrt(2)/4]) circle(d=S);
        translate([ S*sqrt(2)/4, S*sqrt(2)/4]) circle(d=S);
    }
}

module filleted_heart(w, h) {
    offset(r=2) offset(delta=-2) heart2d(w, h);
}

module string_boundary(l_clearance = 0) {
    linear_extrude(height=frame_depth + 2, center=true)
        offset(delta=(-frame_thickness * (1 - (string_embed_percent/100))) + l_clearance) outer_profile();
}

module string_void(l_clearance = 0) {
    translate([0, convergence_y_offset, 0])
        linear_extrude(height=frame_depth * 3, center=true) {
            // Shrink the void by the clearance amount to let the string cut deeper
            offset(delta=-l_clearance) {
                if (void_shape == "Ellipse") {
                    scale([void_width/void_height, 1]) circle(d=void_height);
                } else if (void_shape == "Rectangle") {
                    square([void_width, void_height], center=true);
                } else if (void_shape == "Hexagon") {
                    circle(d=void_width, $fn=6);
                } else if (void_shape == "Heart") {
                    filleted_heart(void_width, void_height);
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
    difference() {
        center_shape_solid();
        if (string_clearance > 0) {
            bounded_string_pattern(
                string_width + (string_clearance * 2), 
                string_height + (string_clearance * 2), 
                string_clearance
            );
        } 
    }
}

module rays() {
    bounded_string_pattern(string_width, string_height);
}

module soccer_ball_dome(radius, groove_width=0.8, groove_depth=1.0) {
    phi = (1 + sqrt(5)) / 2;
    
    // 12 vertices of an Icosahedron (These act as the center points of our 12 pentagons)
    ico_v = [
        for (y=[-1, 1], z=[-1, 1]) [0, y*phi, z],
        for (x=[-1, 1], z=[-1, 1]) [x, 0, z*phi],
        for (x=[-1, 1], y=[-1, 1]) [x*phi, y, 0]
    ];
    
    // 60 vertices of the Truncated Icosahedron
    trunc_v = [
        for (i=[0:11], j=[0:11]) 
            if (norm(ico_v[i] - ico_v[j]) > 1.9 && norm(ico_v[i] - ico_v[j]) < 2.1)
                ico_v[i] + (ico_v[j] - ico_v[i]) / 3
    ];
    
    base_r = norm(trunc_v[0]);
    
    // Sub-module to generate the main grooved geometry
    module grooved_sphere() {
        difference() {
            sphere(r=radius, $fn=120);
            for (i=[0:59], j=[i+1:59]) {
                if (norm(trunc_v[i] - trunc_v[j]) > 0.6 && norm(trunc_v[i] - trunc_v[j]) < 0.75) {
                    hull() {
                        translate((trunc_v[i] / base_r) * (radius - groove_depth)) 
                            sphere(r=groove_width/2, $fn=8);
                        translate((trunc_v[j] / base_r) * (radius - groove_depth)) 
                            sphere(r=groove_width/2, $fn=8);
                        translate((trunc_v[i] / base_r) * (radius + 2)) 
                            sphere(r=groove_width, $fn=8);
                        translate((trunc_v[j] / base_r) * (radius + 2)) 
                            sphere(r=groove_width, $fn=8);
                    }
                }
            }
        }
    }
    
    // Sub-module to generate the 12 pentagon isolation masks
    module pentagon_masks() {
        for (i=[0:11]) {
            hull() {
                cube(0.01, center=true); // Center of the sphere
                for (j=[0:11]) {
                    if (norm(ico_v[i] - ico_v[j]) > 1.9 && norm(ico_v[i] - ico_v[j]) < 2.1) {
                        // Project the pentagon vertices out past the radius to create solid wedges
                        translate(((ico_v[i] + (ico_v[j] - ico_v[i]) / 3) / base_r) * (radius * 1.5))
                            sphere(r=0.1, $fn=8);
                    }
                }
            }
        }
    }

    // Execution: Separate the geometry and assign colors
    difference() {
        union() {
            // 1. The Hexagons
            color(object_color) {
                difference() {
                    grooved_sphere();
                    pentagon_masks();
                }
            }
            // 2. The Pentagons
            color(pentagon_color) {
                intersection() {
                    grooved_sphere();
                    pentagon_masks();
                }
            }
        }
        // Slice the bottom half off to make it a flush dome
        translate([0, 0, -radius]) 
            cube([radius*3, radius*3, radius*2], center=true);
    }
}