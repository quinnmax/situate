
function d_r = situate_image_data_rescale( d, arg1, arg2 )

    % d_r = situate_image_data_rescale( image_data, linear_scaling_factor );
    % d_r = situate_image_data_rescale( image_data, new_rows, new_cols );
    %
    % this helps rescale bounding boxes for a rescaled image.
    %
    % 
    
    
    % if it's a struct array
    if length(d) > 1
        d_r = d;
        if nargin == 2 && length(arg1) == length(d)
            for di = 1:length(d)
                d_r(di) = situate_image_data_rescale( d(di), arg1(di) );
            end
        elseif nargin == 2 && length(arg1) == 1
            for di = 1:length(d)
                d_r(di) = situate_image_data_rescale( d(di), arg1 );
            end
        elseif nargin == 3 && length(arg1) == length(d) && length(arg2) == length(d)
            for di = 1:length(d)
                d_r(di) = situate_image_data_rescale( d(di), arg1(di), arg2(di) );
            end
        elseif nargin == 3 && length(arg1) == 1 && length(arg2) == 1
            for di = 1:length(d)
                d_r(di) = situate_image_data_rescale( d(di), arg1, arg2 );
            end
        else
            error('some size doesn''t match somewhere')
        end
        return
    end
    
    % if it's solo
    switch nargin
    
    
        case 2
             
            linear_scaling_factor = arg1;

            d_r = d;
            d_r.im_w  = linear_scaling_factor * d.im_w;
            d_r.im_h  = linear_scaling_factor * d.im_h;

            if isfield(d_r,'boxes'), 
                d_r.boxes = linear_scaling_factor * d_r.boxes;
            end
            
            if isfield(d_r,'boxes_xywh');
                d_r.boxes_xywh = linear_scaling_factor * d_r.boxes_xywh;
            end

            if isfield(d_r,'boxes_xcycwh');
                d_r.boxes_xcycwh = linear_scaling_factor * d_r.boxes_xcycwh;
            end

            if isfield(d_r,'boxes_r0rfc0cf');
                d_r.boxes_r0rfc0cf = linear_scaling_factor * d_r.boxes_r0rfc0cf;
            end
            
        case 3
          
            new_rows = arg1;
            new_cols = arg2;
            linear_scaling_factor = ( new_rows + new_cols ) / ( d.im_w + d.im_h );

            d_r = d;
            d_r.im_w  = new_cols;
            d_r.im_h  = new_rows;

            if isfield(d_r,'boxes');
                d_r.boxes = linear_scaling_factor * d_r.boxes;
            end

            if isfield(d_r,'boxes_xywh');
                d_r.boxes_xywh = linear_scaling_factor * d_r.boxes_xywh;
            end

            if isfield(d_r,'boxes_xcycwh');
                d_r.boxes_xcycwh = linear_scaling_factor * d_r.boxes_xcycwh;
            end

            if isfield(d_r,'boxes_r0rfc0cf');
                d_r.boxes_r0rfc0cf = linear_scaling_factor * d_r.boxes_r0rfc0cf;
            end
            
        otherwise
            
            error('needs 2 or 3 args');
    
    end
    
end
    
    





