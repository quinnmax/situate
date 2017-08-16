function [ agent_pool_out, adjusted_box_r0rfc0cf, delta_xywh ] = two_tone_w_decay_and_drop_apply( model, current_agent_snapshot, agent_pool, image, cnn_features )

    if ~exist('cnn_features','var')
        cnn_features = [];
    end

    if current_agent_snapshot.support.internal <= model.model_selection_threshold

        [ agent_pool_out, adjusted_box_r0rfc0cf, delta_xywh ] = box_adjust.apply_w_decay( model.sub_models{1}, current_agent_snapshot, agent_pool, image, cnn_features );
        
    else

        [ agent_pool_out, adjusted_box_r0rfc0cf, delta_xywh ] = box_adjust.apply_w_decay( model.sub_models{2}, current_agent_snapshot, agent_pool, image, cnn_features );
        
    end
    
    if any( [agent_pool_out.urgency] < .5 )
        agent_pool_out( [agent_pool_out.urgency] < .5 ) = [];
    end
    
end