
function [boxes_r0rfc0cf, sample_density, model] = salience_normal_sample( model, object_type, n, im_dims, existing_box_r0rfc0cf )
    
    % [boxes_r0rfc0cf, sample_density, model] = salience_normal_sample( model, object_type, [n], [im_row im_col]); 
    %   if run without the existing_box var, then you get a sampled box
    %   model as a return value is only necessary if sampling changes the
    %       distribution (for something like inhibition of return)
    %
    % [boxes_r0rfc0cf, sample_density] = salience_normal_sample( model, object_type, [n], [im_row im_col], existing_box_r0rfc0cf);
    % if you run with the existing_box var, the return box will match it,
    %   and the density will be the density of the box with respect to the
    %   model provided
    %
    
    if ~exist('n','var') || isempty(n)
        n = 1;
    end
    
    if ~exist('im_dims','var')
        im_dims = [];
    end
   
    if exist('existing_box_r0rfc0cf','var') && ~isempty(existing_box_r0rfc0cf)
        sample_density = salience_normal_density( model, object_type, im_dims, existing_box_r0rfc0cf );
        boxes_r0rfc0cf = existing_box_r0rfc0cf;
        return;
    end
    
    % sample location
    if isfield(model,'discretized_map_cdf') && ~isempty(model.discretized_map_cdf)
        sampled_inds = sample_2d( model.discretized_map, 1, [], [], model.discretized_map_cdf );
    else
        [sampled_inds,~,~,model.discretized_map_cdf] = sample_2d( model.discretized_map, 1 );
    end
    rc = sampled_inds(1);
    cc = sampled_inds(2);
    
    % figure out our marginalized distributions for sampling shape and size
    if model.is_conditional
        sub_ind_0 = 1;
    else
        num_vars_per_obj = length(model.mu)/length(model.situation_objects);
        obj_ind          = find( strcmp( object_type, model.situation_objects ), 1, 'first' );
        sub_ind_0        = (obj_ind-1) * num_vars_per_obj + 1;
    end
    inds_of_interest = sub_ind_0 - 1 + [ 7 8 9 10 ];
    [mu_marginalized, Sigma_marginalized] = mvn_marginalize_and_condition( model.mu, model.Sigma, inds_of_interest, [], [] );
        
    % sample shape, size
    shape_size_sample = mvnrnd( mu_marginalized, Sigma_marginalized, 1 );
    aspect_ratio = exp( shape_size_sample(3) );
    area_ratio   = exp( shape_size_sample(4) );
    [w_normalized, h_normalized] = box_aa2wh( aspect_ratio, area_ratio );
    lsf = sqrt( im_dims(1) * im_dims(2) );
    w = lsf * w_normalized;
    h = lsf * h_normalized;
    % since these are based on the discretized map, which is the same size
    % as the image, they're good to go without any scaling.
    
    r0 = round(rc - h/2);
    rf = round(r0 + h - 1);
    c0 = round(cc - w/2);
    cf = round(c0 + w - 1);
    r0 = max( r0, 1 );
    c0 = max( c0, 1 );
    rf = min( rf, im_dims(1) );
    cf = min( cf, im_dims(2) );
    boxes_r0rfc0cf = [r0 rf c0 cf];
    
    % get density
    [~, sample_density] = situation_models.salience_normal_sample( model, object_type, 1, im_dims, boxes_r0rfc0cf );
    
     % ugh, if you've goofed this bad, just do it over
    if (r0>=rf) || (c0>=cf)
        [boxes_r0rfc0cf, sample_density] = situation_models.uniform_then_normal_sample( model, object_type, n, im_dims );
    end
  
end

function sample_density = salience_normal_density( model, object_type, im_dims, existing_box_r0rfc0cf )

    if model.is_conditional
        sub_ind_0 = 1;
    else
        num_vars_per_obj = length(model.mu)/length(model.situation_objects);
        obj_ind          = find( strcmp( object_type, model.situation_objects ), 1, 'first' );
        sub_ind_0        = (obj_ind-1) * num_vars_per_obj + 1;
    end
    inds_of_interest = sub_ind_0 - 1 + [ 7 8 9 10 ];
    [mu_marginalized, Sigma_marginalized] = mvn_marginalize_and_condition( model.mu, model.Sigma, inds_of_interest, [], [] );
    
    if exist('existing_box_r0rfc0cf','var') && ~isempty(existing_box_r0rfc0cf)
        % just get the density and return
        rc = round( (existing_box_r0rfc0cf(1) + existing_box_r0rfc0cf(2)) / 2 );
        cc = round( (existing_box_r0rfc0cf(3) + existing_box_r0rfc0cf(4)) / 2 );
        area_of_pixel = 1 / (im_dims(1) * im_dims(2));
        % pixels sum to 1, constant density in the pixel, so the area of
        % the bottom of the density voxel is the area of a single pixel.
        % then the height of the voxel is the density of the pixel divided
        % by the area of the pixel.
        location_density = model.discretized_map(rc,cc) / area_of_pixel;
       
        lsf = sqrt( 1 / (im_dims(1)*im_dims(2)) ); % linear scaling factor
        r0  = lsf * (existing_box_r0rfc0cf(1) - im_dims(1)/2);
        rf  = lsf * (existing_box_r0rfc0cf(2) - im_dims(1)/2);
        c0  = lsf * (existing_box_r0rfc0cf(3) - im_dims(2)/2);
        cf  = lsf * (existing_box_r0rfc0cf(4) - im_dims(2)/2);
        w   = cf - c0;
        h   = rf - r0;
        log_aspect_ratio = log( w / h );
        log_area_ratio   = log( w * h ); % already normed to unit area image
        box_vect = [ log(w) log(h) log_aspect_ratio log_area_ratio ];
        shape_size_density = mvnpdf( box_vect, mu_marginalized, Sigma_marginalized );
        
        sample_density = location_density * shape_size_density;
    end
    
end





