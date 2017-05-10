function [classifier_output, iou] = IOU_ridge_regression_apply( classifier_struct, target_class, im, box_r0rfc0cf, lb )
% [classifier_output, ground_truth_iou] = IOU_ridge_regression_apply( classifier_struct, target_class, im, box_r0rfc0cf, [lb] )

    % should be in 0-255
    if mean(im(:)) < 1
        im = 255 * im;
    end

    r0 = box_r0rfc0cf(:,1);
    rf = box_r0rfc0cf(:,2);
    c0 = box_r0rfc0cf(:,3);
    cf = box_r0rfc0cf(:,4);
    image_crop = im(r0:rf,c0:cf,:);

    if min(size(image_crop))==0
        % it's possible that we sample a box that gives us a busted crop.
        % if that happens, just return a nonsense confidence value that
        % will definitely fail to beat the max workspace entry
        classifier_output=-1;
        return;
    end
  
    model_ind = strcmp( classifier_struct.classes, target_class );
    
    cnn_features = cnn.cnn_process( image_crop );
    classifier_output = [1 cnn_features'] * classifier_struct.models{model_ind};
    
    if classifier_output > 5 || classifier_output < -1
       display('bloop'); 
    end
    
    if exist('lb','var')
        gt_box_r0rfc0cf = lb.boxes_r0rfc0cf( strcmp(target_class,lb.labels_adjusted), : );
        iou = intersection_over_union( box_r0rfc0cf, gt_box_r0rfc0cf, 'r0rfc0cf' );
    end

end