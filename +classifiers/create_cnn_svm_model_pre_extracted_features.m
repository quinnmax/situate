function [models] = create_cnn_svm_model_pre_extracted_features( fnames_in, p )

    %existing_features_fname = '/Users/Max/Desktop/cnn_features_and_IOUs_padding_0_255.mat';
    existing_features_fname = '/Users/Max/Desktop/cnn_features_and_IOUs_nopadding_0_255.mat';
    data = load(existing_features_fname);
    
    if ~exist('fnames_in','var') || isempty(fnames_in)
        fnames_in = data.fnames(1:400);
        warning('create_cnn_svm_pre_extracted_features using default data');
    end
    if ~exist('p','var') || isempty(p)
        p = data.p;
        warning('create_cnn_svm_pre_extracted_features using default data');
    end
    
    fnames_in_pathless   = cellfun( @(x) x(last(strfind(x,filesep))+1:end), fnames_in, 'UniformOutput', false );
    fnames_data_pathless = cellfun( @(x) x(last(strfind(x,filesep))+1:end), data.fnames, 'UniformOutput', false );
    im_inds_train  = find( ismember( fnames_data_pathless, fnames_in_pathless ) );
    box_rows_train = ismember( data.fname_source_index, im_inds_train );
    
    assert(isequal( data.p.situation_objects, p.situation_objects ));
     
    % need to figure out the iou between each box and each gt object
    gt_boxes_per_image_and_object_r0rfc0cf = cell( max(data.fname_source_index), max(data.box_source_obj_type) );
    for data_row = 1:length(data.box_source_obj_type)
        cur_imi_index = data.fname_source_index( data_row );
        cur_obj_index = data.box_source_obj_type( data_row );
        gt_boxes_per_image_and_object_r0rfc0cf{cur_imi_index,cur_obj_index} = data.box_sources_r0rfc0cf(data_row,:);
    end
    
    proposal_vs_gt_box_IOUs = -1 * ones( length(data.box_source_obj_type), length(p.situation_objects) );
    for data_row = 1:length(data.box_source_obj_type)
    for gt_obj_type = 1:length(p.situation_objects)
        cur_box_r0rfc0cf = data.box_proposals_r0rfc0cf(data_row,:);
        gt_box_r0rfc0cf  = gt_boxes_per_image_and_object_r0rfc0cf{ data.fname_source_index(data_row), gt_obj_type };
        proposal_vs_gt_box_IOUs(data_row,gt_obj_type) = intersection_over_union( cur_box_r0rfc0cf, gt_box_r0rfc0cf, 'r0rfc0cf' ); 
    end
    end
    
    
    
    pos_IOU_floor    = .8; % how good of an IOU before we consider it an instance of the target object?
    neg_IOU_ceil     = .001; % how bad until we consider it an acceptable non-target image
    
    
    crop_size_threshold_px = 5000;
    box_proposal_wh     = [data.box_proposals_r0rfc0cf(:,2)-data.box_proposals_r0rfc0cf(:,1)+1 data.box_proposals_r0rfc0cf(:,4)-data.box_proposals_r0rfc0cf(:,3)+1];
    source_crop_size_px = box_proposal_wh(:,1) .* box_proposal_wh(:,2);
    small_source_inds   =  source_crop_size_px < crop_size_threshold_px ;
    
    background_inds = max(data.box_proposal_gt_IOUs,[],2) < .15; % find inds that are no object
    
    models = cell( length(p.situation_objects), 1 );
    
    for oi = 1:length(p.situation_objects )
        
        obj_inds = data.box_source_obj_type == oi;
    
        over_IOU_inds  = proposal_vs_gt_box_IOUs(:,oi) >= pos_IOU_floor;
        
        inds_train_target    = find( box_rows_train & obj_inds & over_IOU_inds & ~small_source_inds );
        %inds_train_target    = find( box_rows_train & obj_inds & over_IOU_inds );
        
        inds_train_nontarget = find( box_rows_train & background_inds & ~small_source_inds );
        %inds_train_nontarget = find( box_rows_train & background_inds );
        %inds_train_nontarget = find( box_rows_train & under_IOU_inds );
            rp = randperm(length(inds_train_nontarget));
            rp = rp( 1:min(round(1.5*length(inds_train_target)),length(rp)) );
            inds_train_nontarget = inds_train_nontarget( rp );
        
        x = [ data.box_proposal_cnn_features( inds_train_target, : ); ...
              data.box_proposal_cnn_features( inds_train_nontarget, : ) ];
        y = [true( length(inds_train_target),1); false( length(inds_train_nontarget),1) ];
        
        models{oi} = fitcsvm(x, y, 'Standardize', true, 'OutlierFraction', .25);
        models{oi} = models{oi}.compact;
        models{oi} = models{oi}.fitPosterior(x,y);
        fprintf('.');
        
    end
    
    display('cnn svm model training done');
    
    
    % validate the newly generated models
    
    do_validation = false;
    
    if do_validation

        validation_data = cell(1,length(p.situation_objects));
        validation_rows = cell(1,length(p.situation_objects));
        for oi = 1:length(p.situation_objects) 
            obj_inds = data.box_source_obj_type == oi;
            %cur_rows = obj_inds & ~box_rows_train;
            
            % limit number of rows evaluated
            max_eval_rows = 5000;
            cur_rows = obj_inds & box_rows_train;
            cur_rows_list = find( cur_rows );
            cur_rows_list = cur_rows_list( randperm( length(cur_rows_list)) );
            cur_rows_list = cur_rows_list( 1:min(length(cur_rows_list),max_eval_rows) );
            cur_rows = false( size(cur_rows) );
            cur_rows( cur_rows_list ) = true;
            validation_rows{oi} = cur_rows;
            
            x = data.box_proposal_cnn_features( cur_rows, : );
            [~, scores] = models{oi}.predict( x );
            validation_data{oi} = [ data.IOUs_with_source(cur_rows), scores(:,2)  ];
        end

        figure('Name','IOU vs classifier score');
        for oi = 1:length(p.situation_objects) 
            subplot(1,length(p.situation_objects),oi)
            plot( validation_data{oi}(:,1), validation_data{oi}(:,2)+.05*randn(size(validation_data{oi}(:,2))),'.');
            xlabel('IOU with source');
            ylabel('classifier confidence');
        end
        
        for oi = 1:length(p.situation_objects)
            bad_misses = validation_data{oi}(:,1) < .1 & validation_data{oi}(:,2) > .95;
            cur_validation_rows = find(validation_rows{oi});
            bad_miss_rows = cur_validation_rows( bad_misses );
            figure('Name',['false positives: ' p.situation_objects{oi}])
            for bmi = 1:min(length(bad_miss_rows),20)
                subplot(4,5,bmi)
                cur_fname = data.fnames{ data.fname_source_index(bad_miss_rows(bmi)) };
                [~,cur_im] = situate.load_image_and_data( cur_fname, p, true);
                cur_box_r0rfc0cf = data.box_proposals_r0rfc0cf( bad_miss_rows(bmi), : );
                r0 = cur_box_r0rfc0cf(1);
                rf = cur_box_r0rfc0cf(2);
                c0 = cur_box_r0rfc0cf(3);
                cf = cur_box_r0rfc0cf(4);
                cur_crop = cur_im(r0:rf,c0:cf,:);
%                 pad_w = round(.1 * (cf-c0+1));
%                 pad_h = round(.1 * (rf-r0+1));
%                 cur_crop = cur_im(r0-pad_h:rf+pad_h-1,c0-pad_w:cf+pad_w-1,:);
                imshow(cur_crop);
                fprintf('.');
            end
            fprintf('\n');
        end
               
                
                
        
      
           
    end
    
    
end

    