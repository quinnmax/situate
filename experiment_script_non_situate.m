

% this goes through much of the process of setting up the classifier and
% situation model used in situate.
%
% this is a pretty good place to run classifier experiments and stuff that
% shouldn't use situate's stochastic nature to pull crops.

%% initialize the situate structures
    
    p = situate.parameters_initialize_default();
    p.situation_model.fit          = @situation_models.normal_fit;        
    p.situation_model.update       = @situation_models.normal_condition; 
    p.situation_model.sample       = @situation_models.normal_sample;  
    p.situation_model.draw         = @situation_models.normal_draw;  
    
    p.classifier_load_or_train = @classifiers.cnnsvm_train;
    p.classifier_apply         = @classifiers.cnnsvm_apply;
    p.classifier_saved_models_directory = 'default_models/';
    
    experiment_settings = [];
    experiment_settings.title               = 'real life classifier activation stats';
    experiment_settings.situations_struct   = situate.load_situation_definitions();
    experiment_settings.situation           = 'dogwalking'; 
    
    temp = experiment_settings.situations_struct.(experiment_settings.situation);
    p.situation_objects = temp.situation_objects;
    p.situation_objects_possible_labels = temp.situation_objects_possible_labels;
    
    
    
%% find data
    
    try
        data_path = experiment_settings.situations_struct.(experiment_settings.situation).possible_paths{ find(cellfun( @(x) exist(x,'dir'), experiment_settings.situations_struct.(experiment_settings.situation).possible_paths ),1,'first')};
    catch
        while ~exist('data_path','var') || isempty(data_path) || ~isdir(data_path)
            h = msgbox( ['Select directory containing images of ' experiment_settings.situation] );
            uiwait(h);
            data_path = uigetdir(pwd);
        end
    end
    
    split_file_directory = 'default_split/';
    fnames_splits_train = dir(fullfile(split_file_directory, '*_fnames_split_*_train.txt'));
    fnames_splits_test  = dir(fullfile(split_file_directory, '*_fnames_split_*_test.txt' ));
    fnames_splits_train = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_train.name}, 'UniformOutput', false );
    fnames_splits_test  = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_test.name},  'UniformOutput', false );
    assert( ~isempty(fnames_splits_train) );
    assert( length(fnames_splits_train) == length(fnames_splits_test) );
    fprintf('using training splits from:\n');
    fprintf('\t%s\n',fnames_splits_train{:});
    fprintf('using testing splits from:\n');
    fprintf('\t%s\n',fnames_splits_test{:});
    temp = [];
    temp.fnames_lb_train = cellfun( @(x) importdata(x, '\n'), fnames_splits_train, 'UniformOutput', false );
    temp.fnames_lb_test  = cellfun( @(x) importdata(x, '\n'), fnames_splits_test,  'UniformOutput', false );
    data_folds = [];
    for i = 1:length(temp.fnames_lb_train)
        data_folds(i).fnames_lb_train = temp.fnames_lb_train{i};
        data_folds(i).fnames_lb_test  = temp.fnames_lb_test{i};
        data_folds(i).fnames_im_train = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_train{1}, 'UniformOutput', false );
        data_folds(i).fnames_im_test  = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_test{1},  'UniformOutput', false );
    end
    
    %% use what? just everything. manage training/testing splits outside of this
    
    fnames_train = cellfun( @(x) fullfile( data_path, x ), data_folds(1).fnames_lb_train, 'UniformOutput', false );
    fnames_test  = cellfun( @(x) fullfile( data_path, x ), data_folds(1).fnames_lb_test,  'UniformOutput', false );
    
    fnames = [fnames_train; fnames_test];
    %fnames = fnames_train;
    
%% build situation model
    
    %classifier_model = p.classifier_load_or_train( p, fnames_train, p.classifier_saved_models_directory );
    situation_model  = p.situation_model.fit( p, fnames );
    
    demo_image = repmat( imread('cameraman.tif'),1,1,3);
    cnn_output_full = cnn.cnn_process(demo_image);
    cnn_output_full_size = numel(cnn_output_full);
    
