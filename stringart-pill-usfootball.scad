/* [Frame Settings] */
// 1. The total width of the frame (Left to Right).
frame_width = 220; // min:100
// 2. The thickness of the model from the build plate up (Z-axis).
frame_depth = 30; 
// 3. The thickness of the outer frame wall itself.
frame_thickness = 10;
// 4. Controls 2D corner rounding for the X/Y plane (softens the flat bottom corners).
outer_corner_radius = 5; // [0:1:30]
// 5. Controls interior corner rounding.
inner_corner_radius = 5; // [0:1:30]
// 6. Color of the outer frame
frame_color = "#5C2E00"; // color

/* [Center Object] */
// 1. The total length of the football.
football_length = 180; // min:50
// 2. Adjust scale to fit inside the frame.
object_scale_percent = 100; // [1:1:500]
// 3. Fine-tune positioning on the X-axis.
object_offset_x = -5; // [-50:0.5:50]
// 4. Fine-tune positioning on the Y-axis.
object_offset_y = 0; // [-50:0.5:50]
// 5. Color of the football leather
object_color = "#5C2E00"; // color
// 6. Color of the laces and bands
seam_color = "#FFFFFF"; // color

/* [String (Ray) Settings] */
// 1. Number of strings wrapping around one full revolution.
strings_per_row = 30;
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
void_width = 35; // [1:0.5:200]
void_height = 25; // [1:0.5:200]

// Lock the frame height to exactly match the 180:125 width-to-height ratio 
frame_height = frame_width * (135 / 180);

// --- Execution ---
union() {
    color(frame_color) base_frame();
    center_shape();
    color(string_color) rays();
}

// --- Modules ---

module raw_outer_profile() {
    w = frame_width;
    h = frame_height;
    r = h/2;
    hull() {
        translate([-w/2 + r, 0]) circle(r=r);
        translate([w/2 - r, 0]) circle(r=r);
    }
}

module outer_profile() {
    safe_r = min(outer_corner_radius, frame_height/2.1);
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
    safe_r = min(inner_corner_radius, (frame_height-frame_thickness)/2.1);
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

module football_dome(rx, r_yz, seam_width=0.6) {
    
    module lens_profile() {
        d = (rx*rx - r_yz*r_yz) / (2 * r_yz);
        R = (rx*rx + r_yz*r_yz) / (2 * r_yz);
        intersection() {
            translate([-d, 0]) circle(r=R, $fn=120);
            translate([d, 0]) circle(r=R, $fn=120);
        }
    }
    
    module base_shape(offset_val=0) {
        blunt_r = rx * 0.085; 
        
        rotate([0, 90, 0])
        rotate_extrude($fn=120) {
            difference() {
                if (offset_val < 0) {
                    offset(delta=offset_val) {
                        offset(r=blunt_r) offset(delta=-blunt_r) lens_profile();
                    }
                } else if (offset_val > 0) {
                    offset(r=offset_val) {
                        offset(r=blunt_r) offset(delta=-blunt_r) lens_profile();
                    }
                } else {
                    offset(r=blunt_r) offset(delta=-blunt_r) lens_profile();
                }
                
                translate([-max(rx, r_yz)*3, -max(rx, r_yz)*3]) 
                    square([max(rx, r_yz)*3, max(rx, r_yz)*6]);
            }
        }
    }
    
    module seam_segment(t, t_next, R, d, w) {
        p1 = [R * sin(t), R * cos(t) - d, 0];
        p2 = [R * sin(t_next), R * cos(t_next) - d, 0];
        
        n1 = [sin(t), cos(t), 0];
        n2 = [sin(t_next), cos(t_next), 0];
        
        r_fillet = w * 3; 
        shift = r_fillet - (w * 0.6);
        
        p1_out = [p1[0] + n1[0]*shift, p1[1] + n1[1]*shift, 0];
        p2_out = [p2[0] + n2[0]*shift, p2[1] + n2[1]*shift, 0];
        
        hull() {
            translate(p1) sphere(r=w, $fn=8);
            translate(p2) sphere(r=w, $fn=8);
        }
        hull() {
            translate(p1_out) sphere(r=r_fillet, $fn=8);
            translate(p2_out) sphere(r=r_fillet, $fn=8);
        }
    }
    
    module seams_geom(w) {
        step = 2;
        d = (rx*rx - r_yz*r_yz) / (2 * r_yz);
        R = (rx*rx + r_yz*r_yz) / (2 * r_yz);
        max_theta = asin(rx / R);

        for (angle = [-20, 70, 160, 250]) {
            rotate([angle, 0, 0]) {
                for (t = [-max_theta : step : max_theta - 0.001]) {
                    seam_segment(t, min(t + step, max_theta), R, d, w);
                }
            }
        }
    }

