

    
%% pick out training images

    situation_file = 'situation_definitions/dogwalking.json';
    im_dir = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/';
    data_split_dir = 'data_splits/dogwalking_validation';
    
    situation_struct = situate.situation_struct_load_json(situation_file);
    situation_objects = situation_struct.situation_objects;
    
    data_split_struct = situate.data_load_splits_from_directory(data_split_dir);
    fnames_train = data_split_struct(1).fnames_lb_train;
    fnames_test  = data_split_struct(1).fnames_lb_test;
    
    

%% train classifier
    
    fnames_data = fileparts_mq(data.fnames,'name');
    
    im_inds_train = find( ismember( fnames_data, fnames_train ) );
    im_inds_test  = find( ismember( fnames_data, fnames_test  ) );
    
    rows_train  = ismember(data.fname_source_index, im_inds_train );
    
    
    crop_size_threshold_px = 4096;
    crop_wh     = [data.box_proposals_r0rfc0cf(:,2)-data.box_proposals_r0rfc0cf(:,1)+1 data.box_proposals_r0rfc0cf(:,4)-data.box_proposals_r0rfc0cf(:,3)+1];
    crop_size_px = crop_wh(:,1) .* crop_wh(:,2);
    small_source_inds   =  crop_size_px < crop_size_threshold_px ;

    assert(isequal( sort(data.object_labels), sort(situation_objects) ));
    models = cell( length(situation_objects), 1 );
    scores = cell( length(situation_objects), 1 );
    AUROCs = zeros(1,length(situation_objects));
    
    AUROCs_on_training_data = zeros(1,length(situation_objects)); % curious

    acceptable_confusions_matrix = false( length(situation_objects), length(situation_objects) );
    for oi = 1:length(situation_objects)
    for oj = 1:length(situation_objects)
        acceptable_confusions_matrix(oi,oj) = isequal( data.p.situation_objects_possible_labels{oi}, data.p.situation_objects_possible_labels{oj} );
    end
    end
    
    for oi = 1:length(situation_objects)

        obj_inds = data.box_source_obj_type == find(strcmp(situation_objects{oi}, data.object_labels));
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
        
        fprintf('%s AUROC on validation:   %f \n', situation_objects{oi}, AUROCs(oi) );
        fprintf('%s AUROC during training: %f \n', situation_objects{oi}, AUROCs_on_training_data(oi) );

    end
    
    
    
%% load IOU regressor and box-adjust model

        classifier_struct = classifiers.IOU_ridge_regression_train( situation_struct, fnames_train, 'saved_models/');
        models = classifier_struct.models;
        classification_model_mat = horzcat(models{:});

        %agent_adjust_struct = agent_adjustment.bb_regression_two_tone_train( situation_struct, fnames_train, 'saved_models/', [.1 .6] );
        agent_adjust_struct = agent_adjustment.bb_regression_train( situation_struct, fnames_train, 'saved_models/', .6 );

        
        
