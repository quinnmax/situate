function [data, boxes_adjusted, bonk_list ] = situate_gather_image_statistics( fnames_lb )

    % [data, boxes_adjusted, bonk_list ] = situate_gather_image_statistics( fnames_lb );
    %
    % collects orientation, aspect ratio, area ratio, location information
    % for all bounding boxes in the provided fnames


   
    
% get image data, and restructure

    image_data = situate_image_data(fnames_lb);
    data = struct();
    data = repmat(data,length(image_data),1);
    bonk_list = [];
    for i = setdiff(1:length(image_data),bonk_list)

        try
        
        % note, in image_data, 
        % box centers (and hence, object locations), are based on an 
        % image that has been centered at origin and has unit area. 
        % These numbers are small and not based on the size of the image any more. 
        % area_ratio is the only thing that relates the box to the size of the original image

        data(i).im_w = image_data(i).im_w;
        data(i).im_h = image_data(i).im_h;

        data(i).file_name_label     = image_data(i).file_name_label;

        ind_dog                     = find(image_data(i).is_dog);
        data(i).orientation_dog     = image_data(i).orientations{ind_dog};
        data(i).aspect_ratio_dog    = image_data(i).box_aspect_ratio(ind_dog);
        data(i).area_ratio_dog      = image_data(i).box_area_ratio(ind_dog);
        data(i).location_dog        = image_data(i).box_centers(ind_dog,:);
        data(i).w_normed_dog        = sqrt( data(i).area_ratio_dog * data(i).aspect_ratio_dog );
        data(i).h_normed_dog        = data(i).area_ratio_dog / data(i).w_normed_dog;
        data(i).box_raw_xywh_dog    = image_data(i).boxes(ind_dog,:);
        
        ind_person                  = find(image_data(i).is_ped);
        data(i).orientation_person  = image_data(i).orientations{ind_person};
        data(i).aspect_ratio_person = image_data(i).box_aspect_ratio(ind_person);
        data(i).area_ratio_person   = image_data(i).box_area_ratio(ind_person);
        data(i).location_person     = image_data(i).box_centers(ind_person,:);
        data(i).w_normed_person     = sqrt( data(i).area_ratio_person * data(i).aspect_ratio_person );
        data(i).h_normed_person     = data(i).area_ratio_person / data(i).w_normed_person;
        data(i).box_raw_xywh_person = image_data(i).boxes(ind_person,:);
        
        ind_leash                   = find(image_data(i).is_leash);
        data(i).orientation_leash   = image_data(i).orientations{ind_leash};
        data(i).aspect_ratio_leash  = image_data(i).box_aspect_ratio(ind_leash);
        data(i).area_ratio_leash    = image_data(i).box_area_ratio(ind_leash);
        data(i).location_leash      = image_data(i).box_centers(ind_leash,:);
        data(i).w_normed_leash      = sqrt( data(i).area_ratio_leash * data(i).aspect_ratio_leash );
        data(i).h_normed_leash      = data(i).area_ratio_leash / data(i).w_normed_leash;
        data(i).box_raw_xywh_leash  = image_data(i).boxes(ind_leash,:);
        
        catch
            bonk_list = [bonk_list i];
            continue
        end
        
    end
    
    if exist('bonk_list','var') && ~isempty(bonk_list)
        display('Bonk List');
        for i = bonk_list
            display( image_data(i).file_name_label );
        end
    end
    
% adjust boxes for images with unit area, centered at 0,0
%   boxes are still in xywh format (not centers)

    boxes_dog    = cell2mat({data.box_raw_xywh_dog}');
    boxes_person = cell2mat({data.box_raw_xywh_person}');
    boxes_leash  = cell2mat({data.box_raw_xywh_leash}');
    im_w = [data.im_w]';
    im_h = [data.im_h]';
    scalar = 1 ./ sqrt( im_w .* im_h );
    boxes_adjusted.dog    = repmat(scalar,1,4) .* [ boxes_dog(   :,1) - im_w/2, boxes_dog(   :,2) - im_h/2, boxes_dog(   :,3), boxes_dog(   :,4) ];
    boxes_adjusted.person = repmat(scalar,1,4) .* [ boxes_person(:,1) - im_w/2, boxes_person(:,2) - im_h/2, boxes_person(:,3), boxes_person(:,4) ];
    boxes_adjusted.leash  = repmat(scalar,1,4) .* [ boxes_leash( :,1) - im_w/2, boxes_leash( :,2) - im_h/2, boxes_leash( :,3), boxes_leash( :,4) ];
 
end
    
    