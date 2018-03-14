
function rcnn_homebrew_test( )


    % im = imread( 'dogwalking1.jpg' );
    % im = imread( '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking401.jpg' );
    % im = imread( '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking402.jpg' );
    im = imread( '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking403.jpg' );

    box_area_ratios   = [];
    box_aspect_ratios = [];
    box_overlap_ratio = [];

    situation_struct = situate.situation_struct_load_all('dogwalking');
    num_objs = numel( situation_struct.situation_objects);

    split_data = situate.data_load_splits_from_directory('/Users/Max/Dropbox/Projects/situate/data_splits/dogwalking_validation/');
    training_fnames = split_data(1).fnames_lb_train;

    [ boxes_r0rfc0cf, class_assignments, confidences ] = rcnn_homebrew( im, [], [], [], training_fnames, situation_struct );


    % visualize result
    n = 5;
    figure;
    for oi = 1:num_objs

        obj_rows = eq( class_assignments, oi );
        temp_scores = confidences .* obj_rows;
        [~,sort_order] = sort( temp_scores, 'descend' );

        subplot2(1,num_objs,1,oi);
        imshow(im);
        title(situation_struct.situation_objects{oi});
        hold on;
        draw_box( boxes_r0rfc0cf( sort_order(1:n), : ), 'r0rfc0cf' );
        hold off;

    end
    
end


