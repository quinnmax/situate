function [dist_xy, dist_box] = box_model_apply( d, output_size, box_a_raw, box_b_raw, box_c_raw )

    % [dist_xy, dist_box] = box_model_apply( distribution_structure, [output_size_rows, output_size_cols], box_a, box_b );
    %
    %   this takes: 
    %       the learned joint mvn of box shapes and locations in distribution_structure
    %       and
    %       observed boxes from the workspace (box_a_raw and box_b_raw)
    %   to generate conditional distributions for target location and box
    %   shape/size
    %
    %   for example, given a dog location box, what is the discrete conditional
    %   distribution for dog walker boxes (position and shape)
    %
    %   output_size is the size of the output location map, which should be
    %   the same as the size of the image that we're building maps for. it
    %   should be [rows, columns]
    %
    %
    % boxes a and b are input as r0rfc0cf, as they're stored in the situate workspace.
    % the scaling for being zero centered and unit area will happen in this function.
    %
    % the returned xy distribution is for the center of the target box,
    % that is, the center of a xc, yc, w, h box. 
    %
    % see also
    %   box_model_train.m 
    %   box_model_ts.m 
    
    num_args = 0;
    if exist('d','var') && ~isempty(d), num_args = num_args + 1; end
    if exist('output_size','var') && ~isempty(output_size), num_args = num_args + 1; end
    if exist('box_a_raw','var') && ~isempty(box_a_raw), num_args = num_args + 1; end
    if exist('box_b_raw','var') && ~isempty(box_b_raw), num_args = num_args + 1; end
    if exist('box_c_raw','var') && ~isempty(box_c_raw), num_args = num_args + 1; end
    
    switch num_args
        case 0, 
            error('box_model_apply:distribution structure not provided');
        case 1,
            error('box_model_apply:output size not specified'); 
    end
    
    % get our input grid figured out
    % assumes the unit image centered at 0 thing for all the data
    
    im_x = output_size(2);
    im_y = output_size(1);
    ppu = sqrt(im_x * im_y);
    
    x_min = -im_x/2/ppu;
    x_max =  im_x/2/ppu;

    y_min = -im_y/2/ppu;
    y_max =  im_y/2/ppu;
    
    x_domain = linspace(x_min,x_max,im_x);
    y_domain = linspace(y_min,y_max,im_y);
    [target_X,target_Y] = meshgrid(x_domain,y_domain);
    
    % for width/height distributions, we'll condition the input distributions on the boxes provided
    % and return the conditional mu/Sigma matrices. Those can then be
    % sampled from directly
    
    switch num_args
        
        case 2, 
            
            warning('box_model_apply: no workspace boxes, just returning target prior'); 
            
            p_xy_target_flat = mvnpdf( [target_X(:) target_Y(:)], d.mu_xy_target, d.Sigma_xy_target );
            dist_xy = reshape( p_xy_target_flat, [im_y im_x] );
            
            % no conditioning to do, so just grab target distributions from
            % what's stored in the model struct
            dist_box = [];
            dist_box.mu_wh        = d.mu_wh_target;
            dist_box.mu_wh_log    = d.mu_wh_log_target;
            dist_box.mu_aa        = d.mu_aa_target;
            dist_box.mu_aa_log    = d.mu_aa_log_target;
            dist_box.Sigma_wh     = d.Sigma_wh_target;
            dist_box.Sigma_wh_log = d.Sigma_wh_log_target;
            dist_box.Sigma_aa     = d.Sigma_aa_target;
            dist_box.Sigma_aa_log = d.Sigma_aa_log_target;
            
            dist_box.boxes_conditioned_on = [];
            
        case 3, 
            
            % we have 1 workspace box to condition on
            
            % shifting the r0rfc0cf to x0y0wh, rescale, center at 0
            box_a_xywh = [box_a_raw(3), box_a_raw(1), box_a_raw(4)-box_a_raw(3), box_a_raw(2)-box_a_raw(1)]; 
            r = 1/sqrt(im_x*im_y);
            box_a = r * [ box_a_xywh(1) - im_x/2, box_a_xywh(2) - im_y/2, box_a_xywh(3), box_a_xywh(4) ];
            
            % now from x0y0wh to xcycwh (centers)
            box_a_center_xy = [ box_a(1)+box_a(3)/2, box_a(2)+box_a(4)/2 ];
            
            % location distributions
            repeated_box_a_center = repmat(box_a_center_xy,length(target_X(:)),1);
            p_xy_target_flat = mvnpdf( ...
                [ target_X(:) target_Y(:) repeated_box_a_center ], ...
                d.mu_xy_ta, d.Sigma_xy_ta );
            
            dist_xy = reshape( p_xy_target_flat, [im_y im_x] );
            
            % box distributions
            box_a_wh = box_a(:,[3 4]);
            box_a_aa = [box_a(:,3) ./ box_a(:,4), box_a(:,3) * box_a(:,4) / 1 ];
            
             dist_box = [];
            [dist_box.mu_wh,     dist_box.Sigma_wh]     = mvn_conditional( d.mu_wh_ta,     d.Sigma_wh_ta,     [0 0 1 1], box_a_wh );
            [dist_box.mu_wh_log, dist_box.Sigma_wh_log] = mvn_conditional( d.mu_wh_log_ta, d.Sigma_wh_log_ta, [0 0 1 1], log(box_a_wh) );
            [dist_box.mu_aa,     dist_box.Sigma_aa]     = mvn_conditional( d.mu_aa_ta,     d.Sigma_aa_ta,     [0 0 1 1], box_a_aa );
            [dist_box.mu_aa_log, dist_box.Sigma_aa_log] = mvn_conditional( d.mu_aa_log_ta, d.Sigma_aa_log_ta, [0 0 1 1], [log2(box_a_aa(:,1)) log10(box_a_aa(:,2))] );
            
             dist_box.boxes_conditioned_on = box_a_xywh;

            
        case 4, 
            
            % we have 2 workspace boxes to condition on
            
            % shifting the r0rfc0cf to x0y0wh
            box_a_xywh = [box_a_raw(3), box_a_raw(1), box_a_raw(4)-box_a_raw(3), box_a_raw(2)-box_a_raw(1)]; 
            box_b_xywh = [box_b_raw(3), box_b_raw(1), box_b_raw(4)-box_b_raw(3), box_b_raw(2)-box_b_raw(1)]; 
            
            % scale for unit area image centered at 0
            r = 1/sqrt(im_x*im_y);
            box_a = r * [ box_a_xywh(1) - im_x/2, box_a_xywh(2) - im_y/2, box_a_xywh(3), box_a_xywh(4) ];
            box_b = r * [ box_b_xywh(1) - im_x/2, box_b_xywh(2) - im_y/2, box_b_xywh(3), box_b_xywh(4) ];
            
            % now from x0y0wh to xcycwh (centers)
            box_a_center_xy = [ box_a(1)+box_a(3)/2, box_a(2)+box_a(4)/2 ];
            box_b_center_xy = [ box_b(1)+box_b(3)/2, box_b(2)+box_b(4)/2 ];
            
            % location distributions
            %repeated_box_a_box_b_centers = repmat([box_a_center_xy box_b_center_xy],length(target_X(:)),1);
            %p_xy_target_flat = mvnpdf( ...
            %    [ target_X(:) target_Y(:) repeated_box_a_box_b_centers ], ...
            %    d.mu_xy_tab, d.Sigma_xy_tab );
            %dist_xy = reshape( p_xy_target_flat, [im_y im_x] );
            
            repeated_box_a_box_b_centers = repmat([box_a_center_xy box_b_center_xy],length(target_X(:)),1);
            p_xy_target_flat = mvnpdf( ...
                [ target_X(:) target_Y(:) repeated_box_a_box_b_centers ], ...
                d.mu_xy_tab, d.Sigma_xy_tab );
            dist_xy = reshape( p_xy_target_flat, [im_y im_x] );
            
            % now box distributions
            box_a_wh = box_a(:,[3 4]);
            box_b_wh = box_b(:,[3 4]);
            
            box_a_aa = [box_a(:,3) ./ box_a(:,4), box_a(:,3) * box_a(:,4) / 1 ];
            box_b_aa = [box_b(:,3) ./ box_b(:,4), box_b(:,3) * box_b(:,4) / 1 ];
            
            
             dist_box = [];
            [dist_box.mu_wh,     dist_box.Sigma_wh]     = mvn_conditional( d.mu_wh_tab,     d.Sigma_wh_tab,     [0 0 1 1 1 1], [box_a_wh box_b_wh] );
            [dist_box.mu_wh_log, dist_box.Sigma_wh_log] = mvn_conditional( d.mu_wh_log_tab, d.Sigma_wh_log_tab, [0 0 1 1 1 1], [log(box_a_wh) log(box_b_wh)] );
            [dist_box.mu_aa,     dist_box.Sigma_aa]     = mvn_conditional( d.mu_aa_tab,     d.Sigma_aa_tab,     [0 0 1 1 1 1], [box_a_aa box_b_aa] );
            [dist_box.mu_aa_log, dist_box.Sigma_aa_log] = mvn_conditional( d.mu_aa_log_tab, d.Sigma_aa_log_tab, [0 0 1 1 1 1], [log2(box_a_aa(:,1)) log10(box_a_aa(:,2)) log2(box_b_aa(:,1)) log10(box_b_aa(:,2))] );
           
             dist_box.boxes_conditioned_on = [box_a_xywh; box_b_xywh];
             
        case 5, 
            
            % we have 3 workspace boxes to condition on
            
            % shifting the r0rfc0cf to x0y0wh
            box_a_xywh = [box_a_raw(3), box_a_raw(1), box_a_raw(4)-box_a_raw(3), box_a_raw(2)-box_a_raw(1)]; 
            box_b_xywh = [box_b_raw(3), box_b_raw(1), box_b_raw(4)-box_b_raw(3), box_b_raw(2)-box_b_raw(1)]; 
            box_c_xywh = [box_c_raw(3), box_c_raw(1), box_c_raw(4)-box_c_raw(3), box_c_raw(2)-box_c_raw(1)];
            
            % scale for unit area image centered at 0
            r = 1/sqrt(im_x*im_y);
            box_a = r * [ box_a_xywh(1) - im_x/2, box_a_xywh(2) - im_y/2, box_a_xywh(3), box_a_xywh(4) ];
            box_b = r * [ box_b_xywh(1) - im_x/2, box_b_xywh(2) - im_y/2, box_b_xywh(3), box_b_xywh(4) ];
            box_c = r * [ box_c_xywh(1) - im_x/2, box_c_xywh(2) - im_y/2, box_c_xywh(3), box_c_xywh(4) ];
            
            % now from x0y0wh to xcycwh (centers)
            box_a_center_xy = [ box_a(1)+box_a(3)/2, box_a(2)+box_a(4)/2 ];
            box_b_center_xy = [ box_b(1)+box_b(3)/2, box_b(2)+box_b(4)/2 ];
            box_c_center_xy = [ box_c(1)+box_c(3)/2, box_c(2)+box_c(4)/2 ];
            
            % location distributions
            %repeated_box_a_box_b_centers = repmat([box_a_center_xy box_b_center_xy],length(target_X(:)),1);
            %p_xy_target_flat = mvnpdf( ...
            %    [ target_X(:) target_Y(:) repeated_box_a_box_b_centers ], ...
            %    d.mu_xy_tab, d.Sigma_xy_tab );
            %dist_xy = reshape( p_xy_target_flat, [im_y im_x] );
            
            repeated_box_a_box_b_box_c_centers = repmat([box_a_center_xy box_b_center_xy box_c_center_xy],length(target_X(:)),1);
            p_xy_target_flat = mvnpdf( ...
                [ target_X(:) target_Y(:) repeated_box_a_box_b_box_c_centers ], ...
                d.mu_xy_tabc, d.Sigma_xy_tabc );
            dist_xy = reshape( p_xy_target_flat, [im_y im_x] );
            
            % now box distributions
            box_a_wh = box_a(:,[3 4]);
            box_b_wh = box_b(:,[3 4]);
            box_c_wh = box_c(:,[3 4]);
            
            box_a_aa = [box_a(:,3) ./ box_a(:,4), box_a(:,3) * box_a(:,4) / 1 ];
            box_b_aa = [box_b(:,3) ./ box_b(:,4), box_b(:,3) * box_b(:,4) / 1 ];
            box_c_aa = [box_c(:,3) ./ box_c(:,4), box_c(:,3) * box_c(:,4) / 1 ];
            
            
             dist_box = [];
            [dist_box.mu_wh,     dist_box.Sigma_wh]     = mvn_conditional( d.mu_wh_tabc,     d.Sigma_wh_tabc,     [0 0 1 1 1 1 1 1], [box_a_wh box_b_wh box_c_wh] );
            [dist_box.mu_wh_log, dist_box.Sigma_wh_log] = mvn_conditional( d.mu_wh_log_tabc, d.Sigma_wh_log_tabc, [0 0 1 1 1 1 1 1], [log(box_a_wh) log(box_b_wh) log(box_c_wh)] );
            [dist_box.mu_aa,     dist_box.Sigma_aa]     = mvn_conditional( d.mu_aa_tabc,     d.Sigma_aa_tabc,     [0 0 1 1 1 1 1 1], [box_a_aa box_b_aa box_c_aa] );
            [dist_box.mu_aa_log, dist_box.Sigma_aa_log] = mvn_conditional( d.mu_aa_log_tabc, d.Sigma_aa_log_tabc, [0 0 1 1 1 1 1 1], [log2(box_a_aa(:,1)) log10(box_a_aa(:,2)) log2(box_b_aa(:,1)) log10(box_b_aa(:,2)) log2(box_c_aa(:,1)) log10(box_c_aa(:,2))] );
           
             dist_box.boxes_conditioned_on = [box_a_xywh; box_b_xywh; box_c_xywh];
            
        otherwise, 
            error('too many input boxes');
    
    end
    
    % note: debug
    assert(isreal(dist_xy));
    
    assert(isreal(dist_box.mu_wh));
    assert(isreal(dist_box.Sigma_wh));
    assert(isreal(dist_box.mu_wh_log));
    assert(isreal(dist_box.Sigma_wh_log));
    assert(isreal(dist_box.mu_aa));
    assert(isreal(dist_box.Sigma_aa));
    assert(isreal(dist_box.mu_aa_log));
    assert(isreal(dist_box.Sigma_aa_log));
    
end
 
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    