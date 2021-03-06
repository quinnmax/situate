

function inds_supress = non_max_supression( boxes, box_scores, IOU_suppression_threshold, box_format )
% inds_supress = non_max_supression( boxes, box_scores, IOU_suppression_threshold, box_format );

    if ~exist('IOU_supression_threshold','var') || isempty(IOU_suppression_threshold)
        IOU_suppression_threshold = .25;
    end

    % want to use 0 as the floor
    box_scores = box_scores - min(box_scores(:));
    box_scores_initial = box_scores;
    
    go_again = true;
    while go_again
        go_again = false;
        for bi = 1:size(boxes,1)
            iou_vect = intersection_over_union( boxes(bi,:), boxes, box_format, box_format );
            overlap_box_inds = iou_vect > IOU_suppression_threshold;
            % if all intersecting boxes have lower scores (or equal)
            if all( box_scores( overlap_box_inds ) <= box_scores(bi) )
                % mark everything but this box for supression
                suppress_inds = setsub( find(overlap_box_inds), bi );
                if any( box_scores( suppress_inds ) ~= 0 )
                    % if we actually do supress something, go again
                    box_scores( suppress_inds ) = 0;
                    go_again = true;
                end

            end
        end
    end
    
    inds_supress = ~eq( box_scores_initial, box_scores ) | ~( box_scores_initial > 0 );
    
end
