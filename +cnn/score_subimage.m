function score = score_subimage( image, subimage_xywh, model_ind, d, p )

%     persistent im image_features;
%     if ~isequal(image, im)
%         im = image;
%         image = floor(256 * image);
%         image_features = cnn.cnn_process(image, [256, 256]);
%     end
%     subimage_features = cnn.subimage_cnn_features(image_features, subimage_xywh, size(image), [7, 7]);
    subimage = floor(256 * image( ...
        subimage_xywh(2):(subimage_xywh(2)+subimage_xywh(4)-1), ...
        subimage_xywh(1):(subimage_xywh(1)+subimage_xywh(3)-1), :));
    subimage_features = cnn.cnn_process(subimage);
    subimage_features = subimage_features(:)';

%     if size( d(model_ind).learned_stuff.cnn_svm_models.models, 2) > 1
%         feature_vectors = d(model_ind).learned_stuff.cnn_svm_models.models{model_ind, 2};
%         subimage_features = subimage_features * feature_vectors;
%     end
    
    model = d(model_ind).learned_stuff.cnn_svm_models.models{model_ind, 1};
    [~, scores] = predict(model, subimage_features);
    score = scores(2);
    
end

