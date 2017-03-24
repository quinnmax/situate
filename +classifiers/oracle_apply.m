function [noisy_iou, gt_iou] = oracle_apply( classifier_model_struct, target_class_string, ~, box_r0rfc0cf, im_data )
% [noisy_iou, gt_iou] = oracle_apply( classifier_model_struct, target_class_string, image, box_r0rfc0cf, label_file );

    if ~exist('classifier_model_struct','var')
        classifier_model_struct = [];
        classifier_model_struct.mu = 0;
        classifier_model_struct.sigma = 0;
    end
        
    gt_box_r0rfc0cf = im_data.boxes_r0rfc0cf( strcmp( target_class_string, im_data.labels_adjusted ),:);
    
    gt_iou = intersection_over_union( gt_box_r0rfc0cf, box_r0rfc0cf, 'r0rfc0cf' );
    
    noisy_iou = gt_iou + classifier_model_struct.mu + classifier_model_struct.sigma * randn();
    
end