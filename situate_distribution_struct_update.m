function d = situate_distribution_struct_update( d, p, workspace )



%   d = situate_distribution_struct_update( d, p, workspace );
%
%   uses workspace info to update the existing distribution structure d
%   p specifies the parameters used to do this
%
%

    use_reinhibition = false;
    
    switch p.location_sampling_method_before_conditioning
        case {'ior_peaks','ior_sampling'}
            use_reinhibition = true;
    end
    
    switch p.location_sampling_method_after_conditioning
        case {'ior_peaks','ior_sampling'}
            use_reinhibition = true;
    end
    
    if p.use_distribution_tweaking
    
        % we should use tweaking now. 
        % we do this by adding a lot of attention to the region around
        % which this object was found, both in terms of location and in
        % terms of shape and size. 
        
        error('situate_distribution_struct_update:distribution tweaking not implemented yet');
        
    end
    


    % adjust object priority if it's committed to the workspace
        workspace_ind = find( strcmp( d.interest, workspace.labels ) );
        if  ~isempty(workspace_ind) && workspace.total_support(workspace_ind) >= p.thresholds.total_support_final
            d.interest_priority = p.situate_objects_posterior_urgency(strcmp(d.interest,p.situation_objects)); 
        end

    % should we condition this distribution based on what's in the workspace?
        is_time_to_condition = false;
        for cur_conditioning_object = d.conditioning_objects
            if any( strcmp(cur_conditioning_object, workspace.labels ) )
                is_time_to_condition = true;
            end
        end
       
    
    
    if ~is_time_to_condition
        return
    else
        
        d.location_sampling_method  = p.location_sampling_method_after_conditioning;
        d.location_method           = p.location_method_after_conditioning;
        d.box_method                = p.box_method_after_conditioning;

        % build reinhibition mask
        if use_reinhibition
            inhibition_width = p.inhibition_size;
            reinhibition_mask = ones( size(d.location_data,1) + 2*inhibition_width, size(d.location_data,2) + 2*inhibition_width );
            for i = 1:size(d.sampled_boxes_record_centers,1)
                r0 = d.sampled_boxes_record_centers(i,1) - ceil(inhibition_width/2) + 1 + inhibition_width;
                rf = r0 + inhibition_width - 1;
                c0 = d.sampled_boxes_record_centers(i,2) - ceil(inhibition_width/2) + 1 + inhibition_width;
                cf = c0 + inhibition_width - 1;
                reinhibition_mask( r0:rf, c0:cf ) = reinhibition_mask( r0:rf, c0:cf ) .* d.inhibition_mask;
            end
            reinhibition_mask = reinhibition_mask(inhibition_width+1:end-inhibition_width,inhibition_width+1:end-inhibition_width);
        else
            % no-change mask
            reinhibition_mask = ones( size(d.location_data,1), size(d.location_data,2) );
        end
        
        
        
        
        
        
        % gather info to send to the distribution update structure
        [relevant_workspace_objects,~,relevant_workspace_indices] = intersect( d.conditioning_objects, workspace.labels );
        relevant_boxes = workspace.boxes_r0rfc0cf( relevant_workspace_indices, : );  
        target_object  = d.interest;  
        
        switch length( relevant_workspace_indices )
            case 0
                box_a_raw = [];
                box_b_raw = [];
                box_c_raw = [];
            case 1
                box_a_raw = relevant_boxes(1,:);
                box_b_raw = [];
                box_c_raw = [];
            case 2
                box_a_raw = relevant_boxes(1,:);
                box_b_raw = relevant_boxes(2,:);
                box_c_raw = [];
            case 3
                box_a_raw = relevant_boxes(1,:);
                box_b_raw = relevant_boxes(2,:);
                box_c_raw = relevant_boxes(3,:);
        end
        
        
        
        
        
        
        % this stuff should be further down, method specific, and probably
        % a method of the distribution object
        %
        % this is the conditional model selector. this should all by
        % burried in the 'update' function for the current distribution
        % structure. for now, i'll just check to see that the conditional
        % model structure exists, and select the right part of it if it
        % does.
        if isfield(d.learned_stuff,'conditional_models_structure')
            [relevant_model, relevant_model_description] = conditional_model_selector( d.learned_stuff.conditional_models_structure, target_object, relevant_workspace_objects );
        else
            error('situate_distribution-struct_update:conditional models not present');
        end
        
        
        
        
        
        switch d.location_method
            case '4d'
                % it'll happen in the box method
            case 'uniform'
                d.location_data = ones( size(d.location_data,1), size(d.location_data,2) );
            case 'noise'
                d.location_data = rand( size(d.location_data,1), size(d.location_data,2) );
            case 'salience'
                d.location_data = d.hmaxq_data.salience_r + p.dist_xy_padding_value;
            case 'salience_blurry'
                blur_diameter = .3 * sqrt(p.image_redim_px);
                blur_filter = blackman(blur_diameter)*blackman(blur_diameter)';
                d.location_data = filtern( blur_filter, d.hmaxq_data.salience_r) + p.dist_xy_padding_value;
            case 'salience_center_surround'
                small_stack = d.hmaxq_data.c1a_r;
                center_surround_diameter = round( sqrt(size(small_stack,1)*size(small_stack,2)) );
                h_center_surround = center_surround( center_surround_diameter );
                center_surround_stack = filtern( h_center_surround, small_stack );
                d.location_data = mat2gray( imresize( sum( center_surround_stack, 3 ), d.image_size(1:2) ) ) + p.dist_xy_padding_value;
            case 'mvn_conditional_and_salience'
                [conditional_dist_xy, ~] = box_model_apply( relevant_model, [size(d.location_data,1) size(d.location_data,2)], box_a_raw, box_b_raw, box_c_raw );
                conditional_dist_xy = mat2gray(conditional_dist_xy);
                switch p.location_method_before_conditioning
                    case 'salience_blurry'
                        d.location_data = filtern( blackman(100)*blackman(100)', d.hmaxq_data.salience_r);
                    case 'salience_center_surround'
                        small_stack = d.hmaxq_data.c1a_r;
                        center_surround_diameter = round( sqrt(size(small_stack,1)*size(small_stack,2)) );
                        h_center_surround = center_surround( center_surround_diameter );
                        center_surround_stack = filtern( h_center_surround, small_stack );
                        d.location_data = mat2gray( imresize( sum( center_surround_stack, 3 ), d.image_size(1:2) ) );
                    otherwise % default to itti-elazary salience
                        d.location_data = d.hmaxq_data.salience_r;
                end
                d.location_data = d.location_data .* conditional_dist_xy + p.dist_xy_padding_value;
            case 'mvn_conditional'
                [conditional_dist_xy, ~] = box_model_apply( relevant_model, [size(d.location_data,1) size(d.location_data,2)], box_a_raw, box_b_raw, box_c_raw );
                d.location_data = conditional_dist_xy + p.dist_xy_padding_value;
                
            otherwise
                warning('newmethodwarning','new method code goes here');
                error('unrecognized location method');
        end
        d.location_data    = d.location_data .* reinhibition_mask;
        d.location_data    = d.location_data / sum(d.location_data(:));
        d.location_display = d.location_data;
        
        % some box model parameters
        area_ratio_min   = .01;
        area_ratio_max   = .5;
        aspect_ratio_min = .25;
        aspect_ratio_max = 4;
        discretization_n = 100;
        
        width_min  = .05 * sqrt(d.image_size_px);
        width_max  = .95 * sqrt(d.image_size_px);
        height_min = .05 * sqrt(d.image_size_px);
        height_max = .95 * sqrt(d.image_size_px);
        
        std_steps = 4;

        switch d.box_method
            
            case '4d_log_aa'
                
                % now this becomes the conditional mvn, in 4 d
                [conditional_xy, conditional_dist_box] = box_model_apply( relevant_model, [size(d.location_data,1) size(d.location_data,2)], box_a_raw, box_b_raw );
                
                % xy map
                pdf1_2 = d.box_data.pdf1_2_initial;
                conditional_xy = imresize(conditional_xy, size(pdf1_2));
                
                % aspect area map
                d.box_data.mu       = reshape(conditional_dist_box.mu_aa_log,[1,2]);
                d.box_data.Sigma     = conditional_dist_box.Sigma_aa_log;
                discretization_rows = d.box_data.discretization_n;
                discretization_cols = d.box_data.discretization_n;
                [pdf3_4, d.box_data.domains{3}, d.box_data.domains{4}]  = mvnpdf2empdist( d.box_data.mu, d.box_data.Sigma, discretization_rows, discretization_cols );
                
                dim1_2_block = repmat( pdf1_2 .* conditional_xy, 1, 1, size( pdf3_4, 1 ), size(pdf3_4,2 ) );
                dim3_4_block = repmat( reshape(pdf3_4,1,1,size(pdf3_4,1),size(pdf3_4,2)), size(pdf1_2,1), size(pdf1_2,2), 1, 1 );
                
                temp = dim1_2_block .* dim3_4_block;
                padding = p.dist_xy_padding_value;
                pdf4d_temp = (1-padding) * mat2gray(temp) + padding;
                
                d.box_display.method = 'none';
                
                % still need to reinhibit
                reinhibition_block = ior_4d_reinhibition_block( size(d.box_data.pdf4d), d.box_data.domains, d.box_data.inhibition_widths, p.inhibition_intensity, d.sampled_boxes_record_r0rfc0cf );
                d.box_data.pdf4d = pdf4d_temp .* reinhibition_block;
                
            case 'independent_uniform_log_aa'
                d.box_data.pdf1.x = linspace( log2(aspect_ratio_min), log2(aspect_ratio_max), discretization_n );
                d.box_data.pdf1.y = ones(1,discretization_n) / discretization_n;
                d.box_data.pdf2.x = linspace( log10(area_ratio_min), log10(area_ratio_max), discretization_n );
                d.box_data.pdf2.y = ones(1,discretization_n) / discretization_n;
                d.box_display.method = 'plots';
                d.box_display.x1 = d.box_data.pdf1.x;
                d.box_display.y1 = d.box_data.pdf1.y;
                d.box_display.label1 = {'log2 aspect ratio','(width/height)'};
                d.box_display.x2 = d.box_data.pdf2.x;
                d.box_display.y2 = d.box_data.pdf2.y;
                d.box_display.label2 = 'log10 area ratio';
            case 'independent_uniform_log_wh'
                d.box_data.pdf1.x = linspace( log(width_min),  log(width_max),  discretization_n );
                d.box_data.pdf1.y = ones(1,discretization_n) / discretization_n;
                d.box_data.pdf2.x = linspace( log(height_min), log(height_max), discretization_n );
                d.box_data.pdf2.y = ones(1,discretization_n) / discretization_n;
                d.box_display.method = 'plots';
                d.box_display.x1 = d.box_data.pdf1.x;
                d.box_display.y1 = d.box_data.pdf1.y;
                d.box_display.label1 = 'log width';
                d.box_display.x2 = d.box_data.pdf2.x;
                d.box_display.y2 = d.box_data.pdf2.y;
                d.box_display.label2 = 'log height';
            case 'independent_uniform_aa'
                d.box_data.pdf1.x = linspace( aspect_ratio_min, aspect_ratio_max, discretization_n );
                d.box_data.pdf1.y = ones(1,discretization_n) / discretization_n;
                
                d.box_data.pdf2.x = linspace( area_ratio_min, area_ratio_max, discretization_n );
                d.box_data.pdf2.y = ones(1,discretization_n) / discretization_n;
                
                d.box_display.method = 'plots';
                
                d.box_display.x1 = d.box_data.pdf1.x;
                d.box_display.y1 = d.box_data.pdf1.y;
                d.box_display.label1 = {'aspect ratio','(width/height)'};
                
                d.box_display.x2 = d.box_data.pdf2.x;
                d.box_display.y2 = d.box_data.pdf2.y;
                d.box_display.label2 = 'area ratio';
            case 'independent_uniform_wh'
                d.box_data.pdf1.x = linspace( width_min, width_max, discretization_n );
                d.box_data.pdf1.y = ones(1,discretization_n) / discretization_n;
                
                d.box_data.pdf2.x = linspace( height_min, height_max, discretization_n );
                d.box_data.pdf2.y = ones(1,discretization_n) / discretization_n;
                
                d.box_display.method = 'plots';
                
                d.box_display.x1 = d.box_data.pdf1.x;
                d.box_display.y1 = d.box_data.pdf1.y;
                d.box_display.label1 = 'width (pixels)';
                
                d.box_display.x2 = d.box_data.pdf2.x;
                d.box_display.y2 = d.box_data.pdf2.y;
                d.box_display.label2 = 'height (pixels)';
            
            
                
            case 'independent_normals_log_aa'
                interest_index = find(strcmp( d.interest, d.learned_stuff.conditional_models_structure.labels_in_indexing_order ));
                none_index     = find(strcmp( 'none',     d.learned_stuff.conditional_models_structure.labels_in_indexing_order ));
                m = d.learned_stuff.conditional_models_structure.models{interest_index,none_index,none_index}.independent_box_models;
                
                d.box_display.method = 'plots';

                mu    = m.log_aa.mu_log2_aspect_ratio;
                sigma = m.log_aa.sigma_log2_aspect_ratio;
                d.box_data.pdf1.mu    = mu;
                d.box_data.pdf1.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x1 = x;
                d.box_display.y1 = normpdf( x, mu, sigma );
                d.box_display.label1 = {'log2 aspect ratio','(width/height)'};

                mu    = m.log_aa.mu_log10_area_ratio;
                sigma = m.log_aa.sigma_log10_area_ratio;
                d.box_data.pdf2.mu = mu;
                d.box_data.pdf2.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x2 = x;
                d.box_display.y2 = normpdf(x,mu,sigma);
                d.box_display.label2 = 'log10 area ratio';
                
                assert( isreal( d.box_data.pdf1.mu ) );
                assert( isreal( d.box_data.pdf1.sigma ) );
                assert( isreal( d.box_data.pdf2.mu ) );
                assert( isreal( d.box_data.pdf2.sigma ) );
                
                
            case 'independent_normals_log_wh'
                interest_index = find(strcmp( d.interest, d.learned_stuff.conditional_models_structure.labels_in_indexing_order ));
                none_index     = find(strcmp( 'none',     d.learned_stuff.conditional_models_structure.labels_in_indexing_order ));
                m = d.learned_stuff.conditional_models_structure.models{interest_index,none_index,none_index}.independent_box_models;
                
                d.box_display.method = 'plots';
                
                mu    = m.log_wh.mu_log_w;
                sigma = m.log_wh.sigma_log_w;
                d.box_data.pdf1.mu    = mu;
                d.box_data.pdf1.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x1 = x;
                d.box_display.y1 = normpdf( x, mu, sigma );
                d.box_display.label1 = 'log width';

                mu    = m.log_wh.mu_log_h;
                sigma = m.log_wh.sigma_log_h;
                d.box_data.pdf2.mu    = mu;
                d.box_data.pdf2.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x2 = x;
                d.box_display.y2 = normpdf( x, mu, sigma );
                d.box_display.label2 = 'log height';
                
                assert( isreal( d.box_data.pdf1.mu ) );
                assert( isreal( d.box_data.pdf1.sigma ) );
                assert( isreal( d.box_data.pdf2.mu ) );
                assert( isreal( d.box_data.pdf2.sigma ) );
                
            case 'independent_normals_aa'
                interest_index = find(strcmp( d.interest, d.learned_stuff.conditional_models_structure.labels_in_indexing_order ));
                none_index     = find(strcmp( 'none',     d.learned_stuff.conditional_models_structure.labels_in_indexing_order ));
                m = d.learned_stuff.conditional_models_structure.models{interest_index,none_index,none_index}.independent_box_models;
                
                d.box_display.method = 'plots';

                mu    = m.aa.mu_aspect_ratio;
                sigma = m.aa.sigma_aspect_ratio;
                d.box_data.pdf1.mu    = mu;
                d.box_data.pdf1.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x1 = x;
                d.box_display.y1 = normpdf( x, mu, sigma );
                d.box_display.label1 = {'aspect ratio','(width/height)'};

                mu    = m.aa.mu_area_ratio;
                sigma = m.aa.sigma_area_ratio;
                d.box_data.pdf2.mu    = mu;
                d.box_data.pdf2.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x2 = x;
                d.box_display.y2 = normpdf( x, mu, sigma );
                d.box_display.label2 = 'area ratio';
                
                assert( isreal( d.box_data.pdf1.mu ) );
                assert( isreal( d.box_data.pdf1.sigma ) );
                assert( isreal( d.box_data.pdf2.mu ) );
                assert( isreal( d.box_data.pdf2.sigma ) );
                
            case 'independent_normals_wh'
                interest_index = find(strcmp( d.interest, d.learned_stuff.conditional_models_structure.labels_in_indexing_order ));
                none_index     = find(strcmp( 'none',     d.learned_stuff.conditional_models_structure.labels_in_indexing_order ));
                m = d.learned_stuff.conditional_models_structure.models{interest_index,none_index,none_index}.independent_box_models;
                
                d.box_display.method = 'plots';
                
                mu    = m.wh.mu_w;
                sigma = m.wh.sigma_w;
                d.box_data.pdf1.mu    = mu;
                d.box_data.pdf1.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x1 = x;
                d.box_display.y1 = normpdf( x, mu, sigma );
                d.box_display.label1 = 'width (pixels)';

                mu    = m.wh.mu_h;
                sigma = m.wh.sigma_h;
                d.box_data.pdf2.mu    = mu;
                d.box_data.pdf2.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x2 = x;
                d.box_display.y2 = normpdf( x, mu, sigma );
                d.box_display.label2 = 'height (pixels)';
                
                assert( isreal( d.box_data.pdf1.mu ) );
                assert( isreal( d.box_data.pdf1.sigma ) );
                assert( isreal( d.box_data.pdf2.mu ) );
                assert( isreal( d.box_data.pdf2.sigma ) );
                
            case 'conditional_mvn_wh'
                [~, conditional_dist_box] = box_model_apply( relevant_model, [size(d.location_data,1) size(d.location_data,2)], box_a_raw, box_b_raw );
                d.box_data.mu           = reshape(conditional_dist_box.mu_wh,[1,2]);
                d.box_data.Sigma        = conditional_dist_box.Sigma_wh;
                % d.box_display.method    = 'map';
                % d.box_display.xlabel    = 'width (in pixels)';
                % d.box_display.ylabel    = 'height (in pixels)';
                % rows = 200;
                % cols = 100;
                % [map, xvals, yvals]  = mvnpdf2empdist( d.box_data.mu, d.box_data.Sigma, rows, cols );
                % d.box_display.xrange = xvals;
                % d.box_display.yrange = yvals;
                % d.box_display.map    = map;
                % d.box_display.marginal_x = sum( map, 1 ) / sum(map(:));
                % d.box_display.marginal_y = sum( map, 2 ) / sum(map(:));
                
                d.box_display.method    = 'plots';
                std_steps = 3;
                discretization_n = 200;
                
                mu = d.box_data.mu(1);
                sigma = d.box_data.Sigma(1,1);
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x1 = x;
                d.box_display.y1 = normpdf( x, mu, sigma );
                d.box_display.label1 = 'width (pixels)';
                
                mu = d.box_data.mu(2);
                sigma = d.box_data.Sigma(2,2);
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x2 = x;
                d.box_display.y2 = normpdf( x, mu, sigma );
                d.box_display.label1 = 'height (pixels)';
                
                assert( isreal( d.box_data.mu ));
                assert( isreal( d.box_data.Sigma ));
                
            case 'conditional_mvn_log_wh'
                [~, conditional_dist_box] = box_model_apply( relevant_model, [size(d.location_data,1) size(d.location_data,2)], box_a_raw, box_b_raw );
                d.box_data.mu           = reshape(conditional_dist_box.mu_wh_log,[1,2]);
                d.box_data.Sigma        = conditional_dist_box.Sigma_wh_log;
                % d.box_display.method    = 'map';
                % d.box_display.xlabel    = 'log width (in pixels)';
                % d.box_display.ylabel    = 'log height (in pixels)';
                % rows = 200;
                % cols = 100;
                % [map, xvals, yvals]  = mvnpdf2empdist( d.box_data.mu, d.box_data.Sigma, rows, cols );
                % d.box_display.xrange = xvals;
                % d.box_display.yrange = yvals;
                % d.box_display.map    = map;
                % d.box_display.marginal_x = sum( map, 1 ) / sum(map(:));
                % d.box_display.marginal_y = sum( map, 2 ) / sum(map(:));
                
                d.box_display.method    = 'plots';
                
                std_steps = 3;
                discretization_n = 200;
                
                mu = d.box_data.mu(1);
                sigma = d.box_data.Sigma(1,1);
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x1 = x;
                d.box_display.y1 = normpdf( x, mu, sigma );
                d.box_display.label1 = 'log width (pixels)';
                
                mu = d.box_data.mu(2);
                sigma = d.box_data.Sigma(2,2);
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x2 = x;
                d.box_display.y2 = normpdf( x, mu, sigma );
                d.box_display.label1 = 'log height (pixels)';
                
                assert( isreal( d.box_data.mu ));
                assert( isreal( d.box_data.Sigma ));
                
            case 'conditional_mvn_aa'
                [~, conditional_dist_box] = box_model_apply( relevant_model, [size(d.location_data,1) size(d.location_data,2)], box_a_raw, box_b_raw );
                d.box_data.mu           = reshape(conditional_dist_box.mu_aa,[1,2]);
                d.box_data.Sigma        = conditional_dist_box.Sigma_aa;
                % d.box_display.method    = 'map';
                % d.box_display.xlabel    = {'aspect ratio','(width/height)'};
                % d.box_display.ylabel    = 'area ratio';
                % rows = 200;
                % cols = 100;
                % [map, xvals, yvals]  = mvnpdf2empdist( d.box_data.mu, d.box_data.Sigma, rows, cols );
                % d.box_display.xrange = xvals;
                % d.box_display.yrange = yvals;
                % d.box_display.map    = map;
                % d.box_display.marginal_x = sum( map, 1 ) / sum(map(:));
                % d.box_display.marginal_y = sum( map, 2 ) / sum(map(:));
                
                d.box_display.method    = 'plots';
                
                std_steps = 3;
                discretization_n = 200;
                
                mu = d.box_data.mu(1);
                sigma = d.box_data.Sigma(1,1);
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x1 = x;
                d.box_display.y1 = normpdf( x, mu, sigma );
                d.box_display.label1 = {'aspect ratio','(width/height)'};
                
                mu = d.box_data.mu(2);
                sigma = d.box_data.Sigma(2,2);
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x2 = x;
                d.box_display.y2 = normpdf( x, mu, sigma );
                d.box_display.label1 = 'area ratio';
                
                assert( isreal( d.box_data.mu ));
                assert( isreal( d.box_data.Sigma ));
                
            case 'conditional_mvn_log_aa'
                [~, conditional_dist_box] = box_model_apply( relevant_model, [size(d.location_data,1) size(d.location_data,2)], box_a_raw, box_b_raw );
                d.box_data.mu           = reshape(conditional_dist_box.mu_aa_log,[1,2]);
                d.box_data.Sigma        = conditional_dist_box.Sigma_aa_log;
                % d.box_display.method    = 'map';
                % d.box_display.xlabel    = {'log2 aspect ratio','(width/height)'};
                % d.box_display.ylabel    = 'log10 area ratio';
                % rows = 200;
                % cols = 100;
                % [map, xvals, yvals]  = mvnpdf2empdist( d.box_data.mu, d.box_data.Sigma, rows, cols );
                % d.box_display.xrange = xvals;
                % d.box_display.yrange = yvals;
                % d.box_display.map    = map;
                % d.box_display.marginal_x = sum( map, 1 ) / sum(map(:));
                % d.box_display.marginal_y = sum( map, 2 ) / sum(map(:));

                d.box_display.method    = 'plots';
                
                std_steps = 3;
                discretization_n = 200;
                
                mu = d.box_data.mu(1);
                sigma = d.box_data.Sigma(1,1);
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x1 = x;
                d.box_display.y1 = normpdf( x, mu, sigma );
                d.box_display.label1 = {'log2 aspect ratio','(width/height)'};
                
                mu = d.box_data.mu(2);
                sigma = d.box_data.Sigma(2,2);
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, discretization_n );
                d.box_display.x2 = x;
                d.box_display.y2 = normpdf( x, mu, sigma );
                d.box_display.label1 = 'log10 area ratio';
                
                assert( isreal( d.box_data.mu ));
                assert( isreal( d.box_data.Sigma ));
                
            otherwise
                warning('all:newmethodwarning','new method code goes here');
                error('unrecognized box method');
        end
    
        
        
    end
    
    
    
    
    
    
    
    
    
    
    
end










