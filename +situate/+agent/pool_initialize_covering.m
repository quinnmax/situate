function agent_pool = pool_initialize_covering( p, im, im_fname, learned_models )
% primed_agent_pool = situate.agent.pool_initialize_covering( p, im, im_fname, learned_models );

    box_area_ratios = [1/16 1/9 1/4];
    box_aspect_ratios = [1/2 1/1 2/1];
    overlap_ratio = .5;
    
    [primed_boxes_r0rfc0cf, params] = boxes_covering( size(im), box_aspect_ratios, box_area_ratios, overlap_ratio );

    urgency_multiplier   = 20;
    box_urgency_function = @(box_area_ratio) box_area_ratio;
    primed_box_urgencies = box_urgency_function( params(:,2) );
    primed_box_urgencies = primed_box_urgencies / min(primed_box_urgencies);
    primed_box_urgencies = urgency_multiplier * primed_box_urgencies;
    
    inds_remove = primed_boxes_r0rfc0cf(:,1) < 1 ...
                | primed_boxes_r0rfc0cf(:,3) < 1 ...
                | primed_boxes_r0rfc0cf(:,2) > size(im,1) ...
                | primed_boxes_r0rfc0cf(:,4) > size(im,2);
            
    primed_boxes_r0rfc0cf(inds_remove,:) = [];
    primed_box_urgencies(inds_remove) = [];
    
    cur_agent = situate.agent.initialize();
    cur_agent.history = 'primed';
    agent_pool = repmat(cur_agent,size(primed_boxes_r0rfc0cf,1),1);
    for ai = 1:length(agent_pool)
        
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
        
        agent_pool(ai).box.r0rfc0cf = [r0 rf c0 cf];
        agent_pool(ai).box.xywh     = [x y w h];
        agent_pool(ai).box.xcycwh   = [xc yc w h];
        agent_pool(ai).box.aspect_ratio = w/h;
        agent_pool(ai).box.area_ratio   = (w*h)/prod(size(im,1)*size(im,2));
        agent_pool(ai).urgency          = primed_box_urgencies(ai);
        
    end
    
    
    
    
end
    
    
    
    
    

    
    
    