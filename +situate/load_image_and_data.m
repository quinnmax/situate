function [im_data,im] = load_image_and_data( fname_in, p, use_resize )

    % [im_data,im] = load_image_and_data( fname_in, p, use_resize );
    % [im_data]    = load_image_and_data( fname_in, p, use_resize );
    %   just loads the image data
    %
    % if use_resize, resizes to p.image_redim_px

    persistent prev_fname_in;
    persistent prev_p;
    persistent prev_use_resize;
    persistent prev_im_data;
    persistent prev_im;
    
    if ~exist('use_resize','var') || isempty(use_resize)
        if isempty(p.image_redim_px) || p.image_redim_px == 0
            use_resize = false;
        elseif p.image_redim_px > 0
            use_resize = true;
        end
    end
    
    % see if we can get away with returning last times stuff
    if isequal(prev_fname_in, fname_in) ...
    && isequal(prev_p,p) ...
    && isequal( prev_use_resize, use_resize )
        if nargout == 1 ...
        && ~isempty(prev_im_data)
            im_data = prev_im_data; 
            return; 
        end
        
        if nargout > 1 ...
        && ~isempty(prev_im_data) ...
        && ~isempty(prev_im)
            im_data = prev_im_data; 
            im = prev_im; 
            return; 
        end    
    end
    
    
    % if it's a cell, just call on each entry
    if iscell(fname_in)
        im      = cell(1,length(fname_in));
        im_data = [];
        for ci = 1:length(fname_in)
            if nargout >= 2
                [cur_im_data, cur_im] = situate.load_image_and_data(fname_in{ci},p,use_resize);
                im{ci} = cur_im;
            else
                cur_im_data = situate.load_image_and_data(fname_in{ci},p,use_resize);
            end
            im_data{ci} = cur_im_data;
        end
        im_data = [im_data{:}];
        return;
    end
    
    
    
    [path,file,ext] = fileparts(fname_in);
    switch ext
        case '.jpg'
            im_fname = fname_in;
            lb_fname = fullfile(path, [file '.labl']);
        case '.labl'
            lb_fname = fname_in;
            im_fname = fullfile(path, [file '.jpg']);  
    end
    
    if ~exist('use_resize','var') || isempty(use_resize)
        if p.image_redim_px == 0 || isempty(p.image_redim_px)
            use_resize = false;
        elseif p.image_redim_px > 0
            use_resize = true;
        end
    end
    
    % do we load the image?
    if nargout >= 2
        im_in = imread(im_fname);
        if use_resize
            im = imresize_px(im_in, p.image_redim_px);
        else
            im = im_in;
        end
    end
    
    % get the image data
    if exist(lb_fname,'file')
        im_data = situate.image_data(lb_fname);
        if exist('p','var') && ~isempty(p)
            im_data.situation_objects = p.situation_objects;
            im_data.situation_objects_possible_labels = p.situation_objects_possible_labels;
            im_data = situate.image_data_label_adjust( im_data, p);
        end
    else
        im_data = [];
    end
    
    % do we need to resize the image data?
    if use_resize && ~isempty(im_data)
        % want to do this without needing to load the actual image, in case
        % it's just the data being pulled
        
        warning('off','MATLAB:imagesci:tifftagsread:numDirectoryEntriesIsZero');
        image_info = imfinfo(im_fname);
        warning('on','MATLAB:imagesci:tifftagsread:numDirectoryEntriesIsZero');
        
        rows = image_info.Height;
        cols = image_info.Width;
        
        if ~isempty(p.image_redim_px)
            ratio = sqrt( p.image_redim_px / (rows*cols) );
            new_rows = round( rows * ratio );
            new_cols = round( cols * ratio );
            im_data   = situate.image_data_rescale( im_data, new_rows, new_cols );
        end
        
    end
    
    % hang on to the last call's info
    prev_fname_in = fname_in;
    prev_p = p;
    prev_use_resize = use_resize;
    prev_im_data = im_data;
    if exist('im','var')
        prev_im = im;
    end
       
end