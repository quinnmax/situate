function [predictions, dvars] = hog_svm_model_apply( input, hog_svm_model )

% [predictions, dvars] = hog_svm_model_apply( image_fname_cell_array, hog_svm_model );
% [predictions, dvars] = hog_svm_model_apply( image_fname,            hog_svm_model );
% [predictions, dvars] = hog_svm_model_apply( image,                  hog_svm_model );

    if iscell(input)
        % apply to each entry in the cell array with recursive call
        predictions = zeros(1,length(input));
        dvars = zeros(1,length(input));
        for i = 1:length( input )
            [predictions(i), dvars(i)] = hog_svm_model_apply( input{i}, hog_svm_model );
        end
        return;
    elseif ischar(input)
        % load up the image, again, make recursive call
        [predictions, dvars] = hog_svm_model_apply( imread(input), hog_svm_model );
        return;
    else
        image = input;
    end
    
    if max(image(:)) > 1, image = double(image)/255; end
    display([size(image,1), size(image,2), size(image,1)*size(image,2)]);
    
    log2_aspect = log2( size(image,2) / size(image,1) );
    [~,model_to_use_idx] = min( abs( hog_svm_model.log2_w_over_h - log2_aspect ) );
    
    image_r = imresize( image, hog_svm_model.im_sizes( model_to_use_idx, : ) );
    
    hog_features = extractHOGFeatures( image_r );
    
    [predictions, dvars_temp] = hog_svm_model.svm_structs{model_to_use_idx}.predict( hog_features );
    dvars = dvars_temp(:,2);
    
end