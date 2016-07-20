function model = hog_svm_model_train( training_images_cell, training_image_labels, parameters_struct )

% model = hog_svm_model_train( training_images_cell, training_iamge_labels, parameters_struct );
%
%   training_images_cell should be a cell of file names for now
%       should support actual image crops in the future
%   training_image_labels are booleans
%   parameters_struct should be
%       parameters_struct.im_resize_px   = [10000];
%       parameters_struct.shape_clusters = [3];
%
%   model contains
%       model.log2_w_over_h: the log2 aspect ratios that this model is looking for
%       model.im_sizes: the hard sizes that images will be resized to during classification
%       svm_structs: the svm structs that will be used to make predictions
%
% see also
%   hog_svm_model_train_situate_data.m




    if ~exist('training_images_cell','var') || isempty(training_images_cell)
        dir_dog = '/Users/Max/Documents/MATLAB/data/petacat_images/crops/dogs/';
        temp = dir([dir_dog '*.jpg']);
        fnames_dog = cellfun(@(x) [dir_dog x], {temp.name}, 'UniformOutput', false );
        
        dir_dog_distractors = '/Users/Max/Documents/MATLAB/data/petacat_images/crops/dist_dogs/';
        temp = dir([dir_dog_distractors '*.jpg']);
        fnames_dog_distractors = cellfun(@(x) [dir_dog_distractors x], {temp.name}, 'UniformOutput', false );
        
        training_images_cell = [fnames_dog fnames_dog_distractors];
        training_image_labels = [true(length(fnames_dog),1); false(length(fnames_dog_distractors),1)];
    end
    
    if ~exist('parameters_struct','var') || isempty(parameters_struct)
        parameters_struct.im_resize_px = 10000;
        parameters_struct.shape_clusters = 3;
    end
    
    % figure out the sizing model
    
        model = [];

        image_info_data = cellfun(@(x) imfinfo(x), training_images_cell );
        im_widths = [image_info_data.Width];
        im_heights = [image_info_data.Height];
        im_log2_w_over_h = log2( im_widths ./ im_heights );
        [aspect_ratio_cluster_assignments,model.log2_w_over_h] = ...
            kmeans( reshape(im_log2_w_over_h,[],1), parameters_struct.shape_clusters );

        cols = round( sqrt( 2.^model.log2_w_over_h * parameters_struct.im_resize_px ) );
        rows = round( parameters_struct.im_resize_px ./ cols );

        model.im_sizes = [rows cols];
        
    % load images and resize to resize targets
        hog_data = cell(1,parameters_struct.shape_clusters);
        hog_data_labels = cell(1,parameters_struct.shape_clusters);
        for i = 1:length(training_images_cell)
            cur_image = imread( training_images_cell{i} );
            cur_image = double(cur_image) / 255;
            cur_cluster_assignment_idx = aspect_ratio_cluster_assignments(i);
            cur_image = imresize( cur_image, model.im_sizes( cur_cluster_assignment_idx,: ) );
            hog_data{cur_cluster_assignment_idx}(end+1,:) = extractHOGFeatures( cur_image );
            hog_data_labels{cur_cluster_assignment_idx}(end+1) = training_image_labels(i);
        end
        
        model.svm_structs = cell(1,parameters_struct.shape_clusters);
        for i = 1:parameters_struct.shape_clusters
            model.svm_structs{i} = fitcsvm( hog_data{i},hog_data_labels{i} );
            model.svm_structs{i} = model.svm_structs{i}.fitPosterior();
        end
        
        model.target_label = training_image_labels;
        
        
        
        % to apply
        % get an image
        % get it's aspect ratio
        % see which available aspect ratio it is closest to
        % reshape it to the associated size (hard resize)
        % get hog features from the resized image
        % send to the associated svm for that image shape
        
        % or
        
        % to apply
        % get an image
        % resize to each of the known shapes (hard resize)
        % get hog features for each
        % send hog features to their associated svms
        % return the max confidence of positive classification
        
end
            
            
            
            
            
            
    
    
    
    


    
    