


% grab data from a finished situate_gui run

    assert( logical(exist( 'scout_record','var')) )
    assert( logical(exist( 'image_data_test','var' )) )

    im = imresize_px( imread( [image_data_test(1).file_name_label(1:end-5) '.jpg'] ), p.image_redim_px );

    im_d = situate_image_data_rescale( image_data_test(1), sqrt(p.image_redim_px / (image_data_test(1).im_w*image_data_test(1).im_h) ) );
    im_d.im_w = size(im,2);
    im_d.im_h = size(im,1);
    im_d.boxes = round(im_d.boxes);

% remove the empties

    empty_inds = cellfun( @isempty, scout_record.interest);
    scout_record.interest(empty_inds) = [];
    scout_record.box_area_ratio(empty_inds) = [];
    scout_record.box_aspect_ratio(empty_inds) = [];
    scout_record.internal_support(empty_inds) = [];
    scout_record.box_r0rfc0cf(empty_inds,:) = [];

% take a look at the boxes that we came up with

    epsilon_log_area_ratio = .25;

    figure

    subplot(1,3,1);
    cur_gt_ind = strcmp( im_d.object_types, 'dog' );
    scout_inds = logical( ...
        strcmp( scout_record.interest, 'dog' ) ...
        .* le( abs( log(scout_record.box_area_ratio) - log(im_d.box_area_ratio(cur_gt_ind))), epsilon_log_area_ratio ) ...
        );

    imshow( .5 * im );
    hold on
    if any(scout_inds)
        draw_box_r0rfc0cf( scout_record.box_r0rfc0cf( scout_inds, :), 'b' );
    end
    draw_box_xywh( im_d.boxes(cur_gt_ind,:), 'r' );

    subplot(1,3,2);
    cur_gt_ind = strcmp( im_d.object_types, 'leash' );
    scout_inds = logical( ...
        strcmp( scout_record.interest, 'leash' ) ...
        .* le( abs( log(scout_record.box_area_ratio) - log(im_d.box_area_ratio(cur_gt_ind))), epsilon_log_area_ratio ) ...
        );

    imshow( .5 * im  );
    hold on
    if any(scout_inds)
        draw_box_r0rfc0cf( scout_record.box_r0rfc0cf( scout_inds, :), 'b' );
    end
    draw_box_xywh( im_d.boxes(cur_gt_ind,:), 'r' );


    subplot(1,3,3);
    cur_gt_ind = strcmp( im_d.object_types, 'dog-walker' );
    scout_inds = logical( ...
        strcmp( scout_record.interest, 'person' ) ...
        .* le( abs( log(scout_record.box_area_ratio) - log(im_d.box_area_ratio(cur_gt_ind))), epsilon_log_area_ratio ) ...
        );

    imshow( .5 * im  );
    hold on
    if any(scout_inds)
        draw_box_r0rfc0cf( scout_record.box_r0rfc0cf( scout_inds, :), 'b' );
    end
    draw_box_xywh( im_d.boxes(cur_gt_ind,:), 'r' );








