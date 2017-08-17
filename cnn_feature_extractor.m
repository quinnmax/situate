
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
    
    d = dir(fullfile(data_path, '*.labl'));
    
    fnames = cellfun(@(x) fullfile(data_path, x), {d.name}, 'UniformOutput', false )';
    num_images = length(fnames);
    %num_images = 5;
    
    
    
%% build situation model (for estimating external support)
    
    %classifier_model = p.classifier_load_or_train( p, fnames_train, p.classifier_saved_models_directory );
    situation_model  = p.situation_model.learn( p, fnames );
    demo_image = repmat( imread('cameraman.tif'),1,1,3);
    cnn_output_full = cnn.cnn_process(demo_image);
    num_cnn_features = length(cnn_output_full);
    
    
    
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
    
    
    
%% define box set for each image
% this is overkill, but then we re-sample based on the IOUs to get roughly uniform
    
    center_func = @(c, w) c + w * .5 * [randn(1,11) 0];
    wh_func     = @(w)    w * [exp(randn(1,11)/3) 1];
    
    
    
%% gather box proposal information
    
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
    box_proposals_r0rfc0cf     = cell(num_images,num_situation_objects);
    box_sources_r0rfc0cf       = cell(num_images,num_situation_objects);
    box_source_obj_type        = cell(num_images,num_situation_objects);
    IOUs_with_source           = cell(num_images,num_situation_objects);
    fname_source_index         = cell(num_images,num_situation_objects);
    box_deltas_xywh            = cell(num_images,num_situation_objects);
    box_density_prior          = cell(num_images,num_situation_objects);
    box_density_conditioned    = cell(num_images,num_situation_objects);
    
    for imi = 1:num_images
        
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
            
            % make dummy workspaces for combinations of the conditioning objects
            % make dummy situation models
            workspace_combinations_boolean_indices = all_combinations(length(conditioning_objects));
            dummy_conditioning_objects = cell(1,size(workspace_combinations_boolean_indices,1)-1);
            dummy_workspaces = cell(1,size(workspace_combinations_boolean_indices,1)-1);
            dummy_situation_models = cell(1,size(workspace_combinations_boolean_indices,1)-1);
            dummy_workspaces_to_remove = false(1,length(dummy_workspaces));
            for dwi = 1:length(dummy_workspaces)
                cur_conditioning_objects = conditioning_objects( workspace_combinations_boolean_indices(dwi,:) );
                dummy_conditioning_objects{dwi} = cur_conditioning_objects;
                if all(ismember(cur_conditioning_objects,im_data(imi).labels_adjusted))
                    dummy_workspaces{dwi}.labels = cur_conditioning_objects;
                    dummy_workspaces{dwi}.im_size(1)     = im_h;
                    dummy_workspaces{dwi}.im_size(2)     = im_w;
                    [~,workspace_inds] = ismember(cur_conditioning_objects,im_data(imi).labels_adjusted);
                    dummy_workspaces{dwi}.boxes_r0rfc0cf = im_data(imi).boxes_r0rfc0cf( workspace_inds, : );                   
                    dummy_situation_models{dwi} = p.situation_model.update( situation_model, p.situation_objects{oi}, dummy_workspaces{dwi} );
                else
                    dummy_workspaces_to_remove(dwi) = true;
                end
            end
            
                    
            num_new_boxes = size(new_box_proposals_r0rfc0cf,1);
            
            new_box_deltas_xywh               = nan( num_new_boxes, 4 );
            new_box_density_prior             = nan( num_new_boxes, 1 );
            new_box_density_conditioned       = nan( num_new_boxes, length(dummy_situation_models) );
            
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
              
                [~, new_box_density_prior(bi)]          = p.situation_model.sample( situation_model,    cur_obj_type, 1, [im_h im_w], [r0 rf c0 cf] );
                for si = 1:length(dummy_situation_models)
                    [~,new_box_density_conditioned(bi,si)] = p.situation_model.sample( dummy_situation_models{si}, cur_obj_type, 1, [im_h im_w], [r0 rf c0 cf] );
                end
                
            end
            
            box_proposals_r0rfc0cf{imi,oi}     = new_box_proposals_r0rfc0cf;
            box_sources_r0rfc0cf{imi,oi}       = repmat(cur_ob_box_r0rfc0cf,size(new_box_proposals_r0rfc0cf,1),1);
            box_source_obj_type{imi,oi}        = repmat(oi,size(new_box_proposals_r0rfc0cf,1),1);
            IOUs_with_source{imi,oi}           = new_boxes_to_eval_IOU';
            fname_source_index{imi,oi}         = repmat( imi, size(new_box_proposals_r0rfc0cf,1), 1 );
            box_deltas_xywh{imi,oi}            = new_box_deltas_xywh;
            box_density_prior{imi,oi}          = new_box_density_prior;
            box_density_conditioned{imi,oi}    = new_box_density_conditioned;
            
            
        end
        
        progress(imi,num_images);
        
    end
    
    display('boxes decided, now to compute cnn features');
    
    %% more expensive stuff
    
    box_proposal_cnn_features   = cell(num_images,num_situation_objects);
    box_proposal_gt_IOUs        = cell(num_images,num_situation_objects);
    
    tic;
    for imi = 1:num_images
    for oi  = 1:num_situation_objects
        
        [cur_im_data,im_temp] = situate.load_image_and_data( fnames(imi), p, use_resize );
        im = im_temp{1};
        wi = strcmp(cur_im_data.labels_adjusted,p.situation_objects{oi}); % workspace index for the object of interest
        
        num_box_proposals = size(box_proposals_r0rfc0cf{imi,oi},1);
        
        box_proposal_cnn_features{imi,oi} = nan( num_box_proposals, num_cnn_features );
        box_proposal_gt_IOUs{imi,oi} = nan( num_box_proposals, 1 );

        for bi = 1:size(box_proposals_r0rfc0cf{imi,oi},1)
            r0 = box_proposals_r0rfc0cf{imi,oi}(bi,1);
            rf = box_proposals_r0rfc0cf{imi,oi}(bi,2);
            c0 = box_proposals_r0rfc0cf{imi,oi}(bi,3);
            cf = box_proposals_r0rfc0cf{imi,oi}(bi,4);

            box_proposal_gt_IOUs{imi,oi}(bi) = ...
                intersection_over_union( ...
                    box_proposals_r0rfc0cf{imi,oi}(bi,:), ...
                    cur_im_data.boxes_r0rfc0cf(wi,:), ...
                    'r0rfc0cf','r0rfc0cf');
            
            r0 = round(r0);
            rf = round(rf);
            c0 = round(c0);
            cf = round(cf);
            
            try
                box_proposal_cnn_features{imi,oi}(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
            catch
                box_proposal_cnn_features{imi,oi}(bi,:) = nan(1,num_cnn_features);
            end

        end
        
    end
    progress(imi,num_images);
    end
    toc
    
    % need to see which proposals failed due to something being out of bounds, and remove those
    % boxes from all of the structures
    
    display('cnn features computed');
    
    box_proposals_r0rfc0cf      = vertcat( box_proposals_r0rfc0cf{:} );
    box_sources_r0rfc0cf        = vertcat( box_sources_r0rfc0cf{:} );
    box_source_obj_type         = vertcat( box_source_obj_type{:} );
    IOUs_with_source            = vertcat( IOUs_with_source{:} );
    fname_source_index          = vertcat( fname_source_index{:} );
    box_deltas_xywh             = vertcat( box_deltas_xywh{:} );
    box_density_prior           = vertcat( box_density_prior{:} );
    box_density_conditioned     = vertcat( box_density_conditioned{:} );
    box_proposal_cnn_features   = vertcat( box_proposal_cnn_features{:} );
    box_proposal_gt_IOUs        = vertcat( box_proposal_gt_IOUs{:} );
    
    
    % get IOU between each proposal and each gt box in its image
    % (this is appended, could probably be done more efficiently up above)
    oi_inds = zeros( size(box_source_obj_type,1), num_situation_objects );
    for oi = 1:num_situation_objects
        oi_inds(:,oi) = eq( oi, box_source_obj_type );
    end
    IOUs_with_each_gt_obj = zeros( size(box_source_obj_type,1), num_situation_objects );
    imi_list = unique(fname_source_index);
    for imii = 1:length(imi_list)
        imi = imi_list(imii);
        cur_im_inds = eq(imi, fname_source_index);
        for oi = 1:num_situation_objects
            cur_im_ob_inds = cur_im_inds & oi_inds(:,oi);
            cur_gt_box = box_sources_r0rfc0cf( find( cur_im_ob_inds, 1, 'first' ), : );
            IOUs_with_each_gt_obj(cur_im_inds,oi) = intersection_over_union( cur_gt_box, box_proposals_r0rfc0cf(cur_im_inds,:), 'r0rfc0cf', 'r0rfc0cf' );
        end
    end
    
    if exist('directory_out','var') && ~isempty(directory_out) && exist(directory_out,'dir')
        fname_out = fullfile(directory_out, [ [p.situation_objects{:}] '_cnn_features_and_IOUs' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat' ]);
    else
        % just save it to the working directory then
        fname_out = [ [p.situation_objects{:}] '_cnn_features_and_IOUs' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat' ];
    end
    
    object_labels = p.situation_objects;
    
    save( fname_out, '-v7.3', ...
        'fnames', ...
        'object_labels',...
        'p', ...
        'box_proposals_r0rfc0cf',...
        'box_sources_r0rfc0cf',...
        'box_source_obj_type',...
        'IOUs_with_source',...
        'IOUs_with_each_gt_obj',...
        'box_proposal_gt_IOUs',...
        'fname_source_index',...
        'box_proposal_cnn_features',...
        'box_deltas_xywh',...
        'box_density_prior',...
        'box_density_conditioned');
    
    display(['saved cnn_features_and_IOUs data to ' fname_out]);
    
end
    
    
         


