
function joint_dists = situate_build_joint_distribution( fnames_lb, p )

    image_data = situate_image_data( fnames_lb );
    image_data = situate_image_data_label_adjust( image_data, p );
    
    objects_indexing_order = p.situation_objects;
   
    boxes_xywh = cell(1,length(objects_indexing_order));
    for oi = 1:length(objects_indexing_order)
        boxes_xywh{oi} = zeros( length(image_data), 4 );
    end

    for imi = 1:length(image_data)

        cur_labels     = image_data(imi).labels_adjusted;
        cur_boxes_xywh = image_data(imi).boxes_normalized_xywh;
        
        for oi = 1:length(objects_indexing_order)
            
            cur_object = objects_indexing_order(oi);
            cur_ind = find(strcmp(cur_object,cur_labels),1,'first');
            if isempty(cur_ind), error('object not found'); end
            boxes_xywh{oi}(imi,:) = cur_boxes_xywh(cur_ind,:);
            cur_labels(cur_ind) = [];
            cur_boxes_xywh(cur_ind,:) = [];
        
        end
        
    end

    xcyc_data = [];
    wh_data   = [];
    aa_data   = [];
    log_aa_data = [];
    for oi = 1:length(objects_indexing_order)
        x  = boxes_xywh{oi}(:,1);
        y  = boxes_xywh{oi}(:,2);
        w  = boxes_xywh{oi}(:,3);
        h  = boxes_xywh{oi}(:,4);
        xc = x + w/2;
        yc = y + h/2;
        aspect = w ./ h;
        area   = w .* h;
        
        xcyc_data   = [xcyc_data   xc yc ];
        wh_data     = [wh_data     w  h  ];
        aa_data     = [aa_data     aspect area];
        log_aa_data = [log_aa_data log2(aspect) log10(area)];
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




