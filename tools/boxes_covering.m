function [boxes_r0rfc0cf, params] = boxes_covering( imsize_rc, box_aspect_ratios, box_area_ratios, overlap_ratio )
% [boxes_r0rfc0cf, params] = boxes_covering( [im_rows im_cols], box_aspect_ratios, box_area_ratios, overlap_ratio );
% 
% params is [box aspect ratio, box area ratio] for each box

%     if nargin == 0
%         box_area_ratios = [.2 .4].^2; % .2 width of image, .4 width of image
%         box_aspect_ratios = [1/2 1/1 2/1];
%         overlap_ratio = .5;
%         imsize_rc = [1000 1000];
%         warning('boxes_covering had no args');
%     end
    
    rows = imsize_rc(1);
    cols = imsize_rc(2);
    
    boxes_r0rfc0cf = [];
    params = [];
    
    for bi = 1:length(box_area_ratios)
    for bj = 1:length(box_aspect_ratios)
        
        cur_area   = rows * cols * box_area_ratios(bi);
        cur_aspect = box_aspect_ratios(bj);
        [w,h] = box_aa2wh( cur_aspect, cur_area);
        w = round(w);
        h = round(h);
        
        step_w = round( w * (1-overlap_ratio) );
        step_h = round( h * (1-overlap_ratio) );
        
        r0s_temp = round( linspace(1, rows - h+1, round(rows/step_h) ) )';
        c0s_temp = round( linspace(1, cols - w+1, round(cols/step_w) ) )';
        
        r0s = sort(repmat( r0s_temp, size(c0s_temp,1), 1 ));
        c0s = repmat( c0s_temp, size(r0s_temp,1), 1 );
        
        rfs = r0s + h - 1;
        cfs = c0s + w - 1;
        
        cur_box_set = [r0s rfs c0s cfs];
        cur_params = repmat([cur_aspect, box_area_ratios(bi)], size(cur_box_set,1), 1 );
        
        if isempty(boxes_r0rfc0cf), boxes_r0rfc0cf = cur_box_set; else
        boxes_r0rfc0cf(end+1:end+size(cur_box_set,1),:) = cur_box_set; end
    
        if isempty(params), params = cur_params; else
        params(end+1:end+size(cur_params,1),:) = cur_params; end
            
    end
    end
    
    boxes_remove = ...
        boxes_r0rfc0cf(:,1) < 1    | ...
        boxes_r0rfc0cf(:,2) > rows | ...
        boxes_r0rfc0cf(:,3) < 1    | ...
        boxes_r0rfc0cf(:,4) > cols;
    
    boxes_r0rfc0cf(boxes_remove,:) = [];
    params(boxes_remove,:) = [];
    
end
        