function agent_pool = pool_initialize_covering_rcnn_like( p, im, ~, learned_models, varargin )
% primed_agent_pool = situate.agent.pool_initialize_covering_rcnn_like( p, im, im_fname, learned_models, [max_boxes_per_obj_type], [additional_unassigned_agents] );

    % process in puts
    max_boxes_per_obj_type = [];
    num_unassigned_agents = 0;

    if length(varargin) >= 1
        max_boxes_per_obj_type = varargin{1}; 
    end
    
    if length(varargin) >= 2
        num_unassigned_agents = varargin{2};
    end
        

    
    % define anchor points for rcnn
    box_area_ratios   = [ 1/4 1/9 1/16 ];
    box_aspect_ratios = [ 1/2 1/1  2/1 ];
    box_overlap_ratio = .5;
    % situation_struct  = p;
    
    switch learned_models.adjustment_model.model_description
        case 'box_adjust_two_tone'
            [~,conservative_model_index] = max( learned_models.adjustment_model.IOU_thresholds );
            temp_adjust_model = learned_models.adjustment_model.sub_models{ conservative_model_index };
        otherwise
            temp_adjust_model = learned_models.adjustment_model;
    end
    
    
    
    
    
    use_non_max_suppression = true;
    show_viz = false;
    if p.use_parallel, show_progress = false; else show_progress = true; end
    
    [primed_boxes_r0rfc0cf, class_assignments, confidences] = rcnn_homebrew( ...
            im, box_area_ratios, box_aspect_ratios, overlap_ratio, classifier_model, box_adjust_model, ...
            use_non_max_suppression, show_viz, show_progress );
    
        
        
        
    if any(isnan(primed_boxes_r0rfc0cf(:)))
        error('nan boxes');
    end
        
    % remove excess boxes
    if ~isempty(max_boxes_per_obj_type)
        [confidences,sort_order] = sort(confidences,'descend');
        primed_boxes_r0rfc0cf = primed_boxes_r0rfc0cf(sort_order,:);
        class_assignments = class_assignments(sort_order);
        inds_keep = [];
        unique_classes = unique(class_assignments);
        for oii = 1:length(unique_classes)
            oi = unique_classes(oii);
            cur_inds_keep = find( eq( oi, class_assignments ), max_boxes_per_obj_type, 'first' );
            if isempty(inds_keep), inds_keep = cur_inds_keep; else
            inds_keep = [inds_keep; cur_inds_keep]; end
        end
        confidences = confidences( inds_keep );
        class_assignments = class_assignments( inds_keep );
        primed_boxes_r0rfc0cf = primed_boxes_r0rfc0cf( inds_keep, : );
    end
        
    cur_agent = situate.agent.initialize();
    cur_agent.urgency = 1;
    total_agents = size( primed_boxes_r0rfc0cf,1 ) + num_unassigned_agents;
    agent_pool   = repmat( cur_agent, total_agents, 1 );
    for ai = 1:size(primed_boxes_r0rfc0cf,1)
        
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
        
        agent_pool(ai).history = 'primedRCNNish';
        agent_pool(ai).interest         = p.situation_objects{ class_assignments(ai) };
        agent_pool(ai).support.internal = confidences(ai);
        
    end
    
    temp = [agent_pool(1:size(primed_boxes_r0rfc0cf,1)).box];
    temp = vertcat(temp.r0rfc0cf);
    assert( all( temp(:,2) > temp(:,1) ) );
    assert( all( temp(:,4) > temp(:,3) ) );
    
    
    
end
    
    
    
    
    

    
    
    