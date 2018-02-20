


    data = load('/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/dogwalkerdogleash_cnn_features_and_IOUs2017.10.31.00.47.35.mat');
    
    % data = load('/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/handshake_participants_cnn_featuers_and_IOUs.mat');

    
    
    %%
    
    classes = data.object_labels;
    training_image_inds = 1:round(length(data.fnames)*.75);
    rows_train  = ismember(data.fname_source_index, training_image_inds );

    crop_size_threshold_px = 4096;
    crop_wh     = [data.box_proposals_r0rfc0cf(:,2)-data.box_proposals_r0rfc0cf(:,1)+1 data.box_proposals_r0rfc0cf(:,4)-data.box_proposals_r0rfc0cf(:,3)+1];
    crop_size_px = crop_wh(:,1) .* crop_wh(:,2);
    small_source_inds   =  crop_size_px < crop_size_threshold_px ;

    assert(isequal( sort(data.object_labels), sort(classes) ));
    models = cell( length(classes), 1 );
    scores = cell( length(classes), 1 );
    AUROCs = zeros(1,length(classes));
    
    AUROCs_on_training_data = zeros(1,length(classes)); % curious

    acceptable_confusions_matrix = false( length(classes), length(classes) );
    for oi = 1:length(classes)
    for oj = 1:length(classes)
        acceptable_confusions_matrix(oi,oj) = isequal( data.p.situation_objects_possible_labels{oi}, data.p.situation_objects_possible_labels{oj} );
    end
    end
    
    for oi = 1:length(classes)

        obj_inds = data.box_source_obj_type == find(strcmp(classes{oi}, data.object_labels));
        inds_train = find( rows_train & obj_inds & ~small_source_inds );

        % do trust round
        inds_train_trust = inds_train(1:round(.8*length(inds_train)));
        inds_test_trust  = setdiff( inds_train, inds_train_trust );
        x = data.box_proposal_cnn_features( inds_train_trust, : );
        %y = data.IOUs_with_source( inds_train_trust );
        y = data.IOUs_with_each_gt_obj( inds_train_trust, acceptable_confusions_matrix(oi,:) );
        if size(y,2) > 1
            y = max(y,[],2);
        end
        temp_model = ridge( y, x, 1000, 0 );

        x = data.box_proposal_cnn_features( inds_test_trust, : );
        %y = data.IOUs_with_source( inds_test_trust );
        y = data.IOUs_with_each_gt_obj( inds_test_trust, acceptable_confusions_matrix(oi,:) );
        if size(y,2) > 1
            y = max(y,[],2);
        end
        temp_scores = [ones(size(x,1),1) x] * temp_model;
        AUROCs(oi)  = ROC( temp_scores, y>=.5 );

        % then do full training
        x = data.box_proposal_cnn_features( inds_train, : );
        %y = data.IOUs_with_source( inds_train );
        y = data.IOUs_with_each_gt_obj( inds_train, acceptable_confusions_matrix(oi,:) );
        if size(y,2) > 1
            y = max(y,[],2);
        end
        models{oi} = ridge( y, x, 1000, 0 );
        temp_scores = [ones(size(x,1),1) x] * models{oi};
        AUROCs_on_training_data(oi) = ROC( temp_scores, y>=.5 );
        
        fprintf('%s AUROC on validation:   %f \n', classes{oi}, AUROCs(oi) );
        fprintf('%s AUROC during training: %f \n', classes{oi}, AUROCs_on_training_data(oi) );

    end
    
