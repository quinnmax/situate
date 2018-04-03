function [] = rcnn_boxes_vizualize(im_fnames)


    if isempty(im_fnames)
        im_fnames = { ...
            '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking1.jpg', ...
            '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking2.jpg', ...
            '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking3.jpg', ...
            '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking4.jpg', ...
            '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking5.jpg'};
            warning('using default images');
    end
    if ischar( im_fnames )
        im_fnames = {im_fnames};
    end
        
    lb_fnames = cellfun( @(x) [fileparts_mq(x, 'path/name') '.json'], im_fnames,'UniformOutput',false );
    
    situation_struct = situate.situation_struct_load_all('dogwalking');
    
    csv_directory = 'rcnn box data/';
    
    workspaces = cell(1,length(im_fnames));
    imported_data = cell(1,length(im_fname));
    
    for imi = 1:length(im_fnames)
        [workspaces{imi}, imported_data{imi}] = csvs2workspace( csv_directory, im_fnames{imi}, situation_struct );
    end
    
    for imi = 1:length(im_fnames)
        figure;
        
        subplot(1,3,1);
        situate.labl_draw(lb_fnames{imi},situation_struct);

        subplot(1,3,2);
        imshow(imread(im_fnames{imi})); hold on;
        for oi = 1:3
            draw_box( imported_data{imi}{oi}(1:5,1:4), 'xywh' );
        end

        subplot(1,3,3);
        situate.workspace_draw(im_fnames{imi},situation_struct,workspaces{imi});
    end
    
end
        
    
    

    