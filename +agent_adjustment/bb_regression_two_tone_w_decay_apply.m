function [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = bb_regression_two_tone_w_decay_apply( model, current_agent_snapshot, agent_pool, image, cnn_features )
% [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = two_tone_w_decay_apply( model, current_agent_snapshot, agent_pool, image, cnn_features );

    if ~exist('cnn_features','var')
        cnn_features = [];
    end

    if length(model.model_selection_threshold) > 1
        mi = strcmp( current_agent_snapshot.interest, model.object_types );
        threshold = model.model_selection_threshold(mi);
    else
        threshold = model.model_selection_threshold;
    end
    
    if current_agent_snapshot.support.internal <= threshold
        [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = agent_adjustment.bb_regression_w_decay_apply( model.sub_models{1}, current_agent_snapshot, agent_pool, image, cnn_features );
    else
        [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = agent_adjustment.bb_regression_w_decay_apply( model.sub_models{2}, current_agent_snapshot, agent_pool, image, cnn_features );
    end
    
end