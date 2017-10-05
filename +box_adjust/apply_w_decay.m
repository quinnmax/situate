function [ agent_pool, adjusted_box_r0rfc0cf, delta_xywh ] = apply_w_decay( model, current_agent_snapshot, agent_pool, image, cnn_features )

    % [ agent_pool, adjusted_box_r0rfc0cf, delta_xywh ] = apply( model, current_agent_snapshot, agent_pool, image, cnn_features );

    % [adjusted_box_r0rfc0cf, delta_xywh] = apply( model, object_type, box_r0rfc0cf, image, cnn_features );
    %
    % adjusted_box_r0rfc0cf: the adjusted bounding box is returned in r0rfc0cf format
    % delta_xywh: the delta used to generate the adjusted box
    %
    % if cnn features are provided, these will be used. otherwise, they'll be
    % extracted from the input image
    
    % find object index in the model
    oi = find( strcmp( model.object_types, current_agent_snapshot.interest ) );
    
    % get starting stats
    r0 = current_agent_snapshot.box.r0rfc0cf(1);
    rf = current_agent_snapshot.box.r0rfc0cf(2);
    c0 = current_agent_snapshot.box.r0rfc0cf(3);
    cf = current_agent_snapshot.box.r0rfc0cf(4);
    w = cf - c0  +  1;
    h = rf - r0  +  1;
    x = c0 + w/2 - .5;
    y = r0 + h/2 - .5;

    % get cnn features, if necessary
    if ~exist('cnn_features','var') || isempty(cnn_features)
        if mean(image(:)) < 1, image = image*255; end
        cnn_features = cnn.cnn_process( image(r0:rf,c0:cf,:))';
    end
    
    % predict the deltas
    delta_x = [1 cnn_features] * model.weight_vectors{oi,1};
    delta_y = [1 cnn_features] * model.weight_vectors{oi,2};
    delta_w = [1 cnn_features] * model.weight_vectors{oi,3};
    delta_h = [1 cnn_features] * model.weight_vectors{oi,4};
    delta_xywh = [delta_x delta_y delta_w delta_h];
    
    % predict the new box values
    adjusted_x = x + delta_x * w;
    adjusted_y = y + delta_y * h;
    adjusted_w = w * exp(delta_w);
    adjusted_h = h * exp(delta_h);
    
    r0_adjusted = round( adjusted_y  - adjusted_h/2 + .5 );
    rf_adjusted = round( r0_adjusted + adjusted_h - 1);
    c0_adjusted = round( adjusted_x  - adjusted_w/2 + .5 );
    cf_adjusted = round( c0_adjusted + adjusted_w - 1);
    
    % correct for edge effects, update based on changes
    r0_adjusted = max( r0_adjusted, 1 );
    rf_adjusted = min( rf_adjusted, size(image,1) );
    c0_adjusted = max( c0_adjusted, 1 );
    cf_adjusted = min( cf_adjusted, size(image,2) );
    adjusted_w  = cf_adjusted - c0_adjusted + 1;
    adjusted_h  = rf_adjusted - r0_adjusted + 1;
    adjusted_x  = c0_adjusted + adjusted_w/2 - .5;
    adjusted_y  = r0_adjusted + adjusted_h/2 - .5;
    
    adjusted_box_r0rfc0cf = [r0_adjusted rf_adjusted c0_adjusted cf_adjusted];
    
    % construct a new agent to add to the pool
    new_agent = current_agent_snapshot;
    if isfield( new_agent, 'history' )
        new_agent.history = [current_agent_snapshot.history '_boxAdjust'];
    end
    new_agent.type = 'scout';
    new_agent.urgency = current_agent_snapshot.urgency * .9;
    new_agent.support.internal     = 0;
    new_agent.support.external     = 0;
    new_agent.support.total        = 0;
    new_agent.support.GROUND_TRUTH = 0;
    new_agent.GT_label_raw = [];
    
    new_agent.box.r0rfc0cf = adjusted_box_r0rfc0cf;
    new_agent.box.xywh     = [ (adjusted_x-adjusted_w/2+1)  (adjusted_y-adjusted_h/2+1) adjusted_w  adjusted_h];
    new_agent.box.xcycwh   = [adjusted_x adjusted_y  adjusted_w  adjusted_h];
    new_agent.box.aspect_ratio = adjusted_w/adjusted_h;
    new_agent.box.area_ratio   = (adjusted_w*adjusted_h) / (size(image,1)*size(image,2));
    
    if isempty(agent_pool)
        agent_pool = new_agent; 
    else
        agent_pool(end+1) = new_agent; 
    end
    
end