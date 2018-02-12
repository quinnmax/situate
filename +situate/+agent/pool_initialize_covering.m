function primed_agent_pool = pool_initialize_covering( ~, im, ~ )

    im_size = [ size(im,1), size(im,2) ];

    box_size_width_ratios = [.2 .5];
    box_size_urgencies = (1./(1-box_size_width_ratios)).^2;
    
    box_shapes = [1/2 1/1 2/1];
    overlap_ratio = .5;
    
    box_sizes_px = box_size_width_ratios.^2 * im_size(1) * im_size(2);
    
    % ratio of width of the image -> total pixels
    
    primed_boxes_r0rfc0cf = zeros(0,4);
    primed_box_urgencies  = zeros(0,1);
    for bi = 1:length(box_sizes_px)
    for bj = 1:length(box_shapes)
        
        [w,h] = box_aa2wh(box_shapes(bj),box_sizes_px(bi));
        w = round(w);
        h = round(h);
        
        rcs = linspace( 1 + h/2 - .5, im_size(1) - h/2, round((im_size(1)-h/2)/(h * overlap_ratio)) );
        r0s = floor( rcs - h/2 ) + 1;
        rfs = r0s + h - 1;

        ccs = linspace( 1 + w/2 - .5, im_size(2) - w/2, round((im_size(2)-w/2)/(w * overlap_ratio)) );
        c0s = floor( ccs - w/2 ) + 1;
        cfs = c0s + w - 1;

        new_boxes_r0rfc0cf = [sort(repmat( r0s', length(c0s), 1 )) sort(repmat( rfs', length(c0s), 1 )) repmat( c0s', length(r0s), 1 ) repmat( cfs', length(r0s), 1 )];
        
        primed_boxes_r0rfc0cf(end+1:end+size(new_boxes_r0rfc0cf,1),:) = new_boxes_r0rfc0cf;
        primed_box_urgencies(end+1:end+size(new_boxes_r0rfc0cf,1))    = box_size_urgencies( bi ); 
        
    end
    end
    
    inds_remove = primed_boxes_r0rfc0cf(:,1) < 1 ...
                | primed_boxes_r0rfc0cf(:,3) < 1 ...
                | primed_boxes_r0rfc0cf(:,2) > im_size(1) ...
                | primed_boxes_r0rfc0cf(:,4) > im_size(2);
            
    primed_boxes_r0rfc0cf(inds_remove,:) = [];
    
    cur_agent = situate.agent.initialize();
    cur_agent.history = 'primed';
    cur_agent.urgency = 5;
    primed_agent_pool = repmat(cur_agent,size(primed_boxes_r0rfc0cf,1),1);
    for ai = 1:length(primed_agent_pool)
        
        r0 = primed_boxes_r0rfc0cf(ai,1);
        rf = primed_boxes_r0rfc0cf(ai,2);
        c0 = primed_boxes_r0rfc0cf(ai,3);
        cf = primed_boxes_r0rfc0cf(ai,4);
        x = c0;
        y = r0;
        w = cf - c0 + 1;
        h = rf - r0 + 1;
        xc = round( x + w/2 - .5 );
        yc = round( y + h/2 - .5 );
        
        primed_agent_pool(ai).box.r0rfc0cf = [r0 rf c0 cf];
        primed_agent_pool(ai).box.xywh     = [x y w h];
        primed_agent_pool(ai).box.xcycwh   = [xc yc w h];
        primed_agent_pool(ai).box.aspect_ratio = w/h;
        primed_agent_pool(ai).box.area_ratio   = (w*h)/prod(im_size);
        
    end
    
end
