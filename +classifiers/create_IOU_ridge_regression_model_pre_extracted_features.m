function [models, AUROCs] = create_IOU_ridge_regression_model_pre_extracted_features( fnames_in, feature_file_fname, p )
%[models, model_AUROCs] = create_IOU_ridge_regression_model_pre_extracted_features( fnames_in, feature_file_fname, p )
    
    data = load(feature_file_fname);
    
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
    
    crop_size_threshold_px = 5000;
    box_proposal_wh     = [data.box_proposals_r0rfc0cf(:,2)-data.box_proposals_r0rfc0cf(:,1)+1 data.box_proposals_r0rfc0cf(:,4)-data.box_proposals_r0rfc0cf(:,3)+1];
    source_crop_size_px = box_proposal_wh(:,1) .* box_proposal_wh(:,2);
    small_source_inds   =  source_crop_size_px < crop_size_threshold_px ;
    
    models = cell( length(p.situation_objects), 1 );
    
    tic
    for oi = 1:length(p.situation_objects )
        obj_inds = data.box_source_obj_type == oi;
        inds_train = find( box_rows_train & obj_inds & ~small_source_inds );
        x = data.box_proposal_cnn_features( inds_train, : );
        y = data.IOUs_with_source( inds_train );
        models{oi} = ridge( y, x, 1000, 0 );
        fprintf('.');
    end
    toc
    
    
    % get classifier scores on training images
    classifier_scores = zeros( size(data.box_source_obj_type,1), length(p.situation_objects) );
    num_boxes = size(data.box_sources_r0rfc0cf,1);
    for oi = 1:length(p.situation_objects)
        classifier_scores(:,oi) = [ones(num_boxes,1) data.box_proposal_cnn_features] * models{oi};
    end
    
    % get AUROC for each trained model
    % (over under .5 IOU)
    AUROCs = zeros(1,length(p.situation_objects));
    for oi = 1:length(p.situation_objects)

        label = data.IOUs_with_each_gt_obj(:,oi) > .5;
        AUROCs(oi) = ROC( classifier_scores(:,oi), label );

    end
    
    
    display('IOU ridge regression model training done');
    
    % validate the newly generated models
    
    do_validation = false;
    
    if do_validation

        validation_data = cell(1,length(p.situation_objects));
        validation_rows = cell(1,length(p.situation_objects));
        for oi = 1:length(p.situation_objects) 
            obj_inds = data.box_source_obj_type == oi;
            %cur_rows = obj_inds & ~box_rows_train;
            
            % limit number of rows evaluated
            max_eval_rows = 10000;
            cur_rows = obj_inds & ~box_rows_train;
            cur_rows_list = find( cur_rows );
            cur_rows_list = cur_rows_list( randperm( length(cur_rows_list)) );
            cur_rows_list = cur_rows_list( 1:min(length(cur_rows_list),max_eval_rows) );
            cur_rows = false( size(cur_rows) );
            cur_rows( cur_rows_list ) = true;
            validation_rows{oi} = cur_rows;
            
            x = data.box_proposal_cnn_features( cur_rows, : );
            x = [ones(size(x,1),1) x];
            if num_boost_replications ~= 1  
                scores = mean( x * [models{oi,:}], 2 );
            else
                scores = x * models{oi};
            end
            validation_data{oi} = [ data.IOUs_with_source(cur_rows), scores  ];
        end

        figure('Name','IOU vs predicted IOU');
        for oi = 1:length(p.situation_objects) 
            subplot(1,length(p.situation_objects),oi)
            temp = corrcoef( validation_data{oi}(:,1), validation_data{oi}(:,2) );
            plot( validation_data{oi}(:,1), validation_data{oi}(:,2),'.');
            legend( num2str( temp(1,2) ) );
            xlabel('gt IOU');
            ylabel('predicted IOU');
        end
        
        for oi = 1:length(p.situation_objects)
            bad_misses = validation_data{oi}(:,1) < .25 & validation_data{oi}(:,2) > .75;
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

    