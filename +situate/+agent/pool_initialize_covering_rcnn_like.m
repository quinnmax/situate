function agent_pool = pool_initialize_covering_rcnn_like( p, im, ~, learned_models )
% primed_agent_pool = situate.agent.pool_initialize_covering_rcnn_like( p, im, im_fname, learned_models );

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
    
    
    
    
    %display('do RCNN like stuff here');
    
    % apply classifier to each box for internal support
    classifier_output = nan(length(agent_pool),length(p.situation_objects));
    cnn_feature_vects = [];
    for ai = 1:length(agent_pool)
    for oi = 1:length(p.situation_objects)
        [classifier_output(ai,oi), ~, cnn_feature_vect] = p.classifier.apply( learned_models.classifier_model, p.situation_objects{oi}, im, agent_pool(ai).box.r0rfc0cf );
        if isempty(cnn_feature_vects)
            cnn_feature_vects(1,:) = cnn_feature_vect;
            cnn_feature_vects(2:length(agent_pool),:) = nan();
        else
            cnn_feature_vects(ai,:) = cnn_feature_vect;
        end
    end
    if mod(ai,50)==0 || ai == length(agent_pool), progress(ai,length(agent_pool)); end
    end
    
    % assign most likely object to each box
    [internal_support,obj_assignment] = max( classifier_output,[],2);
    
    % apply box adjust to each box 
    for ai = 1:length( agent_pool )
        agent_pool(ai).interest = p.situation_objects{obj_assignment(ai)};
        agent_pool(ai).support.internal = internal_support(ai);
        agent_pool(ai) = p.adjustment_model.apply( learned_models.adjustment_model, agent_pool(ai), agent_pool, im, cnn_feature_vects(ai,:) );
    end
    
    % apply classifier to resulting boxes
    for ai = 1:length(agent_pool)
        agent_pool(ai).support.internal = p.classifier.apply( learned_models.classifier_model, agent_pool(ai).interest, im, agent_pool(ai).box.r0rfc0cf );
        if mod(ai,50)==0 || ai == length(agent_pool), progress(ai,length(agent_pool)); end
    end
    
    % apply non max supression
    IOU_suppression_threshold = .25;
    temp = [agent_pool.box];
    boxes_r0rfc0cf = vertcat(temp.r0rfc0cf);
    temp = [agent_pool.support];
    box_scores = vertcat(temp.internal);
    inds_keep = false(length(agent_pool),length(p.situation_objects));
    for oi = 1:length(p.situation_objects)
        cur_obj_rows = strcmp({agent_pool.interest}, p.situation_objects{oi});
        temp_scores = box_scores;
        temp_scores(~cur_obj_rows) = 0;
        inds_keep(:,oi) = non_max_supression( boxes_r0rfc0cf, temp_scores, IOU_suppression_threshold, 'r0rfc0cf' );
    end
    inds_keep = any(inds_keep,2);
    agent_pool = agent_pool(inds_keep);
    
end
    
    
    
    
    

    
    
    