
function [fname_out] = feature_extractor_bulk( directory_in, directory_out, situation_struct )

    % fname_out = cnn.feature_extractor_bulk( directory_in, directory_out, situation_struct );
    %
    %   the situation struct tells us 
    %       what objects are of interest and 
    %       the possible labels for those objects
    %
    %
    % this pulls a bunch of crops of a roughly uniform IOU distribution for each object of interest,
    % and pulls the cnn features. it takes awhile, but makes training classifiers easier in the
    % future. it does it at the directory level, but keeps track of what image each crop came from,
    % so you can still engage in proper training testing separation when using the resulting file
    
    if ~exist('directory_out','var') || isempty(directory_out)
        directory_out = 'pre_extracted_feature_data';
    end
        
%% get objects of interest
   
    situation_objects = situation_struct.situation_objects;
    num_situation_objects = length(situation_objects);
    
    
%% find data
    
    d1 = dir(fullfile(directory_in, '*.json'));
    d2 = dir(fullfile(directory_in, '*.labl'));
    if length(d1)>length(d2)
        d = d1;
    else
        d = d2;
    end
    fnames = cellfun(@(x) fullfile(directory_in, x), {d.name}, 'UniformOutput', false )';
    num_images = length(fnames);
   
    
%% poke at the cnn output
    
    demo_image = repmat( imread('cameraman.tif'),1,1,3);
    cnn_output_full = cnn.cnn_process(demo_image);
    num_cnn_features = length(cnn_output_full);
    
    
%% get stats on shape,size for each object type

    im_data = situate.labl_load( fnames, situation_struct );
    
    box_shapes = nan(length(im_data),num_situation_objects);
    box_sizes  = nan(length(im_data),num_situation_objects);
    for imi = 1:length(im_data)
        
        cur_im_labels = im_data(imi).labels_adjusted;
        cur_im_shapes = im_data(imi).box_aspect_ratio;
        cur_im_sizes  = im_data(imi).box_area_ratio;
        
        for oi = 1:num_situation_objects
            cur_obj_ind = find( strcmp( cur_im_labels, situation_objects{oi} ) );
            box_shapes(imi,oi) = cur_im_shapes(cur_obj_ind);
            box_sizes(imi,oi)  = cur_im_sizes(cur_obj_ind);
        end
        
    end 
    
    
%% define box set for each image
% generating an absurd number of box proposals, which will be culled to get a roughly uniform
% distribution of intersection over union (IOU) values with the originating bounding box
    
    center_func = @(c, w) c + w * .5 * [randn(1,11) 0];
    wh_func     = @(w)    w * [exp(randn(1,11)/3) 1];
    
    num_bins = 20; % IOU bins between IOU 0 and 1
    samples_per_bin = 5;
    
    
    