%%

    temp = cnn.cnn_process( imread('cameraman.tif') );
    num_cnn_features = length(temp);
    
    model_mat = horzcat(models{:});

    situation_struct = situate.situation_struct_load_all('dogwalking');
    
    % load a few example images
    testing_image_inds = setsub(1:length(data.fnames),training_image_inds);
    
    for imii = 1:length(testing_image_inds)
        
        % load label, get gt boxes
        cur_im_ind = testing_image_inds(imii);
        cur_lb_fname = data.fnames{cur_im_ind};
        lb = situate.labl_load(cur_lb_fname, situation_struct);
        gt_boxes_r0rfc0cf = zeros( length(classes), 4 );
        for oi = 1:length(classes)
            lb_ind = find(strcmp( classes{oi}, lb.labels_adjusted ) );
            gt_boxes_r0rfc0cf(oi,:) = lb.boxes_r0rfc0cf( lb_ind, : );
        end
        
        % load image
        cur_im_fname = strrep( cur_lb_fname, 'labl', 'jpg' );
        cur_im_fname = strrep( cur_im_fname, 'json', 'jpg' );
        im = imread(cur_im_fname);
        
        % generate a set of covering boxes
        box_aspect_ratios = [1/2 1/1 2/1];
        box_area_ratios   = [.2 .4].^2;
        overlap_ratio     = .5;
        [boxes_r0rfc0cf, params] = boxes_covering( size(im), box_aspect_ratios, box_area_ratios, overlap_ratio );
        num_boxes = size(boxes_r0rfc0cf,1);
        
        % apply the cnn
        cnn_features = zeros( num_boxes, num_cnn_features );
        IOUs_est = zeros( num_boxes, length(classes) );
        IOUs_gt  = zeros( num_boxes, length(classes) );
        
        for bi = 1:num_boxes
            r0 = boxes_r0rfc0cf(bi,1);
            rf = boxes_r0rfc0cf(bi,2);
            c0 = boxes_r0rfc0cf(bi,3);
            cf = boxes_r0rfc0cf(bi,4);
            % get cnn features
            cnn_features(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
            % get estimated IOUs
            IOUs_est(bi,:) =  [1 cnn_features(bi,:)] * model_mat;
            % get gt IOUs
            IOUs_gt(bi,:) = intersection_over_union( boxes_r0rfc0cf(bi,:), gt_boxes_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );
            progress(bi,num_boxes);
        end
        
        figure;
        for oi = 1:length(classes)
            subplot(1,length(classes),oi)
            plot( IOUs_est(:,oi), IOUs_gt(:,oi),'.')
            title(classes{oi});
        end
        
        accumulator_maps    = zeros(size(im,1),size(im,2),length(classes));
        accumulator_maps_gt = zeros(size(im,1),size(im,2),length(classes));
        for oi = 1:length(classes)
            for bi = 1:num_boxes
                r0 = boxes_r0rfc0cf(bi,1);
                rf = boxes_r0rfc0cf(bi,2);
                c0 = boxes_r0rfc0cf(bi,3);
                cf = boxes_r0rfc0cf(bi,4);
                w = cf - c0 + 1;
                h = rf - r0 + 1;
                
                accumulator_maps(r0:rf,c0:cf,oi) = accumulator_maps(r0:rf,c0:cf,oi) + IOUs_est(bi,oi);
                accumulator_maps_gt(r0:rf,c0:cf,oi) = accumulator_maps_gt(r0:rf,c0:cf,oi) + IOUs_gt(bi,oi);
                
                progress(bi,num_boxes);
            end
        end
        
        accumulator_maps = accumulator_maps / max(accumulator_maps(:));
        acumulator_maps_softmaxed = softmax_dim(accumulator_maps,3);
        
        accumulator_maps_gt = accumulator_maps_gt / max(accumulator_maps_gt(:));
        
        figure;
        for oi = 1:length(classes)
            subplot2(3,length(classes),1,oi)
            imshow(accumulator_maps(:,:,oi))
            title(classes{oi});
            
            subplot2(3,length(classes),2,oi)
            imshow(acumulator_maps_softmaxed(:,:,oi).^4,[]);
            
            subplot2(3,length(classes),3,oi)
            imshow(accumulator_maps_gt(:,:,oi),[]);
        end
        
    
        
        
        
            
        
    end
    
 
  



