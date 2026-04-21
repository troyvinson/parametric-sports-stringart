/* [Home Plate Frame Settings] */
// 1. The total width of the home plate.
frame_width = 160; // min:100
// 2. The thickness of the model from the build plate up (Z-axis).
frame_depth = 30; // 
// 3. The thickness of the outer frame wall itself.
frame_thickness = 10;
// 4. Controls 2D corner rounding for the X/Y plane.
outer_corner_radius = 5; // [0:1:30]
// 5. Controls interior corner rounding.
inner_corner_radius = 5; // [0:1:30]
// 6. Color of the outer frame
frame_color = "#FF0000"; // color

/* [Center Object] */
// 1. Adjust scale to fit inside the frame.
object_scale_percent = 90; // [1:1:500]
// 2. Fine-tune positioning on the X-axis.
object_offset_x = 0; // [-50:0.5:50]
// 3. Fine-tune positioning on the Y-axis.
object_offset_y = 15; // [-50:0.5:50]
// 4. Color of the baseball leather
object_color = "#FFFFFF"; // color
// 5. Color of the raised stitches
stitch_color = "#FF0000"; // color

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
convergence_y_offset = 15;
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
frame_height = frame_width;

/* Center Void (Experimental) */
// 1. Removes the chaotic center convergence point.
void_shape = "Ellipse"; // [None, Ellipse, Rectangle, Hexagon, Heart]
// 2. Width of the center string cut.
void_width = 20; // [1:0.5:200]
// 3. Height of the center string cut.
void_height = 20; // [1:0.5:200]


// --- Execution ---
union() {
    color(frame_color) base_frame();
    center_shape();
    color(string_color) rays();
}

// --- Modules ---

module raw_outer_profile() {
    w = frame_width;
    // Standard home plate geometry: Flat top, parallel sides, 90-degree point at bottom.
    polygon(points=[
        [-w/2, w/2],   // Top Left
        [w/2, w/2],    // Top Right
        [w/2, 0],      // Right mid
        [0, -w/2],     // Bottom Point
        [-w/2, 0]      // Left mid
    ]);
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

module baseball_dome(radius, seam_width=1.5) {
    // Parametric coefficient to drive the dual-curve seam
    a = 0.4;
    function b_pt(t) =
        let (
            x = cos(t) - a * cos(3*t),
            y = sin(t) + a * sin(3*t),
            z = 2 * sqrt(a) * cos(2*t),
            mag = sqrt(x*x + y*y + z*z)
        ) [radius * x / mag, radius * y / mag, radius * z / mag];
        
    // Apply the ball color only to the sphere geometry
    color(object_color) {
        difference() {
            // Sphere with dual curves presented frontally
            sphere(r=radius, $fn=120);
            // Subtractive seam channel - smooth continuous bead
            for (i=[0:2:358]) {
                hull() {
                    translate(b_pt(i)) sphere(r=seam_width, $fn=16);
                    translate(b_pt(i+2)) sphere(r=seam_width, $fn=16);
                }
            }
            
            // Slices bottom half flat at Z=0
            translate([0, 0, -radius]) 
                cube([radius*3, radius*3, radius*2], center=true);
        }
    }
    
    // Smooth, raised Chevron V-Stitches
    color(stitch_color) {
        intersection() {
            union() {
                // Iteration to wrap 108 individual V-shapes. Step of 3.333 degrees.
                for (i=[0:3.333:358]) {
                    // Calculate local coordinate frame tangent and side vector
                    p = b_pt(i);
                    p_next = b_pt(i + 0.5); 
                    t_vec = p_next - p;
                    t_norm = t_vec / norm(t_vec); 
                    up_norm = p / norm(p);
                    side_norm = cross(up_norm, t_norm); 
                    
                    sw = seam_width * 2; // Width of the V legs
                    sl = seam_width * 0.9; // Length of the V legs
                    r_stitch = seam_width * 0.6; // Thickness of the thread
                    
                    // Left leg
                    hull() {
                        translate(p + side_norm * sw - t_norm * sl) sphere(r=r_stitch, $fn=8);
                        translate(p) sphere(r=r_stitch, $fn=8);
                    }
                    // Right leg
                    hull() {
                        translate(p - side_norm * sw - t_norm * sl) sphere(r=r_stitch, $fn=8);
                        translate(p) sphere(r=r_stitch, $fn=8);
                    }
                }
            }
            // Keep stitches above the flat back
            translate([0, 0, radius]) cube([radius*3, radius*3, radius*2], center=true);
        }
    }
}

module center_shape_solid() {
    scale_factor = (object_scale_percent / 100);
    // Translates the shape down to sit flush on the frame back
    translate([object_offset_x, object_offset_y, -frame_depth/2]) {
        // Removed the color(object_color) wrapper from here
        scale([scale_factor, scale_factor, scale_factor])
            baseball_dome(40);
    }
}