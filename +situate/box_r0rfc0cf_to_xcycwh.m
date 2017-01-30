function box_xcycwh = box_r0rfc0cf_to_xcycwh( box_r0rfc0cf )

    % box_xcycwh = box_r0rfc0cf_to_xcycwh( box_r0rfc0cf );

    r0 = box_r0rfc0cf(1); 
    rf = box_r0rfc0cf(2); 
    c0 = box_r0rfc0cf(3); 
    cf = box_r0rfc0cf(4);
    
    w = cf - c0 + 1; 
    h = rf - r0 + 1; 
    xc = c0 + w/2; 
    yc = r0 + h/2;
    
    box_xcycwh = [xc yc w h];

end