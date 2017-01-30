function [im,im_data] = load_image_and_data( fname_in, p )

    [path,file,ext] = fileparts(fname_in);
    switch ext
        case '.jpg'
            im_fname = fname_in;
            lb_fname = fullfile(path, [file '.labl']);
        case '.labl'
            lb_fname = fname_in;
            im_fname = fullfile(path, [file '.jpg']);  
    end
    
    im_in = double(imread(im_fname))/255;
    im = imresize_px(im_in, p.image_redim_px);
    
    im_data_a = situate.image_data(lb_fname);
    im_data_b = situate.image_data_label_adjust( im_data_a, p);
    im_data   = situate.image_data_rescale( im_data_b, size(im,1), size(im,2) );

end