function inds_keep = non_max_supression( boxes, box_scores, IOU_suppression_threshold, box_format )
% inds_suppress = non_max_supression( boxes, box_scores, IOU_suppression_threshold, box_format );

    go_again = true;
    while go_again
        go_again = false;
        for bi = 1:size(boxes,1)
            iou_vect = intersection_over_union( boxes(bi,:), boxes, box_format, box_format );
            overlap_box_inds = iou_vect > IOU_suppression_threshold;
            if all( box_scores( overlap_box_inds ) <= box_scores(bi) )
                suppress_inds = setsub( find(overlap_box_inds), bi );
                if any( box_scores( suppress_inds ) ~= 0 )
                    box_scores( suppress_inds ) = 0;
                    go_again = true;
                end

            end
        end
    end
    inds_keep = gt( box_scores, 0 );
    
end


