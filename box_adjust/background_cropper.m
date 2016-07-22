function [] = background_cropper(id,object,base_image,x,y,w,h,folder,boxes)
    % test_folder = '/stash/mm-group/evan/crop_learn/data/fullset/test/';
    % training_folder = '/stash/mm-group/evan/crop_learn/data/fullset/training/';
    baseFile = id;
    dim = size(base_image);
    im_x = dim(2);
    im_y = dim(1);
    width_max = min(3*w,im_x*0.3);
    height_max = min(3*h,im_y*0.3);
    width_min = min(w*0.5,im_x*0.05);
    height_min = min(h*0.5,im_y*0.05);


    % x_range = (1400-800).*rand(500,1) + 800;
    % y_range = (400).*rand(500,1);

    x_range = (im_x-(im_x*0.41)).*rand(500,1);
    y_range = (im_y-(im_y*0.41)).*rand(500,1); 

    w_range = (width_max-width_min).*rand(500,1)+width_min;
    h_range = (height_max-height_min).*rand(500,1)+height_min;

    crops = 1;
    idx = 1;
    tidx = 1;
    while crops < 5
        crop_box = [x_range(idx),y_range(idx),w_range(idx),h_range(idx)];
        overlap = 0;
        for ii = 1:numel(boxes)
            x1 = crop_box(1); y1 = crop_box(2); w1 = crop_box(3); h1 = crop_box(4);
            x2 = boxes{ii}(1); y2 = boxes{ii}(2); w2 = boxes{ii}(3); h2 = boxes{ii}(4);
            if (x1 < x2 + w2 && x1 + w1 >x2 && y1 < y2 + h2 && y1 + h1 > y2); 
            % if bboxOverlapRatio(crop_box,boxes{ii}) ~= 0
                overlap = 1;
                break
            end
        end
        if overlap == 0
            crop = imcrop(base_image,crop_box);
            filename = fullfile(folder,strcat(object,'background/',baseFile,'-background',num2str(crops),'.jpg'));
            imwrite(crop,filename);
            idx = idx +1;
            crops = crops + 1;
            continue
        end
        idx = idx +1;
        tidx = tidx +1;
        if idx == 500;
            x_range = (im_x-(im_x*0.41)).*rand(500,1);
            y_range = (im_y-(im_y*0.41)).*rand(500,1); 
            w_range = (width_max-width_min).*rand(500,1)+width_min;
            h_range = (height_max-height_min).*rand(500,1)+height_min;
            idx = 1;
        end
        if tidx == 1500;
            width_max = 55;
            width_min = 25;
            height_max = 55;
            height_min = 25;
            x_range = (im_x-55).*rand(500,1);
            y_range = (im_y-55).*rand(500,1);
            w_range = (width_max-width_min).*rand(500,1)+width_min;
            h_range = (height_max-height_min).*rand(500,1)+height_min;
            tidx = 1;
            idx = 1;
        end
    end
end



