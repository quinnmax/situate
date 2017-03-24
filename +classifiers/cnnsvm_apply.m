function [classifier_output, iou] = cnnsvm_apply( classifier_struct, target_class, im, box_r0rfc0cf, lb )
% [classifier_output, ground_truth_iou] = cnnsvm_apply( classifier_struct, target_class, im, box_r0rfc0cf, [lb] )

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
    
    if mean(image_crop(:)) < 1
        image_crop = image_crop * 255;
    end

    model_ind = strcmp( classifier_struct.classes, target_class );
    
    cnn_features = cnn.cnn_process( image_crop );
    [~, scores] = classifier_struct.models{model_ind}.predict( cnn_features' );
    classifier_output = scores(2);
    
    if exist('lb','var')
        gt_box_r0rfc0cf = lb.boxes_r0rfc0cf( strcmp(target_class,lb.labels_adjusted), : );
        iou = intersection_over_union( box_r0rfc0cf, gt_box_r0rfc0cf, 'r0rfc0cf' );
    end

end