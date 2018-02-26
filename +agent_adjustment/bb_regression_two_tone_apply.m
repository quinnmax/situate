function [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = bb_regression_two_tone_apply( model, input_agent, ~, image, cnn_features )
%        [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = bb_regression_two_tone_apply( model, input_agent, ~, image, cnn_features );

    if ~exist('cnn_features','var')
        cnn_features = [];
    end

    if length(model.model_selection_threshold) > 1
        mi = strcmp( input_agent.interest, model.object_types );
        threshold = model.model_selection_threshold(mi);
    else
        threshold = model.model_selection_threshold;
    end
    
    if input_agent.support.internal <= threshold
        [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = agent_adjustment.bb_regression_apply( model.sub_models{1}, input_agent, [], image, cnn_features );
    else
        [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = agent_adjustment.bb_regression_apply( model.sub_models{2}, input_agent, [], image, cnn_features );
    end
    
end