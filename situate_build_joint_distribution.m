
function joint_dists = situate_build_joint_distribution( fnames_lb, p )

    image_data_temp = situate_image_data( fnames_lb );
    image_data = situate_image_data_label_adjust( image_data_temp, p );
   
    objects_indexing_order = p.situation_objects;
   
    all_boxes_xcycwh_normalized = cell2mat({image_data.boxes_normalized_xcycwh}');
    all_labels = [image_data.labels_adjusted];

    % gather and reformat data
    xcyc_data   = [];
    wh_data     = [];
    aa_data     = [];
    log_aa_data = [];
    for oi = 1:length(p.situation_objects)
        cur_object = p.situation_objects{oi};
        cur_inds   = strcmp( cur_object, all_labels );
        cur_boxes_xcycwh_normalized  = all_boxes_xcycwh_normalized( cur_inds, : );
        cur_xcyc = cur_boxes_xcycwh_normalized(:,1:2);
        cur_wh   = cur_boxes_xcycwh_normalized(:,3:4);
        cur_aspect_ratio = cur_wh(:,1) ./ cur_wh(:,2);
        cur_area_ratio = cur_wh(:,1) .* cur_wh(:,2); % since they've already been normalized for an image of unit area, no denominator needed

        xcyc_data   = [xcyc_data   cur_xcyc ];
        wh_data     = [wh_data     cur_wh  ];
        aa_data     = [aa_data     cur_aspect_ratio cur_area_ratio];
        log_aa_data = [log_aa_data log2(cur_aspect_ratio) log10(cur_area_ratio)];
    end

    % build the joint distributions
    
        joint_dists = [];

        joint_dists.mu_xcyc         = mean(xcyc_data);
        joint_dists.Sigma_xcyc      = cov( xcyc_data);

        joint_dists.mu_wh           = mean(wh_data);
        joint_dists.Sigma_wh        = cov(wh_data);

        joint_dists.mu_log_wh       = mean(log(wh_data));
        joint_dists.Sigma_log_wh    = cov(log(wh_data));

        joint_dists.mu_aa           = mean(aa_data);
        joint_dists.Sigma_aa        = cov(log(aa_data));

        joint_dists.mu_log_aa       = mean(log_aa_data);
        joint_dists.Sigma_log_aa    = cov(log_aa_data);

        joint_dists.objects_indexing_order = objects_indexing_order;
        joint_dists.fnames_lb_train = fnames_lb;

    
end




