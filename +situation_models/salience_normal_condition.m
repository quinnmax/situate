function model_out = salience_normal_condition( model_in, object_type, workspace, image )

    persistent image_backup;
    persistent salience_map;
    
    if isempty(image_backup) || ~isequal( image_backup, image ) && ~isempty(salience_map)
        image_backup = image;
        salience_map_temp = hmaxq_salience( model_in.salience_model, image );
        hn = round(sqrt(size(image,1)*size(image,2))/5);
        h = sqrt( blackmann( hn, hn ) );
        salience_map_temp = filtern( h, salience_map_temp );
        salience_map_temp = salience_map_temp / sum(salience_map_temp(:));
        salience_map = salience_map_temp;
    end
    
    if isempty( setsub( workspace.labels, object_type) )
        % then all we have in the workspace is the object_type, so don't
        % condition
        model_out = model_in;
        model_out.salience_map    = salience_map;
        model_out.discretized_map = salience_map;
    else
        model_out = situation_models.normal_condition( model_in, object_type, workspace );
        im_r = workspace.im_size(1);
        im_c = workspace.im_size(2);
        
        % figure out offset for objects in distribution
        if ~model_in.is_conditional
            params_per_obj = length( model_in.parameters_description );
            block_ind_0 = params_per_obj * ( find( strcmp( object_type, model_in.situation_objects)) - 1 );
        else
            block_ind_0 = 0;
        end
        
        rc_ind = strcmp( model_in.parameters_description, 'rc' );
        cc_ind = strcmp( model_in.parameters_description, 'cc' );
        inds_want = block_ind_0 + find(any([ rc_ind; cc_ind ]));
        inds_have = [];
        data_have = [];
        [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( model_in.mu, model_in.Sigma, inds_want, inds_have, data_have );
        lsf = sqrt( 1 / (im_r * im_c ) );
        
        x_vals = linspace( im_c * lsf * -.5, im_c * lsf * .5, im_c );
        y_vals = linspace( im_r * lsf * -.5, im_r * lsf * .5, im_r );
        [X, Y] = meshgrid( x_vals, y_vals );
        Z_flat = mvnpdf( [Y(:) X(:)], mu_bar, Sigma_bar );
        Z = reshape( Z_flat,im_r, im_c );
        Z = Z / sum(Z(:));
        combined_map = salience_map .* Z;
        combined_map = combined_map / sum(combined_map(:));
        
        model_out.salience_map = salience_map;
        model_out.discretized_map = combined_map;
    end
    
end
        
         
    
    
    
    
    
    
    
    
    
    
    
        