    module laces_2d() {
        total_len = rx * 2;
        laces_length = total_len * (4.375 / 11.0);
        laces_width = total_len * (1.125 / 11.0);
        
        spine_len = laces_length + (total_len * 0.03); 
        spine_width = laces_width * 0.25;
        cross_len = laces_width;
        cross_width = laces_length * 0.07;
        cross_span = laces_length - 1;
        
        union() {
            square([spine_len, spine_width], center=true);
            for(x = [-cross_span/2 : cross_span/7 : cross_span/2]) {
                translate([x, 0]) square([cross_width, cross_len], center=true);
            }
        }
    }
    
    module laces_geom() {
        fillet_r = 0.5;
        base_h = 1.0 - fillet_r; 
        steps = 6; 
        smooth_r = rx * 0.01; 
        
        intersection() {
            difference() {
                base_shape(base_h);
                base_shape(0);   
            }
            rotate([-20, 0, 0]) translate([0, 0, r_yz]) {
                linear_extrude(height=r_yz*2, center=true) {
                    offset(r=smooth_r) offset(delta=-smooth_r) laces_2d();
                }
            }
        }
        
        for (i = [0 : steps - 1]) {
            h_start = base_h + fillet_r * (i / steps);
            h_end = base_h + fillet_r * ((i + 1) / steps);
            
            dy1 = fillet_r * (i / steps);
            dy2 = fillet_r * ((i + 1) / steps);
            shrink1 = fillet_r - sqrt(pow(fillet_r, 2) - pow(dy1, 2));
            shrink2 = fillet_r - sqrt(pow(fillet_r, 2) - pow(dy2, 2));
            shrink_avg = (shrink1 + shrink2) / 2;
            
            intersection() {
                difference() {
                    base_shape(h_end + 0.02);
                    base_shape(h_start); 
                }
                rotate([-20, 0, 0]) translate([0, 0, r_yz]) {
                    linear_extrude(height=r_yz*2, center=true) {
                        offset(r=smooth_r) offset(delta=-smooth_r - shrink_avg) laces_2d();
                    }
                }
            }
        }
    }
    
    // Bounds the stripes mathematically to prevent 360-degree wrapping
    module stripes_mask() {
        total_len = rx * 2;
        laces_length = total_len * (4.375 / 11.0);
        stripe_width = total_len * (.75 / 11.0);
        
        // Midpoint calculation: Exactly halfway between the end of the laces and the tip of the ball
        stripe_dist = (laces_length / 2 + rx) / 2;
        
        // Rotate the bounding box to match the -20 deg laces. 
        // Translating up by exactly half its height (r_yz) aligns its bottom face perfectly with the Z=0 plane (the side seams).
        rotate([-20, 0, 0]) {
            translate([-stripe_dist, 0, r_yz]) cube([stripe_width, r_yz*3, r_yz*2], center=true);
            translate([stripe_dist, 0, r_yz]) cube([stripe_width, r_yz*3, r_yz*2], center=true);
        }
    }
    
    module stripes_inlay() {
        difference() {
            intersection() {
                difference() {
                    base_shape(0);
                    base_shape(-1.5); 
                }
                stripes_mask();
            }
            // Slice the inlay with the longitudinal seams so they remain continuous
            seams_geom(seam_width);
        }
    }
    
    module stripes_cutter() {
        intersection() {
            difference() {
                base_shape(0.1);
                base_shape(-1.5); 
            }
            stripes_mask();
        }
    }
    
    orient_x = -20;
    orient_y = -15;
    orient_z = 10;
    
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
    
    color(object_color) {
        difference() {
            rotate([orient_x, orient_y, orient_z]) {
                difference() {
                    base_shape(0);
                    seams_geom(seam_width); 
                    stripes_cutter(); 
                }
            }
            translate([0, 0, -max(rx, r_yz)]) 
                cube([rx*3, rx*3, max(rx, r_yz)*2], center=true);
            string_cut();
        }
    }
    
    color(seam_color) {
        difference() {
            rotate([orient_x, orient_y, orient_z]) {
                union() {
                    laces_geom();
                    stripes_inlay(); 
                }
            }
            translate([0, 0, -max(rx, r_yz)]) 
                cube([rx*3, rx*3, max(rx, r_yz)*2], center=true);
            string_cut();
        }
    }
}

module center_shape_solid() {
    scale_factor = (object_scale_percent / 100);
    rx = football_length / 2;
    r_yz = rx / 1.65;
    
    translate([object_offset_x, object_offset_y, -frame_depth/2]) {
        scale([scale_factor, scale_factor, scale_factor])
            football_dome(rx, r_yz);
    }
}