function data = subimage_cnn_features( cnn_features, subimage_xywh, image_size, output_size )
%SUBIMAGE_CNN_FEATURES Gets the features of a subimage of an image with
%precomputed CNN features.
    image_size = fliplr(image_size(1:2));
    lower_left = subimage_xywh(1:2) ./ image_size(1:2);
    input_size = (subimage_xywh(3:4)-1) ./ image_size(1:2);
    output_size(3) = size(cnn_features, 3);
    
    data = zeros(output_size);
    resolution = size(cnn_features);
    for x = 1:output_size(1)
        for y = 1:output_size(2)
            cLL = ceil((lower_left + input_size.*[x-1, y-1]./output_size(1:2)) .* resolution(1:2));
            cUR = ceil((lower_left + input_size.*[x, y]./output_size(1:2)) .* resolution(1:2));
            for z = 1:output_size(3)
                data(x,y,z) = max(max( cnn_features(cLL(1):cUR(1), cLL(2):cUR(2), z:z) ));
            end
        end
    end
end

