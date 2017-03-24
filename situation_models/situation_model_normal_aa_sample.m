
function [boxes_r0rfc0cf, sample_density] = situation_model_normal_aa_sample( model, object_type, n, im_dims, existing_box_r0rfc0cf )
    
    % [boxes_r0rfc0cf, sample_density] = situation_model_normal_aa_sample( model, object_type, [n], [im_row im_col]); 
    %   if run without the existing_box var, then you get a sampled box
    %
    % [boxes_r0rfc0cf, sample_density] = situation_model_normal_aa_sample( model, object_type, [n], [im_row im_col], existing_box_r0rfc0cf);
    % if you run with the existing_box var, the return box will match it,
    %   and the density will be the density of the box with respect to the
    %   model provided
    
    if ~exist('n','var') || isempty(n)
        n = 1;
    end
    
    if ~exist('im_dims','var')
        im_dims = [];
    end
    
    % if existing box was passed in, just figure out its density and return
    if exist('existing_box_r0rfc0cf','var') && ~isempty(existing_box_r0rfc0cf)
        
        lsf = sqrt( 1 / (im_dims(1)*im_dims(2)) ); % linear scaling factor
        r0 = lsf * (existing_box_r0rfc0cf(1) - im_dims(1)/2);
        rf = lsf * (existing_box_r0rfc0cf(2) - im_dims(1)/2);
        c0 = lsf * (existing_box_r0rfc0cf(3) - im_dims(2)/2);
        cf = lsf * (existing_box_r0rfc0cf(4) - im_dims(2)/2);
        rc = (r0 + rf) / 2;
        cc = (c0 + cf) / 2;
        w = cf - c0;
        h = rf - r0;
        log_aspect_ratio = log( w / h );
        log_area_ratio   = log( w * h ); % already normed to unit area image
        box_vect = [ r0 rc rf c0 cc cf log(w) log(h) log_aspect_ratio log_area_ratio ];

        if model.is_conditional
            sample_density = mvnpdf( box_vect, model.mu, model.Sigma );
            boxes_r0rfc0cf = existing_box_r0rfc0cf;
        else
            num_vars_per_obj = length(model.mu)/length(model.situation_objects);
            obj_ind          = find( strcmp( object_type, model.situation_objects ), 1, 'first' );
            sub_ind_0        = (obj_ind-1) * num_vars_per_obj + 1;
            sub_ind_f        = sub_ind_0 + num_vars_per_obj - 1;
            [mu_marginalized, Sigma_marginalized] = mvn_marginalize_and_condition( model.mu, model.Sigma, sub_ind_0:sub_ind_f, [], [] );
            sample_density = mvnpdf( box_vect, mu_marginalized, Sigma_marginalized );
            boxes_r0rfc0cf = existing_box_r0rfc0cf;
        end
        
        return;
    end
    
    
    
    raw_samples = mvnrnd( model.mu, model.Sigma, n);
    
    sample_density = mvnpdf( raw_samples, model.mu, model.Sigma );
    
    rc_col         = strcmp( 'rc',               model.parameters_description );
    cc_col         = strcmp( 'cc',               model.parameters_description );
    log_aspect_col = strcmp( 'log aspect ratio', model.parameters_description );
    log_area_col   = strcmp( 'log area ratio',   model.parameters_description );
    
    if model.is_conditional
        obj_samples = raw_samples;
    else
        % need to focus on the region of the vector that has the object of interest
        num_vars_per_obj = length(model.mu)/length(model.situation_objects);
        obj_ind     = find( strcmp( object_type, model.situation_objects ), 1, 'first' );
        sub_ind_0   = (obj_ind-1) * num_vars_per_obj + 1;
        sub_ind_f   = sub_ind_0 + num_vars_per_obj - 1;
        obj_samples = raw_samples(:, sub_ind_0:sub_ind_f );
    end
    
    rc     = obj_samples(:,rc_col);
    cc     = obj_samples(:,cc_col);
    aspect = exp(obj_samples(:,log_aspect_col));
    area   = exp(obj_samples(:,log_area_col));
    [w, h] = box_aa2wh( aspect, area );
    r0     = rc - h/2;
    rf     = r0 + h;
    c0     = cc - w/2;
    cf     = c0 + w;

    boxes_r0rfc0cf_unit = [r0 rf c0 cf];

    % if we have im_dims, rescale
    % else, return for unit box centered at origin
    if isempty(im_dims)
        boxes_r0rfc0cf = boxes_r0rfc0cf_unit;
    else
        r_mid = im_dims(1) / 2;
        c_mid = im_dims(2) / 2;
        lsf = sqrt(im_dims(1) * im_dims(2));
        
        r0 = round( lsf * boxes_r0rfc0cf_unit(:,1) + r_mid );
        rf = round( lsf * boxes_r0rfc0cf_unit(:,2) + r_mid );
        c0 = round( lsf * boxes_r0rfc0cf_unit(:,3) + c_mid );
        cf = round( lsf * boxes_r0rfc0cf_unit(:,4) + c_mid );
        
        r0 = max( r0, 1 );
        rf = min( rf, im_dims(1) );
       
        c0 = max( c0, 1 );
        cf = min( cf, im_dims(2) );
        
        boxes_r0rfc0cf = [r0 rf c0 cf];
        
        % recompute density based on changes
        [~, sample_density] = situation_model_normal_aa_sample( model, object_type, n, im_dims, [r0 rf c0 cf] );
        
        % ugh, if you've goofed this bad, just do it over
        if (r0>=rf) || (c0>=cf)
            [boxes_r0rfc0cf, sample_density] = situation_model_normal_aa_sample( model, object_type, n, im_dims );
        end
        
    end

end







