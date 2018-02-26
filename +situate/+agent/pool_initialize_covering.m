function primed_agent_pool = pool_initialize_covering( ~, im, ~ )
% primed_agent_pool = situate.agent.primed_agent_pool = pool_initialize_covering( ~, im, ~ );

    box_area_ratios = [1/16 1/4];
    box_aspect_ratios = [1/2 1/1 2/1];
    overlap_ratio = .5;
    
    [primed_boxes_r0rfc0cf, params] = boxes_covering( size(im), box_aspect_ratios, box_area_ratios, overlap_ratio );

    box_urgency_function = @(box_area_ratio) box_area_ratio;
    primed_box_urgencies = box_urgency_function( params(:,2) );
    primed_box_urgencies = primed_box_urgencies / min(primed_box_urgencies);
    
    inds_remove = primed_boxes_r0rfc0cf(:,1) < 1 ...
                | primed_boxes_r0rfc0cf(:,3) < 1 ...
                | primed_boxes_r0rfc0cf(:,2) > size(im,1) ...
                | primed_boxes_r0rfc0cf(:,4) > size(im,2);
            
    primed_boxes_r0rfc0cf(inds_remove,:) = [];
    primed_box_urgencies(inds_remove) = [];
    
    cur_agent = situate.agent.initialize();
    cur_agent.history = 'primed';
    primed_agent_pool = repmat(cur_agent,size(primed_boxes_r0rfc0cf,1),1);
    urgency_multiplier = 5;
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
        primed_agent_pool(ai).box.area_ratio   = (w*h)/prod(size(im,1)*size(im,2));
        primed_agent_pool(ai).urgency = urgency_multiplier * primed_box_urgencies(ai);
        
    end
    
end
