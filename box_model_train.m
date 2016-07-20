
function models = box_model_train( target_boxes, data_boxes_a, data_boxes_b, data_boxes_c )


% models = box_model_train(target_boxes, data_boxes_a, data_boxes_b, data_boxes_c, specification);
%
% boxes should be xywh format (not centers)
% output d contains mean and covariance matrices to be used with
% box_model_apply_mq.
% The boxes are assumed to be scaled already, so the unit area and zero
% centered stuff should happen outside of this.
%
% the restulting distributions are for box centers, 
% which does not match the input data, fyi
%
% see also
%   box_model_ts.m
%   box_model_apply.m



args_exist = [false false false];
if exist('target_boxes','var') && ~isempty(target_boxes)
    args_exist(1) = true;
else
    error('at least need some target boxes')
end
if exist('data_boxes_a','var') && ~isempty(data_boxes_a)
    args_exist(2) = true;
end
if exist('data_boxes_b','var') && ~isempty(data_boxes_b)
    args_exist(3) = true;
end
if exist('data_boxes_b','var') && ~isempty(data_boxes_b)
    args_exist(3) = true;
end
if exist('data_boxes_c','var') && ~isempty(data_boxes_c)
    args_exist(4) = true;
end


switch sum(args_exist)
    case 0, error('box_model:not enough inputs');
    case 1, number_localized_objs = 0;
    case 2, number_localized_objs = 1;
        while isempty(data_boxes_a)
            data_boxes_a = data_boxes_b;
            data_boxes_b = data_boxes_c;
            data_boxes_c = [];
        end
    case 3, number_localized_objs = 2;
        while isempty(data_boxes_a)
            data_boxes_a = data_boxes_b;
            data_boxes_b = data_boxes_c;
            data_boxes_c = [];
        end
        while isempty(data_boxes_b)
            data_boxes_b = data_boxes_c;
            data_boxes_c = [];
        end
    case 4, number_localized_objs = 3;
end



models = [];
models.note = {'wh_log uses natural log'; 'aa_log uses log2 for aspect ratio, log10 for area ratio'};



% okay, we now know how many there are, and if they're non-empty. 

% get box centers, aspect ratios, area ratios

    xc_target = target_boxes(:,1) + target_boxes(:,3)/2;
    yc_target = target_boxes(:,2) + target_boxes(:,4)/2;
    center_target = [xc_target yc_target];
    aspect_ratios_target = target_boxes(:,3) ./ target_boxes(:,4);
    area_ratios_target   = target_boxes(:,3) .* target_boxes(:,4);
    
    if number_localized_objs >= 1

        xc_boxa = data_boxes_a(:,1) + data_boxes_a(:,3)/2;
        yc_boxa = data_boxes_a(:,2) + data_boxes_a(:,4)/2;
        center_box_a = [xc_boxa yc_boxa];
        aspect_ratios_box_a = data_boxes_a(:,3) ./ data_boxes_a(:,4);
        area_ratios_box_a   = data_boxes_a(:,3) .* data_boxes_a(:,4);
    
    end

    if number_localized_objs >= 2

        xc_boxb = data_boxes_b(:,1) + data_boxes_b(:,3)/2;
        yc_boxb = data_boxes_b(:,2) + data_boxes_b(:,4)/2;
        center_box_b = [xc_boxb yc_boxb];
        aspect_ratios_box_b = data_boxes_b(:,3) ./ data_boxes_b(:,4);
        area_ratios_box_b   = data_boxes_b(:,3) .* data_boxes_b(:,4);

    end
    
    if number_localized_objs >= 3

        xc_boxc = data_boxes_c(:,1) + data_boxes_c(:,3)/2;
        yc_boxc = data_boxes_c(:,2) + data_boxes_c(:,4)/2;
        center_box_c = [xc_boxc yc_boxc];
        aspect_ratios_box_c = data_boxes_c(:,3) ./ data_boxes_c(:,4);
        area_ratios_box_c   = data_boxes_c(:,3) .* data_boxes_c(:,4);

    end

