function class_boxes = find_boxes( boxes, scores, class, nms_threshold, score_threshold )

    class_boxes = [boxes(:, (1+(class-1)*4):(class*4)), scores(:, class)];
    class_boxes = class_boxes(nms(class_boxes, nms_threshold), :);
    class_boxes = class_boxes(class_boxes(:, 5) >= score_threshold, :);
    class_boxes = num2cell(class_boxes, 2);
    class_boxes = map(class_boxes, @faster_rcnn.RectLTRB2LTWH);
end

