function [fnames_lb_train_pass, fnames_lb_train_fail, error_list] = situate_validate_training_data( fnames_lb_train, p )
% [fnames_lb_train_pass, fnames_lb_train_fail, error_list] = situate_validate_training_data( fnames_lb_train, p );
%
%   checks to make sure all boxes are in bounds, and that the required
%   situaiton objects are all present in the ground truth labels

    image_data_initial = situate_image_data( fnames_lb_train );
    image_data = situate_image_data_label_adjust( image_data_initial, p );
    
    bonk_list = false(1,length(fnames_lb_train));
    error_list = cell(1,length(fnames_lb_train));
    for fi = 1:length(fnames_lb_train)
        
        try
            assert( all( ismember( p.situation_objects, image_data(fi).labels_adjusted ) ), 'not all situation objects present' );
            assert( all( image_data(fi).boxes_r0rfc0cf(:,1) >= 1 ), 'row_initial too low' );
            assert( all( image_data(fi).boxes_r0rfc0cf(:,2) <= image_data(fi).im_h ), 'row_final too high' );
            assert( all( image_data(fi).boxes_r0rfc0cf(:,3) >= 1 ), 'column_initial too low' );
            assert( all( image_data(fi).boxes_r0rfc0cf(:,4) <= image_data(fi).im_w ), 'column_final too high' );
            %assert( false, 'test bonk' );
        catch blerg
            error_list{fi} = blerg;
            bonk_list(fi)  = true;
        end

    end
    
    fnames_lb_train_pass = fnames_lb_train(~bonk_list);
    fnames_lb_train_fail = fnames_lb_train( bonk_list);
    error_list = error_list( bonk_list);
    
end