%% get stats on shape,size for each object type

    use_resize = true;
    im_data = situate.labl_load( fnames, p );
    
    box_shapes = nan(length(im_data),length(p.situation_objects));
    box_sizes  = nan(length(im_data),length(p.situation_objects));
    for imi = 1:length(im_data)
        
        cur_im_labels = im_data(imi).labels_adjusted;
        cur_im_shapes = im_data(imi).box_aspect_ratio;
        cur_im_sizes  = im_data(imi).box_area_ratio;
        
        for oi = 1:length(p.situation_objects)
            cur_obj = p.situation_objects{oi};
            cur_obj_ind = find(strcmp(cur_im_labels,cur_obj));
            box_shapes(imi,oi) = cur_im_shapes(cur_obj_ind);
            box_sizes(imi,oi)  = cur_im_sizes(cur_obj_ind);
        end
        
    end 
    
    figure
    for oi = 1:length(p.situation_objects)
        subplot2(4,length(p.situation_objects),1,oi); hist(box_shapes(:,oi),50);
        xlabel('shapes');
        title(p.situation_objects{oi});
        subplot2(4,length(p.situation_objects),2,oi); hist(box_sizes(:,oi),20);
        xlabel('sizes');
        
        subplot2(4,length(p.situation_objects),3,oi); hist(log(box_shapes(:,oi)),50);
        xlabel('log shapes');
        title(p.situation_objects{oi});
        subplot2(4,length(p.situation_objects),4,oi); hist(log(box_sizes(:,oi)),20);
        xlabel('log sizes');
    end
        
    
    
%% define box set for each image
% this is overkill, but then we re-sample based on the IOUs to get roughly uniform

%     center_func = @(c, w) c + w * [-1*sqrt(2).^(0:-1:-10) 0 sqrt(2).^(-10:0)];
%     wh_func     = @(w)    w * exp(linspace(log(.5),log(2),11));
    
    center_func = @(c, w) c + w * .5 * [randn(1,11) 0];
    wh_func     = @(w)    w * [exp(randn(1,11)/3) 1];
    
    
