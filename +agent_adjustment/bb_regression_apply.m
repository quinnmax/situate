function [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = bb_regression_apply( model, input_agent, ~, image, cnn_features )

    % [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = apply( model, input_agent, ~, image, cnn_features );
    %
    % adjusted_box_r0rfc0cf: the adjusted bounding box is returned in r0rfc0cf format
    % delta_xywh: the delta used to generate the adjusted box
    %
    % if cnn features are provided, these will be used. otherwise, they'll be
    % extracted from the input image
    
    % find object index in the model, grab weight vector
    oi = strcmp( model.object_types, input_agent.interest );
    weight_vectors = horzcat(model.weight_vectors{oi,:});
   
    % get adjusted box
    [ adjusted_box_r0rfc0cf, delta_xywh ] = agent_adjustment.bb_regression_adjust_box( weight_vectors, input_agent.box.r0rfc0cf, image, cnn_features );
    
    % construct a new agent based on the input agent
    new_agent = input_agent;
    if isfield( new_agent, 'history' )
        new_agent.history = [input_agent.history '_boxAdjust'];
    end
    if isfield( new_agent, 'generation' )
        new_agent.generation = new_agent.generation + 1;
    end
    new_agent.type = 'scout';
    new_agent.urgency               = 1;
    new_agent.support.internal      = nan;
    new_agent.support.external      = nan;
    new_agent.support.total         = nan;
    new_agent.support.GROUND_TRUTH  = nan;
    new_agent.GT_label_raw          = [];
    
    new_agent.box.r0rfc0cf      = adjusted_box_r0rfc0cf;
    new_agent.box.xywh          = [ (adjusted_x-adjusted_w/2+1)  (adjusted_y-adjusted_h/2+1) adjusted_w  adjusted_h ];
    new_agent.box.xcycwh        = [ adjusted_x adjusted_y  adjusted_w  adjusted_h ];
    new_agent.box.aspect_ratio  = adjusted_w/adjusted_h;
    new_agent.box.area_ratio    = ( adjusted_w * adjusted_h ) / ( size(image,1) * size(image,2) );
   
end