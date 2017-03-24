function models = create_cnn_svm_models( training_images, p )
% models = create_cnn_svm_models( training_images, p )

    for type = 1:numel(p.situation_objects)
        disp(['Creating CNN-SVM model for ' p.situation_objects{type}]);

        [positive, negative] = situate_crop_extractor(training_images, p.situation_objects(type), p, 3);
        positive = [positive{:}];
        negative = [negative{:}];
        
        data = [cnn_features(negative); cnn_features(positive)];
        labels = [map(1:numel(negative), @(x) 'neg') map(1:numel(positive), @(x) 'pos')];

        svm_model = fitcsvm(data, labels, 'Standardize', 'on');
        svm_model = fitSVMPosterior(svm_model);
        models{type, 1} = svm_model.compact;
    end
    
end

function data = cnn_features( images )
    % data = cell2mat(map(images, @(x) cnn.cnn_process(x)))';
    data = cell(1,length(images));
    for i = 1:length(images)
        data{i} = cnn.cnn_process(images{i});
        progress(i,length(images),'extracting CNN features');
    end
    data = cell2mat(data)';
end
