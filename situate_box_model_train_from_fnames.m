

function conditional_models_structure = situate_box_model_train_from_fnames( fnames )

% conditional_models_structure = situate_box_model_train_from_fnames( fnames );


    if ~exist('fnames','var') || isempty(fnames)
        
        warning('situate_box_model_train_from_fnames:demo_warning','situate_box_model_train_from_fnames is using a full demo directory to build models');
        data_path = '/Users/Max/Documents/MATLAB/data/petacat_images/PortlandSimpleDogWalking/';
        d = dir([ data_path '*.labl' ]);
        fnames_no_path = {d.name};
        fnames = cellfun( @(x) [data_path x], fnames_no_path, 'UniformOutput', false );
    
    end



    image_data = situate_image_data(fnames);
    
    data = struct();
    data = repmat(data,length(image_data),1);

    for i = 1:length(image_data)

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
        
    end
    
% adjust boxes for unit area, centered at 0,0 for training purposes
%   boxes are now in xcycwh format (centers of boxs)

    boxes_dog    = cell2mat({data.box_raw_xywh_dog}');
    boxes_person = cell2mat({data.box_raw_xywh_person}');
    boxes_leash  = cell2mat({data.box_raw_xywh_leash}');
    im_w = [data.im_w]';
    im_h = [data.im_h]';
    scalar = 1 ./ sqrt( im_w .* im_h );
    boxes_adjusted_dog    = repmat(scalar,1,4) .* [ boxes_dog(:,1)    - im_w/2, boxes_dog(:,2)    - im_h/2, boxes_dog(:,3),    boxes_dog(:,4)    ];
    boxes_adjusted_person = repmat(scalar,1,4) .* [ boxes_person(:,1) - im_w/2, boxes_person(:,2) - im_h/2, boxes_person(:,3), boxes_person(:,4) ];
    boxes_adjusted_leash  = repmat(scalar,1,4) .* [ boxes_leash(:,1)  - im_w/2, boxes_leash(:,2)  - im_h/2, boxes_leash(:,3),  boxes_leash(:,4)  ];
    
    


    boxes_adjusted_dog_train    = boxes_adjusted_dog;
    boxes_adjusted_person_train = boxes_adjusted_person;
    boxes_adjusted_leash_train  = boxes_adjusted_leash;




% build the models
%
%   boxes are provided in xywh format (based on images that are unit area and centered at 0) 
%   but the model produces centers and w,h data
%
%   this has a bunch of redundancy, but who cares. the thing you're looking
%   for is more likely to be where you look. they're all static, so it's no
%   biggie.

    dog_index    = 1;
    person_index = 2;
    leash_index  = 3;
    none_index   = 4;

    models = cell(3,4,4);

    for target_ind = [dog_index person_index leash_index]
    for box_a_ind  = [dog_index person_index leash_index none_index]
    for box_b_ind  = [dog_index person_index leash_index none_index]

        switch target_ind
            case 1, target_data_train = boxes_adjusted_dog_train;
            case 2, target_data_train = boxes_adjusted_person_train;
            case 3, target_data_train = boxes_adjusted_leash_train;
        end

        switch box_a_ind
            case 1, box_a_data_train = boxes_adjusted_dog_train;
            case 2, box_a_data_train = boxes_adjusted_person_train;
            case 3, box_a_data_train = boxes_adjusted_leash_train;
            case 4, box_a_data_train = [];
        end

        switch box_b_ind
            case 1, box_b_data_train = boxes_adjusted_dog_train;
            case 2, box_b_data_train = boxes_adjusted_person_train;
            case 3, box_b_data_train = boxes_adjusted_leash_train;
            case 4, box_b_data_train = [];
        end

        models{target_ind, box_a_ind, box_b_ind} =  box_model_train( target_data_train, box_a_data_train, box_b_data_train );

    end
    end
    end

    conditional_models_structure.models = models;
    conditional_models_structure.dog_index    = dog_index;
    conditional_models_structure.person_index = person_index;
    conditional_models_structure.leash_index  = leash_index;
    conditional_models_structure.none_index   = none_index;
    conditional_models_structure.models_object_indexing = {'dog','person','leash','none'};
  
end




    
    
    
    
    
    
    
    
    
    
    
    
    






