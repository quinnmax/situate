
function [fname_out] = cnn_feature_extractor( directory_in, directory_out, p )

    % fname_out = cnn_feature_extractor( [directory_in], [directory_out], [p] );
    %
    %   this goes through much of the process of setting up the classifier and
    %   situation model used in situate.
    %
    %   this is a pretty good place to run classifier experiments and stuff that
    %   shouldn't use situate's stochastic nature to pull crops.
    %
    %   no directory_in means it tries to use default dog-walking images
    %   no directory_out means save to current directory
    %   no p structure means a default parameterization for Situate
    
    
    
%% initialize the situate structures
    
    if ~exist('p','var')
        p = situate.parameters_initialize();
    end
        
    experiment_settings = [];
    experiment_settings.title               = 'feature extraction';
    experiment_settings.situations_struct   = situate.situation_definitions();
    experiment_settings.situation           = 'dogwalking'; 
    
    temp = experiment_settings.situations_struct.(experiment_settings.situation);
    p.situation_objects = temp.situation_objects;
    p.situation_objects_possible_labels = temp.situation_objects_possible_labels;
    situation_objects = p.situation_objects;
    num_situation_objects = length(situation_objects);
    
    
    
%% find data
    
    if exist('directory_in','var') && ~isempty(directory_in)
        data_path = directory_in;
    else
        try
            data_path = experiment_settings.situations_struct.(experiment_settings.situation).possible_paths{ find(cellfun( @(x) exist(x,'dir'), experiment_settings.situations_struct.(experiment_settings.situation).possible_paths ),1,'first')};
        catch
            while ~exist('data_path','var') || isempty(data_path) || ~isdir(data_path)
                h = msgbox( ['Select directory containing images of ' experiment_settings.situation] );
                uiwait(h);
                data_path = uigetdir(pwd);
            end
        end
    end
    
    d = dir([data_path '*.labl']);
    
    fnames = cellfun(@(x) fullfile(data_path, x), {d.name}, 'UniformOutput', false )';
    
    
    
%% build situation model (for estimating external support)
    
    %classifier_model = p.classifier_load_or_train( p, fnames_train, p.classifier_saved_models_directory );
    situation_model  = p.situation_model.learn( p, fnames );
    demo_image = repmat( imread('cameraman.tif'),1,1,3);
    cnn_output_full = cnn.cnn_process(demo_image);
    
    
    
%% get stats on shape,size for each object type

    use_resize = true;
    im_data = situate.load_image_and_data(fnames, p, use_resize );
    
    box_shapes = nan(length(im_data),num_situation_objects);
    box_sizes  = nan(length(im_data),num_situation_objects);
    for imi = 1:length(im_data)
        
        cur_im_labels = im_data(imi).labels_adjusted;
        cur_im_shapes = im_data(imi).box_aspect_ratio;
        cur_im_sizes  = im_data(imi).box_area_ratio;
        
        for oi = 1:num_situation_objects
            cur_obj = situation_objects{oi};
            cur_obj_ind = find(strcmp(cur_im_labels,cur_obj));
            box_shapes(imi,oi) = cur_im_shapes(cur_obj_ind);
            box_sizes(imi,oi)  = cur_im_sizes(cur_obj_ind);
        end
        
    end 
    
    figure
    for oi = 1:num_situation_objects
        subplot2(4,num_situation_objects,1,oi); hist(box_shapes(:,oi),50);
        xlabel('shapes');
        title(situation_objects{oi});
        subplot2(4,num_situation_objects,2,oi); hist(box_sizes(:,oi),20);
        xlabel('sizes');
        
        subplot2(4,num_situation_objects,3,oi); hist(log(box_shapes(:,oi)),50);
        xlabel('log shapes');
        title(situation_objects{oi});
        subplot2(4,num_situation_objects,4,oi); hist(log(box_sizes(:,oi)),20);
        xlabel('log sizes');
    end
        
    
    
