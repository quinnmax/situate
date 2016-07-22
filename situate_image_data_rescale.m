
function d_r = situate_image_data_rescale( d, arg1, arg2 )

    % d_r = situate_image_data_rescale( d, linear_scaling_factor );
    % d_r = situate_image_data_rescale( d, new_rows, new_cols );
    %
    % this helps rescale bounding boxes for a rescaled image.
    %
    % d is 

    if nargin < 1
        
        display('situate_image_data_rescale is in demo mode.');

        fname_im  = 'dogwalking1.jpg';
        fname_lb = [fname_im(1:end-4) '.labl'];

        im   = imread(fname_im);
        d = situate_image_data(fname_lb);

        figure();

        subplot(1,2,1);
        imshow(im);
        hold on;
        plot(d.box_centers(:,2),d.box_centers(:,1),'or');
        draw_box(d.boxes,'xywh');
        hold off;

        rescale_size_px = 100000;
        im_r = imresize_px(im,rescale_size_px); 

        linear_scaling_factor = ( size(im_r,1) + size(im_r,2) ) / ( d.im_w + d.im_h );
        d_r = d;
        d_r.boxes = d_r.boxes * linear_scaling_factor;
        d_r.im_w = size(im_r,2);
        d_r.im_h = size(im_r,1);
        d_r.box_centers = d_r.box_centers * linear_scaling_factor;

        subplot(1,2,2);
        imshow(im_r);
        hold on;
        plot(d_r.box_centers(:,2),d_r.box_centers(:,1),'or');
        draw_box(d_r.boxes, 'xywh');
        hold off;
        
    elseif nargin < 2 || nargin > 3
        
        display('situate_image_data_rescale needs 2 or 3 args.');

    elseif nargin == 2

        linear_scaling_factor = arg1;

        d_r = d;
        d_r.boxes = linear_scaling_factor * d_r.boxes;
        d_r.im_w  = linear_scaling_factor * d.im_w;
        d_r.im_h  = linear_scaling_factor * d.im_h;
    
    elseif nargin == 3

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
        
    end
    
    





