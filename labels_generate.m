function result = labels_generate( in, h )

    % labels_generate( image_file_name );
    % labels_generate( directory );
    % labels_generate( cell_array_of_image_file_names );
    %
    % gui for labeling objects in images. 
    % resulting files have same name as image, but with .json ext.
    % if a directory is provided, will loop through each image in the directory that does not have an associated .json label file. 
    
    
    %% routing stuff
    if ~exist('h','var') || isempty(h) || ~ishandle(h)
        h = figure();
    end

    if isdir(in)
        dir_data = dir(fullfile(in, '*.jpg'));
        dir_data = dir_data(~[dir_data.isdir]);
        fnames = fullfile( in, {dir_data.name} );
        
        % remove fnames that already have label files
        labels_exist = cellfun( @(x) exist( strrep( x, '.jpg', '.json' ), 'file' ), fnames );
        
        in = fnames(~labels_exist);
    end
    
    if iscell( in )
        for imi = 1:length(in)
            result = labels_generate( in{imi}, h );
            if isequal( result, 'stop' )
                return;
            end
        end
        close(h);
        return;
    end

    
    %% real function
    
    figure(h);
    im = imread(in);
    imshow( im );
    hold on;
    
    user_boxes_xywh = zeros(0,4);
    user_labels = {};
    
    result = 'carryon';
    
    while true

        try
            [x1, y1, button] = ginput(1);
            if button == 27, break; end
            dot_handle = plot(x1,y1,'o');
            [x2, y2, button] = ginput(1);
            if button == 27, break; end
        catch
            % we get here if they close the window
            result = 'stop';
            break;
        end
        
        % assign initial and final
        x0 = min([x1, x2]);
        xf = max([x1, x2]);
        y0 = min([y1, y2]);
        yf = max([y1, y2]);
        
        % restrict to within image bounds
        x0 = max([x0,1]);
        xf = min([xf,size(im,2)]);
        y0 = max([y0,1]);
        yf = min([yf,size(im,1)]);
       
        % show the box
        w = abs(xf - x0 + 1);
        h = abs(yf - y0 + 1);
        draw_box( [x0 y0 w h], 'xywh', 'color', get(dot_handle,'Color') );

        % get user label
        user_label = inputdlg('label for new box');
        
        user_boxes_xywh(end+1,:) = round([x0 y0 w h]);
        user_labels(end+1) = user_label;
        
    end
    if ishandle(h)
        hold off;
    end
   
    if ~isempty(user_labels)
        write_label_file( user_boxes_xywh, user_labels, in );
    end
  
    
end
    
    
function [] = write_label_file( boxes_xywh, labels, fname_in )

    info = imfinfo(fname_in);

    label_struct = [];
    label_struct.im_w = info.Width;
    label_struct.im_h = info.Height;
    label_struct.objects = [];
    for bi = 1:length(labels)
        label_struct.objects(bi).desc = labels{bi};
        label_struct.objects(bi).box_xywh = boxes_xywh(bi,:);
    end

    json_text = jsonencode( label_struct );

    fname_out = strrep( fname_in, '.jpg', '.json' );
    fid = fopen(fname_out,'w+');
    fwrite( fid, json_text );
    fclose(fid);
     
end










