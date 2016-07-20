function box, boxes = sample_proposal( boxes, is_sample, is_replacement )
%SAMPLE_PROPOSALS Picks a single box from the proposal list

    if nargsin < 2
        is_sample = false;
    end
    if nargsin < 3
        is_replacement = false;
    end

    if ~is_sample
        box_id = 1;
    else
        box_id = randsample(size(boxes, 1), 1, true, boxes(:, 5));
    end
    box = boxes(box_id, 1:4);
    
    if ~is_replacement
        index = true(1, size(boxes, 1));
        index(box_id) = false;
        boxes = boxes(index, :);
    end
    
end

