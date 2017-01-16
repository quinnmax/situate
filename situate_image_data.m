


function data = situate_image_data( label_file_name )


    % data = situate_image_data( label_file_name );
    %     data.labels_raw = labels_raw;
    % 
    %     data.boxes_xywh             = boxes_xywh;
    %     data.boxes_xcycwh           = boxes_xcycwh;
    %     data.boxes_r0rfc0cf         = boxes_r0rfc0c0f;
    %     
    %     % normalized boxes are for images assumed to be zero centered and
    %     % unit area
    %     data.boxes_normalized_xywh      = boxes_normalized_xywh;
    %     data.boxes_normalized_xcycwh    = boxes_normalized_xcycwh;
    %     data.boxes_normalized_r0rfc0cf  = boxes_normalized_r0rfc0cf;
    % 
    %     data.box_area_ratio = box_area_ratio;
    %     data.box_aspect_ratio = box_aspect_ratio;
    % 
    %     data.im_w = im_w;
    %     data.im_h = im_h;
    % 
    %     data.fname_lb = label_file_name;

    
    % if it's a cell, recursively apply to each entry
        if iscell(label_file_name)
            data = cellfun( @situate_image_data, label_file_name );
            return
        end
        
    % if it's a jpeg, look for the labl file matching it
        if strcmp('jpg',label_file_name(end-2:end))
            label_file_name = [label_file_name(1:end-3) 'labl'];
        end
    
    % get label information
        fid = fopen( label_file_name );
        specification_string = fgetl(fid);
        spec = strsplit( specification_string, '|' );
        fclose(fid);
        
     % gather image info
        im_w = str2double( spec{1} );
        im_h = str2double( spec{2} );
        
    % loop through for box specifications
        num_boxes = str2double( spec{3} );
        si = 4; % start index for the box specifications
        boxes_xywh              = zeros(num_boxes,4);
        boxes_r0rfc0c0f         = zeros(num_boxes,4);
        boxes_xcycwh            = zeros(num_boxes,4);
        
        boxes_normalized_xywh       = zeros(num_boxes,4);
        boxes_normalized_r0rfc0cf	= zeros(num_boxes,4);
        boxes_normalized_xcycwh     = zeros(num_boxes,4);
        
        box_area_ratio          = zeros(num_boxes,1);
        box_aspect_ratio        = zeros(num_boxes,1);
        for bi = 1:num_boxes
            
            x = str2double( spec{si+0} );
            y = str2double( spec{si+1} );
            w = str2double( spec{si+2} );
            h = str2double( spec{si+3} );
            
            assert(w>1);
            assert(h>1);
            
            boxes_xywh(bi,:) = [x y w h];
            
            xc = x + w/2;
            yc = y + h/2;
            boxes_xcycwh(bi,:) = [xc yc w h];
            
            r0 = max(y,1);
            rf = min(y+h,im_h);
            c0 = max(x,1);
            cf = min(x+w,im_w);
            boxes_r0rfc0c0f(bi,:) = [r0 rf c0 cf];
            
            r = sqrt(1/(im_w*im_h));
            
            boxes_normalized_xywh(bi,:)     = r * ([x y w h] - [im_w/2 im_h/2 0 0]);
            boxes_normalized_xcycwh(bi,:)   = r * ([xc yc w h] - [im_w/2 im_h/2 0 0]);
            boxes_normalized_r0rfc0cf(bi,:) = r * ([r0 rf c0 cf] - [im_h/2 im_h/2 im_w/2 im_w/2]);
            
            box_area_ratio(bi) = (w*h) / (im_w*im_h);
            box_aspect_ratio(bi) = w/h;
            
            si = si + 4; % iterate for the next box
            
        end
        
    % gather box labels
        labels_raw = spec( end-num_boxes+1 : end );
        
    % return the data
        data.labels_raw = labels_raw;
        
        data.boxes_xywh             = boxes_xywh;
        data.boxes_xcycwh           = boxes_xcycwh;
        data.boxes_r0rfc0cf         = boxes_r0rfc0c0f;
        data.boxes_normalized_xywh      = boxes_normalized_xywh;
        data.boxes_normalized_xcycwh    = boxes_normalized_xcycwh;
        data.boxes_normalized_r0rfc0cf  = boxes_normalized_r0rfc0cf;
        
        data.box_area_ratio = box_area_ratio;
        data.box_aspect_ratio = box_aspect_ratio;
        
        data.im_w = im_w;
        data.im_h = im_h;
        
        data.fname_lb = label_file_name;
        
end



