%% generate box proposals
    
    % define the set of boxes
    
    % for each gt bounding box
    %   propose boxes
    %   get gt iou with target object
    %   get IOU with each object
    % cull down to boxes we want
    % get box delta with its origin box
        
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
        
        for oi = 1:num_situation_objects
            
            cur_ob_ind = strcmp(situation_objects{oi},im_data(imi).labels_adjusted);
            cur_ob_box_r0rfc0cf = im_data(imi).boxes_r0rfc0cf( cur_ob_ind,:);
            
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
            
            new_box_proposals_r0rfc0cf_prelim = zeros(length(rcs)*length(ccs)*length(ws)*length(hs),4);
            bi = 1;
            for ri = 1:length(rcs)
            for ci = 1:length(ccs)
            for wi = 1:length(ws)
            for hi = 1:length(hs)
                cur_r0 = round( rcs(ri) - hs(hi)/2 );
                cur_rf = cur_r0 + hs(hi) - 1;
                cur_c0 = round( ccs(ci) - ws(wi)/2 );
                cur_cf = cur_c0 + ws(wi) - 1;
                new_box_proposals_r0rfc0cf_prelim(bi,:) = [cur_r0 cur_rf cur_c0 cur_cf];
                bi = bi + 1;
            end
            end
            end
            end
            
            % figure out IOU of each proposed box
            new_box_proposals_IOU_prelim = intersection_over_union( [r0 rf c0 cf], new_box_proposals_r0rfc0cf_prelim, 'r0rfc0cf','r0rfc0cf');
            
            % remove boxes that got out of the image bounds
            boxes_to_remove = false(size(new_box_proposals_IOU_prelim,1),1);
            boxes_to_remove( new_box_proposals_r0rfc0cf_prelim(:,1) < 1 )    = true;
            boxes_to_remove( new_box_proposals_r0rfc0cf_prelim(:,2) > im_data(imi).im_h ) = true;
            boxes_to_remove( new_box_proposals_r0rfc0cf_prelim(:,3) < 1 )    = true;
            boxes_to_remove( new_box_proposals_r0rfc0cf_prelim(:,4) > im_data(imi).im_w ) = true;
            new_box_proposals_r0rfc0cf_prelim(boxes_to_remove,:) = [];
            new_box_proposals_IOU_prelim(boxes_to_remove)        = [];
            
            [~, ~, input_assignments] = hist_bin_assignments( new_box_proposals_IOU_prelim, num_bins );
            new_box_proposals_r0rfc0cf = [];
            new_box_proposals_IOU      = [];
            for bi = 1:num_bins
                cur_bin_inds = find(eq(bi,input_assignments));
                cur_bin_inds_rand_perm = cur_bin_inds(randperm(length(cur_bin_inds)));
                sampled_bin_inds = cur_bin_inds_rand_perm( 1:min(samples_per_bin,length(cur_bin_inds_rand_perm) ) );
                new_box_proposals_r0rfc0cf(end+1:end+length(sampled_bin_inds),:) = new_box_proposals_r0rfc0cf_prelim(sampled_bin_inds,:);
                new_box_proposals_IOU(     end+1:end+length(sampled_bin_inds))   = new_box_proposals_IOU_prelim(sampled_bin_inds);
            end
                    
            num_new_boxes = size(new_box_proposals_r0rfc0cf,1);
            new_box_deltas_xywh = nan( num_new_boxes, 4 );
            
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
               
            end
            
            box_proposals_r0rfc0cf{imi,oi}     = new_box_proposals_r0rfc0cf;
            box_sources_r0rfc0cf{imi,oi}       = repmat(cur_ob_box_r0rfc0cf,size(new_box_proposals_r0rfc0cf,1),1);
            box_source_obj_type{imi,oi}        = repmat(oi,size(new_box_proposals_r0rfc0cf,1),1);
            IOUs_with_source{imi,oi}           = new_box_proposals_IOU';
            fname_source_index{imi,oi}         = repmat( imi, size(new_box_proposals_r0rfc0cf,1), 1 );
            box_deltas_xywh{imi,oi}            = new_box_deltas_xywh;
            
        end
        
        progress(imi,num_images);
        
    end
    
    
    
    %% more expensive stuff
    % getting the actual cnn features
    
    box_proposal_cnn_features   = cell(num_images,num_situation_objects);
    box_proposal_gt_IOUs        = cell(num_images,num_situation_objects);
    
    tic;
    for imi = 1:num_images
        
        im = imread( strrep( strrep( fnames{imi}, 'labl', 'jpg' ), 'json', 'jpg') ); % ugh
        cur_im_data = situate.labl_load( fnames{imi}, situation_struct );
        
        for oi  = 1:num_situation_objects

            wi = strcmp(cur_im_data.labels_adjusted,situation_objects{oi}); % workspace index for the object of interest

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
    
    disp('cnn features computed');
    
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
        fname_out = fullfile(directory_out, [ [situation_objects{:}] '_cnn_features_and_IOUs' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat' ]);
    else
        % just save it to the working directory then
        fname_out = [ [situation_objects{:}] '_cnn_features_and_IOUs' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat' ];
    end
    
    % this helps to keep track of what's been included, rather than trying to figure it out from the
    % save call
    output_struct = [];
    output_struct.fnames                        = fnames;
    output_struct.object_labels                 = situation_objects;
    output_struct.box_proposals_r0rfc0cf        = box_proposals_r0rfc0cf;
    output_struct.box_sources_r0rfc0cf          = box_sources_r0rfc0cf;
    output_struct.box_source_obj_type           = box_source_obj_type;
    output_struct.IOUs_with_source              = IOUs_with_source;
    output_struct.IOUs_with_each_gt_obj         = IOUs_with_each_gt_obj;
    output_struct.box_proposal_gt_IOUs          = box_proposal_gt_IOUs;
    output_struct.fname_source_index            = fname_source_index;
    output_struct.box_proposal_cnn_features     = box_proposal_cnn_features;
    output_struct.box_deltas_xywh               = box_deltas_xywh;
    output_struct.box_density_prior             = box_density_prior;
    output_struct.box_density_conditioned       = box_density_conditioned;
    
    save( fname_out, '-v7.3', ...
        '-struct', 'output_struct' );
    
    disp(['saved cnn_features_and_IOUs data to ' fname_out]);
    
end
    
    
         


