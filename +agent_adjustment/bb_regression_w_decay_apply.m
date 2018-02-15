function [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = bb_regression_w_decay_apply( model, current_agent_snapshot, agent_pool, image, cnn_features )

    % [ agent_pool, adjusted_box_r0rfc0cf, delta_xywh ] = bb_regression_w_decay_apply( model, current_agent_snapshot, agent_pool, image, cnn_features );

    % [adjusted_box_r0rfc0cf, delta_xywh] = bb_regression_w_decay_apply( model, object_type, box_r0rfc0cf, image, cnn_features );
    %
    % adjusted_box_r0rfc0cf: the adjusted bounding box is returned in r0rfc0cf format
    % delta_xywh: the delta used to generate the adjusted box
    %
    % if cnn features are provided, these will be used. otherwise, they'll be
    % extracted from the input image
    
    [new_agent, adjusted_box_r0rfc0cf, delta_xywh] =  agent_adjustment.bb_regression_apply( model, current_agent_snapshot, agent_pool, image, cnn_features );
    
    if isempty( strfind( current_agent_snapshot.history, '_boxAdjust') )
        new_agent(end).urgency = 1;
    else
        new_agent(end).urgency = current_agent_snapshot.urgency * .9;
    end
    
end