%% for each image
    
    % define the set of boxes
    
    % for each box
    % propose boxes
    % get gt iou with target object
    % get IOU with each object
    % cull down to boxes we want
    % get density info
    % get box delta with its origin box
    
    score_per_obj = cell(1,length(p.situation_objects));
    
    num_bins = 20; % IOU bins between IOU 0 and 1
    samples_per_bin = 5;
        
    column_descriptions = { ...
        'image index', ...
        'box coordinates r0rfc0cf', ...
        'source object type index (p.situation_objects ordering)', ...
        'source object box r0rfc0cf', ...
        'gt iou with source box', ...
        ...
        'box delta with source box (xc/w yc/h w_scalar h_scalar)', ...
        ...
        'cnn features', ...
        ...
        'solo density values (in order of situation_objects)', ...
        'single conditioned density values (in order of situation_objects)', ...
        'single conditioned density values (in order of situation_objects)', ...
        'double conditioned density values (in order of situation_objects)' };
    
    % boxes and box info for this image
    box_proposals_r0rfc0cf = zeros(0,4);
    box_sources_r0rfc0cf   = [];
    box_source_obj_type    = [];
    IOUs_with_source       = [];
    fname_source_index     = [];
    
    box_deltas_xywh            = zeros(0,4);
    
    box_density_prior             = [];
    box_density_conditioned_1a    = [];
    box_density_conditioned_1b    = [];
    box_density_conditioned_2     = [];
    
   
    
    for imi = 1:length(fnames)
        
        im_h = im_data(imi).im_h;
        im_w = im_data(imi).im_w;
        
        linear_scaling_factor = sqrt(1 / ( im_data(imi).im_h * im_data(imi).im_w )); % for density estimation
        
        for oi = 1:length(p.situation_objects)
            
            cur_ob_ind = find(strcmp(p.situation_objects{oi},im_data(imi).labels_adjusted));
            cur_ob_box_r0rfc0cf = im_data(imi).boxes_r0rfc0cf( cur_ob_ind,:);
            cur_obj_type = p.situation_objects{oi};
            conditioning_objects = setsub( p.situation_objects, cur_obj_type );
            
            r0 = cur_ob_box_r0rfc0cf(1);
            rf = cur_ob_box_r0rfc0cf(2);
            c0 = cur_ob_box_r0rfc0cf(3);
            cf = cur_ob_box_r0rfc0cf(4);
            w = cf - c0 + 1;
            h = rf - r0 + 1;
            rc = r0 + h/2;
            cc = c0 + w/2;
            
            rcs = round( center_func( rc,  h ) ); 
            ccs = round( center_func( cc,  w ) ); 
            ws  = round( wh_func(w) );
            hs  = round( wh_func(h) );
            
            new_boxes_to_eval_r0rfc0cf_prelim = zeros(length(rcs)*length(ccs)*length(ws)*length(hs),4);
            bi = 1;
            for ri = 1:length(rcs)
            for ci = 1:length(ccs)
            for wi = 1:length(ws)
            for hi = 1:length(hs)
                cur_w  = ws(wi);
                cur_r0 = round( rcs(ri) - hs(hi)/2 );
                cur_rf = cur_r0 + hs(hi) - 1;
                cur_c0 = round( ccs(ci) - ws(wi)/2 );
                cur_cf = cur_c0 + ws(wi) - 1;
                new_boxes_to_eval_r0rfc0cf_prelim(bi,:) = [cur_r0 cur_rf cur_c0 cur_cf];
                bi = bi + 1;
            end
            end
            end
            end
            
            % figure out IOU of each proposed box
            new_boxes_to_eval_IOU_prelim = intersection_over_union( [r0 rf c0 cf], new_boxes_to_eval_r0rfc0cf_prelim, 'r0rfc0cf','r0rfc0cf');
            
            % remove boxes that got out of the image bounds
            boxes_to_remove = false(size(new_boxes_to_eval_IOU_prelim,1),1);
            boxes_to_remove( new_boxes_to_eval_r0rfc0cf_prelim(:,1) < 1 )    = true;
            boxes_to_remove( new_boxes_to_eval_r0rfc0cf_prelim(:,2) > im_h ) = true;
            boxes_to_remove( new_boxes_to_eval_r0rfc0cf_prelim(:,3) < 1 )    = true;
            boxes_to_remove( new_boxes_to_eval_r0rfc0cf_prelim(:,4) > im_w ) = true;
            new_boxes_to_eval_r0rfc0cf_prelim(boxes_to_remove,:) = [];
            new_boxes_to_eval_IOU_prelim(boxes_to_remove)        = [];
            
            [counts, bin_bounds, input_assignments] = hist_bin_assignments( new_boxes_to_eval_IOU_prelim, num_bins );
            new_box_proposals_r0rfc0cf = [];
            new_boxes_to_eval_IOU      = [];
            for bi = 1:num_bins
                cur_bin_inds = find(eq(bi,input_assignments));
                cur_bin_inds_rand_perm = cur_bin_inds(randperm(length(cur_bin_inds)));
                sampled_bin_inds = cur_bin_inds_rand_perm( 1:min(samples_per_bin,length(cur_bin_inds_rand_perm) ) );
                new_box_proposals_r0rfc0cf(end+1:end+length(sampled_bin_inds),:) = new_boxes_to_eval_r0rfc0cf_prelim(sampled_bin_inds,:);
                new_boxes_to_eval_IOU(end+1:end+length(sampled_bin_inds)) = new_boxes_to_eval_IOU_prelim(sampled_bin_inds);
            end
            
          
            % for density estimation, make dummy workspaces using the other
            % gt objects
                workspace_temp_1a = [];
                    workspace_temp_1a.labels = conditioning_objects(1);
                    workspace_temp_1a.boxes_r0rfc0cf = im_data(imi).boxes_normalized_r0rfc0cf( strcmp(conditioning_objects(1),im_data(imi).labels_adjusted), : );
                    workspace_temp_1a.im_size(1) = im_h;
                    workspace_temp_1a.im_size(2) = im_w;
                workspace_temp_1b = [];
                    workspace_temp_1b.labels = conditioning_objects(2);
                    workspace_temp_1b.boxes_r0rfc0cf = im_data(imi).boxes_normalized_r0rfc0cf( strcmp(conditioning_objects(2),im_data(imi).labels_adjusted), : );
                    workspace_temp_1b.im_size(1) = im_h;
                    workspace_temp_1b.im_size(2) = im_w;
                workspace_temp_2  = [];
                    workspace_temp_2.labels = conditioning_objects;
                    workspace_temp_2.boxes_r0rfc0cf = im_data(imi).boxes_normalized_r0rfc0cf( logical(strcmp(conditioning_objects(1),im_data(imi).labels_adjusted) + strcmp(conditioning_objects(2),im_data(imi).labels_adjusted)), : );
                    workspace_temp_2.im_size(1) = im_h;
                    workspace_temp_2.im_size(2) = im_w;
                    
            
            
            num_new_boxes = size(new_box_proposals_r0rfc0cf,1);
            
            
            new_box_deltas_xywh               = nan( num_new_boxes, 4 );
            
            new_box_density_prior             = nan( num_new_boxes, 1 );
            new_box_density_conditioned_1a    = nan( num_new_boxes, 1 );
            new_box_density_conditioned_1b    = nan( num_new_boxes, 1 );
            new_box_density_conditioned_2     = nan( num_new_boxes, 1 );
            
            for bi = 1:num_new_boxes
                % do box related stuff
                
                r0 = new_box_proposals_r0rfc0cf(bi,1);
                rf = new_box_proposals_r0rfc0cf(bi,2);
                c0 = new_box_proposals_r0rfc0cf(bi,3);
                cf = new_box_proposals_r0rfc0cf(bi,4);
                
                w  = cf - c0 + 1;
                h  = rf - r0 + 1;
                xc = c0 + w/2 - .5;
                yc = r0 + h/2 - .5;
                
                gt_r0 = cur_ob_box_r0rfc0cf(1);
                gt_rf = cur_ob_box_r0rfc0cf(2);
                gt_c0 = cur_ob_box_r0rfc0cf(3);
                gt_cf = cur_ob_box_r0rfc0cf(4);
                gt_w  = gt_cf - gt_c0 + 1;
                gt_h  = gt_rf - gt_r0 + 1;
                gt_xc = gt_c0 + gt_w/2 - .5;
                gt_yc = gt_r0 + gt_h/2 - .5;
                
                x_delta = (gt_xc - xc) / w;
                y_delta = (gt_yc - yc) / h;
                w_delta = log( gt_w / w );
                h_delta = log( gt_h / h );
                
                new_box_deltas_xywh(bi,:) = [x_delta y_delta w_delta h_delta];
                
                % density stuff
                r0_normed = linear_scaling_factor * (r0 - im_data(imi).im_h/2);
                rf_normed = linear_scaling_factor * (rf - im_data(imi).im_h/2);
                c0_normed = linear_scaling_factor * (c0 - im_data(imi).im_w/2);
                cf_normed = linear_scaling_factor * (cf - im_data(imi).im_w/2);
                w_normed  = linear_scaling_factor * w;
                h_normed  = linear_scaling_factor * h;
                rc_normed = r0_normed + h_normed/2;
                cc_normed = c0_normed + w_normed/2;
                log_aspect_ratio = log(w_normed / h_normed);
                log_area_ratio = log(w_normed * h_normed);

                cur_box_long_vect = [ r0_normed rc_normed rf_normed c0_normed cc_normed cf_normed log(w_normed) log(h_normed) log_aspect_ratio log_area_ratio];

                [~, new_box_density_prior(bi)]          = p.situation_model.sample( situation_model, cur_obj_type, 1, [im_h im_w] );
                [~, new_box_density_conditioned_1a(bi)] = p.situation_model.sample( situation_model, cur_obj_type, 1, [im_h im_w] );
                [~, new_box_density_conditioned_1b(bi)] = p.situation_model.sample( situation_model, cur_obj_type, 1, [im_h im_w] );
                [~, new_box_density_conditioned_2(bi)]  = p.situation_model.sample( situation_model, cur_obj_type, 1, [im_h im_w] );
            
            end
            
            box_proposals_r0rfc0cf      = [ box_proposals_r0rfc0cf; new_box_proposals_r0rfc0cf ];
            box_sources_r0rfc0cf        = [ box_sources_r0rfc0cf;   repmat(cur_ob_box_r0rfc0cf,size(new_box_proposals_r0rfc0cf,1),1) ];
            box_source_obj_type         = [ box_source_obj_type;    repmat(oi,size(new_box_proposals_r0rfc0cf,1),1) ];
            IOUs_with_source            = [ IOUs_with_source;       new_boxes_to_eval_IOU' ];
            fname_source_index          = [ fname_source_index;     repmat( imi, size(new_box_proposals_r0rfc0cf,1), 1 ) ];
            box_deltas_xywh             = [ box_deltas_xywh;            new_box_deltas_xywh];
            box_density_prior           = [ box_density_prior;          new_box_density_prior];
            box_density_conditioned_1a  = [ box_density_conditioned_1a; new_box_density_conditioned_1a];
            box_density_conditioned_1b  = [ box_density_conditioned_1b; new_box_density_conditioned_1b];
            box_density_conditioned_2   = [ box_density_conditioned_2;  new_box_density_conditioned_2];
            
        end
        
        progress(imi, length(fnames), 'image progress');
        
    end
    
    %% more expensive stuff
    
    box_proposal_cnn_features = single( nan( size(box_proposals_r0rfc0cf,1), 4096 ) );
    box_proposal_gt_IOUs = single( -1 * ones( size(box_proposals_r0rfc0cf,1), length(p.situation_objects) ) );
    box_proposal_thumbnail = cell( size(box_proposals_r0rfc0cf,1), 1 );
    box_proposal_size_px = zeros( size(box_proposals_r0rfc0cf,1), 1 );
    for bi = 1:size(box_proposal_cnn_features,1)
        
        im_temp = imread( fnames(fname_source_index(bi)) );
        cur_im_data = situate.labl_load( fnames(fname_source_index(bi)) );
        im = im_temp{1};
        r0 = box_proposals_r0rfc0cf(bi,1);
        rf = box_proposals_r0rfc0cf(bi,2);
        c0 = box_proposals_r0rfc0cf(bi,3);
        cf = box_proposals_r0rfc0cf(bi,4);
        
        % get IOU with each object (in p.situation_objects order)
        for oi = 1:length(p.situation_objects)
            oi_label_ind = strcmp( p.situation_objects{oi},cur_im_data.labels_adjusted);
            box_proposal_gt_IOUs(bi,oi) = ...
                intersection_over_union( ...
                    box_proposals_r0rfc0cf(bi,:), ...
                    cur_im_data.boxes_r0rfc0cf(oi_label_ind,:), ...
                    'r0rfc0cf', 'r0rfc0cf' );
        end
        
        % get cnn features
        % pad box slightly (10% per side)
        %padding_multiplier = .2; % total, divided up between top and bottom
        w     = cf - c0 + 1;
        h     = rf - r0 + 1;
        %pad_w = padding_multiplier * w;
        %pad_h = padding_multiplier * h;
        %r0 = r0 - pad_h/2;
        %rf = r0 + h + pad_h - 1;
        %c0 = c0 - pad_w/2;
        %cf = c0 + w + pad_w - 1;
        
        r0 = round(r0);
        rf = round(rf);
        c0 = round(c0);
        cf = round(cf);
        try
            box_proposal_cnn_features(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
            box_proposal_size_px(bi) = w * h;
            %box_proposal_thumbnail{bi} = imresize_px( im(r0:rf,c0:cf,:), 10000);
        end
        
        if mod(bi,1000)  == 0, progress(bi,size(box_proposal_cnn_features,1)); end
        
    end
    
    save_name = ['cnn_features_and_IOUs' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat' ];
    
    save( fullfile( save_name ), '-v7.3', ...
        'fnames', ...
        'p', ...
        'experiment_settings',...
        'box_proposals_r0rfc0cf',...
        'box_sources_r0rfc0cf',...
        'box_source_obj_type',...
        'box_proposal_thumbnail', ...
        'box_proposal_size_px', ...
        'IOUs_with_source',...
        'box_proposal_gt_IOUs',...
        'fname_source_index',...
        'box_proposal_cnn_features',...
        'box_deltas_xywh',...
        'box_density_prior',...
        'box_density_conditioned_1a',...
        'box_density_conditioned_1b',...
        'box_density_conditioned_2');
    
    display(['saved cnn_features_and_IOUs data to ' fullfile( save_name )]);
    
    
         


