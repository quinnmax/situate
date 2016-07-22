function [dvar, class_prediction] = situate_hog_svm_apply( model, image, b_xywh )

%[dvar, class_prediction] = situate_hog_svm_apply( model, image, box_xywh );

    if exist('b_xywh','var') && ~isempty(b_xywh)
        image_in = image;
        r0 = b_xywh(2);
        rf = r0 + b_xywh(4) - 1;
        c0 = b_xywh(1);
        cf = c0 + b_xywh(3) - 1;
        image = image_in(r0:rf,c0:cf,:);
    end

    features = extractHOGFeatures( imresize( image,[100 100] ) );
    [class_prediction,posteriors] = predict(model,features);
    dvar = posteriors(2);
    
end