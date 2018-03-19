
function rcnn_homebrew_test( )

    situation = 'handshaking';
    
    switch situation
        case 'dogwalking'

            % im = imread( 'dogwalking1.jpg' );
            % im = imread( '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking401.jpg' );
            % im = imread( '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking402.jpg' );
            im = imread( '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking403.jpg' );

            split_data = situate.data_load_splits_from_directory('/Users/Max/Dropbox/Projects/situate/data_splits/dogwalking_validation/');
            training_fnames = split_data(1).fnames_lb_train;

        case 'handshaking'
            
            im = {};
            im{1} = imread('/Users/Max/Documents/MATLAB/data/situate_images/Handshaking_train/handshake401.jpg');
            im{2} = imread('/Users/Max/Documents/MATLAB/data/situate_images/Handshaking_train/handshake402.jpg');
            im{3} = imread('/Users/Max/Documents/MATLAB/data/situate_images/Handshaking_train/handshake403.jpg');
            im{4} = imread('/Users/Max/Documents/MATLAB/data/situate_images/Handshaking_train/handshake404.jpg');
            im{5} = imread('/Users/Max/Documents/MATLAB/data/situate_images/Handshaking_train/handshake405.jpg');
            
            split_data = situate.data_load_splits_from_directory('/Users/Max/Dropbox/Projects/situate/data_splits/handshaking_validation/');
            training_fnames = split_data(1).fnames_lb_train;
            
    end
    
    situation_struct = situate.situation_struct_load_all(situation);
    num_objs = numel( situation_struct.situation_objects);

    box_area_ratios   = [ 1/16 1/9 1/4 ];
    box_aspect_ratios = [  1/2 1/1 2/1 ];
    box_overlap_ratio = .5;

    if ~iscell(im)
        im = {im};
    end
    
    for imi = 1:5
    %for imi = 1:length(im)
        
        use_nonmax_suppression = true;
        show_viz = true;
        [ boxes_r0rfc0cf, class_assignments, confidences ] = ...
            rcnn_homebrew( ...
            im{imi}, box_area_ratios, box_aspect_ratios, box_overlap_ratio, training_fnames, situation_struct, ...
            use_nonmax_suppression, show_viz );
        
    end

end


