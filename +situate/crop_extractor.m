function [positives, negatives] = crop_extractor(fname, p, target_object, num_negs_per_image)
       % [positives, negatives] = crop_extractor(fname, p, target_object, num_negs_per_image);
       %
       % both positives and negaties will be returned in cell arrays
       % the negatives will be the same size as the first target crop and will be
       % non-intersecting with the specified target
       
        persistent fname_saved
        persistent im_saved
        persistent im_data_saved
        
        if isequal(fname, fname_saved)
            im = im_saved;
            im_data = im_data_saved;
        else
            use_resize = false;
            [im_data,im] = situate.load_image_and_data( fname, p, use_resize );
            im_saved = im;
            im_data_saved = im_data;
            fname_saved = fname;
        end
        
        
        target_box_inds = find(strcmp( target_object, im_data.labels_adjusted ));
        if isempty(target_box_inds), error('target not in image'); end
        positives = cell(1,length(target_box_inds));
        target_boxes_r0rfc0cf = im_data.boxes_r0rfc0cf(target_box_inds,:);
        for bi = length(target_box_inds):-1:1
            r0 = target_boxes_r0rfc0cf(bi,1);
            rf = target_boxes_r0rfc0cf(bi,2);
            c0 = target_boxes_r0rfc0cf(bi,3);
            cf = target_boxes_r0rfc0cf(bi,4);
            positives{bi} = im(r0:rf,c0:cf,:);
        end
        
        % make a grid of possible negatives that's the same size as the
        % target box
        box_w = cf-c0+1;
        box_h = rf-r0+1;
        neg_rcs = round(linspace( box_h/2, im_data.im_h-box_h/2, 10 ));
        neg_ccs = round(linspace( box_w/2, im_data.im_w-box_w/2, 10 ));
        
        neg_r0s = floor(neg_rcs - box_h/2) + 1;
        neg_c0s = floor(neg_ccs - box_w/2) + 1;
        neg_r0rfc0cf = zeros(length(neg_r0s)*length(neg_c0s),4);
        ni = 1;
        for ri = 1:length(neg_r0s)
        for ci = 1:length(neg_c0s)
            neg_r0rfc0cf(ni,1) = neg_r0s(ri);
            neg_r0rfc0cf(ni,2) = neg_r0s(ri) + box_h - 1;
            neg_r0rfc0cf(ni,3) = neg_c0s(ci);
            neg_r0rfc0cf(ni,4) = neg_c0s(ci) + box_w - 1;
            ni = ni + 1;
        end
        end
        
        % see the iou between the proposed boxes and the target box
        % cull any intersecting boxes
        neg_ious = zeros(size(neg_r0rfc0cf,1),1);
        for ni = 1:size(neg_r0rfc0cf,1)
            neg_ious(ni) = intersection_over_union(neg_r0rfc0cf(ni,:),target_boxes_r0rfc0cf,'r0rfc0cf');
        end
        
%         figure
%         imshow(im);
%         hold on
%         draw_box(target_box_r0rfc0cf,'r0rfc0cf','red');
%         draw_box(neg_r0rfc0cf,'r0rfc0cf','blue');
        
        % randomize the order, and return crops from the requested number
        % of them
        neg_r0rfc0cf( neg_ious>0, : ) = [];
        neg_r0rfc0cf = neg_r0rfc0cf( randperm(size(neg_r0rfc0cf,1)), : );
        
        negatives = cell(1,num_negs_per_image);
        for ni = 1:num_negs_per_image
            r0 = neg_r0rfc0cf(ni,1);
            rf = neg_r0rfc0cf(ni,2);
            c0 = neg_r0rfc0cf(ni,3);
            cf = neg_r0rfc0cf(ni,4);
            negatives{ni} = im(r0:rf,c0:cf,:);
        end
       
end