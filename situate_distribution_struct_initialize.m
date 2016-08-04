function d = situate_distribution_struct_initialize( interest, p, im, learned_stuff )

    % d = situate_distribution_struct_initialize( interest, p, im, models_structure )
    %
    % interest should be in {'dog','person','leash'}
    % im should be an image matrix
    % p has a lot of options 
    %
    % see also situate_parameters_initialize.m

    if isfield( learned_stuff, 'conditional_models_structure' )
        conditional_models_structure = learned_stuff.conditional_models_structure;
    end

    % things that distributions will always have

        d.interest = interest;
        d.interest_priority = p.situation_objects_prior_urgency(strcmp(interest,p.situation_objects));
        d.conditioning_objects = setsub( p.situation_objects, d.interest );

        d.image_size = [size(im,1) size(im,2) size(im,3)];
        d.image_size_px = size(im,1) * size(im,2);
        
    % define yourself
    
        d.location_sampling_method = p.location_sampling_method_before_conditioning;
        d.location_method          = p.location_method_before_conditioning;
        
    % will we need salience at some point?
        
        methods_using_salience = { ...
            'salience', ...
            'salience_blurry', ...
            'salience_center_surround', ...
            'mvn_conditional_and_salience' };
    
        if any(strcmp(p.location_method_before_conditioning, methods_using_salience)) ...
        || any(strcmp(p.location_method_after_conditioning,  methods_using_salience))
            d.hmaxq_data = hmaxq_im2c1( p.salience_model, im );
        end
        
    % location stuff
    
        % if we use IOR before or after conditioning, 
        % generate an inhibition mask
        if any(strcmp( p.location_sampling_method_before_conditioning, {'ior_sampling','ior_peaks'})) ...
        || any(strcmp( p.location_sampling_method_after_conditioning,  {'ior_sampling','ior_peaks'}))
            switch p.inhibition_method
                case 'blackman'
                    d.inhibition_mask = 1 - (p.inhibition_intensity * blackmann(p.inhibition_size) );
                case 'disk'
                    d.inhibition_mask = 1 - (p.inhibition_intensity * disk(p.inhibition_size) );
                otherwise
                    error('initialize_distribution_struct_v2:unrecognized inhibition type');
            end
        end

        switch d.location_method
            case 'salience'
                d.location_data = d.hmaxq_data.salience_r + p.dist_xy_padding_value;
            case 'salience_blurry'
                blur_diameter = .3 * sqrt(p.image_redim_px);
                blur_filter = blackman(blur_diameter)*blackman(blur_diameter)';
                sal_map = filtern( blur_filter, d.hmaxq_data.salience_r );
                d.location_data = sal_map + p.dist_xy_padding_value;
            case 'salience_center_surround'
                small_stack = d.hmaxq_data.c1a_r;
                center_surround_diameter = round( sqrt(size(small_stack,1)*size(small_stack,2)) );
                h_center_surround = center_surround( center_surround_diameter );
                center_surround_stack = filtern( h_center_surround, small_stack );
                d.location_data = mat2gray( imresize( sum( center_surround_stack, 3 ), d.image_size(1:2) ) ) + p.dist_xy_padding_value;
            case 'uniform'
                d.location_data = ones( size(im,1), size(im,2) );
            case 'noise'
                d.location_data = rand( size(im,1), size(im,2) );
            otherwise
                warning('all:newmethodwarning','new method code goes here');
                error('initialize_distribution_struct_v2:unrecognized p.location_method_before_conditioning');
        end

        d.location_data = (d.location_data) / sum(d.location_data(:)); % normalize, only really matters for sampling without IOR
        d.location_display = d.location_data;

    % box stuff    

        d.box_method = p.box_method_before_conditioning;
        
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
                if ~exist('conditional_models_structure','var') || isempty(conditional_models_structure), error('conditional models structure not provided'); end

                interest_index = find( strcmp( interest, conditional_models_structure.labels_in_indexing_order ), 1, 'first' ); 
                none_index     = find( strcmp( 'none',   conditional_models_structure.labels_in_indexing_order ) ); 
                
                m = conditional_models_structure.models{interest_index,none_index,none_index}.independent_box_models;
                d.box_display.method = 'none';
                d.box_data.inhibition_widths = p.sal4d_parameters.inhibition_widths;
                d.box_data.discretization_n  = p.sal4d_parameters.discretization_n;
                d.box_data.discretization_m  = p.sal4d_parameters.discretization_m;
                
                pdf1_2 = imresize_px(d.location_data, p.sal4d_parameters.salience_redim_px );
                d.box_data.domains{1} = linspace(1,size(im,1), size(pdf1_2,1));
                d.box_data.domains{2} = linspace(1,size(im,2), size(pdf1_2,2));

                mu    = m.log_aa.mu_log2_aspect_ratio;
                sigma = m.log_aa.sigma_log2_aspect_ratio;
                d.box_data.pdf1.mu    = mu;
                d.box_data.pdf1.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, d.box_data.discretization_n  );
                pdf3 = normpdf( x, mu, sigma );
                d.box_data.domains{3} = x;

                mu    = m.log_aa.mu_log10_area_ratio;
                sigma = m.log_aa.sigma_log10_area_ratio;
                d.box_data.pdf2.mu = mu;
                d.box_data.pdf2.sigma = sigma;
                xmin = mu - std_steps * sigma;
                xmax = mu + std_steps * sigma;
                x = linspace( xmin, xmax, d.box_data.discretization_m  );
                pdf4 = normpdf( x, mu, sigma );
                d.box_data.domains{4} = x;

                % build the 4d block
                dim1_2_block = repmat( pdf1_2, 1, 1, length(d.box_data.domains{3}), length(d.box_data.domains{4}) );
                dim3_block  = repmat( reshape(pdf3,1,1,[],1), length(d.box_data.domains{1}), length(d.box_data.domains{2}), 1, length(d.box_data.domains{4}) );
                dim4_block  = repmat( reshape(pdf4,1,1,1,[]), length(d.box_data.domains{1}), length(d.box_data.domains{2}), length(d.box_data.domains{3}), 1 );

                temp = dim1_2_block .* dim3_block .* dim4_block;
                padding = p.dist_xy_padding_value;
                d.box_data.pdf4d = (1-padding) * mat2gray(temp) + padding;
                d.box_data.pdf1_2_initial = pdf1_2;

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

                if ~exist('conditional_models_structure','var') || isempty(conditional_models_structure), error('conditional models structure not provided'); end

                interest_index = find( strcmp( interest, conditional_models_structure.labels_in_indexing_order ), 1, 'first' ); 
                none_index     = find( strcmp( 'none',   conditional_models_structure.labels_in_indexing_order ) ); 
                
                if ndims(conditional_models_structure.models) == 3
                    m = conditional_models_structure.models{ interest_index, none_index, none_index}.independent_box_models;
                elseif ndims(conditional_models_structure.models) == 4
                    m = conditional_models_structure.models{ interest_index, none_index, none_index, none_index}.independent_box_models;
                end
                    
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
               
            case 'independent_normals_log_wh'
                
                if ~exist('conditional_models_structure','var') || isempty(conditional_models_structure), error('conditional models structure not provided'); end

                interest_index = find( strcmp( interest, conditional_models_structure.labels_in_indexing_order ), 1, 'first' ); 
                none_index     = find( strcmp( 'none',   conditional_models_structure.labels_in_indexing_order ) ); 
                
                if ndims(conditional_models_structure.models) == 3
                    m = conditional_models_structure.models{ interest_index, none_index, none_index}.independent_box_models;
                elseif ndims(conditional_models_structure.models) == 4
                    m = conditional_models_structure.models{ interest_index, none_index, none_index, none_index}.independent_box_models;
                end
                
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
               
            case 'independent_normals_aa'
                
                if ~exist('conditional_models_structure','var') || isempty(conditional_models_structure), error('conditional models structure not provided'); end

                interest_index = find( strcmp( interest, conditional_models_structure.labels_in_indexing_order ), 1, 'first' ); 
                none_index     = find( strcmp( 'none',   conditional_models_structure.labels_in_indexing_order ) ); 
                
                if ndims(conditional_models_structure.models) == 3
                    m = conditional_models_structure.models{ interest_index, none_index, none_index}.independent_box_models;
                elseif ndims(conditional_models_structure.models) == 4
                    m = conditional_models_structure.models{ interest_index, none_index, none_index, none_index}.independent_box_models;
                end
                
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
                
            case 'independent_normals_wh'
                
                if ~exist('conditional_models_structure','var') || isempty(conditional_models_structure), error('conditional models structure not provided'); end

                interest_index = find( strcmp( interest, conditional_models_structure.labels_in_indexing_order ), 1, 'first' ); 
                none_index     = find( strcmp( 'none',   conditional_models_structure.labels_in_indexing_order ) ); 
                
                if ndims(conditional_models_structure.models) == 3
                    m = conditional_models_structure.models{ interest_index, none_index, none_index}.independent_box_models;
                elseif ndims(conditional_models_structure.models) == 4
                    m = conditional_models_structure.models{ interest_index, none_index, none_index, none_index}.independent_box_models;
                end
                
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
                
            case {'conditional_mvn_wh', 'conditional_mvn_aa', 'conditional_mvn_log_wh', 'conditional_mvn_log_aa'}
                error([d.box_method ' not implemented for initial box distribution structure']);
                
            otherwise
                warning('newmethodwarning','new method code goes here');
               error('unrecognized box method');
        end
    
        d.sampled_boxes_record_r0rfc0cf   = zeros(0,4);
        d.sampled_boxes_record_centers    = zeros(0,2);
        % d.sampled_boxes_record_pdf4d_inds = zeros(0,4);
        d.reinhibition_mask = ones( size(im,1), size(im,2) );
        
    % conditional model stuff
    
        d.learned_stuff = learned_stuff;
       
end
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
