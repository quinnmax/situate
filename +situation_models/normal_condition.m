function model_out = normal_condition( model_in, object_type, workspace )

    % model_out = situation_model_normal_condition( model_in, object_type, workspace );
    %   model_in: should have mu, Sigma, situation_objects list and column_description list
    %   object_type: is the string from the situation_objects list for the object we want to sample for
    %   workspace: contains information on the conditioning objects
    %       workspace.labels are object strings from situation_objects
    %       workspace.boxes_r0rfc0cf are boxes for the known objects
    
    % num_features_per_object = length of model.mu / num situaiton objects;
    % need to match up situation objects and objects in workspace
    % then construct the 'have' vector so we can condition
    
    if isempty(workspace) || ~isstruct(workspace) || ~isfield(workspace,'labels') || isempty( setsub( workspace.labels, object_type ) )
        % nothing to condition on
        model_out = model_in;
        return;
    end
    
    num_parameters = length(model_in.mu)/length(model_in.situation_objects);
    
    oi = find( strcmp( model_in.situation_objects, object_type ) );
    
    known_inds     = false( 1, length(model_in.mu) );
    known_values   = nan(   1, length(model_in.mu) );
    want_data_inds = false( 1, length(model_in.mu) );
    
    want_data_inds( ((oi-1)*num_parameters+1):(oi*num_parameters) ) = true;

    for oj = setsub( 1:length(model_in.situation_objects), oi )

        % update known inds and known values
        obj_oj = model_in.situation_objects{oj};
        if exist('workspace','var') && isstruct(workspace) && isfield(workspace,'labels')
            obj_oj_workspace_ind = find( strcmp( obj_oj, workspace.labels ), 1, 'first' );
        else
            obj_oj_workspace_ind = [];
        end
        if ~isempty( obj_oj_workspace_ind )
            
            % move coordinates to zero centered, unit square
            lsf = sqrt( 1 / (workspace.im_size(1)*workspace.im_size(2)) ); % linear scaling factor
            r0 = lsf * ( workspace.boxes_r0rfc0cf(obj_oj_workspace_ind,1) - workspace.im_size(1)/2 );
            rf = lsf * ( workspace.boxes_r0rfc0cf(obj_oj_workspace_ind,2) - workspace.im_size(1)/2 );
            c0 = lsf * ( workspace.boxes_r0rfc0cf(obj_oj_workspace_ind,3) - workspace.im_size(2)/2 );
            cf = lsf * ( workspace.boxes_r0rfc0cf(obj_oj_workspace_ind,4) - workspace.im_size(2)/2 );
            
            rc = (r0 + rf) / 2;
            cc = (c0 + cf) / 2;
            w = cf - c0;
            h = rf - r0;
            log_aspect_ratio = log( w / h );
            log_area_ratio   = log( w * h ); % already normed to unit area image
            
            obj_oj_inds = ((oj-1)*num_parameters+1):(oj*num_parameters);
            known_inds(  obj_oj_inds ) = true;
            known_values( obj_oj_inds ) = [ r0 rc rf c0 cc cf log(w) log(h) log_aspect_ratio log_area_ratio ];
        end
    end
        
        
        % do the conditioning
        [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( model_in.mu, model_in.Sigma, want_data_inds, known_inds, known_values );

        % save it to the object_specific distribution struct
        
        model_out       = model_in;
        model_out.mu    = mu_bar;
        model_out.Sigma = Sigma_bar;
        
        model_out.conditioning_data.known_inds      = find(known_inds);
        model_out.conditioning_data.known_values    = known_values(known_inds);
        model_out.conditioning_data.want_data_inds  = find(want_data_inds);
        
        model_out.is_conditional = true;
      
end
        
         
    
    
    
    
    
    
    
    
    
    
    
        