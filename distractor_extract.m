
function sampled_boxes_r0rfc0cf = distractor_extract( im_rows, im_cols, box_rows, box_cols, n, boxes_r0rfc0cf_avoid )

    % sampled_boxes_r0rfc0cf = distractor_extract( im_rows, im_cols, box_rows, box_cols, n, boxes_r0rfc0cf_avoid );
    %
    % sampling some boxes in a manner that avoids some defined regions of
    % the image. this is for extracting distractor boxes from an image that
    % might contain targets that we should avoid
    %
    % im_rows, im_cols define the shape of the image
    % box_rows, box_cols define the size of the crop that we'll pull
    % n is the number of boxes to pull. probably just use 1
    % boxes_r0rfc0cf_avoid can be nx4, avoids all of them
    %
    % if there are no qualifying locations from which to sample, the
    % returned matrix will just have 0 rows. 
    
    if ~exist('boxes_r0rfc0cf_avoid','var') || isempty(boxes_r0rfc0cf_avoid)
        boxes_r0rfc0cf_avoid = zeros(0,4);
    end
    
    if ~exist('n','var') || isempty(n)
        n = 1;
    end
    
    good_locations = true( im_rows, im_cols);
    % block the edges
    good_locations(end-box_rows+1:end,:) = false;
    good_locations(:,end-box_cols+1:end) = false;
    
    for bi = 1:size(boxes_r0rfc0cf_avoid,1)
        % get bounds to block for this box
        % we'll be sampling [r0 c0], so keep that in mind
        r0 = boxes_r0rfc0cf_avoid(bi,1) - box_rows;
        rf = boxes_r0rfc0cf_avoid(bi,2);
        c0 = boxes_r0rfc0cf_avoid(bi,3) - box_cols;
        cf = boxes_r0rfc0cf_avoid(bi,4);
        r0 = max(r0,1);
        rf = min(rf,im_rows);
        c0 = max(c0,1);
        cf = min(cf,im_cols);
        good_locations(r0:rf,c0:cf) = false;
    end
    
    % now see if there are any good locations left
    if ~any( good_locations(:) )
        sampled_boxes_r0rfc0cf = zeros(0,4);
        return;
    end
    
    % sample an r0, c0 location
    r0sc0s = sample_2d( good_locations, n );
    r0s = r0sc0s(:,1);
    rfs = r0s + box_rows - 1;
    c0s = r0sc0s(:,2);
    cfs = c0s + box_cols - 1;
    
    sampled_boxes_r0rfc0cf = [r0s rfs c0s cfs];
    
end
    
    
    
    








