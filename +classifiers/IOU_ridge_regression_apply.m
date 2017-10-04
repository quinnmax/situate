function [classifier_output, gt_iou, cnn_feature_vect]    = IOU_ridge_regression_apply( classifier_struct, target_class, im, box_r0rfc0cf, lb )
% [classifier_output, ground_truth_iou, cnn_feature_vect] = IOU_ridge_regression_apply( classifier_struct, target_class, im, box_r0rfc0cf, [lb] )

    persistent im_old;
    persistent box_r0rfc0cf_old;
    persistent cnn_feature_vect_old;
    
    if isequal(box_r0rfc0cf, box_r0rfc0cf_old) && isequal(im, im_old)
        cnn_feature_vect = cnn_feature_vect_old;
    else

        % should be in 0-255
        if mean(im(:)) < 1
            im = 255 * im;
        end

        r0 = box_r0rfc0cf(:,1);
        rf = box_r0rfc0cf(:,2);
        c0 = box_r0rfc0cf(:,3);
        cf = box_r0rfc0cf(:,4);
        
        % fix boxes
        r0 = max(r0,1);
        rf = min(rf,size(im,1));
        c0 = max(c0,1);
        cf = min(cf,size(im,2));
        
        image_crop = im(r0:rf,c0:cf,:);

        if min(size(image_crop))==0
            % it's possible that we sample a box that gives us a busted crop.
            % if that happens, just return a nonsense confidence value that
            % will definitely fail to beat the max workspace entry
            classifier_output=-1;
            return;
        end

        cnn_feature_vect = cnn.cnn_process( image_crop );
        
        % make these new values the old values
        im_old = im;
        box_r0rfc0cf_old = box_r0rfc0cf;
        cnn_feature_vect_old = cnn_feature_vect;
        
    end
    
    model_ind = strcmp( classifier_struct.classes, target_class );
    classifier_output = [1 cnn_feature_vect'] * classifier_struct.models{model_ind};
    
    if classifier_output > 5 || classifier_output < -1
       warning('classifiers.IOU_ridge_regression_apply is giving some extreme values'); 
    end
    
    if exist('lb','var') && ~isempty(lb) && any(ismember(lb.labels_adjusted,target_class))
        gt_box_r0rfc0cf = lb.boxes_r0rfc0cf( strcmp(target_class,lb.labels_adjusted), : );
        gt_iou = intersection_over_union( box_r0rfc0cf, gt_box_r0rfc0cf, 'r0rfc0cf' );
    else
        gt_iou = nan;
    end

end