%%

    temp = cnn.cnn_process( imread('cameraman.tif') );
    num_cnn_features = length(temp);
    
    for imi = 1:length(fnames_test)
        
        % load label, get gt boxes
        cur_lb_fname = fullfile( im_dir, fnames_test{imi} );
        lb = situate.labl_load(cur_lb_fname, situation_struct);
        gt_boxes_r0rfc0cf = zeros( length(situation_objects), 4 );
        for oi = 1:length(situation_objects)
            lb_ind = find(strcmp( situation_objects{oi}, lb.labels_adjusted ) );
            gt_boxes_r0rfc0cf(oi,:) = lb.boxes_r0rfc0cf( lb_ind, : );
        end
        
        % load image
        cur_im_fname = strrep( cur_lb_fname, 'labl', 'jpg' );
        cur_im_fname = strrep( cur_im_fname, 'json', 'jpg' );
        im = imread(cur_im_fname);
        
        % generate a set of covering boxes
        box_aspect_ratios = [1/2 1/1 2/1];
        %box_area_ratios   = [1/16 1/4];
        box_area_ratios = (1./(2:4)).^2;
        overlap_ratio     = .5;
        [boxes_r0rfc0cf, params] = boxes_covering( size(im), box_aspect_ratios, box_area_ratios, overlap_ratio );
        num_boxes = size(boxes_r0rfc0cf,1);
        
        % apply cnn, get IOU estimates
        cnn_features     = zeros( num_boxes, num_cnn_features );
        IOUs_est         = zeros( num_boxes, length(situation_objects) );
        IOUs_est_softmax = zeros( num_boxes, length(situation_objects) );
        IOUs_gt          = zeros( num_boxes, length(situation_objects) );
        
        for bi = 1:num_boxes
            r0 = boxes_r0rfc0cf(bi,1);
            rf = boxes_r0rfc0cf(bi,2);
            c0 = boxes_r0rfc0cf(bi,3);
            cf = boxes_r0rfc0cf(bi,4);
            
            % get cnn features
            cnn_features(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
            
            % get estimated IOUs
            IOUs_est(bi,:) =  [1 cnn_features(bi,:)] * classification_model_mat;
            % softamax
            IOUs_est_softmax(bi,:) = softmax_dim(IOUs_est(bi,:),2);
            % get gt IOUs
            IOUs_gt(bi,:) = intersection_over_union( boxes_r0rfc0cf(bi,:), gt_boxes_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );
            
            progress(bi,num_boxes);
        end
        
        figure('name','using initial covering')
        for oi = 1:length(situation_objects)
            subplot(1,length(situation_objects),oi);
            plot( IOUs_est(eq(box_obj_assignment,oi)), IOUs_gt(eq(box_obj_assignment,oi)), '.' );
            xlim([-.1 1.1]);
            ylim([-.1 1.1]);
            title(situation_objects{oi});
        end
        
        % do local non-max supression
        IOU_suppression_threshold = .25;
        IOUs_nms = IOUs_est;
        go_again = true;
        while go_again
            go_again = false;
            for bi = 1:size(boxes_r0rfc0cf,1)
                iou_vect = intersection_over_union( boxes_r0rfc0cf(bi,:), boxes_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );
                for oi = 1:length(situation_objects)
                    overlap_box_inds = iou_vect > IOU_suppression_threshold;
                    if all(IOUs_nms(bi,oi) >= IOUs_nms( overlap_box_inds, oi ))
                        suppress_inds = setsub( find(overlap_box_inds), bi );
                        if any( IOUs_nms( suppress_inds, oi ) ~= 0 )
                            IOUs_nms( suppress_inds, oi ) = 0;
                            go_again = true;
                        end
                        
                    end
                end
            end
            display('going again');
        end
        
        
        
        
        
        
        
        
        
        
        
        % assign boxes to objects
        [box_obj_IOU_est, box_obj_assignment] = max(IOUs_est,[],2);
        
        % cull
        % remove boxes that are under IOU threshold
        iou_threshold = .0;
        inds_keep = box_obj_IOU_est >= iou_threshold;
        boxes_culled_r0rfc0cf = boxes_r0rfc0cf(inds_keep,:);
        boxes_culled_IOU_est = box_obj_IOU_est(inds_keep);
        boxes_culled_obj_assignment = box_obj_assignment(inds_keep);
        cnn_features_culled = cnn_features(inds_keep,:);
        num_boxes = size(boxes_culled_r0rfc0cf,1);
        
        % get adjusted boxes
        boxes_adjusted_r0rfc0cf = zeros(num_boxes, 4);
        for bi = 1:num_boxes
            % select the box adjust vector we want to use based on obj, IOU est
            oi = boxes_culled_obj_assignment(bi);
            if isfield(agent_adjust_struct,'sub_models')
                if boxes_culled_IOU_est(bi) < agent_adjust_struct.model_selection_threshold(oi)
                    box_adjust_weights = horzcat( agent_adjust_struct.sub_models{1}.weight_vectors{oi,:} );
                else
                    box_adjust_weights = horzcat( agent_adjust_struct.sub_models{2}.weight_vectors{oi,:} );
                end
            else
                box_adjust_weights = horzcat( agent_adjust_struct.weight_vectors{oi,:} );
            end
            % get the updated box
            boxes_adjusted_r0rfc0cf(bi,:) = agent_adjustment.bb_regression_adjust_box( box_adjust_weights, boxes_culled_r0rfc0cf(bi,:), im, cnn_features_culled(bi,:) );
        end
        
        % apply cnn, get IOU estimates
        boxes_adjusted_cnn_features = zeros( num_boxes, num_cnn_features );
        boxes_adjusted_IOUs_est     = zeros( num_boxes, length(situation_objects) );
        boxes_adjusted_IOUs_gt      = zeros( num_boxes, length(situation_objects) );
        for bi = 1:num_boxes
            r0 = boxes_adjusted_r0rfc0cf(bi,1);
            rf = boxes_adjusted_r0rfc0cf(bi,2);
            c0 = boxes_adjusted_r0rfc0cf(bi,3);
            cf = boxes_adjusted_r0rfc0cf(bi,4);
            
            % get cnn features
            boxes_adjusted_cnn_features(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
            % get estimated IOUs
            boxes_adjusted_IOUs_est(bi,:) =  [1 boxes_adjusted_cnn_features(bi,:)] * classification_model_mat;
            % get gt IOUs
            boxes_adjusted_IOUs_gt(bi,:) = intersection_over_union( boxes_adjusted_r0rfc0cf(bi,:), gt_boxes_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );
            
            progress(bi,num_boxes);
        end
        
        % do local non-max supression
        IOU_suppression_threshold = .25;
        boxes_adjusted_IOUs_est_nms = boxes_adjusted_IOUs_est;
        go_again = true;
        while go_again
            go_again = false;
            for bi = 1:size(boxes_adjusted_r0rfc0cf,1)
                iou_vect = intersection_over_union( boxes_adjusted_r0rfc0cf(bi,:), boxes_adjusted_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );
                for oi = 1:length(situation_objects)
                    overlap_box_inds = iou_vect > IOU_suppression_threshold;
                    if all(boxes_adjusted_IOUs_est_nms(bi,oi) >= boxes_adjusted_IOUs_est_nms( overlap_box_inds, oi ))
                        suppress_inds = setsub( find(overlap_box_inds), bi );
                        if any( boxes_adjusted_IOUs_est_nms( suppress_inds, oi ) ~= 0 )
                            boxes_adjusted_IOUs_est_nms( suppress_inds, oi ) = 0;
                            go_again = true;
                        end
                        
                    end
                end
            end
            display('going again');
        end
        
   
        
        num_boxes_to_show = 5;
        figure()
        for oi = 1:length(situation_objects)
            
            cur_inds = eq( boxes_culled_obj_assignment, oi );
            
            subplot2(2,length(situation_objects),1,oi);
            plot( boxes_adjusted_IOUs_est_nms(cur_inds), boxes_adjusted_IOUs_gt(cur_inds),'.');
            title(situation_objects{oi});
            xlabel('boxes adjusted est IOU');
            ylabel('boxes adjusted gt IOU');
            xlim([-.1 1.1]);
            ylim([-.1 1.1]);
            
            [cur_est_ious,sort_order] = sort(boxes_adjusted_IOUs_est_nms(cur_inds,:),'descend');
            cur_boxes = boxes_adjusted_r0rfc0cf(cur_inds,:);
            cur_boxes = cur_boxes(sort_order,:);
            
            
            subplot2(2,length(situation_objects),2,oi);
            imshow(im);
            hold on;
            draw_box( cur_boxes(1:num_boxes_to_show,:), 'r0rfc0cf');
            for bi = 1:num_boxes_to_show
               text(cur_boxes(bi,3), cur_boxes(bi,1), num2str(cur_est_ious(bi)) )
            end
            hold off
            
        end
        
         
        
        % build accumulator maps
        accumulator_maps    = zeros(size(im,1),size(im,2),length(situation_objects));
        accumulator_maps_nms = zeros(size(im,1),size(im,2),length(situation_objects)); % non max supression
        accumulator_maps_gt = zeros(size(im,1),size(im,2),length(situation_objects));  % ground truth
        
        for oi = 1:length(situation_objects)
            for bi = 1:size(boxes_r0rfc0cf,1)
                r0 = boxes_r0rfc0cf(bi,1);
                rf = boxes_r0rfc0cf(bi,2);
                c0 = boxes_r0rfc0cf(bi,3);
                cf = boxes_r0rfc0cf(bi,4);
                w = cf - c0 + 1;
                h = rf - r0 + 1;
                
                accumulator_maps(r0:rf,c0:cf,oi)     = accumulator_maps(r0:rf,c0:cf,oi)     + IOUs_est(bi,oi);
                accumulator_maps_nms(r0:rf,c0:cf,oi) = accumulator_maps_nms(r0:rf,c0:cf,oi) + IOUs_nms(bi,oi);
                accumulator_maps_gt(r0:rf,c0:cf,oi)  = accumulator_maps_gt(r0:rf,c0:cf,oi)  + IOUs_gt(bi,oi);
                
                progress(bi,size(boxes_r0rfc0cf,1));
            end
        end
        
        accumulator_maps = accumulator_maps / max(accumulator_maps(:));
        accumulator_maps_gt = accumulator_maps_gt / max(accumulator_maps_gt(:));
        accumulator_maps_nms = accumulator_maps_nms / max(accumulator_maps_nms(:));
     
        % do it for adjusted boxes
        accumulator_maps_adjusted_boxes = zeros(size(im,1),size(im,2),length(situation_objects)); 
        accumulator_maps_adjusted_boxes_nms = zeros(size(im,1),size(im,2),length(situation_objects)); % non max supression
        for oi = 1:length(situation_objects)
            for bi = 1:size(boxes_adjusted_r0rfc0cf,1)
                r0 = boxes_adjusted_r0rfc0cf(bi,1);
                rf = boxes_adjusted_r0rfc0cf(bi,2);
                c0 = boxes_adjusted_r0rfc0cf(bi,3);
                cf = boxes_adjusted_r0rfc0cf(bi,4);
                w = cf - c0 + 1;
                h = rf - r0 + 1;
                
                accumulator_maps_adjusted_boxes(r0:rf,c0:cf,oi) = accumulator_maps_adjusted_boxes(r0:rf,c0:cf,oi) + boxes_adjusted_IOUs_est(bi,oi);
                accumulator_maps_adjusted_boxes_nms(r0:rf,c0:cf,oi) = accumulator_maps_adjusted_boxes_nms(r0:rf,c0:cf,oi) + boxes_adjusted_IOUs_est_nms(bi,oi);
                
                progress(bi,size(boxes_adjusted_r0rfc0cf,1));
            end
        end
        accumulator_maps_adjusted_boxes = accumulator_maps_adjusted_boxes / max(accumulator_maps_adjusted_boxes(:));
        accumulator_maps_adjusted_boxes_nms = accumulator_maps_adjusted_boxes_nms / max(accumulator_maps_adjusted_boxes_nms(:));
        
    
        
        figure;
        for oi = 1:length(situation_objects)
            subplot2(5,length(situation_objects),1,oi)
            imshow(accumulator_maps(:,:,oi))
            
            title(situation_objects{oi});
            if oi == 1, ylabel('IOU est sum'); end
            
            subplot2(5,length(situation_objects),2,oi)
            imshow(accumulator_maps_nms(:,:,oi),[]);
            if oi == 1, ylabel('IOU nms'); end
            
            subplot2(5,length(situation_objects),3,oi)
            imshow(accumulator_maps_adjusted_boxes(:,:,oi),[]);
            if oi == 1, ylabel('IOU adjusted boxes'); end
            
            subplot2(5,length(situation_objects),4,oi)
            imshow(accumulator_maps_adjusted_boxes_nms(:,:,oi),[]);
            if oi == 1, ylabel('IOU adjusted boxes'); end
            
            subplot2(5,length(situation_objects),5,oi)
            imshow(accumulator_maps_gt(:,:,oi),[]);
            if oi == 1, ylabel('IOU gt sum'); end
            
        end
        
    
        
        
        
            
        
    end
    
 
  



