function models = create_cnn_svm_models( training_images, p )
%UNTITLED Summary of this function goes here
    

    p.use_nn_model = false;


    for type = 1:numel(p.situation_objects)
        disp(['Creating CNN-SVM model for ' p.situation_objects{type}]);

        [positive, negative] = situate_crop_extractor(training_images, p.situation_objects(type), p, 3);
        positive = [positive{:}];
        negative = [negative{:}];
        
        data = [cnn_features(negative); cnn_features(positive)];
        labels = [map(1:numel(negative), @(x) 'neg') map(1:numel(positive), @(x) 'pos')];

%         feature_vectors = pca(data, 'NumComponents', 2000);
%         data = data * feature_vectors;

        if p.use_nn_model
            labels = +strcmp(labels, 'pos');
            nn_model = fitnet([500, 100]);
            nn_model = train(nn_model,data',labels);%,'useParallel','yes','useGPU','yes');
            models{type, 1} = nn_model;
        else
            svm_model = fitcsvm(data, labels, 'Standardize', 'on');
            svm_model = fitSVMPosterior(svm_model);
            models{type, 1} = svm_model.compact;
        end
%         models{type, 2} = feature_vectors;
    end
    
    fnames_lb_train = training_images;
    %save(['saved_models_cnn_svm/cnnsvm_' num2str(now) '.mat'], 'models', 'fnames_lb_train');
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