% build the models

    % build the simple, independent distributions for box shape and size
    models.independent_box_models.wh.mu_w = mean(target_boxes(:,3));
    models.independent_box_models.wh.mu_h = mean(target_boxes(:,4));
    models.independent_box_models.log_wh.mu_log_w = mean(log(target_boxes(:,3)));
    models.independent_box_models.log_wh.mu_log_h = mean(log(target_boxes(:,4)));
    models.independent_box_models.aa.mu_aspect_ratio = mean(aspect_ratios_target);
    models.independent_box_models.aa.mu_area_ratio   = mean(area_ratios_target);
    models.independent_box_models.log_aa.mu_log2_aspect_ratio = mean(log2( aspect_ratios_target));
    models.independent_box_models.log_aa.mu_log10_area_ratio  = mean(log10(area_ratios_target));
    
    if isempty(data_boxes_a) && isempty(data_boxes_b) && isempty(data_boxes_c)
        if ~isreal(models.independent_box_models.log_aa.mu_log2_aspect_ratio) || ...
           ~isreal(models.independent_box_models.log_aa.mu_log10_area_ratio)
            display('boop'); 
        end
    end
    
    models.independent_box_models.wh.sigma_w                        = std(target_boxes(:,3));
    models.independent_box_models.wh.sigma_h                        = std(target_boxes(:,4));
    models.independent_box_models.log_wh.sigma_log_w                = std(log(target_boxes(:,3)));
    models.independent_box_models.log_wh.sigma_log_h                = std(log(target_boxes(:,4)));
    models.independent_box_models.aa.sigma_aspect_ratio             = std(aspect_ratios_target);
    models.independent_box_models.aa.sigma_area_ratio               = std(area_ratios_target);
    models.independent_box_models.log_aa.sigma_log2_aspect_ratio    = std(log2( aspect_ratios_target));
    models.independent_box_models.log_aa.sigma_log10_area_ratio     = std(log10(area_ratios_target));
     
    % now the unconditioned, but dependent MVN
    models.mu_xy_target     = mean( center_target );
    models.mu_wh_target     = mean( target_boxes(:,[3 4] ) );
    models.mu_wh_log_target = mean( log(target_boxes(:,[3 4])) );
    models.mu_aa_target     = mean( [ aspect_ratios_target area_ratios_target ] );
    models.mu_aa_log_target = mean( [ log2(aspect_ratios_target) log10(area_ratios_target) ] );
    
    models.Sigma_xy_target     = cov( center_target );
    models.Sigma_wh_target     = cov( target_boxes(:,[3 4]) );
    models.Sigma_wh_log_target = cov( log(target_boxes(:,[3 4])) );
    models.Sigma_aa_target     = cov( [ aspect_ratios_target area_ratios_target ] );
    models.Sigma_aa_log_target = cov( [ log2(aspect_ratios_target) log10(area_ratios_target) ] );
    
    [~,err1] = cholcov(models.Sigma_xy_target);
    [~,err2] = cholcov(models.Sigma_wh_target);
    [~,err3] = cholcov(models.Sigma_wh_log_target);
    [~,err4] = cholcov(models.Sigma_aa_target);
    [~,err5] = cholcov(models.Sigma_aa_log_target);
    if any([err1 err2 err3 err4 err5])
        error('some of the data is grumpy');
    end
    
    
   
    if number_localized_objs >= 1

        models.mu_xy_ta     = mean( [center_target center_box_a] );
        models.mu_wh_ta     = mean( [target_boxes(:,[3 4]) data_boxes_a(:,[3 4])] );
        models.mu_wh_log_ta = mean( [log(target_boxes(:,[3 4])) log(data_boxes_a(:,[3 4]))] );
        models.mu_aa_ta     = mean( [aspect_ratios_target area_ratios_target aspect_ratios_box_a area_ratios_box_a] );
        models.mu_aa_log_ta = mean( [log2(aspect_ratios_target) log10(area_ratios_target) log2(aspect_ratios_box_a) log10(area_ratios_box_a)] );
        
        models.Sigma_xy_ta     = cov( [center_target center_box_a] );
        models.Sigma_wh_ta     = cov( [target_boxes(:,[3 4]) data_boxes_a(:,[3 4])] );
        models.Sigma_wh_log_ta = cov( [log(target_boxes(:,[3 4])) log(data_boxes_a(:,[3 4]))] );
        models.Sigma_aa_ta     = cov( [aspect_ratios_target area_ratios_target aspect_ratios_box_a area_ratios_box_a] );
        models.Sigma_aa_log_ta = cov( [log2(aspect_ratios_target) log10(area_ratios_target) log2(aspect_ratios_box_a) log10(area_ratios_box_a)] );
        
        [~,err1] = cholcov(models.Sigma_xy_ta);
        [~,err2] = cholcov(models.Sigma_wh_ta);
        [~,err3] = cholcov(models.Sigma_wh_log_ta);
        [~,err4] = cholcov(models.Sigma_aa_ta);
        [~,err5] = cholcov(models.Sigma_aa_log_ta);
        if any([err1 err2 err3 err4 err5])
            error('some of the data is grumpy');
        end
        
    end

    if number_localized_objs >= 2

        models.mu_xy_tab        = mean( [center_target center_box_a center_box_b] );
        models.mu_wh_tab        = mean( [target_boxes(:,[3 4]) data_boxes_a(:,[3 4]) data_boxes_b(:,[3 4])] );
        models.mu_wh_log_tab    = mean( [log(target_boxes(:,[3 4])) log(data_boxes_a(:,[3 4])) log(data_boxes_b(:,[3 4]))] );
        models.mu_aa_tab        = mean( [aspect_ratios_target area_ratios_target aspect_ratios_box_a area_ratios_box_a aspect_ratios_box_b area_ratios_box_b] );
        models.mu_aa_log_tab    = mean( [log2(aspect_ratios_target) log10(area_ratios_target) log2(aspect_ratios_box_a) log10(area_ratios_box_a) log2(aspect_ratios_box_b) log10(area_ratios_box_b)] );
       
        models.Sigma_xy_tab     = cov( [center_target center_box_a center_box_b] );
        models.Sigma_wh_tab     = cov( [target_boxes(:,[3 4]) data_boxes_a(:,[3 4]) data_boxes_b(:,[3 4])] );
        models.Sigma_wh_log_tab = cov( [log(target_boxes(:,[3 4])) log(data_boxes_a(:,[3 4])) log(data_boxes_b(:,[3 4]))] );
        models.Sigma_aa_tab     = cov( [aspect_ratios_target area_ratios_target aspect_ratios_box_a area_ratios_box_a aspect_ratios_box_b area_ratios_box_b] );
        models.Sigma_aa_log_tab = cov( [log2(aspect_ratios_target) log10(area_ratios_target) log2(aspect_ratios_box_a) log10(area_ratios_box_a) log2(aspect_ratios_box_b) log10(area_ratios_box_b)] );
        
        [~,err1] = cholcov(models.Sigma_xy_tab);
        [~,err2] = cholcov(models.Sigma_wh_tab);
        [~,err3] = cholcov(models.Sigma_wh_log_tab);
        [~,err4] = cholcov(models.Sigma_aa_tab);
        [~,err5] = cholcov(models.Sigma_aa_log_tab);
        if any([err1 err2 err3 err4 err5])
            error('some of the data is grumpy');
        end
        
    end
    
    if number_localized_objs >= 3

        models.mu_xy_tabc        = mean( [center_target center_box_a center_box_b center_box_c] );
        models.mu_wh_tabc        = mean( [target_boxes(:,[3 4]) data_boxes_a(:,[3 4]) data_boxes_b(:,[3 4]) data_boxes_c(:,[3 4])] );
        models.mu_wh_log_tabc    = mean( [log(target_boxes(:,[3 4])) log(data_boxes_a(:,[3 4])) log(data_boxes_b(:,[3 4])) log(data_boxes_c(:,[3 4]))] );
        models.mu_aa_tabc        = mean( [aspect_ratios_target area_ratios_target aspect_ratios_box_a area_ratios_box_a aspect_ratios_box_b area_ratios_box_b aspect_ratios_box_c area_ratios_box_c] );
        models.mu_aa_log_tabc    = mean( [log2(aspect_ratios_target) log10(area_ratios_target) log2(aspect_ratios_box_a) log10(area_ratios_box_a) log2(aspect_ratios_box_b) log10(area_ratios_box_b) log2(aspect_ratios_box_c) log10(area_ratios_box_c)] );
       
        models.Sigma_xy_tabc     = cov( [center_target center_box_a center_box_b center_box_c] );
        models.Sigma_wh_tabc     = cov( [target_boxes(:,[3 4]) data_boxes_a(:,[3 4]) data_boxes_b(:,[3 4]) data_boxes_c(:,[3 4])] );
        models.Sigma_wh_log_tabc = cov( [log(target_boxes(:,[3 4])) log(data_boxes_a(:,[3 4])) log(data_boxes_b(:,[3 4])) log(data_boxes_c(:,[3 4]))] );
        models.Sigma_aa_tabc     = cov( [aspect_ratios_target area_ratios_target aspect_ratios_box_a area_ratios_box_a aspect_ratios_box_b area_ratios_box_b aspect_ratios_box_c area_ratios_box_c] );
        models.Sigma_aa_log_tabc = cov( [log2(aspect_ratios_target) log10(area_ratios_target) log2(aspect_ratios_box_a) log10(area_ratios_box_a) log2(aspect_ratios_box_b) log10(area_ratios_box_b) log2(aspect_ratios_box_c) log10(area_ratios_box_c)] );
       
        [~,err1] = cholcov(models.Sigma_xy_tabc);
        [~,err2] = cholcov(models.Sigma_wh_tabc);
        [~,err3] = cholcov(models.Sigma_wh_log_tabc);
        [~,err4] = cholcov(models.Sigma_aa_tabc);
        [~,err5] = cholcov(models.Sigma_aa_log_tabc);
        if any([err1 err2 err3 err4 err5])
            error('some of the data is grumpy');
        end
        
    end
    
    if number_localized_objs >= 4
        error('too many localized objects for this hack to keep going');
    end
    
    % note: debug
    assert(all(structfun(@isreal,models.independent_box_models.aa)));
    assert(all(structfun(@isreal,models.independent_box_models.log_aa)));
    assert(all(structfun(@isreal,models.independent_box_models.log_wh)));
    assert(all(structfun(@isreal,models.independent_box_models.wh)));
    
    assert(isreal(models.mu_xy_target));
    assert(isreal(models.Sigma_xy_target));
    
    assert(isreal(models.mu_aa_log_target));
    assert(isreal(models.Sigma_aa_log_target));
    
    assert(isreal(models.mu_aa_target));
    assert(isreal(models.Sigma_aa_target));
    
    assert(isreal(models.mu_wh_log_target));
    assert(isreal(models.Sigma_wh_log_target));
    
    assert(isreal(models.mu_wh_target));
    assert(isreal(models.Sigma_wh_target));
    
    
    
    
end
    
    





