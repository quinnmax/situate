
function [crops_target, crops_negative] = situate_crop_extractor( fname_lb, target_label, parameters_struct, num_negatives )

    % [crops_pos_cell, crops_neg_cell] = situate_crop_extractor( label_file_name, target_label, parameters_struct, num_negatives );
    %   crops_pos_cell will contain each crop matchingthe target label
    %   crops_neg_cell will contain negatives matchine the size of the
    %   positive crops. there must be at least one positive crop
    %
    % [crops_pos_cell_per_input_image, crops_neg_cell_per_input_image] = situate_crop_extractor( label_file_cell_array, parameters_struct, num_negatives );
    %   will apply to each label file in the label_file_cell_array, adding
    %   a layer of nesting to the output cell
    
    iou_limit = .05;
    
    if iscell(fname_lb)
        
        crops_target   = cell(1,length(fname_lb));
        crops_negative = cell(1,length(fname_lb));
        for i = 1:length(fname_lb)
            [crops_target{i}, crops_negative{i}] = situate_crop_extractor( fname_lb{i}, target_label, parameters_struct, num_negatives );
        end
        return;
        
    end
    
    image_data_initial = situate_image_data( fname_lb );
    image_data = situate_image_data_label_adjust( image_data_initial, parameters_struct );
    
    persistent fname_im % avoid reopening the same image several times, if we can
    persistent image
    if ~strcmp( fname_im, [fname_lb(1:end-4) 'jpg'] )
        fname_im = [fname_lb(1:end-4) 'jpg'];
        image = imread( fname_im );
    end
       
    % grab the positive boxes
    inds_target = find(strcmp( target_label, image_data.labels_adjusted ));
    crops_target = cell(1,length(inds_target));
    for i = 1:length(inds_target)
        bi = inds_target(i);
        r0 = image_data.boxes_r0rfc0cf(bi,1);
        rf = image_data.boxes_r0rfc0cf(bi,2);
        c0 = image_data.boxes_r0rfc0cf(bi,3);
        cf = image_data.boxes_r0rfc0cf(bi,4);
        crops_target{i} = image(r0:rf,c0:cf,:);
    end
    
    % make a lot of proposal boxes for the negative class for each positive
    % box that was found
    boxes_negative_xywh = zeros(0,4);
    for bi = inds_target
        n = 100 * num_negatives; % provisional boxes per target box
        w = image_data.boxes_xywh(bi,3);
        h = image_data.boxes_xywh(bi,4);
        x = randi( max(1,image_data.im_w - w), [n,1] );
        y = randi( max(1,image_data.im_h - h), [n,1] );
        boxes_negative_xywh(end+1:end+n,:) = [x y repmat(w,n,1) repmat(h,n,1)];
    end
    
    % check the IOU scores of the proposals, cull boxes
    iou_scores = intersection_over_union( image_data.boxes_xywh(inds_target,:), boxes_negative_xywh, 'xywh' );
    boxes_negative_xywh( iou_scores >= iou_limit, : ) = [];
    rp = randperm(size(boxes_negative_xywh,1));
    boxes_negative_xywh = boxes_negative_xywh( rp(1:min(num_negatives,length(rp))), : );
    
    % pull the negative crops
    crops_negative = cell(1,size(boxes_negative_xywh,1));
    for bi = 1:size(boxes_negative_xywh,1)
        x = boxes_negative_xywh(bi,1);
        y = boxes_negative_xywh(bi,2);
        w = boxes_negative_xywh(bi,3);
        h = boxes_negative_xywh(bi,4);
        r0 = max( 1, y );
        rf = min( r0 + h - 1, size(image,1) );
        c0 = max( 1, x );
        cf = min( c0 + w - 1, size(image,2) );
        crops_negative{bi} = image(r0:rf,c0:cf,:);
    end
    
end
    
    
    
    
    
    
    
    
    
    