%% define box set for each image
% this is overkill, but then we re-sample based on the IOUs to get roughly uniform
    
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
    
   % score_per_obj = cell(1,length(situation_objects));
    
    num_bins = 20; % IOU bins between IOU 0 and 1
    samples_per_bin = 5;
        
    % boxes and box info for this image
    box_proposals_r0rfc0cf     = cell(length(fnames),num_situation_objects);
    box_sources_r0rfc0cf       = cell(length(fnames),num_situation_objects);
    box_source_obj_type        = cell(length(fnames),num_situation_objects);
    IOUs_with_source           = cell(length(fnames),num_situation_objects);
    fname_source_index         = cell(length(fnames),num_situation_objects);
    box_deltas_xywh            = cell(length(fnames),num_situation_objects);
    box_density_prior          = cell(length(fnames),num_situation_objects);
    box_density_conditioned_1a = cell(length(fnames),num_situation_objects);
    box_density_conditioned_1b = cell(length(fnames),num_situation_objects);
    box_density_conditioned_2  = cell(length(fnames),num_situation_objects);
    
    for imi = 1:length(fnames)
        
        im_h = im_data(imi).im_h;
        im_w = im_data(imi).im_w;
        
        %linear_scaling_factor = sqrt(1 / ( im_data(imi).im_h * im_data(imi).im_w )); % for density estimation
        
        for oi = 1:num_situation_objects
            
            cur_ob_ind = strcmp(situation_objects{oi},im_data(imi).labels_adjusted);
            cur_ob_box_r0rfc0cf = im_data(imi).boxes_r0rfc0cf( cur_ob_ind,:);
            cur_obj_type = situation_objects{oi};
            conditioning_objects = setsub( situation_objects, cur_obj_type );
            
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
            
            [~, ~, input_assignments] = hist_bin_assignments( new_boxes_to_eval_IOU_prelim, num_bins );
            new_box_proposals_r0rfc0cf = [];
            new_boxes_to_eval_IOU      = [];
            for bi = 1:num_bins
                cur_bin_inds = find(eq(bi,input_assignments));
                cur_bin_inds_rand_perm = cur_bin_inds(randperm(length(cur_bin_inds)));
                sampled_bin_inds = cur_bin_inds_rand_perm( 1:min(samples_per_bin,length(cur_bin_inds_rand_perm) ) );
                new_box_proposals_r0rfc0cf(end+1:end+length(sampled_bin_inds),:) = new_boxes_to_eval_r0rfc0cf_prelim(sampled_bin_inds,:);
                new_boxes_to_eval_IOU(end+1:end+length(sampled_bin_inds)) = new_boxes_to_eval_IOU_prelim(sampled_bin_inds);
            end
            
            % for density estimation, make dummy workspaces using the other gt objects
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
              
                [~, new_box_density_prior(bi)]          = p.situation_model.sample( situation_model, cur_obj_type, 1, [im_h im_w] );
                [~, new_box_density_conditioned_1a(bi)] = p.situation_model.sample( situation_model, cur_obj_type, 1, [im_h im_w] );
                [~, new_box_density_conditioned_1b(bi)] = p.situation_model.sample( situation_model, cur_obj_type, 1, [im_h im_w] );
                [~, new_box_density_conditioned_2(bi)]  = p.situation_model.sample( situation_model, cur_obj_type, 1, [im_h im_w] );
            
            end
            
            box_proposals_r0rfc0cf{imi,oi}     = new_box_proposals_r0rfc0cf;
            box_sources_r0rfc0cf{imi,oi}       = repmat(cur_ob_box_r0rfc0cf,size(new_box_proposals_r0rfc0cf,1),1);
            box_source_obj_type{imi,oi}        = repmat(oi,size(new_box_proposals_r0rfc0cf,1),1);
            IOUs_with_source{imi,oi}           = new_boxes_to_eval_IOU';
            fname_source_index{imi,oi}         = repmat( imi, size(new_box_proposals_r0rfc0cf,1), 1 );
            box_deltas_xywh{imi,oi}            = new_box_deltas_xywh;
            box_density_prior{imi,oi}          = new_box_density_prior;
            box_density_conditioned_1a{imi,oi} = new_box_density_conditioned_1a;
            box_density_conditioned_1b{imi,oi} = new_box_density_conditioned_1b;
            box_density_conditioned_2{imi,oi}  = new_box_density_conditioned_2;
            
        end
        
        progress(imi,length(fnames));
        
    end
    
    display('boxes decided, now to compute cnn features');
    
    %% more expensive stuff
    
    box_proposal_cnn_features   = cell(length(fnames),num_situation_objects);
    box_proposal_gt_IOUs        = cell(length(fnames),num_situation_objects);
    box_proposal_size_px        = cell(length(fnames),num_situation_objects);
    
    parfor imi = 1:length(fnames)
        
        for oj = 1:num_situation_objects
        
            [cur_im_data,im_temp] = situate.load_image_and_data( fnames(imi), p, use_resize );
            im = im_temp{1};

            for bi = 1:size(box_proposals_r0rfc0cf{imi},1)
                r0 = box_proposals_r0rfc0cf{imi}(bi,1);
                rf = box_proposals_r0rfc0cf{imi}(bi,2);
                c0 = box_proposals_r0rfc0cf{imi}(bi,3);
                cf = box_proposals_r0rfc0cf{imi}(bi,4);

                % get IOU with each object (in situation_objects order)
                for oi = 1:num_situation_objects
                    oi_label_ind = strcmp( situation_objects{oi},cur_im_data.labels_adjusted);
                    box_proposal_gt_IOUs{imi,oj}(bi,oi) = ...
                        intersection_over_union( ...
                            box_proposals_r0rfc0cf{imi}(bi,:), ...
                            cur_im_data.boxes_r0rfc0cf(oi_label_ind,:), ...
                            'r0rfc0cf', 'r0rfc0cf' );
                end
                w = cf - c0 + 1;
                h = rf - r0 + 1;
                r0 = round(r0);
                rf = round(rf);
                c0 = round(c0);
                cf = round(cf);
                try
                    box_proposal_cnn_features{imi,oj}(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
                    box_proposal_size_px{imi,oj}(bi) = w * h;
                    %box_proposal_thumbnail{bi} = imresize_px( im(r0:rf,c0:cf,:), 10000);
                end

            end
        
        end
        
        fprintf('.');
        
    end
    
    display('cnn features computed');
    
    box_proposals_r0rfc0cf      = vertcat( box_proposals_r0rfc0cf{:} );
    box_sources_r0rfc0cf        = vertcat( box_sources_r0rfc0cf{:} );
    box_source_obj_type         = vertcat( box_source_obj_type{:} );
    IOUs_with_source            = vertcat( IOUs_with_source{:} );
    fname_source_index          = vertcat( fname_source_index{:} );
    box_deltas_xywh             = vertcat( box_deltas_xywh{:} );
    box_density_prior           = vertcat( box_density_prior{:} );
    box_density_conditioned_1a  = vertcat( box_density_conditioned_1a{:} );
    box_density_conditioned_1b  = vertcat( box_density_conditioned_1b{:} );
    box_density_conditioned_2   = vertcat( box_density_conditioned_2{:} );
    
    box_proposal_cnn_features   = vertcat( box_proposal_cnn_features{:} );
    box_proposal_gt_IOUs        = vertcat( box_proposal_gt_IOUs{:} );
    box_proposal_size_px        = vertcat( box_proposal_size_px{:} );
    
    
    if exist('directory_out','var') && ~isempty(directory_out) && exist(directory_out,'dir')
        fname_out = fullfile(directory_out, ['cnn_features_and_IOUs' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat' ]);
    else
        % just save it to the working directory then
        fname_out = ['cnn_features_and_IOUs' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat' ];
    end
    
    save( fname_out, '-v7.3', ...
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
    
    display(['saved cnn_features_and_IOUs data to ' fname_out]);
    
end
    
    
         


