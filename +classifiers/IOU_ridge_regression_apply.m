function [classifier_output, cnn_feature_vect] = IOU_ridge_regression_apply( classifier_struct, target_class, im, box_r0rfc0cf, varargin )
% [classifier_output, cnn_feature_vect] = IOU_ridge_regression_apply(classifier_struct, target_class, im, box_r0rfc0cf );
%
% given 
%   a trained model (classifier_struct ), 
%   a target class known to the model (string), 
%   an image,
%   a bounding box specifying a region in the image (r0 rf c0 cf format), 
% produces
%   estimate the intersection over union between the proposed box and a ground truth box
%   the cnn feature vector that was generated during the estimation

    persistent im_old;
    persistent box_r0rfc0cf_old;
    persistent cnn_feature_vect_old;
    
    if isequal(box_r0rfc0cf, box_r0rfc0cf_old) && isequal(im, im_old)
        cnn_feature_vect = cnn_feature_vect_old;
    else

        % should be in 0-255
        % if mean(im(:)) < 1, im = 255 * im; end
          
        [success, box_r0rfc0cf] = box_fix( box_r0rfc0cf, 'r0rfc0cf', [size(im,1) size(im,2)] );
        
        if ~success
            classifier_output=-1;
            return;
        end
        
        r0 = box_r0rfc0cf(:,1);
        rf = box_r0rfc0cf(:,2);
        c0 = box_r0rfc0cf(:,3);
        cf = box_r0rfc0cf(:,4);
        
        image_crop = im(r0:rf,c0:cf,:);

        cnn_feature_vect = cnn.cnn_process( image_crop );
        
        % make these new values the old values
        im_old = im;
        box_r0rfc0cf_old = box_r0rfc0cf;
        cnn_feature_vect_old = cnn_feature_vect;
        
    end
    
    model_ind = strcmp( classifier_struct.classes, target_class );
    classifier_output = [1 cnn_feature_vect'] * classifier_struct.models{model_ind};
    
    if classifier_output > 5 || classifier_output < -1.5
       warning(sprintf('classifiers.IOU_ridge_regression_apply is giving some extreme values: %f',classifier_output)); 
    end
  
end